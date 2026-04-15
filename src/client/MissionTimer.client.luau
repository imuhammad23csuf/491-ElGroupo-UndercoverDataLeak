-- MissionTimer.client.luau
-- Renders a live HUD timer during an active mission and shows a
-- completion card (with personal-best celebration) when the mission ends.

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Wait for Remotes ────────────────────────────────────────────────────────
local Remotes      = ReplicatedStorage:WaitForChild("MissionTimerRemotes", 10)
local EvStart      = Remotes:WaitForChild("StartTimer")
local EvStop       = Remotes:WaitForChild("StopTimer")
local EvNewBest    = Remotes:WaitForChild("NewBestTime")
local EvLeaderboard= Remotes:WaitForChild("LeaderboardUpdate")
local FnGetBest    = Remotes:WaitForChild("GetMyBestTime")

-- ─── Build ScreenGui ─────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "MissionTimerGui"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- ══════════════════════════════════════════════════════════════
-- HUD TIMER  (top-centre, shown during mission)
-- ══════════════════════════════════════════════════════════════
local hudFrame = Instance.new("Frame")
hudFrame.Name            = "HudTimer"
hudFrame.Size            = UDim2.new(0, 200, 0, 52)
hudFrame.AnchorPoint     = Vector2.new(0.5, 0)
hudFrame.Position        = UDim2.new(0.5, 0, 0, 18)
hudFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
hudFrame.BackgroundTransparency = 0.25
hudFrame.BorderSizePixel = 0
hudFrame.Visible         = false
hudFrame.Parent          = screenGui

local hudCorner = Instance.new("UICorner", hudFrame)
hudCorner.CornerRadius = UDim.new(0, 10)

local hudStroke = Instance.new("UIStroke", hudFrame)
hudStroke.Color = Color3.fromRGB(80, 200, 255)
hudStroke.Thickness = 1.5
hudStroke.Transparency = 0.4

local hudLabel = Instance.new("TextLabel")
hudLabel.Name            = "TimeLabel"
hudLabel.Size            = UDim2.new(1, 0, 1, 0)
hudLabel.BackgroundTransparency = 1
hudLabel.Font            = Enum.Font.GothamBold
hudLabel.TextSize        = 26
hudLabel.TextColor3      = Color3.fromRGB(220, 245, 255)
hudLabel.Text            = "00:00.00"
hudLabel.Parent          = hudFrame

-- small "MISSION TIME" caption above the digits
local hudCaption = Instance.new("TextLabel")
hudCaption.Size              = UDim2.new(1, 0, 0, 14)
hudCaption.Position          = UDim2.new(0, 0, -0.35, 0)
hudCaption.BackgroundTransparency = 1
hudCaption.Font              = Enum.Font.GothamMedium
hudCaption.TextSize          = 11
hudCaption.TextColor3        = Color3.fromRGB(80, 200, 255)
hudCaption.Text              = "MISSION TIME"
hudCaption.TextTransparency  = 0.2
hudCaption.Parent            = hudFrame

-- ══════════════════════════════════════════════════════════════
-- COMPLETION CARD  (centre screen, shown on mission end)
-- ══════════════════════════════════════════════════════════════
local cardFrame = Instance.new("Frame")
cardFrame.Name               = "CompletionCard"
cardFrame.Size               = UDim2.new(0, 340, 0, 210)
cardFrame.AnchorPoint        = Vector2.new(0.5, 0.5)
cardFrame.Position           = UDim2.new(0.5, 0, 0.5, 0)
cardFrame.BackgroundColor3   = Color3.fromRGB(8, 8, 16)
cardFrame.BackgroundTransparency = 0.1
cardFrame.BorderSizePixel    = 0
cardFrame.Visible            = false
cardFrame.Parent             = screenGui

local cardCorner = Instance.new("UICorner", cardFrame)
cardCorner.CornerRadius = UDim.new(0, 16)

local cardStroke = Instance.new("UIStroke", cardFrame)
cardStroke.Color     = Color3.fromRGB(80, 200, 255)
cardStroke.Thickness = 2

local outcomeLabel = Instance.new("TextLabel")
outcomeLabel.Name                = "OutcomeLabel"
outcomeLabel.Size                = UDim2.new(1, -20, 0, 44)
outcomeLabel.Position            = UDim2.new(0, 10, 0, 14)
outcomeLabel.BackgroundTransparency = 1
outcomeLabel.Font                = Enum.Font.GothamBlack
outcomeLabel.TextSize            = 32
outcomeLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
outcomeLabel.Text                = "ESCAPED"
outcomeLabel.Parent              = cardFrame

local timeValueLabel = Instance.new("TextLabel")
timeValueLabel.Name              = "TimeValue"
timeValueLabel.Size              = UDim2.new(1, -20, 0, 54)
timeValueLabel.Position          = UDim2.new(0, 10, 0, 64)
timeValueLabel.BackgroundTransparency = 1
timeValueLabel.Font              = Enum.Font.GothamBold
timeValueLabel.TextSize          = 48
timeValueLabel.TextColor3        = Color3.fromRGB(80, 220, 255)
timeValueLabel.Text              = "00:00.00"
timeValueLabel.Parent            = cardFrame

local bestLabel = Instance.new("TextLabel")
bestLabel.Name                   = "BestLabel"
bestLabel.Size                   = UDim2.new(1, -20, 0, 22)
bestLabel.Position               = UDim2.new(0, 10, 0, 124)
bestLabel.BackgroundTransparency = 1
bestLabel.Font                   = Enum.Font.GothamMedium
bestLabel.TextSize               = 15
bestLabel.TextColor3             = Color3.fromRGB(160, 200, 220)
bestLabel.Text                   = "Personal Best: --:--.--"
bestLabel.Parent                 = cardFrame

local newBestBadge = Instance.new("TextLabel")
newBestBadge.Name                = "NewBestBadge"
newBestBadge.Size                = UDim2.new(0, 140, 0, 28)
newBestBadge.AnchorPoint         = Vector2.new(0.5, 0)
newBestBadge.Position            = UDim2.new(0.5, 0, 0, 155)
newBestBadge.BackgroundColor3    = Color3.fromRGB(255, 195, 0)
newBestBadge.BorderSizePixel     = 0
newBestBadge.Visible             = false
newBestBadge.Parent              = cardFrame

local badgeCorner = Instance.new("UICorner", newBestBadge)
badgeCorner.CornerRadius = UDim.new(0, 6)

local badgeText = Instance.new("TextLabel")
badgeText.Size               = UDim2.new(1, 0, 1, 0)
badgeText.BackgroundTransparency = 1
badgeText.Font               = Enum.Font.GothamBlack
badgeText.TextSize           = 14
badgeText.TextColor3         = Color3.fromRGB(30, 20, 0)
badgeText.Text               = "🏆 NEW BEST TIME!"
badgeText.Parent             = newBestBadge

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function formatTime(seconds: number): string
	local mins  = math.floor(seconds / 60)
	local secs  = math.floor(seconds % 60)
	local cents = math.floor((seconds % 1) * 100)
	return ("%02d:%02d.%02d"):format(mins, secs, cents)
end

local function showCard(elapsed: number, outcome: string)
	local isEscaped = outcome == "escaped"
	outcomeLabel.Text      = isEscaped and "✓ ESCAPED" or "✗ CAUGHT"
	outcomeLabel.TextColor3 = isEscaped
		and Color3.fromRGB(80, 255, 160)
		or  Color3.fromRGB(255, 80, 80)
	cardStroke.Color       = isEscaped
		and Color3.fromRGB(80, 255, 160)
		or  Color3.fromRGB(255, 80, 80)

	timeValueLabel.Text    = formatTime(elapsed)
	newBestBadge.Visible   = false

	-- Load personal best label
	task.spawn(function()
		local best = FnGetBest:InvokeServer()
		if best then
			bestLabel.Text = "Personal Best: " .. formatTime(best)
		else
			bestLabel.Text = "Personal Best: --:--.--"
		end
	end)

	cardFrame.Visible = true
	cardFrame.BackgroundTransparency = 1
	TweenService:Create(cardFrame,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.1 }
	):Play()

	-- Auto-hide after 5 seconds
	task.delay(5, function()
		local tween = TweenService:Create(cardFrame,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		cardFrame.Visible = false
	end)
end

-- ─── State ───────────────────────────────────────────────────────────────────
local missionStartTick: number? = nil
local runConnection: RBXScriptConnection? = nil

local function startHUD()
	missionStartTick  = tick()
	hudFrame.Visible  = true
	cardFrame.Visible = false

	runConnection = RunService.Heartbeat:Connect(function()
		if not missionStartTick then return end
		local elapsed = tick() - missionStartTick
		hudLabel.Text = formatTime(elapsed)
	end)
end

local function stopHUD()
	if runConnection then
		runConnection:Disconnect()
		runConnection = nil
	end
	hudFrame.Visible = false
	missionStartTick = nil
end

-- ─── Event Wiring ────────────────────────────────────────────────────────────
EvStart.OnClientEvent:Connect(function()
	startHUD()
end)

EvStop.OnClientEvent:Connect(function(elapsed: number, outcome: string)
	stopHUD()
	showCard(elapsed, outcome)
end)

EvNewBest.OnClientEvent:Connect(function(newTime: number, _previousTime: number?)
	-- Show the golden badge on the card that's already visible
	newBestBadge.Visible = true
	-- Pulse animation
	local pulse = TweenService:Create(newBestBadge,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
		{ Size = UDim2.new(0, 154, 0, 32) }
	)
	pulse:Play()
end)

print("[MissionTimer] Client module loaded.")
