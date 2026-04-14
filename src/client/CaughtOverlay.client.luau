local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("CaughtRemotes")
local showCaughtEvent = remotesFolder:WaitForChild("ShowCaught")
local CAUGHT_SOUND_ID = "rbxassetid://15641323951"

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CaughtOverlayGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
background.BackgroundTransparency = 0.35
background.Parent = screenGui

local label = Instance.new("TextLabel")
label.Name = "CaughtLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.5)
label.Size = UDim2.fromScale(0.45, 0.15)
label.BackgroundTransparency = 1
label.Text = "CAUGHT"
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(255, 80, 80)
label.Parent = background

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = 72
textConstraint.MinTextSize = 24
textConstraint.Parent = label

local subLabel = Instance.new("TextLabel")
subLabel.Name = "CaughtSubLabel"
subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
subLabel.Position = UDim2.fromScale(0.5, 0.6)
subLabel.Size = UDim2.fromScale(0.4, 0.08)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Cover Blown" .. utf8.char(0x1F480)
subLabel.TextScaled = true
subLabel.Font = Enum.Font.GothamMedium
subLabel.TextColor3 = Color3.fromRGB(255, 210, 210)
subLabel.Parent = background

local subTextConstraint = Instance.new("UITextSizeConstraint")
subTextConstraint.MaxTextSize = 36
subTextConstraint.MinTextSize = 16
subTextConstraint.Parent = subLabel

local caughtSound = Instance.new("Sound")
caughtSound.Name = "CaughtOverlaySound"
caughtSound.SoundId = CAUGHT_SOUND_ID
caughtSound.Volume = 1
caughtSound.Looped = false
caughtSound.Parent = SoundService

showCaughtEvent.OnClientEvent:Connect(function(isVisible)
	screenGui.Enabled = isVisible

	if isVisible then
		caughtSound:Stop()
		caughtSound.TimePosition = 0
		caughtSound:Play()
	else
		caughtSound:Stop()
	end
end)
