--!strict
-- PlayerStateService: session state: line, critters on their way, cooldowns, shields (spec 9.2).
-- C01-M1: session LP (default 0) and the debug unlock set, so biome access has one rule from the start. LP moves to
-- the saved profile in C01-M4; callers keep using GetLP and IsBiomeUnlocked.
-- C01-M2: the line (entries and critters on their way), upgrade levels, Golden Bait, the tutorial's free-throw count
-- and the throw cooldown. Upgrades, Golden Bait and tutorial progress move to the saved profile in C01-M4; LineService
-- and ThrowService read and change them through the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)
local Unlocks = require(Shared:WaitForChild("Unlocks") :: ModuleScript)

-- One critter in a line (spec 4.3): species, variant, bound; `Paid` is saved with it later (4.2).
export type LineEntry = {
	Species: string,
	Variant: number, -- 0 Normal, 1 Golden, 2 Rainbow
	Bound: boolean,
	Paid: boolean,
}

export type Session = {
	LP: number,
	DebugUnlocked: Unlocks.DebugSet,
	Upgrades: { Leash: number, Bait: number },
	Rebirths: number,
	LongerLeash: boolean,
	GoldenBait: number,
	Tutorial: { Done: boolean, FreeThrows: number },
	Line: { Entries: { LineEntry }, Incoming: number },
	LastThrowAt: number, -- os.clock() of the last accepted throw
	ThrowBucket: Net.Bucket,
}

local PlayerStateService = {}

local sessions: { [Player]: Session } = {}

local function newSession(): Session
	return {
		LP = 0,
		DebugUnlocked = {},
		Upgrades = { Leash = 1, Bait = 1 },
		Rebirths = 0,
		LongerLeash = false,
		GoldenBait = 0,
		Tutorial = { Done = false, FreeThrows = 0 },
		Line = { Entries = {}, Incoming = 0 },
		LastThrowAt = -math.huge,
		ThrowBucket = Net.NewBucket(Net.RateLimits.ThrowBait),
	}
end

-- The player's session, created on first use (deferred signals mean PlayerAdded may not have fired yet).
-- Nil for a player who has left.
function PlayerStateService.Get(player: Player): Session?
	if player.Parent ~= Players then
		return nil
	end
	local session = sessions[player]
	if not session then
		session = newSession()
		sessions[player] = session
	end
	return session
end

function PlayerStateService.GetLP(player: Player): number
	local session = PlayerStateService.Get(player)
	return if session then session.LP else 0
end

function PlayerStateService.SetLP(player: Player, lp: number): ()
	local session = PlayerStateService.Get(player)
	if session and lp == lp and lp >= 0 and lp < math.huge then
		session.LP = lp
		player:SetAttribute("LP", lp)
	end
end

function PlayerStateService.SetGoldenBait(player: Player, count: number): ()
	local session = PlayerStateService.Get(player)
	if session and count == count and count >= 0 and count < math.huge then
		session.GoldenBait = math.floor(count)
		player:SetAttribute("GoldenBait", session.GoldenBait)
	end
end

function PlayerStateService.AddDebugUnlock(player: Player, biomeId: string): ()
	local session = PlayerStateService.Get(player)
	if session then
		session.DebugUnlocked[biomeId] = true
	end
end

function PlayerStateService.ClearDebugUnlocks(player: Player): ()
	local session = PlayerStateService.Get(player)
	if session then
		table.clear(session.DebugUnlocked)
	end
end

function PlayerStateService.IsBiomeUnlocked(player: Player, biomeId: string): boolean
	local session = PlayerStateService.Get(player)
	if not session then
		return false
	end
	return Unlocks.IsBiomeUnlocked(session.LP, session.DebugUnlocked, biomeId)
end

function PlayerStateService.TopTier(player: Player): number
	local session = PlayerStateService.Get(player)
	if not session then
		return 0
	end
	return Unlocks.TopTier(session.LP, session.DebugUnlocked)
end

local function onPlayerAdded(player: Player)
	local session = PlayerStateService.Get(player)
	if session then
		player:SetAttribute("LP", session.LP)
		player:SetAttribute("GoldenBait", session.GoldenBait)
	end
end

function PlayerStateService.Init(): () end

function PlayerStateService.Start(): ()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
end

export type PlayerStateService = typeof(PlayerStateService)

return PlayerStateService
