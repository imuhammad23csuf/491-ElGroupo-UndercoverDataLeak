local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local REMOTE_NAME = "AgentRayDialogueEvent"
local AdvanceKeys = {
	Enum.KeyCode.E,
	Enum.KeyCode.Space,
	Enum.KeyCode.Return,
	Enum.KeyCode.ButtonA,
}

local DialogueRemote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 20)
if not DialogueRemote or not DialogueRemote:IsA("RemoteEvent") then
	warn("[AgentRayDialogue] Missing AgentRayDialogueEvent remote.")
	return
end

local activeToken = nil
local activeLines = {}
local currentIndex = 1
local isTyping = false
local currentFullText = ""

local Gui = Instance.new("ScreenGui")
Gui.Name = "AgentRayDialogueGui"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 110
Gui.Enabled = false
Gui.Parent = PlayerGui

local Shade = Instance.new("Frame")
Shade.Name = "Shade"
Shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shade.BackgroundTransparency = 1
Shade.BorderSizePixel = 0
Shade.Size = UDim2.fromScale(1, 1)
Shade.Parent = Gui

local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 1)
Panel.Position = UDim2.fromScale(0.5, 1.04)
Panel.Size = UDim2.fromScale(0.78, 0.24)
Panel.BackgroundColor3 = Color3.fromRGB(12, 18, 24)
Panel.BackgroundTransparency = 1
Panel.BorderSizePixel = 0
Panel.Parent = Gui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 8)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = Color3.fromRGB(72, 139, 190)
PanelStroke.Thickness = 2
PanelStroke.Transparency = 0.24
PanelStroke.Parent = Panel

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 16)
Padding.PaddingBottom = UDim.new(0, 16)
Padding.PaddingLeft = UDim.new(0, 18)
Padding.PaddingRight = UDim.new(0, 18)
Padding.Parent = Panel

local NameLabel = Instance.new("TextLabel")
NameLabel.Name = "NameLabel"
NameLabel.BackgroundTransparency = 1
NameLabel.Text = "SPECIAL AGENT RAY"
NameLabel.TextColor3 = Color3.fromRGB(224, 205, 138)
NameLabel.Font = Enum.Font.GothamBold
NameLabel.TextSize = 18
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.Size = UDim2.new(1, 0, 0, 24)
NameLabel.Parent = Panel

local AgencyLabel = Instance.new("TextLabel")
AgencyLabel.Name = "AgencyLabel"
AgencyLabel.BackgroundTransparency = 1
AgencyLabel.Text = "FEDERAL FIELD OPERATIONS"
AgencyLabel.TextColor3 = Color3.fromRGB(158, 190, 210)
AgencyLabel.Font = Enum.Font.GothamMedium
AgencyLabel.TextSize = 12
AgencyLabel.TextXAlignment = Enum.TextXAlignment.Left
AgencyLabel.Position = UDim2.fromOffset(0, 26)
AgencyLabel.Size = UDim2.new(1, 0, 0, 18)
AgencyLabel.Parent = Panel

local Divider = Instance.new("Frame")
Divider.BackgroundColor3 = Color3.fromRGB(66, 108, 140)
Divider.BackgroundTransparency = 0.35
Divider.BorderSizePixel = 0
Divider.Position = UDim2.fromOffset(0, 52)
Divider.Size = UDim2.new(1, 0, 0, 1)
Divider.Parent = Panel

local BodyLabel = Instance.new("TextLabel")
BodyLabel.Name = "BodyLabel"
BodyLabel.BackgroundTransparency = 1
BodyLabel.Text = ""
BodyLabel.TextColor3 = Color3.fromRGB(235, 240, 245)
BodyLabel.Font = Enum.Font.Gotham
BodyLabel.TextSize = 19
BodyLabel.TextWrapped = true
BodyLabel.TextXAlignment = Enum.TextXAlignment.Left
BodyLabel.TextYAlignment = Enum.TextYAlignment.Top
BodyLabel.Position = UDim2.fromOffset(0, 66)
BodyLabel.Size = UDim2.new(1, 0, 1, -104)
BodyLabel.Parent = Panel

local HintLabel = Instance.new("TextLabel")
HintLabel.Name = "HintLabel"
HintLabel.AnchorPoint = Vector2.new(1, 1)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "E / SPACE TO CONTINUE"
HintLabel.TextColor3 = Color3.fromRGB(150, 188, 212)
HintLabel.Font = Enum.Font.GothamSemibold
HintLabel.TextSize = 12
HintLabel.TextXAlignment = Enum.TextXAlignment.Right
HintLabel.Position = UDim2.new(1, 0, 1, 0)
HintLabel.Size = UDim2.new(0.55, 0, 0, 22)
HintLabel.Parent = Panel

local Scale = Instance.new("UIScale")
Scale.Scale = 1
Scale.Parent = Panel

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	Scale.Scale = math.clamp(viewport.Y / 820, 0.82, 1.05)
end

updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function showGui()
	Gui.Enabled = true
	Shade.BackgroundTransparency = 1
	Panel.BackgroundTransparency = 1
	Panel.Position = UDim2.fromScale(0.5, 1.04)

	TweenService:Create(
		Shade,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.48 }
	):Play()
	TweenService:Create(
		Panel,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.965), BackgroundTransparency = 0.02 }
	):Play()
end

local function hideGui()
	TweenService:Create(
		Shade,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
	local tween = TweenService:Create(
		Panel,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromScale(0.5, 1.04), BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	Gui.Enabled = false
end

local function typeLine(text)
	isTyping = true
	currentFullText = tostring(text or "")
	BodyLabel.Text = ""

	for index = 1, #currentFullText do
		if not isTyping then
			BodyLabel.Text = currentFullText
			return
		end

		BodyLabel.Text = string.sub(currentFullText, 1, index)
		task.wait(0.014)
	end

	isTyping = false
end

local function completeDialogue()
	local token = activeToken
	activeToken = nil
	activeLines = {}
	currentIndex = 1
	isTyping = false
	hideGui()

	if token then
		DialogueRemote:FireServer("Complete", token)
	end
end

local function showCurrentLine()
	if not activeToken then
		return
	end

	local line = activeLines[currentIndex]
	if line == nil then
		completeDialogue()
		return
	end

	task.spawn(typeLine, line)
end

local function advanceDialogue()
	if not activeToken then
		return
	end

	if isTyping then
		isTyping = false
		BodyLabel.Text = currentFullText
		return
	end

	currentIndex = currentIndex + 1
	showCurrentLine()
end

local function startDialogue(token, lines)
	if activeToken then
		DialogueRemote:FireServer("Cancel", activeToken)
	end

	activeToken = token
	activeLines = {}
	currentIndex = 1

	if type(lines) == "table" then
		for _, line in ipairs(lines) do
			table.insert(activeLines, tostring(line))
		end
	end

	if #activeLines == 0 then
		table.insert(activeLines, "Special Agent Ray has no briefing available.")
	end

	showGui()
	showCurrentLine()
end

DialogueRemote.OnClientEvent:Connect(function(action, token, lines)
	if action == "Start" then
		startDialogue(token, lines)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not activeToken then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		advanceDialogue()
		return
	end

	for _, keyCode in ipairs(AdvanceKeys) do
		if input.KeyCode == keyCode then
			advanceDialogue()
			return
		end
	end
end)
