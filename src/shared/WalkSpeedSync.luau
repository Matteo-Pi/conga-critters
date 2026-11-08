--!strict
-- WalkSpeedSync: a player's walk speed, applied inside the shared simulation (spec 4.3, 9.1).
--
-- Under Server Authority, Humanoid.WalkSpeed is a predicted property. A server script that writes it outside the
-- simulation makes the client mispredict: it rolls back and replays its last frames, which shows as a nudge while
-- walking and a replayed fall animation mid-jump (measured 2026-11-08, spec 16). So the server never writes it.
-- Instead it announces each change ahead of time ("light a fuse", Server Authority techniques):
--
--   Player attribute WalkSpeedPlan = Vector3(from, to, at)   speed is `from` before simulation time `at`, then `to`
--
-- One attribute, so the three values always arrive together; both sides read the same float32 numbers. The server
-- sets `at` = time() + Config.Line.SpeedLeadSeconds, so the plan reaches the client before it applies, and both
-- sides' BindToSimulation callbacks switch on the same step. Only one change is pending at a time: Announce returns
-- false while one is, and the caller (LineService's 15 Hz sample) tries again.
--
-- Started on the server (every player) and on the client (its own character only; others aren't predicted). If
-- BindToSimulation isn't available (AuthorityMode Automatic without fixed simulation), the server applies the plan on
-- Heartbeat instead and the client does nothing: the client owns its character there and the property replicates.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config") :: ModuleScript)

local ATTRIBUTE = "WalkSpeedPlan"

local WalkSpeedSync = {}

local humanoids: { [Player]: Humanoid } = {}
local started = false

-- The planned speed at simulation time `t`, or nil if nothing is announced yet.
function WalkSpeedSync.SpeedAt(player: Player, t: number): number?
	local plan = player:GetAttribute(ATTRIBUTE)
	if typeof(plan) ~= "Vector3" then
		return nil
	end
	return if t >= plan.Z then plan.Y else plan.X
end

-- Server: announce that `player` walks at `speed`. Returns true if it is announced (or already the target), false
-- while an earlier change is still pending; call again later. The first announcement applies at once.
function WalkSpeedSync.Announce(player: Player, speed: number): boolean
	assert(RunService:IsServer(), "WalkSpeedSync.Announce is server-only")
	local now = time()
	local plan = player:GetAttribute(ATTRIBUTE)
	if typeof(plan) ~= "Vector3" then
		player:SetAttribute(ATTRIBUTE, Vector3.new(speed, speed, now))
		return true
	end
	if math.abs(plan.Y - speed) < 1e-3 then
		return true
	end
	if now < plan.Z then
		return false
	end
	player:SetAttribute(ATTRIBUTE, Vector3.new(plan.Y, speed, now + Config.Line.SpeedLeadSeconds))
	return true
end

local function apply()
	local t = time()
	for player, humanoid in humanoids do
		local speed = WalkSpeedSync.SpeedAt(player, t)
		if speed and humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end
end

local function track(player: Player)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") and player.Character == character then
			humanoids[player] = humanoid
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function WalkSpeedSync.Start(): ()
	if started then
		return
	end
	started = true
	local server = RunService:IsServer()
	local bound = pcall(function()
		RunService:BindToSimulation(apply)
	end)
	if not bound then
		if not server then
			return
		end
		RunService.Heartbeat:Connect(apply)
	end
	if server then
		Players.PlayerAdded:Connect(track)
		Players.PlayerRemoving:Connect(function(player: Player)
			humanoids[player] = nil
		end)
		for _, player in Players:GetPlayers() do
			track(player)
		end
	else
		track(Players.LocalPlayer)
	end
end

return WalkSpeedSync
