--!strict
-- Zones: point-in-zone tests (spec 3.2). Pure maths on a zone part's CFrame, Size and attributes; no physics queries.
--
-- Box zones (SafeZone, Gate, Pen, ...): the point must be inside the part's box.
-- Trapezoid zones (Biome, DepthBand): the part also has NearWidth and FarWidth attributes. Its CFrame and Size are
-- the bounding box; its LookVector points from the near end (the local +Z face) to the far end (the local -Z face),
-- and its width along local X changes linearly from NearWidth to FarWidth with depth. Depth (Z) and height (Y) are
-- checked against Size as for a box.

local CollectionService = game:GetService("CollectionService")

local Zones = {}

export type ZoneInfo = {
	Safe: boolean, -- inside any SafeZone (hub, gates, coming-soon gates; pens sit inside the hub)
	BiomeId: string?, -- inside a Biome trapezoid
	Band: number?, -- inside a DepthBand (1 Near, 2 Mid, 3 Far)
	GateBiomeId: string?, -- inside a Gate
	ComingSoonSlot: number?, -- inside a ComingSoonGate
	PenIndex: number?, -- inside a Pen plot
}

-- The tags Classify reads (spec 3.2).
local CLASSIFY_TAGS = { "SafeZone", "Biome", "DepthBand", "Gate", "ComingSoonGate", "Pen" }

-- Tagged parts under a root, kept up to date as streaming or edits add and remove them.
local index: { [string]: { [BasePart]: true } } = {}
local indexRoot: Instance? = nil

local function track(tag: string, instance: Instance, root: Instance)
	if instance:IsA("BasePart") and instance:IsDescendantOf(root) then
		index[tag][instance] = true
	end
end

local function buildIndex(root: Instance)
	if indexRoot == root then
		return
	end
	assert(indexRoot == nil, "Zones: the index is already built for another root")
	indexRoot = root
	for _, tag in CLASSIFY_TAGS do
		index[tag] = {}
		for _, instance in CollectionService:GetTagged(tag) do
			track(tag, instance, root)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
			track(tag, instance, root)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
			if instance:IsA("BasePart") then
				index[tag][instance] = nil
			end
		end)
	end
end

-- Tagged parts under the indexed root, for callers that need them (MapService, checks).
function Zones.Tagged(root: Instance, tag: string): { BasePart }
	buildIndex(root)
	local out: { BasePart } = {}
	for part in index[tag] or {} do
		table.insert(out, part)
	end
	return out
end

-- Width of a zone at a local Z inside its bounding box: the box width, or the interpolated trapezoid width.
function Zones.WidthAt(part: BasePart, localZ: number): number
	local near = part:GetAttribute("NearWidth")
	local far = part:GetAttribute("FarWidth")
	if type(near) ~= "number" or type(far) ~= "number" then
		return part.Size.X
	end
	local depth = part.Size.Z
	local t = math.clamp((depth / 2 - localZ) / depth, 0, 1) -- 0 at the near end, 1 at the far end
	return near + (far - near) * t
end

function Zones.Contains(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	if math.abs(p.Y) > half.Y or math.abs(p.Z) > half.Z then
		return false
	end
	return math.abs(p.X) <= Zones.WidthAt(part, p.Z) / 2
end

-- Every zone a point is in. `root` is Workspace.Map.Zones; the first call indexes its tagged parts.
function Zones.Classify(root: Instance, point: Vector3): ZoneInfo
	buildIndex(root)
	local info: ZoneInfo = { Safe = false }
	for part in index.SafeZone do
		if Zones.Contains(part, point) then
			info.Safe = true
			break
		end
	end
	for part in index.Biome do
		if Zones.Contains(part, point) then
			local id = part:GetAttribute("BiomeId")
			info.BiomeId = if type(id) == "string" then id else nil
			break
		end
	end
	for part in index.DepthBand do
		if Zones.Contains(part, point) then
			local band = part:GetAttribute("Band")
			info.Band = if type(band) == "number" then band else nil
			break
		end
	end
	for part in index.Gate do
		if Zones.Contains(part, point) then
			local id = part:GetAttribute("BiomeId")
			info.GateBiomeId = if type(id) == "string" then id else nil
			break
		end
	end
	for part in index.ComingSoonGate do
		if Zones.Contains(part, point) then
			local slot = part:GetAttribute("Slot")
			info.ComingSoonSlot = if type(slot) == "number" then slot else nil
			break
		end
	end
	for part in index.Pen do
		if Zones.Contains(part, point) then
			local penIndex = part:GetAttribute("PenIndex")
			info.PenIndex = if type(penIndex) == "number" then penIndex else nil
			break
		end
	end
	return info
end

-- A short label for logs and checks, e.g. "safe pen=3", "biome=meadow band=2", "none".
function Zones.Describe(info: ZoneInfo): string
	local parts: { string } = {}
	if info.Safe then
		table.insert(parts, "safe")
	end
	if info.PenIndex then
		table.insert(parts, `pen={info.PenIndex}`)
	end
	if info.GateBiomeId then
		table.insert(parts, `gate={info.GateBiomeId}`)
	end
	if info.ComingSoonSlot then
		table.insert(parts, `soon={info.ComingSoonSlot}`)
	end
	if info.BiomeId then
		table.insert(parts, `biome={info.BiomeId}`)
	end
	if info.Band then
		table.insert(parts, `band={info.Band}`)
	end
	return if #parts == 0 then "none" else table.concat(parts, " ")
end

export type Zones = typeof(Zones)

return Zones
