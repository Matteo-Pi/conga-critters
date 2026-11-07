--!strict
-- Zones: point-in-zone tests (spec 3.2). Pure maths on a zone part's CFrame, Size and attributes; no physics queries.
--
-- Box zones (SafeZone, Gate, Pen, ...): the point must be inside the part's box.
-- Trapezoid zones (Biome, DepthBand): the part also has NearWidth and FarWidth attributes. Its CFrame and Size are
-- the bounding box; its LookVector points from the near end (the local +Z face) to the far end (the local -Z face),
-- and its width along local X changes linearly from NearWidth to FarWidth with depth. Depth (Z) and height (Y) are
-- checked against Size as for a box.

local Zones = {}

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

export type Zones = typeof(Zones)

return Zones
