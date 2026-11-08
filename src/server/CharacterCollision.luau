--!strict
-- Characters never collide with each other (spec 16, 2026-11-08). Two characters that walked into each other used
-- to step up onto each other in turn and climb high into the air; it would also let one player body-block another.
-- Every part of a player character or a debug leader goes in the "Characters" collision group, which doesn't collide
-- with itself. Characters still collide with the map (floors, fences, walls) as before.
--
-- The server sets the group; part collision groups and the group table replicate, so each client's own predicted
-- character (Server Authority) uses the same rule.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Characters"

local CharacterCollision = {}

local function ensureGroup()
	if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
		PhysicsService:RegisterCollisionGroup(GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

local function setPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = GROUP
	end
end

-- Put every part of `model`, now and added later (accessories, tools), in the Characters group.
function CharacterCollision.Apply(model: Model): ()
	ensureGroup()
	for _, descendant in model:GetDescendants() do
		setPart(descendant)
	end
	model.DescendantAdded:Connect(setPart)
end

local started = false

-- Apply to every player character as it spawns. Safe to call twice.
function CharacterCollision.Start(): ()
	if started then
		return
	end
	started = true
	ensureGroup()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(CharacterCollision.Apply)
		if player.Character then
			CharacterCollision.Apply(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterCollision
