-- MissionTimer.client.luau
-- Original lightweight HUD for the server-authored mission timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MissionTimerRemotes", 15)
if not remotes then
	warn("[MissionTimer] MissionTimerRemotes not found.")
	return
end

local EvStartTimer = remotes:WaitForChild("StartTimer")
local EvStopTimer = remotes:WaitForChild("StopTimer")
local EvNewBestTime = remotes:WaitForChild("NewBestTime")
local FnGetTimerState = remotes:WaitForChild("GetTimerState")

local running = false
local startClock = 0
local displayedElapsed = 0

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local minutes = math.floor(seconds / 60)
	local wholeSeconds = math.floor(seconds % 60)
	local centiseconds = math.floor((seconds % 1) * 100)
	return ("%02d:%02d.%02d"):format(minutes, wholeSeconds, centiseconds)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MissionTimerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "TimerFrame"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 18)
frame.Size = UDim2.new(0, 220, 0, 46)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(20, 100, 200)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.new(0, 12, 0, 5)
title.Size = UDim2.new(1, -24, 0, 14)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "MISSION TIMER"
title.TextColor3 = Color3.fromRGB(180, 205, 255)
title.TextSize = 11
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Position = UDim2.new(0, 12, 0, 17)
timeLabel.Size = UDim2.new(1, -24, 0, 24)
timeLabel.BackgroundTransparency = 1
timeLabel.Font = Enum.Font.GothamBlack
timeLabel.Text = formatTime(0)
timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timeLabel.TextSize = 22
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = frame

local function setElapsed(seconds)
	displayedElapsed = math.max(0, tonumber(seconds) or 0)
	timeLabel.Text = formatTime(displayedElapsed)
end

local function startTimer(initialElapsed)
	local elapsed = math.max(0, tonumber(initialElapsed) or 0)
	running = true
	startClock = os.clock() - elapsed
	setElapsed(elapsed)
end

local function stopTimer(elapsed, outcome)
	running = false

	if outcome == "caught" or outcome == "reset" then
		setElapsed(0)
	else
		setElapsed(elapsed)
	end
end

EvStartTimer.OnClientEvent:Connect(function(initialElapsed)
	startTimer(initialElapsed)
end)

EvStopTimer.OnClientEvent:Connect(stopTimer)

EvNewBestTime.OnClientEvent:Connect(function(newBest)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Mission Timer",
			Text = "New best time: " .. formatTime(newBest),
			Duration = 4,
		})
	end)
end)

RunService.RenderStepped:Connect(function()
	if running then
		setElapsed(os.clock() - startClock)
	end
end)

task.spawn(function()
	local ok, state = pcall(function()
		return FnGetTimerState:InvokeServer()
	end)

	if ok and type(state) == "table" then
		if state.running then
			startTimer(state.elapsed)
		else
			stopTimer(state.elapsed, "reset")
		end
	end
end)
