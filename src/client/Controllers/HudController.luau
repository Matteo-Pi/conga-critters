--!strict
-- HudController: interface (spec 7.1, 9.2).
-- C01-M2: a plain line counter, "length / capacity", from the Player's `LineLen` and `LineCap` attributes.
-- C01-M3: the Conga multiplier beside it (4.3), and a banner with confetti when the line first reaches each of
-- Config.Line.Banners (50 and 100; a clip moment, 7.4), or "FULL LINE!" instead when a line of at least
-- FullLineBannerMin reaches its own capacity (100 free, 150 with Longer Leash), so every player's top gets the same
-- celebration. Placeholder look until the UI pass (Sun 15 Nov); coins,
-- LP and the rest arrive with their milestones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local LineRules = require(Shared:WaitForChild("LineRules") :: ModuleScript)

local localPlayer = Players.LocalPlayer

local HudController = {}

local label: TextLabel? = nil
local badge: TextLabel? = nil
local gui: ScreenGui? = nil
local lastLength = 0

local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function attributeNumber(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function multiplierText(multiplier: number): string
	local text = string.format("%.2f", multiplier):gsub("0+$", ""):gsub("%.$", "")
	return `×{text}`
end

local function confetti(parent: ScreenGui)
	local colors = {
		Color3.fromRGB(255, 92, 92),
		Color3.fromRGB(255, 196, 40),
		Color3.fromRGB(92, 220, 120),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(200, 120, 255),
	}
	local rng = Random.new()
	local pieces: { { Frame: Frame, X: number, Y: number, VX: number, VY: number, Spin: number } } = {}
	for i = 1, 60 do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(rng:NextInteger(6, 12), rng:NextInteger(10, 18))
		frame.BackgroundColor3 = colors[i % #colors + 1]
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Parent = parent
		table.insert(pieces, {
			Frame = frame,
			X = rng:NextNumber(0.3, 0.7),
			Y = 0.2,
			VX = rng:NextNumber(-0.35, 0.35),
			VY = rng:NextNumber(-0.9, -0.3),
			Spin = rng:NextNumber(-360, 360),
		})
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local age = os.clock() - started
		for _, piece in pieces do
			piece.VY += 1.4 * dt
			piece.X += piece.VX * dt
			piece.Y += piece.VY * dt
			piece.Frame.Position = UDim2.fromScale(piece.X, piece.Y)
			piece.Frame.Rotation += piece.Spin * dt
			piece.Frame.BackgroundTransparency = math.clamp((age - 1.6) / 0.8, 0, 1)
		end
		if age > 2.4 then
			connection:Disconnect()
			for _, piece in pieces do
				piece.Frame:Destroy()
			end
		end
	end)
end

local function banner(length: number, title: string?)
	local parent = gui
	if not parent then
		return
	end
	local text = Instance.new("TextLabel")
	text.Name = "Banner"
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.3)
	text.Size = UDim2.fromScale(0.6, 0.12)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 230, 120)
	text.TextStrokeTransparency = 0.2
	text.TextScaled = true
	text.FontFace = FONT
	text.Text = `{title or `{length}!`}  {multiplierText(LineRules.Conga(length))}`
	text.Parent = parent
	confetti(parent)
	task.delay(2.4, function()
		text:Destroy()
	end)
end

local function refresh()
	local length = attributeNumber("LineLen")
	local capacity = attributeNumber("LineCap")
	local text = label
	if text then
		text.Text = `{length} / {capacity}`
	end
	local multiplier = LineRules.Conga(length)
	local mark = badge
	if mark then
		mark.Text = multiplierText(multiplier)
		mark.Visible = length > 0
	end
	if capacity >= Config.Line.FullLineBannerMin and lastLength < capacity and length >= capacity then
		banner(length, "FULL LINE!")
	else
		for _, threshold in Config.Line.Banners do
			if lastLength < threshold and length >= threshold then
				banner(threshold)
			end
		end
	end
	lastLength = length
end

function HudController.Init(): () end

function HudController.Start(): ()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Hud"
	screen.ResetOnSpawn = false
	gui = screen

	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 8)
	text.Size = UDim2.fromOffset(140, 40)
	text.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.FontFace = FONT
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = text
	text.Parent = screen
	label = text

	local mark = Instance.new("TextLabel")
	mark.Name = "Conga"
	mark.AnchorPoint = Vector2.new(0, 0)
	mark.Position = UDim2.new(0.5, 76, 0, 12)
	mark.Size = UDim2.fromOffset(64, 32)
	mark.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	mark.BackgroundTransparency = 0.1
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.TextStrokeTransparency = 0.5
	mark.TextScaled = true
	mark.FontFace = FONT
	mark.Visible = false
	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(0.4, 0)
	markCorner.Parent = mark
	mark.Parent = screen
	badge = mark

	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	lastLength = attributeNumber("LineLen") -- no banners for a line we joined with
	localPlayer:GetAttributeChangedSignal("LineLen"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("LineCap"):Connect(refresh)
	refresh()
end

export type HudController = typeof(HudController)

return HudController
