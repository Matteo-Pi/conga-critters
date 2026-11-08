--!strict
-- Net: remote names, payload types and rate limits (spec 9.4).
-- The server creates every remote under ReplicatedStorage.Remotes at boot; clients wait for them.
-- Rules (9.4): never trust numbers from a client; drop bad payloads silently and count them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Net = {}

local FOLDER_NAME = "Remotes"

-- Remote names. Each milestone adds its own.
Net.Names = table.freeze({
	ThrowBait = "ThrowBait", -- client → server: (target: Vector3, golden: boolean)
	CritterSpawned = "CritterSpawned", -- server → all: CritterSpawnedPayload
	LineSync = "LineSync", -- server → all (or one, for snapshots on request): LineSyncPayload
	RequestLineSync = "RequestLineSync", -- client → server: no payload; answered with a snapshot of every line
})

-- LineSync ops (spec 9.4). Each line has its own sequence number: every op but a requested snapshot adds 1, so a
-- client that sees a gap asks again with RequestLineSync. `entries` are packed critters (Net.PackCritter).
export type LineSyncOp = "snapshot" | "append" | "removeFront" | "clear"

export type LineSyncPayload = {
	userId: number, -- the line's owner; negative for debug leaders
	seq: number,
	op: LineSyncOp,
	entries: { number }?, -- snapshot: the whole line, front first; append: the new critters
	count: number?, -- removeFront: how many left the front
}

export type CritterSpawnedPayload = {
	id: number, -- server-wide spawn id
	owner: number, -- UserId of the thrower
	species: number, -- species wire index (Config.Critters.IndexById)
	variant: number, -- 0 Normal, 1 Golden, 2 Rainbow
	bound: boolean, -- from Golden Bait
	from: Vector3, -- where it runs in from
	to: Vector3, -- the bait
	joinAt: number, -- workspace:GetServerTimeNow() when the server adds it to the line; the bait landed JoinDelay before
}

-- Token buckets per remote (spec 9.4 "Rate limit" column): refill 1 token per `Per` seconds, hold up to `Burst`.
export type RateLimit = { Per: number, Burst: number }

Net.RateLimits = table.freeze({
	ThrowBait = table.freeze({
		Per = Config.Throw.Cooldown - Config.Throw.RateLimitSlack,
		Burst = Config.Throw.RateLimitBurst,
	}),
	RequestLineSync = table.freeze({ Per = 2, Burst = 1 }),
}) :: { [string]: RateLimit }

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- The RemoteEvent with this name: created on the server, waited for on clients.
function Net.Event(name: string): RemoteEvent
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name) :: RemoteEvent
end

-- A token bucket. `Take(now)` spends a token and returns true, or returns false when empty.
export type Bucket = {
	Take: (self: Bucket, now: number) -> boolean,
	Tokens: number,
	Updated: number,
}

function Net.NewBucket(limit: RateLimit): Bucket
	local bucket = { Tokens = limit.Burst, Updated = -math.huge } :: Bucket
	function bucket.Take(self: Bucket, now: number): boolean
		if self.Updated > -math.huge then
			self.Tokens = math.min(limit.Burst, self.Tokens + (now - self.Updated) / limit.Per)
		end
		self.Updated = now
		if self.Tokens >= 1 then
			self.Tokens -= 1
			return true
		end
		return false
	end
	return bucket
end

local MAX_COORDINATE = 1e6

local function finite(x: number): boolean
	return x == x and math.abs(x) < MAX_COORDINATE
end

-- True for a Vector3 whose components are all finite and of a sane size.
function Net.IsFiniteVector3(value: any): boolean
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

-- Critters on the wire (spec 9.4): species index × 8 + variant × 2 + bound.
function Net.PackCritter(speciesIndex: number, variant: number, bound: boolean): number
	return speciesIndex * 8 + variant * 2 + (if bound then 1 else 0)
end

function Net.UnpackCritter(packed: number): (number, number, boolean)
	return packed // 8, (packed % 8) // 2, packed % 2 == 1
end

return Net
