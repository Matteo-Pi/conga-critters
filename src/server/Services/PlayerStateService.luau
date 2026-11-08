--!strict
-- PlayerStateService: session state: line, critters on their way, cooldowns, shields (spec 9.2).
-- C01-M1: session LP (default 0) and the debug unlock set, so biome access has one rule from the start. LP moves to
-- the saved profile in C01-M4; callers keep using GetLP and IsBiomeUnlocked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Unlocks = require(Shared:WaitForChild("Unlocks") :: ModuleScript)

export type Session = {
	LP: number,
	DebugUnlocked: Unlocks.DebugSet,
}

local PlayerStateService = {}

local sessions: { [Player]: Session } = {}

local function newSession(): Session
	return { LP = 0, DebugUnlocked = {} }
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

function PlayerStateService.Init(): () end

function PlayerStateService.Start(): ()
	Players.PlayerAdded:Connect(function(player: Player)
		PlayerStateService.Get(player)
	end)
	for _, player in Players:GetPlayers() do
		PlayerStateService.Get(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
end

export type PlayerStateService = typeof(PlayerStateService)

return PlayerStateService
