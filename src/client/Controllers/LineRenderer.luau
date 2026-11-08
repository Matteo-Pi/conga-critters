--!strict
-- LineRenderer: followers: paths, pools, level of detail, BulkMoveTo (spec 9.2, 9.5).
--
-- Line contents come from the server over LineSync (snapshot, append, removeFront, clear; one sequence number per
-- line, a gap asks again with RequestLineSync). Positions are this client's own: every simulation frame (Heartbeat)
-- it records each visible leader into its own Path, and every drawn frame (RenderStepped) it places the followers
-- from it. Recording on Heartbeat means a frame that isn't drawn leaves no gap in the path. Positions are only for
-- show (9.3); the server keeps its own paths for cuts.
--
-- Drawing:
--   * one pool of models per species, anchored, with CanCollide, CanTouch, CanQuery and CastShadow off, in
--     ClientFx/Lines (a client-only folder that aim rays already skip);
--   * every follower moved with one workspace:BulkMoveTo per frame (FireCFrameChanged);
--   * hop = |sin(t·ω + i·φ)| × h, scaled down while the leader stands still, plus a small side-to-side waddle;
--   * paths stay at ground height (Path.Locate); every jump, walking or standing, sends a hop wave down the line
--     (Render.JumpWave); each jump starts its own wave, so several can run down the line at once, and a follower
--     reached by two at the same moment takes the higher hop, not the sum. With Render.JumpHopAtSpot on (off by
--     default), followers also hop as they pass the take-off point (a hop marker);
--   * smoothing takes out sudden jumps in a follower's target (a delivery moving the line up, a snapshot) over about
--     3 / Smoothing s, so followers trace the path exactly while walking; jumps beyond SnapDistance snap;
--   * level of detail by distance from the local character: hop, waddle, colour cycling (and later particles)
--     within 80 studs; beyond that, flat and moved every FarUpdateEvery frames, and only when it has moved; hidden
--     beyond 200 (150 on phones); at most 900 drawn (350 on phones), own line first, then the nearest lines;
--   * a joining critter hops from its bait (CritterFx.ClaimArrival) into its place;
--   * a leader that streams out hides its line; its path starts again when it streams back in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local LineRules = require(Shared:WaitForChild("LineRules") :: ModuleScript)
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)
local Path = require(Shared:WaitForChild("Path") :: ModuleScript)

local CritterFx = require(script.Parent:WaitForChild("CritterFx") :: ModuleScript)

local localPlayer = Players.LocalPlayer
local Render = Config.Line.Render

local LineRenderer = {}

-- A pooled model of one species.
type Item = {
	Model: Model,
	Parts: { BasePart },
	Offsets: { CFrame }, -- each part relative to the pivot
	Bottom: number, -- pivot height above the model's lowest point
	Body: BasePart?,
	BodyColor: Color3,
	BodyMaterial: Enum.Material,
}

type Follower = {
	Packed: number,
	Species: number, -- wire index
	Variant: number,
	Item: Item?,
	Shown: Vector3?, -- last drawn ground position, without the hop; nil = snap next time
	Err: Vector3, -- shown − target, decaying to zero
	Facing: Vector3,
	GlideFrom: Vector3?,
	GlideStart: number,
	Placed: Vector3?, -- pivot position last sent to BulkMoveTo (far tier skips unchanged moves)
	PlacedFacing: Vector3,
	PathDist: number?, -- its path distance last frame, to see it pass a hop marker; nil = not drawn last frame
	JumpAt: number?, -- when its jump hop started
}

type View = {
	OwnerId: number,
	Seq: number,
	Followers: { Follower },
	Offsets: { number },
	Path: Path.Path?,
	Dirty: boolean, -- targets jumped (a sync op): turn the jump into a glide
	LastGround: Vector3?,
	Moving: number, -- 0 standing still … 1 walking
	Drawn: number,
	LeaderDistance: number,
	Root: BasePart?,
	Humanoid: Humanoid?,
	Waves: { number }, -- start times of the hop waves running down the line, oldest first (Render.JumpWave)
}

local views: { [number]: View } = {}
local pools: { [number]: { Item } } = {}
local templates: Instance? = nil
local linesFolder: Folder? = nil
local requestSync: RemoteEvent? = nil
local syncWanted = false
local lastRequestAt = -math.huge
local REQUEST_SECONDS = Net.RateLimits.RequestLineSync.Per + 0.1

-- Reused every frame.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local samplePos: { Vector3 } = {}
local sampleDir: { Vector3 } = {}
local order: { View } = {}
local frameNumber = 0

-- Stats for the debug bridge and the MicroProfiler check.
local stats = {
	Frames = 0,
	TotalMs = 0,
	MaxMs = 0,
	LastMs = 0,
	BulkMs = 0, -- total ms inside BulkMoveTo since the last reset
	JumpHops = 0, -- followers that passed a hop marker since the last reset
	HopMissMax = 0, -- studs (flat) between such a follower and its marker's point, at the frame it passed
	HopMissSum = 0,
	Events = {} :: { string }, -- take-offs and marker passes since the last reset (first 80), for the checks
	Drawn = 0,
	Parts = 0,
	Window = {} :: { number },
}

local function folder(): Folder
	local existing = linesFolder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Lines"
	created.Parent = CritterFx.Folder()
	linesFolder = created
	return created
end

local function isPhone(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

-- Pools ---------------------------------------------------------------------------------------------------------

local function newItem(speciesIndex: number): Item?
	local def = Config.Critters.List[speciesIndex]
	local source = templates
	local template = source and def and source:FindFirstChild(def.Id)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			table.insert(parts, descendant)
			table.insert(offsets, pivot:ToObjectSpace(descendant.CFrame))
		end
	end
	local body = model.PrimaryPart
	return {
		Model = model,
		Parts = parts,
		Offsets = offsets,
		Bottom = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2),
		Body = body,
		BodyColor = if body then body.Color else Color3.new(1, 1, 1),
		BodyMaterial = if body then body.Material else Enum.Material.Plastic,
	}
end

local function acquire(follower: Follower): Item?
	local pool = pools[follower.Species]
	local item = if pool and #pool > 0 then table.remove(pool) else newItem(follower.Species)
	if not item then
		return nil
	end
	local body = item.Body
	if body then
		if follower.Variant == 1 then
			body.Color = Color3.fromRGB(255, 196, 40)
			body.Material = Enum.Material.Foil
		else
			body.Color = item.BodyColor
			body.Material = item.BodyMaterial
		end
	end
	item.Model.Parent = folder()
	return item
end

local function release(follower: Follower)
	local item = follower.Item
	if not item then
		return
	end
	follower.Item = nil
	follower.Shown = nil
	follower.GlideFrom = nil
	follower.Placed = nil
	follower.PathDist = nil
	follower.JumpAt = nil
	item.Model.Parent = nil
	local pool = pools[follower.Species]
	if not pool then
		pool = {}
		pools[follower.Species] = pool
	end
	table.insert(pool, item)
end

-- Views ---------------------------------------------------------------------------------------------------------

local function newFollower(packed: number): Follower?
	local speciesIndex, variant = Net.UnpackCritter(packed)
	if not Config.Critters.List[speciesIndex] then
		return nil
	end
	return {
		Packed = packed,
		Species = speciesIndex,
		Variant = variant,
		Item = nil,
		Shown = nil,
		Err = Vector3.zero,
		Facing = -Vector3.zAxis,
		GlideFrom = nil,
		GlideStart = 0,
		Placed = nil,
		PlacedFacing = Vector3.zero,
		PathDist = nil,
		JumpAt = nil,
	}
end

local function rebuildOffsets(view: View)
	local followers = view.Followers
	Path.Offsets(#followers, function(i)
		return LineRules.Spacing(Config.Critters.List[followers[i].Species].Id)
	end, view.Offsets)
end

local function getView(ownerId: number): View
	local view = views[ownerId]
	if view then
		return view
	end
	local created: View = {
		OwnerId = ownerId,
		Seq = 0,
		Followers = {},
		Offsets = {},
		Path = nil,
		Dirty = false,
		LastGround = nil,
		Moving = 0,
		Drawn = 0,
		LeaderDistance = math.huge,
		Root = nil,
		Humanoid = nil,
		Waves = {},
	}
	views[ownerId] = created
	return created
end

local function dropView(ownerId: number)
	local view = views[ownerId]
	if not view then
		return
	end
	for _, follower in view.Followers do
		release(follower)
	end
	views[ownerId] = nil
end

local function hideView(view: View)
	for _, follower in view.Followers do
		release(follower)
	end
	view.Path = nil
	view.LastGround = nil
	view.Drawn = 0
end

-- LineSync ------------------------------------------------------------------------------------------------------

local function applySnapshot(view: View, entries: { number })
	-- Keep the followers of the unchanged front of the line (a cut leaves the victim's front as it was).
	local old = view.Followers
	local keep = 0
	while keep < #old and keep < #entries and old[keep + 1].Packed == entries[keep + 1] do
		keep += 1
	end
	for i = keep + 1, #old do
		release(old[i])
		old[i] = nil
	end
	for i = keep + 1, #entries do
		local follower = newFollower(entries[i])
		if follower then
			table.insert(old, follower)
		end
	end
	view.Dirty = true
	rebuildOffsets(view)
end

local function applyAppend(view: View, entries: { number })
	for _, packed in entries do
		local follower = newFollower(packed)
		if follower then
			local def = Config.Critters.List[follower.Species]
			local from = CritterFx.ClaimArrival(view.OwnerId, def.Id, follower.Variant)
			if from then
				follower.GlideFrom = from
				follower.GlideStart = os.clock()
			end
			table.insert(view.Followers, follower)
		end
	end
	rebuildOffsets(view)
end

local function applyRemoveFront(view: View, count: number)
	local followers = view.Followers
	local n = math.clamp(math.floor(count), 0, #followers)
	for i = 1, n do
		release(followers[i]) -- the pop at the pen arrives with delivery (C01-M4)
	end
	table.move(followers, n + 1, #followers + n, 1)
	view.Dirty = true
	rebuildOffsets(view)
end

local function onLineSync(data: any)
	if type(data) ~= "table" or type(data.userId) ~= "number" or type(data.seq) ~= "number" then
		return
	end
	local payload = data :: Net.LineSyncPayload
	local ownerId = payload.userId
	if payload.op == "snapshot" then
		local view = getView(ownerId)
		applySnapshot(view, payload.entries or {})
		view.Seq = payload.seq
		return
	end
	if payload.op == "clear" then
		dropView(ownerId)
		return
	end
	local view = views[ownerId]
	local expected = (if view then view.Seq else 0) + 1
	if payload.seq ~= expected then
		syncWanted = true -- a gap: ask for snapshots again
		return
	end
	local target = view or getView(ownerId)
	if payload.op == "append" then
		applyAppend(target, payload.entries or {})
	elseif payload.op == "removeFront" then
		applyRemoveFront(target, payload.count or 0)
	end
	target.Seq = payload.seq
end

-- Leaders -------------------------------------------------------------------------------------------------------

local function leaderOf(ownerId: number): (BasePart?, Humanoid?)
	-- A player first (Studio test players have negative ids too), then a debug leader.
	local player = Players:GetPlayerByUserId(ownerId)
	local model: Instance? = player and player.Character
	if not player and ownerId < 0 then
		local leaders = workspace:FindFirstChild(Config.Debug.LeadersFolderName)
		model = leaders and leaders:FindFirstChild(`{Config.Debug.LeaderNamePrefix}{-ownerId}`)
	end
	if not model then
		return nil, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, model:FindFirstChildOfClass("Humanoid")
end

-- Frame ---------------------------------------------------------------------------------------------------------

local function smoothstep(a: number): number
	return a * a * (3 - 2 * a)
end

local function drawView(view: View, t: number, dt: number, focus: Vector3, hideDistance: number, budget: number): number
	local followers = view.Followers
	local count = #followers
	local path = view.Path
	local root = view.Root
	if count == 0 or not path or not root then
		view.Dirty = false
		return 0
	end
	local head = Path.LiveHead(path, root, view.Humanoid)
	Path.Sample(path, head, view.Offsets, count, samplePos, sampleDir)
	local headDist = Path.FollowDistance(path, head)
	local pathOffsets = view.Offsets
	local hopDist = path.HopDist
	local hopAt = path.HopAt
	local markers = #hopDist
	local jumpSeconds = Render.JumpHopSeconds
	local jumpHeight = Render.JumpHopHeight
	-- A wave ends once it has passed the last follower; the oldest ends first.
	local waves = view.Waves
	local waveDelay = Render.JumpWaveDelay
	while #waves > 0 and t - waves[1] > count * waveDelay + jumpSeconds do
		table.remove(waves, 1)
	end
	local waveCount = #waves

	local decay = math.exp(-Render.Smoothing * dt)
	local hopScale = Render.IdleHop + (1 - Render.IdleHop) * view.Moving
	local hopHeight = Render.HopHeight * hopScale
	local waddle = math.rad(Render.WaddleDegrees) * hopScale
	local glideSeconds = Config.Throw.HopSeconds
	local dirty = view.Dirty
	local drawn = 0
	local fullDetail = Render.FullDetailDistance
	local farEvery = Render.FarUpdateEvery

	for i = 1, count do
		local follower = followers[i]
		local target = samplePos[i]
		local distance = (target - focus).Magnitude
		local visible = drawn < budget and distance <= hideDistance
		if not visible then
			if follower.Item then
				release(follower)
			end
			continue
		end
		local item = follower.Item or acquire(follower)
		if not item then
			continue
		end
		follower.Item = item
		drawn += 1

		-- Where to draw it, on the ground.
		local shown: Vector3
		local lift = 0
		local glideFrom = follower.GlideFrom
		if glideFrom then
			local a = (t - follower.GlideStart) / glideSeconds
			if a >= 1 then
				follower.GlideFrom = nil
				follower.Err = Vector3.zero
				shown = target
			else
				shown = glideFrom:Lerp(target, smoothstep(math.max(a, 0)))
				lift = 4 * a * (1 - a) * Render.JoinHopHeight
			end
		else
			local previous = follower.Shown
			if not previous then
				follower.Err = Vector3.zero
			elseif dirty then
				local jump = previous - target
				follower.Err = if jump.Magnitude > Render.SnapDistance then Vector3.zero else jump
			end
			follower.Err *= decay
			if follower.Err.Magnitude < 1e-3 then
				follower.Err = Vector3.zero
			end
			shown = target + follower.Err
		end
		follower.Shown = shown

		-- Jump hops (4.3): a follower that has just passed a hop marker starts its hop, which plays out in time, so a
		-- line that stops mid-hop still lands.
		local pathDist = headDist - pathOffsets[i]
		local previousDist = follower.PathDist
		if markers > 0 and previousDist and Render.JumpHopAtSpot then
			for k = 1, markers do
				local marker = hopDist[k]
				if previousDist < marker and marker <= pathDist then
					-- Backdated by the overshoot, so the arc starts at the marker even at a low frame rate.
					follower.JumpAt = t - dt * (pathDist - marker) / (pathDist - previousDist)
					local miss = Vector3.new(target.X - hopAt[k].X, 0, target.Z - hopAt[k].Z).Magnitude
					stats.JumpHops += 1
					stats.HopMissSum += miss
					stats.HopMissMax = math.max(stats.HopMissMax, miss)
					if #stats.Events < 80 then
						table.insert(
							stats.Events,
							string.format(
								"%.2f hop: line %d follower %d at (%.1f, %.1f), marker %.1f at (%.1f, %.1f), miss %.2f",
								t,
								view.OwnerId,
								i,
								target.X,
								target.Z,
								marker,
								hopAt[k].X,
								hopAt[k].Z,
								miss
							)
						)
					end
					break
				end
			end
		end
		follower.PathDist = pathDist
		local jumpAt = follower.JumpAt
		if jumpAt then
			local a = (t - jumpAt) / jumpSeconds
			if a >= 1 then
				follower.JumpAt = nil
			else
				lift += 4 * a * (1 - a) * jumpHeight
			end
		end
		if waveCount > 0 then
			local waveLift = 0
			for w = 1, waveCount do
				local a = (t - waves[w] - i * waveDelay) / jumpSeconds
				if a > 0 and a < 1 then
					waveLift = math.max(waveLift, 4 * a * (1 - a) * Render.JumpWaveHeight)
				end
			end
			lift += waveLift
		end

		-- Facing along the path; hop and waddle.
		local direction = sampleDir[i]
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 1e-3 then
			follower.Facing = flat.Unit
		end
		local far = distance > fullDetail
		local cframe: CFrame
		if far then
			-- Far tier: no hop or waddle; moved every FarUpdateEvery frames, and only when it has moved.
			local pivotPosition = shown + Vector3.new(0, item.Bottom + lift, 0)
			local placed = follower.Placed
			if placed and lift == 0 then
				if (frameNumber + i) % farEvery ~= 0 then
					continue
				end
				if (pivotPosition - placed).Magnitude < 0.01 and follower.Facing == follower.PlacedFacing then
					continue
				end
			end
			follower.Placed = pivotPosition
			follower.PlacedFacing = follower.Facing
			cframe = CFrame.lookAt(pivotPosition, pivotPosition + follower.Facing)
		else
			local phase = t * Render.HopSpeed + i * Render.HopPhase
			local hop = math.abs(math.sin(phase)) * hopHeight
			local pivotPosition = shown + Vector3.new(0, item.Bottom + hop + lift, 0)
			follower.Placed = pivotPosition
			follower.PlacedFacing = follower.Facing
			cframe = CFrame.lookAt(pivotPosition, pivotPosition + follower.Facing)
				* CFrame.Angles(0, 0, math.sin(phase) * waddle)
		end

		local parts = item.Parts
		local offsets = item.Offsets
		for j = 1, #parts do
			table.insert(partList, parts[j])
			table.insert(cframeList, cframe * offsets[j])
		end

		-- Full detail: colour cycling for Rainbow (particles join with the art pass).
		if follower.Variant == 2 and item.Body and not far then
			item.Body.Color = Color3.fromHSV((t * 0.5 + i * 0.03) % 1, 0.8, 1)
		end
	end
	view.Dirty = false
	Path.DropPassed(path, headDist - pathOffsets[count])
	return drawn
end

-- Record every leader into its path. Runs on Heartbeat, with the simulation, so a frame that isn't drawn (a hitch,
-- or an unfocused Studio window) leaves no gap in the path.
local function record(dt: number)
	debug.profilebegin("LineRenderer.Record")
	for ownerId, view in views do
		local root, humanoid = leaderOf(ownerId)
		if not root or (humanoid and humanoid.Health <= 0) then
			if view.Path or view.Drawn > 0 then
				hideView(view) -- streamed out (or gone): start again when it is back
			end
			view.Root = nil
			continue
		end
		view.Root = root
		view.Humanoid = humanoid
		local path = view.Path
		if not path then
			path = Path.new(LineRules.PathKeep(Config.Line.MaxCapacity))
			view.Path = path
		end
		-- Ground height only, never in the air (4.3); a take-off leaves a hop marker.
		local ground, airborne = Path.Locate(path, root, humanoid)
		local reset, tookOff = Path.Record(path, ground, airborne, -root.CFrame.LookVector)
		if tookOff and #stats.Events < 80 then
			table.insert(
				stats.Events,
				string.format(
					"%.2f take-off: line %d at (%.1f, %.1f), %d hop markers",
					os.clock(),
					ownerId,
					ground.X,
					ground.Z,
					#path.HopDist
				)
			)
		end
		if reset then
			for _, follower in view.Followers do
				follower.Shown = nil -- reset: snap, don't glide
				follower.GlideFrom = nil
				follower.PathDist = nil
			end
		elseif tookOff and Render.JumpWave then
			table.insert(view.Waves, os.clock())
			if #view.Waves > Render.JumpWaveMax then
				table.remove(view.Waves, 1)
			end
		end
		local last = view.LastGround
		local speed = if last and dt > 0 then Vector3.new(ground.X - last.X, 0, ground.Z - last.Z).Magnitude / dt else 0
		view.LastGround = ground
		local movingTarget = math.clamp(speed / 6, 0, 1)
		view.Moving += (movingTarget - view.Moving) * (1 - math.exp(-8 * dt))
	end
	debug.profileend()
end

local function step(dt: number)
	local started = os.clock()
	debug.profilebegin("LineRenderer")

	if syncWanted and started - lastRequestAt >= REQUEST_SECONDS and requestSync then
		syncWanted = false
		lastRequestAt = started
		requestSync:FireServer()
	end

	local t = os.clock()
	frameNumber += 1
	local phone = isPhone()
	local hideDistance = if phone then Render.HideDistancePhone else Render.HideDistance
	local budget = if phone then Render.MaxDrawnPhone else Render.MaxDrawn

	local ownRoot = leaderOf(localPlayer.UserId)
	local camera = workspace.CurrentCamera
	local focus = if ownRoot then ownRoot.Position elseif camera then camera.CFrame.Position else Vector3.zero

	-- Find each recorded line's distance; the nearest are drawn first.
	table.clear(order)
	for _, view in views do
		local root = view.Root
		if not root or not view.Path then
			continue
		end
		local ground = Path.GroundPoint(root, view.Humanoid)
		local extent = view.Offsets[#view.Offsets] or 0
		view.LeaderDistance = (ground - focus).Magnitude
		if view.LeaderDistance - extent > hideDistance then
			if view.Drawn > 0 then
				for _, follower in view.Followers do
					release(follower)
				end
				view.Drawn = 0
			end
			continue
		end
		table.insert(order, view)
	end
	local ownId = localPlayer.UserId
	table.sort(order, function(a: View, b: View)
		if (a.OwnerId == ownId) ~= (b.OwnerId == ownId) then
			return a.OwnerId == ownId
		end
		return a.LeaderDistance < b.LeaderDistance
	end)

	table.clear(partList)
	table.clear(cframeList)
	local drawn = 0
	for _, view in order do
		view.Drawn = drawView(view, t, dt, focus, hideDistance, budget - drawn)
		drawn += view.Drawn
	end
	if #partList > 0 then
		local bulkStarted = os.clock()
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
		stats.BulkMs += (os.clock() - bulkStarted) * 1000
	end

	debug.profileend()
	local ms = (os.clock() - started) * 1000
	stats.Frames += 1
	stats.TotalMs += ms
	stats.LastMs = ms
	stats.MaxMs = math.max(stats.MaxMs, ms)
	stats.Drawn = drawn
	stats.Parts = #partList
	table.insert(stats.Window, ms)
	if #stats.Window > 120 then
		table.remove(stats.Window, 1)
	end
end

-- Debug (Studio only) -------------------------------------------------------------------------------------------

-- For the checks: each line's state, the largest settled error (|shown − target| over drawn followers that aren't
-- gliding in), the frame cost, and every `every`-th target of a line.
local function report(command: any, arg: any): any
	if command == "reset" then
		stats.Frames, stats.TotalMs, stats.MaxMs, stats.BulkMs = 0, 0, 0, 0
		stats.JumpHops, stats.HopMissMax, stats.HopMissSum = 0, 0, 0
		table.clear(stats.Events)
		return "stats reset"
	end
	if command == "events" then
		return table.concat(stats.Events, "\n")
	end
	if command == "path" then
		local view = views[tonumber(arg) or localPlayer.UserId]
		local path = view and view.Path
		if not view or not path or not view.Root then
			return "no recorded line"
		end
		local head = Path.LiveHead(path, view.Root, view.Humanoid)
		local hopList = {}
		for k, d in path.HopDist do
			local at = path.HopAt[k]
			table.insert(hopList, string.format("%.1f (%.1f, %.1f, %.1f)", d, at.X, at.Y, at.Z))
		end
		local out = {
			string.format(
				"client path: %d points, %.2f studs; head (%.2f, %.2f, %.2f), airborne %s; head distance %.1f; %d hop markers%s",
				path.Count,
				Path.Length(path, head),
				head.X,
				head.Y,
				head.Z,
				tostring(path.Airborne),
				Path.HeadDistance(path, head),
				#path.HopDist,
				if #hopList > 0 then ": " .. table.concat(hopList, ", ") else ""
			),
		}
		for k, p in Path.Newest(path, 8) do
			table.insert(out, string.format("  %d: (%.2f, %.2f, %.2f)", k - 1, p.X, p.Y, p.Z))
		end
		return table.concat(out, "\n")
	end
	if command == "positions" then
		local view = views[tonumber(arg) or localPlayer.UserId]
		if not view or not view.Path or not view.Root then
			return "no drawn line"
		end
		local count = #view.Followers
		local pos: { Vector3 } = {}
		local dir: { Vector3 } = {}
		Path.Sample(view.Path, Path.LiveHead(view.Path, view.Root, view.Humanoid), view.Offsets, count, pos, dir)
		return pos
	end
	local lines: { string } = {}
	local maxErr, errCount, gliding = 0, 0, 0
	for ownerId, view in views do
		local drawn = 0
		for _, follower in view.Followers do
			if follower.Item then
				drawn += 1
				if follower.GlideFrom then
					gliding += 1
				else
					errCount += 1
					maxErr = math.max(maxErr, follower.Err.Magnitude)
				end
			end
		end
		table.insert(
			lines,
			string.format(
				"  line %d: %d followers, %d drawn, seq %d, path %d points, leader %.0f studs away, %d waves running",
				ownerId,
				#view.Followers,
				drawn,
				view.Seq,
				if view.Path then view.Path.Count else 0,
				view.LeaderDistance,
				#view.Waves
			)
		)
	end
	table.sort(lines)
	local window = 0
	for _, ms in stats.Window do
		window += ms
	end
	return string.format(
		"LineRenderer: %d lines, %d drawn (%d parts), phone %s\n%s\n  settled error: max %.4f studs over %d followers (%d gliding)\n  frame: last %.3f ms, avg (120) %.3f ms, avg (all %d) %.3f ms (BulkMoveTo %.3f ms), max %.3f ms\n  jump hops: %d followers passed a marker, miss max %.2f studs, mean %.2f studs",
		#lines,
		stats.Drawn,
		stats.Parts,
		tostring(isPhone()),
		table.concat(lines, "\n"),
		maxErr,
		errCount,
		gliding,
		stats.LastMs,
		if #stats.Window > 0 then window / #stats.Window else 0,
		stats.Frames,
		if stats.Frames > 0 then stats.TotalMs / stats.Frames else 0,
		if stats.Frames > 0 then stats.BulkMs / stats.Frames else 0,
		stats.MaxMs,
		stats.JumpHops,
		stats.HopMissMax,
		if stats.JumpHops > 0 then stats.HopMissSum / stats.JumpHops else 0
	)
end

function LineRenderer.Init(): () end

function LineRenderer.Start(): ()
	task.spawn(function()
		templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Critters")
	end)
	task.spawn(function()
		Net.Event(Net.Names.LineSync).OnClientEvent:Connect(onLineSync)
		local remote = Net.Event(Net.Names.RequestLineSync)
		requestSync = remote
		lastRequestAt = os.clock()
		remote:FireServer() -- snapshots of every line already in the server
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		dropView(player.UserId)
	end)
	RunService.Heartbeat:Connect(record)
	RunService.RenderStepped:Connect(step)

	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = Config.Debug.RendererBridgeName
		bridge.OnInvoke = report
		bridge.Parent = localPlayer:WaitForChild("PlayerScripts")
	end
end

export type LineRenderer = typeof(LineRenderer)

return LineRenderer
