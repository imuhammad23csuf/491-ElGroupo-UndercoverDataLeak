-- FULLSCREEN AUTO-BUILT TITLE SCREEN
-- Just drop this LocalScript into StarterPlayerScripts or StarterGui

-- Rewrite this entire thing

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------
-- CREATE SCREEN GUI
---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TitleScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

---------------------------------------------------------
-- HELPER: CREATE A CENTERED PANEL
---------------------------------------------------------
local function createPanel(name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0.5, 0, 0.55, 0)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	return frame
end

---------------------------------------------------------
-- MAIN MENU PANEL
---------------------------------------------------------
local mainFrame = createPanel("MainFrame")
mainFrame.Visible = true

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 70)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "Undercover: Data Compromised"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local buttonHolder = Instance.new("Frame")
buttonHolder.Size = UDim2.new(1, -40, 0, 160)
buttonHolder.Position = UDim2.new(0.5, 0, 0.45, 0)
buttonHolder.AnchorPoint = Vector2.new(0.5, 0)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent = mainFrame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = buttonHolder

local function makeButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 45)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamSemibold
	button.Parent = buttonHolder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

local startButton   = makeButton("Start Mission")
local settingsButton = makeButton("Settings")
local helpButton    = makeButton("Help")

---------------------------------------------------------
-- SETTINGS PANEL
---------------------------------------------------------
local settingsFrame = createPanel("SettingsFrame")

local stitle = Instance.new("TextLabel")
stitle.Size = UDim2.new(1, 0, 0, 50)
stitle.Position = UDim2.new(0, 0, 0, 10)
stitle.BackgroundTransparency = 1
stitle.Text = "Settings"
stitle.TextColor3 = Color3.new(1, 1, 1)
stitle.TextScaled = true
stitle.Font = Enum.Font.GothamBold
stitle.Parent = settingsFrame

local function makeVolumeRow(labelText)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(0.85, 0, 0, 50)
	row.BackgroundTransparency = 1
	row.Parent = settingsFrame

	local layout = settingsFrame:FindFirstChild("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = settingsFrame
	end

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText .. " (0–100)"
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.35, 0, 1, 0)
	box.Position = UDim2.new(0.65, 0, 0, 0)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.Text = "50"
	box.TextScaled = true
	box.Font = Enum.Font.Gotham
	box.TextColor3 = Color3.new(1, 1, 1)
	box.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box

	return box
end

local masterBox = makeVolumeRow("Master Volume")
local sfxBox = makeVolumeRow("SFX Volume")

local settingsBack = Instance.new("TextButton")
settingsBack.Size = UDim2.new(0.5, 0, 0, 40)
settingsBack.AnchorPoint = Vector2.new(0.5, 1)
settingsBack.Position = UDim2.new(0.5, 0, 0.95, 0)
settingsBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
settingsBack.Text = "Back"
settingsBack.TextColor3 = Color3.new(1, 1, 1)
settingsBack.TextScaled = true
settingsBack.Font = Enum.Font.GothamSemibold
settingsBack.Parent = settingsFrame
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = settingsBack
end

---------------------------------------------------------
-- HELP PANEL
---------------------------------------------------------
local helpFrame = createPanel("HelpFrame")

local htitle = Instance.new("TextLabel")
htitle.Size = UDim2.new(1, 0, 0, 50)
htitle.Position = UDim2.new(0, 0, 0, 10)
htitle.BackgroundTransparency = 1
htitle.Text = "Mission Briefing"
htitle.TextColor3 = Color3.new(1, 1, 1)
htitle.TextScaled = true
htitle.Font = Enum.Font.GothamBold
htitle.Parent = helpFrame

local body = Instance.new("TextLabel")
body.Size = UDim2.new(0.9, 0, 0.65, 0)
body.Position = UDim2.new(0.5, 0, 0.55, 0)
body.AnchorPoint = Vector2.new(0.5, 0.5)
body.BackgroundTransparency = 1
body.TextColor3 = Color3.new(1, 1, 1)
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.Font = Enum.Font.Gotham
body.Text = [[
You are contacted by an undercover cybersecurity professional.

Their agency is under heavy controversy. Someone inside the organization
is leaking confidential data, repeatedly and intentionally.

Your objectives:
• Identify WHO is leaking the data
• Determine WHAT they leaked
• Figure out HOW they are doing it

Use your in-game tablet to hack systems, analyze logs, and uncover the truth.
]]
body.TextScaled = false
body.TextSize = 18
body.Parent = helpFrame

local helpBack = Instance.new("TextButton")
helpBack.Size = UDim2.new(0.5, 0, 0, 40)
helpBack.AnchorPoint = Vector2.new(0.5, 1)
helpBack.Position = UDim2.new(0.5, 0, 0.95, 0)
helpBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
helpBack.Text = "Back"
helpBack.TextColor3 = Color3.new(1, 1, 1)
helpBack.TextScaled = true
helpBack.Font = Enum.Font.GothamSemibold
helpBack.Parent = helpFrame
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = helpBack
end

---------------------------------------------------------
-- MENU SWITCHING
---------------------------------------------------------
local function showMain()
	mainFrame.Visible = true
	settingsFrame.Visible = false
	helpFrame.Visible = false
end

local function showSettings()
	mainFrame.Visible = false
	settingsFrame.Visible = true
	helpFrame.Visible = false
end

local function showHelp()
	mainFrame.Visible = false
	settingsFrame.Visible = false
	helpFrame.Visible = true
end

---------------------------------------------------------
-- SOUND CONTROL
---------------------------------------------------------
local function applyVolume()
	local m = tonumber(masterBox.Text) or 50
	local s = tonumber(sfxBox.Text) or 50
	SoundService.Volume = math.clamp(m / 100, 0, 1)
	SoundService:SetAttribute("SFXVolume", math.clamp(s / 100, 0, 1))
end

masterBox.FocusLost:Connect(applyVolume)
sfxBox.FocusLost:Connect(applyVolume)

---------------------------------------------------------
-- CUTSCENE CALL
---------------------------------------------------------
local function startCutscene()
	local evt = ReplicatedStorage:FindFirstChild("StartNewsCutscene")
	if evt then
		evt:FireServer()
	else
		warn("StartNewsCutscene RemoteEvent missing in ReplicatedStorage!")
	end
end

---------------------------------------------------------
-- BUTTON CONNECTIONS
---------------------------------------------------------
startButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
	startCutscene()
end)

settingsButton.MouseButton1Click:Connect(showSettings)
helpButton.MouseButton1Click:Connect(showHelp)
settingsBack.MouseButton1Click:Connect(showMain)
helpBack.MouseButton1Click:Connect(showMain)

showMain()
