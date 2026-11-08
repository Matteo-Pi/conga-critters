--!strict
-- InputController: throw actions (Input Action System) (spec 4.1, 9.2).
--
-- One InputContext ("PlayContext") with two Bool actions:
--   ThrowForward: the THROW button (InputBinding.UIButton, phones) and the right trigger (ButtonR2, console).
--                 Throws along the camera's forward direction to full range.
--   ThrowPointer: left click (MouseLeftButton). Throws at the mouse point, limited to range. Only acts when the
--                 preferred input is keyboard and mouse, and ignores clicks on our buttons.
-- The landing point is moved back towards the player until it is on the floor of the biome they stand in, so a
-- throw at a wall lands at the wall. The client keeps the 0.8 s cooldown, draws the arc at once (CritterFx) and sends
-- ThrowBait; the server decides (spec 9.3).
--
-- THROW is hidden outside biomes (the hub, gates, pens) and greys out when the line plus the critters on their way
-- reach capacity (spec 4.1). It is shown on every device, because it is also the leash-full indicator (spec 16).
-- The Golden Bait toggle appears once the player owns some (spec 4.1).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)
local LineRules = require(Shared:WaitForChild("LineRules") :: ModuleScript)

local Controllers = script.Parent
local CritterFx = require(Controllers:WaitForChild("CritterFx") :: ModuleScript)
local ZoneController = require(Controllers:WaitForChild("ZoneController") :: ModuleScript)

local localPlayer = Players.LocalPlayer

local InputController = {}

local READY_COLOR = Color3.fromRGB(255, 176, 32)
local COOLDOWN_COLOR = Color3.fromRGB(255, 214, 140)
local FULL_COLOR = Color3.fromRGB(130, 130, 130)
local GOLDEN_ON_COLOR = Color3.fromRGB(255, 200, 40)
local GOLDEN_OFF_COLOR = Color3.fromRGB(90, 80, 60)
local LANDING_STEP = 2 -- studs: how far back each try moves a landing point that missed the biome

local throwRemote: RemoteEvent? = nil
local throwButton: TextButton? = nil
local goldenButton: TextButton? = nil
local goldenSelected = false
local lastThrowAt = -math.huge
local state = "" -- set on the first refresh

-- The button's state: "hidden", "full", "cooldown" or "ready". Also the button's `State` attribute, for tests.
function InputController.State(): string
	return state
end

local function attributeNumber(name: string, default: number): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" then value else default
end

-- This player's throw cooldown: 0.8 s, 0.05 s less per rebirth, at least 0.5 s (the server checks the same rule).
local function ownCooldown(): number
	return LineRules.ThrowCooldown(attributeNumber("Rebirths", 0))
end

local function isFull(): boolean
	return attributeNumber("LineLen", 0) + CritterFx.PendingOwn() >= attributeNumber("LineCap", 0)
end

local function liveRoot(): BasePart?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function rayParams(): RaycastParams
	local exclude: { Instance } = { CritterFx.Folder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true -- zone parts don't collide, so rays pass through them
	return params
end

-- The floor point `distance` studs along `direction`, moved back until it is in `biomeId`. Nil if none is.
local function landingPoint(root: BasePart, direction: Vector3, distance: number, biomeId: string): Vector3?
	local params = rayParams()
	local d = distance
	while d >= 0 do
		local p = root.Position + direction * d
		local hit = workspace:Raycast(Vector3.new(p.X, root.Position.Y + 10, p.Z), Vector3.new(0, -60, 0), params)
		if hit then
			local zone = ZoneController.Classify(hit.Position)
			if zone and zone.BiomeId == biomeId then
				return hit.Position
			end
		end
		d -= LANDING_STEP
	end
	return nil
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

local function forwardTarget(root: BasePart, biomeId: string): Vector3?
	local camera = workspace.CurrentCamera
	local direction = (camera and flat(camera.CFrame.LookVector)) or flat(root.CFrame.LookVector)
	if not direction then
		return nil
	end
	return landingPoint(root, direction, Config.Throw.Range, biomeId)
end

local function pointerTarget(root: BasePart, biomeId: string): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams())
	local aim = if hit then hit.Position else ray.Origin + ray.Direction * 1000
	local offset = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local direction = flat(offset) or flat(root.CFrame.LookVector)
	if not direction then
		return nil
	end
	return landingPoint(root, direction, math.min(offset.Magnitude, Config.Throw.Range), biomeId)
end

local function overOurButton(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local mouse = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(mouse.X - inset.X, mouse.Y - inset.Y) do
		if object:IsA("GuiButton") and object.Visible then
			return true
		end
	end
	return false
end

local function tryThrow(mode: "forward" | "pointer")
	if os.clock() - lastThrowAt < ownCooldown() then
		return
	end
	local root = liveRoot()
	local biomeId = ZoneController.Current().BiomeId
	if not root or not biomeId or isFull() then
		return
	end
	local target = if mode == "pointer" then pointerTarget(root, biomeId) else forwardTarget(root, biomeId)
	if not target then
		return
	end
	local golden = goldenSelected and attributeNumber("GoldenBait", 0) > 0
	lastThrowAt = os.clock()
	local origin = root.Position + Vector3.new(0, 1.5, 0) + (flat(target - root.Position) or Vector3.zero)
	CritterFx.ThrowLocal(origin, target, golden)
	if throwRemote then
		throwRemote:FireServer(target, golden)
	end
end

local function buildGui(): (TextButton, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ThrowGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local touch = UserInputService.TouchEnabled
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local small = math.min(viewport.X, viewport.Y) <= 500
	-- Above the touch jump button on phones; bottom-right elsewhere. The UI pass (Sun 15 Nov) revisits this.
	local size = if touch then (if small then 100 else 130) else 110
	local position = if touch
		then (if small then UDim2.new(1, -20, 1, -110) else UDim2.new(1, -40, 1, -240))
		else UDim2.new(1, -40, 1, -40)

	local button = Instance.new("TextButton")
	button.Name = "Throw"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = READY_COLOR
	button.AutoButtonColor = true
	button.Text = "THROW"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.16, 0)
	padding.PaddingRight = UDim.new(0.16, 0)
	padding.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(120, 60, 0)
	stroke.Parent = button
	button.Parent = gui

	local golden = Instance.new("TextButton")
	golden.Name = "Golden"
	golden.AnchorPoint = Vector2.new(1, 1)
	golden.Position = position - UDim2.fromOffset(size + 12, 0)
	golden.Size = UDim2.fromOffset(math.floor(size * 0.6), math.floor(size * 0.6))
	golden.BackgroundColor3 = GOLDEN_OFF_COLOR
	golden.Text = "GOLD"
	golden.TextColor3 = Color3.new(1, 1, 1)
	golden.TextScaled = true
	golden.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	golden.Visible = false
	local goldenCorner = Instance.new("UICorner")
	goldenCorner.CornerRadius = UDim.new(0.5, 0)
	goldenCorner.Parent = golden
	golden.Parent = gui

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return button, golden
end

local function buildActions(button: TextButton)
	local folder = Instance.new("Folder")
	folder.Name = "Inputs"

	local context = Instance.new("InputContext")
	context.Name = "PlayContext"
	context.Parent = folder

	local forward = Instance.new("InputAction")
	forward.Name = "ThrowForward"
	forward.Type = Enum.InputActionType.Bool
	forward.Parent = context
	local touchBinding = Instance.new("InputBinding")
	touchBinding.Name = "TouchBinding"
	touchBinding.UIButton = button
	touchBinding.Parent = forward
	local gamepadBinding = Instance.new("InputBinding")
	gamepadBinding.Name = "GamepadBinding"
	gamepadBinding.KeyCode = Enum.KeyCode.ButtonR2
	gamepadBinding.Parent = forward

	local pointer = Instance.new("InputAction")
	pointer.Name = "ThrowPointer"
	pointer.Type = Enum.InputActionType.Bool
	pointer.Parent = context
	local mouseBinding = Instance.new("InputBinding")
	mouseBinding.Name = "MouseBinding"
	mouseBinding.KeyCode = Enum.KeyCode.MouseLeftButton
	mouseBinding.Parent = pointer

	forward.Pressed:Connect(function()
		tryThrow("forward")
	end)
	pointer.Pressed:Connect(function()
		if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse and not overOurButton() then
			tryThrow("pointer")
		end
	end)

	folder.Parent = localPlayer:WaitForChild("PlayerScripts")
end

local function setState(newState: string)
	local button = throwButton
	if not button then
		return
	end
	if newState ~= state then
		state = newState
		button:SetAttribute("State", newState)
	end
	button.Visible = newState ~= "hidden"
	button.BackgroundColor3 = if newState == "full"
		then FULL_COLOR
		elseif newState == "cooldown" then COOLDOWN_COLOR
		else READY_COLOR
	button.TextTransparency = if newState == "full" then 0.45 else 0
	button.AutoButtonColor = newState == "ready"
end

local function refresh()
	local inBiome = ZoneController.Current().BiomeId ~= nil and liveRoot() ~= nil
	if not inBiome then
		setState("hidden")
	elseif isFull() then
		setState("full")
	elseif os.clock() - lastThrowAt < ownCooldown() then
		setState("cooldown")
	else
		setState("ready")
	end

	local golden = goldenButton
	if golden then
		local count = attributeNumber("GoldenBait", 0)
		if count <= 0 then
			goldenSelected = false
		end
		golden.Visible = count > 0 and state ~= "hidden"
		golden.Text = `GOLD ×{count}`
		golden.BackgroundColor3 = if goldenSelected then GOLDEN_ON_COLOR else GOLDEN_OFF_COLOR
	end
end

function InputController.Init(): () end

function InputController.Start(): ()
	local button, golden = buildGui()
	throwButton = button
	goldenButton = golden
	golden.Activated:Connect(function()
		goldenSelected = not goldenSelected
	end)
	buildActions(button)
	task.spawn(function()
		throwRemote = Net.Event(Net.Names.ThrowBait)
	end)
	RunService.Heartbeat:Connect(refresh)
end

export type InputController = typeof(InputController)

return InputController
