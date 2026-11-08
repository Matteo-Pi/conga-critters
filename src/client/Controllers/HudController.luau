--!strict
-- HudController: interface (spec 7.1, 9.2).
-- C01-M2: a plain line counter, "length / capacity", from the Player's `LineLen` and `LineCap` attributes. The full
-- HUD (Conga multiplier, coins, LP, banners) arrives with its milestones and the UI pass.

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local HudController = {}

local label: TextLabel? = nil

local function refresh()
	local text = label
	if not text then
		return
	end
	local length = localPlayer:GetAttribute("LineLen")
	local capacity = localPlayer:GetAttribute("LineCap")
	text.Text =
		`{if type(length) == "number" then length else 0} / {if type(capacity) == "number" then capacity else 0}`
end

function HudController.Init(): () end

function HudController.Start(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 8)
	text.Size = UDim2.fromOffset(140, 40)
	text.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = text
	text.Parent = gui
	label = text

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	localPlayer:GetAttributeChangedSignal("LineLen"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("LineCap"):Connect(refresh)
	refresh()
end

export type HudController = typeof(HudController)

return HudController
