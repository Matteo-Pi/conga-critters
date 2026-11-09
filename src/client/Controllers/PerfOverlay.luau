--!strict
-- PerfOverlay: `/debug perf [on|off]` (spec 9.10). A small box on the player's own screen with FPS, the average and
-- worst LineRenderer ms over the last Config.Debug.PerfWindowSeconds (5 s), and how many followers are drawn.
-- Client only: the client hears its own chat command (TextChatCommand.Triggered fires on the sender's client as well
-- as the server), so nothing goes over the network. Debug-whitelisted players and Studio only (DebugAccess); off by
-- default and never saved. While it's off, LineRenderer has no observer and pays nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local DebugAccess = require(Shared:WaitForChild("DebugAccess") :: ModuleScript)
local LineRenderer = require(script.Parent:WaitForChild("LineRenderer") :: ModuleScript)

local localPlayer = Players.LocalPlayer

local PerfOverlay = {}

local FONT = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

local gui: ScreenGui? = nil
local label: TextLabel? = nil
local on = false

-- Frames in the window: when each was drawn (os.clock) and its LineRenderer ms. `head` is the oldest kept.
local times: { number } = {}
local costs: { number } = {}
local head = 1
local lastDrawn = 0
local nextRefresh = 0

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
	text.Size = UDim2.fromOffset(196, 62)
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	text.BackgroundTransparency = 0.3
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextSize = 13
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

local function refresh(now: number)
	local text = label
	if not text then
		return
	end
	local count, sum, worst, lastSecond = 0, 0, 0, 0
	for i = head, #times do
		local ms = costs[i]
		count += 1
		sum += ms
		worst = math.max(worst, ms)
		if now - times[i] <= 1 then
			lastSecond += 1
		end
	end
	local window = Config.Debug.PerfWindowSeconds
	text.Text = if count == 0
		then "perf: no frames yet"
		else string.format(
			"FPS %d\nLine avg %.2f ms\nLine max %.2f ms (%gs)\nDrawn %d",
			lastSecond,
			sum / count,
			worst,
			window,
			lastDrawn
		)
end

local function onFrame(ms: number, drawn: number)
	local now = os.clock()
	table.insert(times, now)
	table.insert(costs, ms)
	lastDrawn = drawn
	local cutoff = now - Config.Debug.PerfWindowSeconds
	while head <= #times and times[head] < cutoff do
		head += 1
	end
	if head > 256 then -- drop the expired front now and then, so the arrays don't grow
		local kept = #times - head + 1
		table.move(times, head, #times, 1)
		table.move(costs, head, #costs, 1)
		for i = #times, kept + 1, -1 do
			times[i] = nil
			costs[i] = nil
		end
		head = 1
	end
	if now >= nextRefresh then
		nextRefresh = now + Config.Debug.PerfRefreshSeconds
		refresh(now)
	end
end

function PerfOverlay.SetEnabled(enabled: boolean): ()
	if enabled == on then
		return
	end
	on = enabled
	if enabled then
		table.clear(times)
		table.clear(costs)
		head = 1
		lastDrawn = 0
		nextRefresh = 0
		build().Text = "perf: waiting for frames"
		LineRenderer.SetFrameObserver(onFrame)
	else
		LineRenderer.SetFrameObserver(nil)
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
