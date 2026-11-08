--!strict
-- Path: breadcrumb path maths for the server and clients (spec 9.5).
--
-- A ring buffer of ground-level points with the cumulative distance walked at each. The leader adds a point once it
-- has moved MinStep studs; the path keeps `Keep` studs (capacity × KeepPerCapacity + KeepExtra) and grows its ring
-- when it needs more room. `Sample` places every follower in one pass from the leader's live position back through
-- the points, so it costs points + followers, not points × followers. A jump longer than ResetJump between two
-- samples (a respawn, or the server moving the player) resets the path to a straight line behind the leader.
--
-- Breadcrumbs are always at ground height, never in the air (4.3). `Locate` gives the leader's feet while it stands
-- on something, and the floor straight below it (a downward raycast into `workspace.Map`) while it is airborne, so a
-- jump on the spot adds no path at all and a running jump adds only its ground track. Each take-off is kept as a hop
-- marker at the path distance (and point) where the leader left the ground: a follower plays a hop as it passes a
-- marker (the client draws it), and the marker is dropped once the last follower has passed it (`DropPassed`).

local Config = require(script.Parent.Config)

local Path = {}

export type Path = {
	Points: { Vector3 },
	Dist: { number }, -- cumulative distance at each point
	Size: number, -- ring capacity
	Head: number, -- ring index of the newest point
	Count: number,
	Keep: number, -- studs to keep
	HopDist: { number }, -- hop markers: path distance of each take-off, oldest first
	HopAt: { Vector3 }, -- … and where it was, on the ground
	Airborne: boolean, -- the leader was in the air at the last Record
	GroundDist: number, -- head distance at the last Record on the ground
	GroundAt: Vector3, -- … and the leader's ground point then
	FloorY: number, -- height of the ground point at the last Record (the floor below, while airborne)
}

local INITIAL_SIZE = 64

local function index(path: Path, k: number): number
	-- k = 0 is the newest point, k = Count − 1 the oldest
	return (path.Head - 1 - k) % path.Size + 1
end

function Path.new(keep: number): Path
	return {
		Points = table.create(INITIAL_SIZE, Vector3.zero),
		Dist = table.create(INITIAL_SIZE, 0),
		Size = INITIAL_SIZE,
		Head = 0,
		Count = 0,
		Keep = keep,
		HopDist = {},
		HopAt = {},
		Airborne = false,
		GroundDist = 0,
		GroundAt = Vector3.zero,
		FloorY = 0,
	}
end

function Path.SetKeep(path: Path, keep: number): ()
	path.Keep = keep
end

-- Where a character's feet are: below the root by half its height plus the hip height.
function Path.GroundPoint(root: BasePart, humanoid: Humanoid?): Vector3
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
end

-- Floors are everything queryable under workspace.Map (zone parts have CanQuery off) plus terrain. Characters,
-- critters and effects are never floors.
local floorParams: RaycastParams? = nil
local floorMap: Instance? = nil

local function floors(): RaycastParams?
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	if floorParams and floorMap == map then
		return floorParams
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map, workspace.Terrain }
	floorParams = params
	floorMap = map
	return params
end

-- The leader's ground point and whether it is airborne. The ground point is always on the floor straight below the
-- leader (its feet's X and Z, the floor's height), so the bob of a take-off or landing adds no path; the leader is
-- airborne when its feet are more than AirborneGap above that floor (steps and slopes stay under it). With no floor
-- in reach (or the map not streamed in) it keeps the height of the path's newest point.
function Path.Locate(path: Path?, root: BasePart, humanoid: Humanoid?): (Vector3, boolean)
	local feet = Path.GroundPoint(root, humanoid)
	local params = floors()
	local hit = if params
		then workspace:Raycast(
			root.Position,
			Vector3.new(0, feet.Y - root.Position.Y - Config.Line.Path.FloorProbe, 0),
			params
		)
		else nil
	if hit then
		return Vector3.new(feet.X, hit.Position.Y, feet.Z), feet.Y - hit.Position.Y > Config.Line.Path.AirborneGap
	end
	if path and path.Count > 0 then
		return Vector3.new(feet.X, path.Points[path.Head].Y, feet.Z), true
	end
	return feet, params ~= nil
end

-- Remove the oldest `drop` hop markers.
local function shiftHops(path: Path, drop: number)
	local n = #path.HopDist
	if drop <= 0 then
		return
	end
	table.move(path.HopDist, drop + 1, n, 1)
	table.move(path.HopAt, drop + 1, n, 1)
	for k = n - drop + 1, n do
		path.HopDist[k] = nil
		path.HopAt[k] = nil
	end
end

-- Hop markers that the path no longer reaches (older than its oldest point) go.
local function dropHopsBefore(path: Path, distance: number)
	local hops = path.HopDist
	local drop = 0
	while drop < #hops and hops[drop + 1] < distance do
		drop += 1
	end
	shiftHops(path, drop)
end

local function grow(path: Path)
	local size = path.Size * 2
	local points = table.create(size, Vector3.zero)
	local dist = table.create(size, 0)
	-- Oldest first, so the newest ends at Count.
	for k = path.Count - 1, 0, -1 do
		local from = index(path, k)
		local to = path.Count - k
		points[to] = path.Points[from]
		dist[to] = path.Dist[from]
	end
	path.Points = points
	path.Dist = dist
	path.Size = size
	path.Head = path.Count
end

local function push(path: Path, point: Vector3, distance: number)
	if path.Count == path.Size then
		grow(path)
	end
	path.Head = path.Head % path.Size + 1
	path.Points[path.Head] = point
	path.Dist[path.Head] = distance
	path.Count += 1
	-- Drop the oldest point while the one after it still covers Keep studs.
	local trimmed = false
	while path.Count > 2 and distance - path.Dist[index(path, path.Count - 2)] >= path.Keep do
		path.Count -= 1
		trimmed = true
	end
	if trimmed and #path.HopDist > 0 then
		dropHopsBefore(path, path.Dist[index(path, path.Count - 1)])
	end
end

-- Start again: a straight line `Keep` studs long running back from `position` along `back`. Hop markers go.
function Path.Reset(path: Path, position: Vector3, back: Vector3): ()
	local flat = Vector3.new(back.X, 0, back.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	path.Head = 0
	path.Count = 0
	table.clear(path.HopDist)
	table.clear(path.HopAt)
	push(path, position + direction * path.Keep, 0)
	push(path, position, path.Keep)
	path.GroundDist = path.Keep
	path.GroundAt = position
end

-- The leader's live ground point between Records, without a raycast: its feet's X and Z at the floor height of the
-- last Record. Use this as `head` for Sample, Length and HeadDistance.
function Path.LiveHead(path: Path, root: BasePart, humanoid: Humanoid?): Vector3
	local feet = Path.GroundPoint(root, humanoid)
	if path.Count == 0 then
		return feet
	end
	return Vector3.new(feet.X, path.FloorY, feet.Z)
end

-- Path distance of the leader's live ground position `head` (the newest point's distance plus the way from it).
function Path.HeadDistance(path: Path, head: Vector3): number
	if path.Count == 0 then
		return 0
	end
	return path.Dist[path.Head] + (head - path.Points[path.Head]).Magnitude
end

-- Add the leader's ground point (from `Locate`). Returns (reset, tookOff): reset when the path started again
-- (empty, or a jump longer than ResetJump), so callers snap their followers instead of gliding them; tookOff when
-- the leader has just left the ground, which also adds a hop marker where it took off (unless one is within
-- HopMinGap). `back` points behind the leader, for resets.
function Path.Record(path: Path, position: Vector3, airborne: boolean, back: Vector3): (boolean, boolean)
	local reset = false
	if path.Count == 0 then
		Path.Reset(path, position, back)
		reset = true
	else
		local newest = path.Points[path.Head]
		local step = (position - newest).Magnitude
		if step > Config.Line.Path.ResetJump then
			Path.Reset(path, position, back)
			reset = true
		elseif step >= Config.Line.Path.MinStep then
			push(path, position, path.Dist[path.Head] + step)
		end
	end

	local tookOff = false
	if airborne then
		if not path.Airborne and not reset then
			tookOff = true
			local hops = path.HopDist
			local last = hops[#hops]
			if not last or path.GroundDist - last >= Config.Line.Path.HopMinGap then
				table.insert(hops, path.GroundDist)
				table.insert(path.HopAt, path.GroundAt)
			end
		end
	else
		path.GroundDist = Path.HeadDistance(path, position)
		path.GroundAt = position
	end
	path.Airborne = airborne
	path.FloorY = position.Y
	return reset, tookOff
end

-- Drop the hop markers every follower has passed: those at or behind `tailDistance`, the path distance of the last
-- follower (the head distance minus its offset; the head distance itself for an empty line).
function Path.DropPassed(path: Path, tailDistance: number): ()
	local hops = path.HopDist
	if #hops == 0 or hops[1] > tailDistance then
		return
	end
	local drop = 0
	while drop < #hops and hops[drop + 1] <= tailDistance do
		drop += 1
	end
	shiftHops(path, drop)
end

-- Studs of path behind the leader's live position `head`.
function Path.Length(path: Path, head: Vector3): number
	if path.Count == 0 then
		return 0
	end
	return Path.HeadDistance(path, head) - path.Dist[index(path, path.Count - 1)]
end

-- The newest `n` points, newest first (debug).
function Path.Newest(path: Path, n: number): { Vector3 }
	local out: { Vector3 } = {}
	for k = 0, math.min(n, path.Count) - 1 do
		table.insert(out, path.Points[index(path, k)])
	end
	return out
end

-- Place followers 1..count at `offsets[i]` studs behind `head` (ascending). Writes positions to `outPos` and the
-- forward direction of the path there (towards the leader, not normalised to flat) to `outDir`. Past the end of the
-- path, followers continue in a straight line.
function Path.Sample(
	path: Path,
	head: Vector3,
	offsets: { number },
	count: number,
	outPos: { Vector3 },
	outDir: { Vector3 }
): ()
	if count <= 0 then
		return
	end
	if path.Count == 0 then
		for i = 1, count do
			outPos[i] = head + Vector3.zAxis * offsets[i]
			outDir[i] = -Vector3.zAxis
		end
		return
	end
	local k = 0
	local segStart = head -- the newer end of the current segment
	local segEnd = path.Points[path.Head] -- the older end
	local segLen = (segStart - segEnd).Magnitude
	local acc = 0 -- studs from head to segStart
	local forward = -Vector3.zAxis
	if segLen > 1e-4 then
		forward = (segStart - segEnd) / segLen
	elseif path.Count > 1 then
		local older = path.Points[index(path, 1)]
		local d = segEnd - older
		if d.Magnitude > 1e-4 then
			forward = d.Unit
		end
	end
	local i = 1
	while i <= count do
		local want = offsets[i]
		if want <= acc + segLen then
			local a = if segLen > 1e-4 then (want - acc) / segLen else 0
			outPos[i] = segStart:Lerp(segEnd, a)
			outDir[i] = forward
			i += 1
		else
			k += 1
			if k >= path.Count then
				-- Off the end: carry on straight back from the oldest point.
				local tail = acc + segLen
				for j = i, count do
					outPos[j] = segEnd - forward * (offsets[j] - tail)
					outDir[j] = forward
				end
				return
			end
			acc += segLen
			segStart = segEnd
			local older = index(path, k)
			segEnd = path.Points[older]
			segLen = path.Dist[index(path, k - 1)] - path.Dist[older]
			if segLen > 1e-4 then
				forward = (segStart - segEnd) / segLen
			end
		end
	end
end

-- Cumulative spacing: offsets[i] = spacing of followers 1..i (spec 9.5). `spacing(i)` gives follower i's spacing.
function Path.Offsets(count: number, spacing: (i: number) -> number, out: { number }?): { number }
	local offsets = out or table.create(count, 0)
	local total = 0
	for i = 1, count do
		total += spacing(i)
		offsets[i] = total
	end
	if out then
		for i = count + 1, #out do
			out[i] = nil
		end
	end
	return offsets
end

return Path
