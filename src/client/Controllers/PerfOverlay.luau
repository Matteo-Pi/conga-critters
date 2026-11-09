--!strict
-- PerfOverlay: `/debug perf [on|off]` (spec 9.10). A small box on the player's own screen:
--   * FPS over the last second, and the frame time (average and worst) over the last PerfWindowSeconds (5 s);
--   * LineRenderer's own time per drawn frame, average and worst, and its split: path sampling, jump waves and hops,
--     hop/waddle and CFrames, the rest of the per-follower loop, BulkMoveTo, and Heartbeat recording;
--   * how many followers (and parts) are drawn;
--   * Server Authority corrections in the last PerfCorrectionSeconds (30 s). Game scripts may not connect
--     RunService.Misprediction (it needs the PluginOrOpenCloud capability, so it only works from Studio plugins and
--     MCP), so the box uses the first source that works: Misprediction (with what was mispredicted), then
--     RunService.Rollback, then the start of each resimulation burst seen in a BindToSimulation callback
--     (RunService:IsResimulating). The box names the source it uses.
-- The split comes from os.clock timers inside LineRenderer that run only while the box is on; their own cost is
-- estimated (calls × the cost of one os.clock call on this device) and shown, so it can be taken off the totals.
-- Client only: the client hears its own chat command (TextChatCommand.Triggered fires on the sender's client as well
-- as the server), so nothing goes over the network. Debug-whitelisted players and Studio only (DebugAccess); off by
-- default and never saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local DebugAccess = require(Shared:WaitForChild("DebugAccess") :: ModuleScript)
local LineRenderer = require(script.Parent:WaitForChild("LineRenderer") :: ModuleScript)

local localPlayer = Players.LocalPlayer

local PerfOverlay = {}

local FONT = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

-- Per-frame series kept for the window, oldest at `head`.
local KEYS = { "Gap", "Ms", "SampleMs", "WaveMs", "HopMs", "LoopMs", "BulkMs", "RecordMs", "Timers" }

local gui: ScreenGui? = nil
local label: TextLabel? = nil
local on = false
local times: { number } = {}
local series: { [string]: { number } } = {}
local head = 1
local lastFrameAt = 0
local lastDrawn = 0
local lastParts = 0
local nextRefresh = 0
local clockCost = 0 -- ms per os.clock call on this device

local corrections: { number } = {} -- os.clock of each Misprediction in the last PerfCorrectionSeconds
local lastCorrection = "none"
local lastCorrectionAt = 0
local correctionSource = "none"
local stopCorrections: (() -> ())? = nil

for _, key in KEYS do
	series[key] = {}
end

local function build(): TextLabel
	local existing = label
	if existing and existing.Parent then
		return existing
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "PerfOverlay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 100
	screen.Enabled = false

	local text = Instance.new("TextLabel")
	text.Name = "Stats"
	text.AnchorPoint = Vector2.new(1, 0)
	text.Position = UDim2.new(1, -8, 0, 8)
	text.Size = UDim2.fromOffset(300, 132)
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	text.BackgroundTransparency = 0.3
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextSize = 12
	text.FontFace = FONT
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.Text = "perf: waiting for frames"
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text
	text.Parent = screen

	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
	label = text
	return text
end

-- What was mispredicted, from RunService.Misprediction's instances list: "HumanoidRootPart.CFrame +2".
local function describe(instances: any): string
	if type(instances) ~= "table" or #instances == 0 then
		return "?"
	end
	local first = instances[1]
	local name, property = "?", "?"
	if typeof(first) == "Instance" then
		name = first.Name
	elseif type(first) == "table" then
		local instance = first.Instance
		if typeof(instance) == "Instance" then
			name = instance.Name
		end
		local properties = first.Properties
		if type(properties) == "table" then
			for key, value in properties do
				if type(key) == "string" then
					property = key
				elseif type(value) == "table" and type(value.Name) == "string" then
					property = value.Name
				else
					property = tostring(value)
				end
				break
			end
		end
	end
	local more = if #instances > 1 then ` +{#instances - 1}` else ""
	return `{name}.{property}{more}`
end

local function onCorrection(what: string)
	local now = os.clock()
	table.insert(corrections, now)
	lastCorrectionAt = now
	lastCorrection = what
end

local function onMisprediction(_time: any, instances: any)
	local ok, text = pcall(describe, instances)
	onCorrection(if ok then text else "?")
end

-- Connect the first correction source this script is allowed to use; returns its name and how to stop it.
local function startCorrections(): (string, (() -> ())?)
	local okMis, misConnection = pcall(function(): RBXScriptConnection
		return RunService.Misprediction:Connect(onMisprediction)
	end)
	if okMis then
		return "mispredictions", function()
			misConnection:Disconnect()
		end
	end
	local okRollback, rollbackConnection = pcall(function(): RBXScriptConnection
		return (RunService :: any).Rollback:Connect(function()
			onCorrection("rollback")
		end)
	end)
	if okRollback then
		return "rollbacks", function()
			rollbackConnection:Disconnect()
		end
	end
	local resimulating = false
	local okResim, resimConnection = pcall(function(): any
		return RunService:BindToSimulation(function()
			local now = RunService:IsResimulating()
			if now and not resimulating then
				onCorrection("resimulation")
			end
			resimulating = now
		end)
	end)
	if okResim then
		return "resimulations",
			function()
				if typeof(resimConnection) == "RBXScriptConnection" then
					resimConnection:Disconnect()
				end
			end
	end
	return "unavailable", nil
end

local function refresh(now: number)
	local text = label
	if not text then
		return
	end
	local count = #times - head + 1
	if count <= 0 then
		text.Text = "perf: no frames yet"
		return
	end
	local sums: { [string]: number } = {}
	for _, key in KEYS do
		sums[key] = 0
	end
	local worstMs, worstGap, lastSecond = 0, 0, 0
	for i = head, #times do
		for _, key in KEYS do
			sums[key] += series[key][i]
		end
		worstMs = math.max(worstMs, series.Ms[i])
		worstGap = math.max(worstGap, series.Gap[i])
		if now - times[i] <= 1 then
			lastSecond += 1
		end
	end
	local function avg(key: string): number
		return sums[key] / count
	end
	local loopRest = avg("LoopMs") - avg("WaveMs") - avg("HopMs")
	local window = Config.Debug.PerfWindowSeconds

	local cutoff = now - Config.Debug.PerfCorrectionSeconds
	while #corrections > 0 and corrections[1] < cutoff do
		table.remove(corrections, 1)
	end
	local ago = if lastCorrectionAt > 0 then string.format(", %.0fs ago", now - lastCorrectionAt) else ""

	text.Text = table.concat({
		string.format("FPS %d  frame %.1f ms (max %.1f)", lastSecond, avg("Gap"), worstGap),
		string.format("Line %.2f ms avg, %.2f max (%gs)", avg("Ms"), worstMs, window),
		string.format(" sample %.2f  waves %.2f  hop %.2f", avg("SampleMs"), avg("WaveMs"), avg("HopMs")),
		string.format(" loop rest %.2f  bulk %.2f", loopRest, avg("BulkMs")),
		string.format(" record %.2f (Heartbeat, extra)", avg("RecordMs")),
		string.format(" timers ~%.2f ms (%d calls)", avg("Timers") * clockCost, math.floor(avg("Timers") + 0.5)),
		string.format("Drawn %d (%d parts)", lastDrawn, lastParts),
		string.format(
			"Corrections %gs: %d %s (%s%s)",
			Config.Debug.PerfCorrectionSeconds,
			#corrections,
			correctionSource,
			lastCorrection,
			ago
		),
	}, "\n")
end

local function onFrame(split: LineRenderer.FrameSplit)
	local now = os.clock()
	local gap = if lastFrameAt > 0 then (now - lastFrameAt) * 1000 else 0
	lastFrameAt = now
	table.insert(times, now)
	table.insert(series.Gap, gap)
	table.insert(series.Ms, split.Ms)
	table.insert(series.SampleMs, split.SampleMs)
	table.insert(series.WaveMs, split.WaveMs)
	table.insert(series.HopMs, split.HopMs)
	table.insert(series.LoopMs, split.LoopMs)
	table.insert(series.BulkMs, split.BulkMs)
	table.insert(series.RecordMs, split.RecordMs)
	table.insert(series.Timers, split.Timers)
	lastDrawn = split.Drawn
	lastParts = split.Parts

	local cutoff = now - Config.Debug.PerfWindowSeconds
	while head <= #times and times[head] < cutoff do
		head += 1
	end
	if head > 256 then -- drop the expired front now and then, so the arrays don't grow
		local n = #times
		local kept = n - head + 1
		for _, list in
			{
				times,
				series.Gap,
				series.Ms,
				series.SampleMs,
				series.WaveMs,
				series.HopMs,
				series.LoopMs,
				series.BulkMs,
				series.RecordMs,
				series.Timers,
			}
		do
			table.move(list, head, n, 1)
			for i = n, kept + 1, -1 do
				list[i] = nil
			end
		end
		head = 1
	end
	if now >= nextRefresh then
		nextRefresh = now + Config.Debug.PerfRefreshSeconds
		refresh(now)
	end
end

-- The cost of one os.clock call here, so the box can say how much its own timers add.
local function measureClock(): number
	local calls = 20000
	local started = os.clock()
	for _ = 1, calls do
		local _ = os.clock()
	end
	return (os.clock() - started) * 1000 / calls
end

function PerfOverlay.SetEnabled(enabled: boolean): ()
	if enabled == on then
		return
	end
	on = enabled
	if enabled then
		table.clear(times)
		for _, key in KEYS do
			table.clear(series[key])
		end
		table.clear(corrections)
		head = 1
		lastFrameAt = 0
		lastDrawn = 0
		lastParts = 0
		nextRefresh = 0
		lastCorrection = "none"
		lastCorrectionAt = 0
		clockCost = measureClock()
		build().Text = "perf: waiting for frames"
		correctionSource, stopCorrections = startCorrections()
		LineRenderer.SetFrameObserver(onFrame)
	else
		LineRenderer.SetFrameObserver(nil)
		local stop = stopCorrections
		if stop then
			stop()
			stopCorrections = nil
		end
	end
	local screen = gui
	if screen then
		screen.Enabled = enabled
	end
end

-- `/debug perf`, `/d perf on`, … from this client's own chat.
local function onCommand(source: TextSource, text: string)
	if source.UserId ~= localPlayer.UserId then
		return
	end
	local words: { string } = {}
	for word in string.gmatch(string.lower(text), "%S+") do
		table.insert(words, word)
	end
	-- words[1] is the alias (/debug or /d)
	if words[2] ~= string.lower(Config.Debug.PerfCommand) then
		return
	end
	local arg = words[3]
	PerfOverlay.SetEnabled(if arg == "on" then true elseif arg == "off" then false else not on)
end

function PerfOverlay.Init(): () end

function PerfOverlay.Start(): ()
	if not DebugAccess.Allowed(localPlayer.UserId) then
		return
	end
	task.spawn(function()
		-- The server creates the command in AdminService.Start; it replicates to every client.
		local command = TextChatService:WaitForChild(Config.Debug.ChatCommandName) :: TextChatCommand
		command.Triggered:Connect(onCommand)
	end)
end

export type PerfOverlay = typeof(PerfOverlay)

return PerfOverlay
