--!strict
-- ThrowService: ThrowBait checks, rolls, CritterSpawned (spec 4.1, 4.2, 9.4).
--
-- A throw is checked in this order; the first failure rejects it and is counted under its reason:
--   payload       target isn't a finite Vector3, or golden isn't a boolean
--   rate          the ThrowBait token bucket is empty (1 per own cooldown − RateLimitSlack s, burst RateLimitBurst)
--   cooldown      less than own cooldown − RateLimitSlack s since this player's last accepted throw
--                 (own cooldown = LineRules.ThrowCooldown(rebirths): 0.8 s, 0.05 s less per rebirth, at least 0.5 s)
--   noCharacter   no live character
--   notInBiome    the server-side position isn't in a biome (the hub, a gate, a pen)
--   locked        the player hasn't unlocked that biome
--   range         target farther than Range + TargetRangeSlack from the server-side position
--   targetBiome   target not in the same biome
--   full          line length + critters on their way has reached capacity
--   noGoldenBait  golden is true but the player has none
-- An accepted throw rolls each critter with Odds.Roll (luck from the band the bait lands in), tells every client with
-- CritterSpawned, and adds it to the line JoinDelay s after the bait lands. During the tutorial, free throws 3 and 6
-- get a fixed rarity (Config.Tutorial.FixedRolls; spec 2.1, 2.2): the species is still an equal pick among that
-- biome's species of that rarity, and the variant is rolled as usual. Golden Bait throws never use fixed rolls.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)
local LineRules = require(Shared:WaitForChild("LineRules") :: ModuleScript)
local Odds = require(Shared:WaitForChild("Odds") :: ModuleScript)
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local Services = script.Parent
local LineService = require(Services:WaitForChild("LineService") :: ModuleScript)
local MapService = require(Services:WaitForChild("MapService") :: ModuleScript)
local PlayerStateService = require(Services:WaitForChild("PlayerStateService") :: ModuleScript)

local TAG = "[Throw]"

local ThrowService = {}

export type Stats = {
	Accepted: number,
	Rejected: { [string]: number },
	Spawned: number,
	Joined: number,
	Dropped: number,
}

local stats: Stats = { Accepted = 0, Rejected = {}, Spawned = 0, Joined = 0, Dropped = 0 }
local rng = Random.new()
local nextId = 0
local critterSpawned: RemoteEvent? = nil

type Burrow = { Position: Vector3, BiomeId: string }
local burrows: { Burrow } = {}

local function log(message: string)
	if Config.Debug.LogThrows then
		print(`{TAG} {message}`)
	end
end

local function reject(player: Player, reason: string, detail: string?)
	stats.Rejected[reason] = (stats.Rejected[reason] or 0) + 1
	log(`{player.Name} rejected: {reason}{if detail then ` ({detail})` else ""}`)
end

function ThrowService.GetStats(): Stats
	return stats
end

function ThrowService.ResetStats(): ()
	stats.Accepted = 0
	table.clear(stats.Rejected)
	stats.Spawned = 0
	stats.Joined = 0
	stats.Dropped = 0
end

function ThrowService.Report(): string
	local lines = {
		`Throws: {stats.Accepted} accepted; critters {stats.Spawned} spawned, {stats.Joined} joined, {stats.Dropped} dropped`,
	}
	local reasons: { string } = {}
	local total = 0
	for reason, count in stats.Rejected do
		table.insert(reasons, reason)
		total += count
	end
	table.sort(reasons)
	table.insert(lines, `Rejected: {total}`)
	for _, reason in reasons do
		table.insert(lines, string.format("  %-13s %d", reason, stats.Rejected[reason]))
	end
	return table.concat(lines, "\n")
end

-- Where the critter runs in from (spec 4.2 Arrival): the nearest Burrow of that biome within BurrowSearchRadius of
-- the bait; otherwise FallbackSpawnMin–FallbackSpawnMax studs away in a random direction, inside the biome if any
-- of a few tries is. Kept at the bait's height so it runs along the floor.
local function startPoint(target: Vector3, biomeId: string): Vector3
	local best: Vector3? = nil
	local bestDistance = Config.Throw.BurrowSearchRadius
	for _, burrow in burrows do
		if burrow.BiomeId == biomeId then
			local flat = Vector3.new(burrow.Position.X - target.X, 0, burrow.Position.Z - target.Z)
			local distance = flat.Magnitude
			if distance <= bestDistance then
				best = Vector3.new(burrow.Position.X, target.Y, burrow.Position.Z)
				bestDistance = distance
			end
		end
	end
	if best then
		return best
	end
	local fallback = target
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(Config.Throw.FallbackSpawnMin, Config.Throw.FallbackSpawnMax)
		fallback = target + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if MapService.ZoneAt(fallback).BiomeId == biomeId then
			return fallback
		end
	end
	return fallback
end

local function fixedRarity(throwNumber: number): string?
	for _, fixed in Config.Tutorial.FixedRolls do
		if fixed.Throw == throwNumber then
			return fixed.Rarity
		end
	end
	return nil
end

local function onThrowBait(player: Player, target: any, golden: any)
	-- Payload
	if not Net.IsFiniteVector3(target) or type(golden) ~= "boolean" then
		reject(player, "payload")
		return
	end
	local session = PlayerStateService.Get(player)
	if not session then
		return
	end
	local now = os.clock()
	local cooldown = LineRules.ThrowCooldown(session.Rebirths) - Config.Throw.RateLimitSlack
	if not session.ThrowBucket:Take(now, cooldown) then
		reject(player, "rate")
		return
	end
	if now - session.LastThrowAt < cooldown then
		reject(player, "cooldown", string.format("%.2f s after the last", now - session.LastThrowAt))
		return
	end

	-- Where the player is, on the server
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		reject(player, "noCharacter")
		return
	end
	local position = root.Position
	local here = MapService.ZoneAt(position)
	local biomeId = here.BiomeId
	if not biomeId then
		reject(player, "notInBiome", Zones.Describe(here))
		return
	end
	if not PlayerStateService.IsBiomeUnlocked(player, biomeId) then
		reject(player, "locked", `{biomeId}, LP {session.LP}`)
		return
	end
	local distance = (target - position).Magnitude
	if distance > Config.Throw.Range + Config.Throw.TargetRangeSlack then
		reject(player, "range", string.format("%.1f studs", distance))
		return
	end
	local there = MapService.ZoneAt(target)
	if there.BiomeId ~= biomeId then
		reject(player, "targetBiome", `in {biomeId}, target {Zones.Describe(there)}`)
		return
	end
	local room = LineService.Room(player)
	if room <= 0 then
		reject(
			player,
			"full",
			`{LineService.Length(player)} + {LineService.Incoming(player)} of {LineService.Capacity(player)}`
		)
		return
	end
	if golden and session.GoldenBait < 1 then
		reject(player, "noGoldenBait")
		return
	end

	-- Accepted
	session.LastThrowAt = now
	stats.Accepted += 1
	if golden then
		PlayerStateService.SetGoldenBait(player, session.GoldenBait - 1)
	end
	local fixed: string? = nil
	if not golden and not session.Tutorial.Done then
		session.Tutorial.FreeThrows += 1
		fixed = fixedRarity(session.Tutorial.FreeThrows)
	end

	local ctx = Odds.DefaultContext()
	ctx.BaitLevel = session.Upgrades.Bait
	ctx.Band = there.Band or 1
	ctx.GoldenBait = golden
	-- Server Luck (C01-M6), events and Golden Hour (C01-M8) join the context when they exist.

	local serverNow = workspace:GetServerTimeNow()
	local landAt = serverNow + math.max(0, Config.Throw.FlightSeconds - player:GetNetworkPing())
	local joinAt = landAt + Config.Throw.JoinDelay
	local count = math.min(room, Config.Throw.CrittersPerThrow)
	LineService.Reserve(player, count)

	for i = 1, count do
		local species: string, rarity: string, variant: number
		if fixed and i == 1 then
			local pool = Odds.Pool(biomeId, fixed)
			species = pool[rng:NextInteger(1, #pool)]
			rarity = fixed
			variant = Odds.PickVariant(Odds.VariantChances(ctx.GoldenBait, ctx.GoldenHour), rng:NextNumber())
		else
			local result = Odds.Roll(biomeId, ctx, rng)
			if not result then
				LineService.Cancel(player, 1) -- the validator makes this unreachable
				continue
			end
			species, rarity, variant = result.Species, result.Rarity, result.Variant
		end
		local bound = golden
		local paid = golden or ctx.ServerLuck
		nextId += 1
		local id = nextId
		stats.Spawned += 1
		local from = startPoint(target, biomeId)
		local payload: Net.CritterSpawnedPayload = {
			id = id,
			owner = player.UserId,
			species = Config.Critters.IndexById[species],
			variant = variant,
			bound = bound,
			from = from,
			to = target,
			joinAt = joinAt,
		}
		assert(critterSpawned, "ThrowService not started"):FireAllClients(payload)
		log(
			string.format(
				"%s accepted #%d: free throw %s, %s band %d λ=%.2f -> %s (%s%s, variant %d), runs %.1f studs, lands %.3f, joins %.3f",
				player.Name,
				id,
				if golden then "-" else tostring(session.Tutorial.FreeThrows),
				biomeId,
				ctx.Band,
				Odds.Luck(ctx),
				species,
				rarity,
				if fixed and i == 1 then ", fixed tutorial roll" else "",
				variant,
				(from - target).Magnitude,
				landAt,
				joinAt
			)
		)

		task.delay(joinAt - serverNow, function()
			local joined =
				LineService.Arrive(player, { Species = species, Variant = variant, Bound = bound, Paid = paid })
			if joined then
				stats.Joined += 1
			else
				stats.Dropped += 1
			end
			log(
				string.format(
					"%s #%d %s at %.3f (%.2f s after landing); line %d/%d, %d on the way",
					player.Name,
					id,
					if joined then "joined" else "dropped",
					workspace:GetServerTimeNow(),
					workspace:GetServerTimeNow() - landAt,
					LineService.Length(player),
					LineService.Capacity(player),
					LineService.Incoming(player)
				)
			)
		end)
	end
end

function ThrowService.Init(): ()
	critterSpawned = Net.Event(Net.Names.CritterSpawned)
	Net.Event(Net.Names.ThrowBait).OnServerEvent:Connect(onThrowBait)
end

function ThrowService.Start(): ()
	local root = MapService.ZonesRoot()
	for _, part in CollectionService:GetTagged("Burrow") do
		if part:IsA("BasePart") and part:IsDescendantOf(root) then
			local biomeId = part:GetAttribute("BiomeId")
			if type(biomeId) == "string" then
				table.insert(burrows, { Position = part.Position, BiomeId = biomeId })
			end
		end
	end
	if #burrows == 0 then
		warn(`{TAG} no Burrow parts found; critters will run in from random directions`)
	end
	-- A player who leaves: their critters on the way are dropped when they arrive (spec 4.2, 9.7), since
	-- LineService.Arrive finds no session.
end

export type ThrowService = typeof(ThrowService)

return ThrowService
