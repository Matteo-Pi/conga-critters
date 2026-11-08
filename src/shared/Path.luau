--!strict
-- Path: breadcrumb path maths for the server and clients (spec 9.5).
--
-- A ring buffer of ground-level points with the cumulative distance walked at each. The leader adds a point once it
-- has moved MinStep studs; the path keeps `Keep` studs (capacity × KeepPerCapacity + KeepExtra) and grows its ring
-- when it needs more room. `Sample` places every follower in one pass from the leader's live position back through
-- the points, so it costs points + followers, not points × followers. A jump longer than ResetJump between two
-- samples (a respawn, or the server moving the player) resets the path to a straight line behind the leader.
--
-- Followers walk the leader's exact path, height included, so a jump makes the line hop at the same spot (4.3).

local Config = require(script.Parent.Config)

local Path = {}

export type Path = {
	Points: { Vector3 },
	Dist: { number }, -- cumulative distance at each point
	Size: number, -- ring capacity
	Head: number, -- ring index of the newest point
	Count: number,
	Keep: number, -- studs to keep
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
	while path.Count > 2 and distance - path.Dist[index(path, path.Count - 2)] >= path.Keep do
		path.Count -= 1
	end
end

-- Start again: a straight line `Keep` studs long running back from `position` along `back`.
function Path.Reset(path: Path, position: Vector3, back: Vector3): ()
	local flat = Vector3.new(back.X, 0, back.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	path.Head = 0
	path.Count = 0
	push(path, position + direction * path.Keep, 0)
	push(path, position, path.Keep)
end

-- Add the leader's position. Returns true when the path was reset (empty, or a jump longer than ResetJump):
-- callers snap their followers instead of gliding them. `back` points behind the leader, for resets.
function Path.Record(path: Path, position: Vector3, back: Vector3): boolean
	if path.Count == 0 then
		Path.Reset(path, position, back)
		return true
	end
	local newest = path.Points[path.Head]
	local step = (position - newest).Magnitude
	if step > Config.Line.Path.ResetJump then
		Path.Reset(path, position, back)
		return true
	end
	if step >= Config.Line.Path.MinStep then
		push(path, position, path.Dist[path.Head] + step)
	end
	return false
end

-- Studs of path behind the leader's live position `head`.
function Path.Length(path: Path, head: Vector3): number
	if path.Count == 0 then
		return 0
	end
	local newest = path.Head
	return (head - path.Points[newest]).Magnitude + path.Dist[newest] - path.Dist[index(path, path.Count - 1)]
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
