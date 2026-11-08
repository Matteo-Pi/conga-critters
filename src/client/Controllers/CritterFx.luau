--!strict
-- CritterFx: run-ins, eating, joins, loose critters, snips, delivery pops (spec 9.2).
-- C01-M2: the bait arc, the puff when a throw is rejected, and each critter's arrival (spec 4.1, 4.2 Arrival):
--   bait lands (landAt) -> runs in from `from` (RunInSeconds) -> eats (EatSeconds) -> the server adds it at joinAt
--   -> hops to the owner's back (HopSeconds) and vanishes.
-- Following arrives with LineRenderer in C01-M3; until then a joined critter disappears into the line.
-- Times are server times (workspace:GetServerTimeNow), so every client plays the same arrival at the same moment.
--
-- There is no reply to ThrowBait (spec 9.4), so a rejection shows as a bait that no CritterSpawned matched within
-- RejectGraceSeconds (plus the ping) of landing: it vanishes in a small puff (spec 4.1).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)

local TAG = "[CritterFx]"
local localPlayer = Players.LocalPlayer

local CritterFx = {}

type Bait = {
	Part: BasePart,
	Origin: Vector3,
	Target: Vector3,
	ThrownAt: number,
	LandAt: number,
	Deadline: number,
	Own: boolean,
	Matched: boolean,
	RemoveAt: number?,
}

type Critter = {
	Id: number,
	OwnerId: number,
	Own: boolean,
	Species: string,
	Rank: number,
	Color: Color3,
	Variant: number,
	Model: Model?,
	BottomOffset: number,
	From: Vector3,
	Stop: Vector3,
	To: Vector3,
	LandAt: number,
	BaitLandedAt: number, -- for logs: when this client saw the bait land
	JoinAt: number,
	Phase: string, -- "wait", "run", "eat", "hop"
	HopFrom: Vector3?,
	RanInAt: number?,
	AteAt: number?,
}

local fxFolder: Folder? = nil
local templates: Instance? = nil
local baits: { Bait } = {}
local critters: { Critter } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function log(message: string)
	if Config.Debug.LogThrows then
		print(`{TAG} {message}`)
	end
end

-- The client-only folder for effects (also excluded from aiming rays).
function CritterFx.Folder(): Folder
	local folder = fxFolder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientFx"
		folder.Parent = workspace
		fxFolder = folder
	end
	return folder
end

local function quietPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function ball(size: number, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	part.Material = material
	quietPart(part)
	return part
end

-- A sphere that grows and fades: the rejection puff and the rarity burst.
local function burst(
	position: Vector3,
	color: Color3,
	fromSize: number,
	toSize: number,
	seconds: number,
	startAlpha: number
)
	local part = ball(fromSize, color, Enum.Material.Neon)
	part.Transparency = startAlpha
	part.Position = position
	part.Parent = CritterFx.Folder()
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - started) / seconds, 0, 1)
		local size = fromSize + (toSize - fromSize) * a
		part.Size = Vector3.new(size, size, size)
		part.Position = position
		part.Transparency = startAlpha + (1 - startAlpha) * a
		if a >= 1 then
			connection:Disconnect()
			part:Destroy()
		end
	end)
end

local BAIT_COLOR = Color3.fromRGB(255, 214, 92)
local GOLDEN_BAIT_COLOR = Color3.fromRGB(255, 170, 0)
local BAIT_SIZE = 0.9

local function newBait(
	origin: Vector3,
	target: Vector3,
	golden: boolean,
	thrownAt: number,
	landAt: number,
	own: boolean
): Bait
	local part = ball(BAIT_SIZE, if golden then GOLDEN_BAIT_COLOR else BAIT_COLOR, Enum.Material.Neon)
	part.Position = origin
	part.Parent = CritterFx.Folder()
	local bait: Bait = {
		Part = part,
		Origin = origin,
		Target = target,
		ThrownAt = thrownAt,
		LandAt = landAt,
		Deadline = landAt + Config.Throw.RejectGraceSeconds + 2 * localPlayer:GetNetworkPing(),
		Own = own,
		Matched = not own,
		RemoveAt = nil,
	}
	table.insert(baits, bait)
	return bait
end

-- The local player threw: draw the arc at once (spec 4.1). The server's CritterSpawned confirms it.
function CritterFx.ThrowLocal(origin: Vector3, target: Vector3, golden: boolean): ()
	local t = now()
	newBait(origin, target, golden, t, t + Config.Throw.FlightSeconds, true)
end

-- Throws of ours still waiting for an answer, plus our critters on their way: THROW greys out when
-- LineLen + this reaches LineCap.
function CritterFx.PendingOwn(): number
	local count = 0
	for _, bait in baits do
		if bait.Own and not bait.Matched then
			count += 1
		end
	end
	local t = now()
	for _, critter in critters do
		if critter.Own and t < critter.JoinAt + 0.3 then
			count += 1
		end
	end
	return count
end

local function speciesModel(species: string): (Model?, number)
	local folder = templates
	local template = folder and folder:FindFirstChild(species)
	if not template or not template:IsA("Model") then
		return nil, 0
	end
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			quietPart(descendant)
		end
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottomOffset = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	return model, bottomOffset
end

local function tint(critter: Critter, t: number)
	local model = critter.Model
	if not model or critter.Variant == 0 then
		return
	end
	local color = if critter.Variant == 1 then Color3.fromRGB(255, 196, 40) else Color3.fromHSV((t * 0.5) % 1, 0.8, 1)
	local body = model.PrimaryPart
	if body then
		body.Color = color
		if critter.Variant == 1 then
			body.Material = Enum.Material.Foil
		end
	end
end

local function onCritterSpawned(data: any)
	if type(data) ~= "table" then
		return
	end
	local payload = data :: Net.CritterSpawnedPayload
	local def = Config.Critters.List[payload.species]
	if not def or typeof(payload.from) ~= "Vector3" or typeof(payload.to) ~= "Vector3" then
		return
	end
	local rarity = Config.Rarities.ById[def.Rarity]
	local own = payload.owner == localPlayer.UserId
	local landAt = payload.joinAt - Config.Throw.JoinDelay
	local baitLandedAt = landAt

	-- Match our own waiting bait by its landing point; anyone else's bait just appears where it lands.
	-- Unmatched baits first (oldest wins), then one already matched (several critters per throw share a bait).
	local matched: Bait? = nil
	if own then
		for pass = 1, 2 do
			for _, bait in baits do
				if bait.Own and bait.Matched == (pass == 2) and (bait.Target - payload.to).Magnitude < 0.5 then
					matched = bait
					break
				end
			end
			if matched then
				break
			end
		end
	end
	local eatEnd = landAt + Config.Throw.RunInSeconds + Config.Throw.EatSeconds
	if matched then
		matched.Matched = true
		matched.RemoveAt = math.max(matched.RemoveAt or 0, eatEnd)
		baitLandedAt = matched.LandAt
	else
		local bait = newBait(payload.to, payload.to, payload.bound, landAt, landAt, false)
		bait.Part.Parent = nil -- shown from landAt
		bait.RemoveAt = eatEnd
	end

	local direction = payload.to - payload.from
	local stop = if direction.Magnitude > 1.5 then payload.to - direction.Unit * 1.2 else payload.from

	local critter: Critter = {
		Id = payload.id,
		OwnerId = payload.owner,
		Own = own,
		Species = def.Id,
		Rank = rarity and rarity.Rank or 1,
		Color = rarity and rarity.Color or Color3.new(1, 1, 1),
		Variant = payload.variant,
		Model = nil,
		BottomOffset = 0,
		From = payload.from,
		Stop = stop,
		To = payload.to,
		LandAt = landAt,
		BaitLandedAt = baitLandedAt,
		JoinAt = payload.joinAt,
		Phase = "wait",
		HopFrom = nil,
		RanInAt = nil,
		AteAt = nil,
	}
	table.insert(critters, critter)
end

local function place(critter: Critter, position: Vector3, facing: Vector3)
	local model = critter.Model
	if not model then
		return
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local pivot = position + Vector3.new(0, critter.BottomOffset, 0)
	if flat.Magnitude > 0.01 then
		model:PivotTo(CFrame.lookAt(pivot, pivot + flat))
	else
		model:PivotTo(CFrame.new(pivot) * model:GetPivot().Rotation)
	end
end

local function ownerTail(critter: Critter): Vector3?
	local owner = Players:GetPlayerByUserId(critter.OwnerId)
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local back = root.Position - root.CFrame.LookVector * 3
	return Vector3.new(back.X, critter.To.Y, back.Z)
end

-- Returns false when the critter is finished.
local function stepCritter(critter: Critter, t: number): boolean
	local runEnd = critter.LandAt + Config.Throw.RunInSeconds
	local hopEnd = critter.JoinAt + Config.Throw.HopSeconds

	if t < critter.LandAt then
		return true
	end
	if not critter.Model then
		local model, bottomOffset = speciesModel(critter.Species)
		critter.Model = model
		critter.BottomOffset = bottomOffset
		if model then
			model.Parent = CritterFx.Folder()
		end
	end
	tint(critter, t)

	if t < runEnd then
		critter.Phase = "run"
		local a = (t - critter.LandAt) / Config.Throw.RunInSeconds
		local hop = math.abs(math.sin(a * math.pi * 6)) * 0.5
		place(critter, critter.From:Lerp(critter.Stop, a) + Vector3.new(0, hop, 0), critter.To - critter.From)
	elseif t < critter.JoinAt then
		if critter.Phase ~= "eat" then
			critter.Phase = "eat"
			critter.RanInAt = t
			if critter.Rank >= 2 or critter.Variant ~= 0 then
				burst(critter.Stop + Vector3.new(0, 1.5, 0), critter.Color, 1, 6 + critter.Rank * 2, 0.45, 0.25)
			end
		end
		local peck = math.abs(math.sin((t - runEnd) * math.pi * 5)) * 0.3
		place(critter, critter.Stop - Vector3.new(0, peck, 0), critter.To - critter.Stop)
	elseif t < hopEnd then
		if critter.Phase ~= "hop" then
			critter.Phase = "hop"
			critter.AteAt = t
			critter.RanInAt = critter.RanInAt or t
			critter.HopFrom = critter.Stop
		end
		local from = critter.HopFrom or critter.Stop
		local tail = ownerTail(critter) or from
		local a = (t - critter.JoinAt) / Config.Throw.HopSeconds
		local height = 4 * a * (1 - a) * 2.5
		place(critter, from:Lerp(tail, a) + Vector3.new(0, height, 0), tail - from)
	else
		if critter.Own then
			local base = critter.BaitLandedAt
			log(
				string.format(
					"#%d %s: bait landed %.3f; ran in +%.2f, ate +%.2f, joined +%.2f s (server join +%.2f)",
					critter.Id,
					critter.Species,
					base,
					(critter.RanInAt or t) - base,
					(critter.AteAt or t) - base,
					t - base,
					critter.JoinAt - base
				)
			)
		end
		if critter.Model then
			critter.Model:Destroy()
			critter.Model = nil
		end
		return false
	end
	return true
end

-- Returns false when the bait is finished.
local function stepBait(bait: Bait, t: number): boolean
	if t < bait.LandAt then
		local a = math.clamp((t - bait.ThrownAt) / math.max(bait.LandAt - bait.ThrownAt, 1e-3), 0, 1)
		local arc = Vector3.new(0, 4 * a * (1 - a) * Config.Throw.ArcHeight, 0)
		bait.Part.Position = bait.Origin:Lerp(bait.Target + Vector3.new(0, BAIT_SIZE / 2, 0), a) + arc
	else
		if not bait.Part.Parent then
			bait.Part.Parent = CritterFx.Folder()
		end
		bait.Part.Position = bait.Target + Vector3.new(0, BAIT_SIZE / 2, 0)
	end
	if bait.Own and not bait.Matched and t > bait.Deadline then
		log(string.format("bait puffed: no critter %.2f s after landing (throw rejected)", t - bait.LandAt))
		burst(bait.Part.Position, Color3.fromRGB(220, 220, 220), 0.8, 3, 0.3, 0.3)
		bait.Part:Destroy()
		return false
	end
	if bait.RemoveAt and t >= bait.RemoveAt then
		bait.Part:Destroy()
		return false
	end
	return true
end

function CritterFx.Init(): () end

function CritterFx.Start(): ()
	task.spawn(function()
		templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Critters")
	end)
	task.spawn(function()
		Net.Event(Net.Names.CritterSpawned).OnClientEvent:Connect(onCritterSpawned)
	end)
	RunService.RenderStepped:Connect(function()
		local t = now()
		for i = #baits, 1, -1 do
			if not stepBait(baits[i], t) then
				table.remove(baits, i)
			end
		end
		for i = #critters, 1, -1 do
			if not stepCritter(critters[i], t) then
				table.remove(critters, i)
			end
		end
	end)
end

export type CritterFx = typeof(CritterFx)

return CritterFx
