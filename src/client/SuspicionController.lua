local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UpdateEvent = ReplicatedStorage:WaitForChild("UpdateSuspicionEvent")


local SuspicionManager = require(ReplicatedStorage:WaitForChild("SuspicionManager"))

-- calls the files 
local gui = script.Parent
local background = gui:FindFirstChild("BackgroundBar", true)
local fillBar = background:FindFirstChild("FillBar", true)
local titleLabel = background:FindFirstChild("TitleLabel", true)


local neonGlow = gui:FindFirstChild("NeonGlow", true)
local glowStroke = neonGlow and neonGlow:FindFirstChild("UIStroke", true)
local uiGradient = glowStroke and glowStroke:FindFirstChild("UIGradient", true)

local COLORS = {
	SAFE = Color3.fromRGB(0, 255, 150),
	CAUTION = Color3.fromRGB(255, 200, 0),
	DANGER = Color3.fromRGB(255, 50, 50)
}

-- changes the color of the bar and text to match sus level
SuspicionManager.Changed:Connect(function(newValue)
	local percent = math.clamp(newValue / 100, 0, 1)

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(fillBar, tweenInfo, {Size = UDim2.new(percent, 0, 1, 0)}):Play()


	local targetColor
	if percent > 0.8 then
		targetColor = COLORS.DANGER
		titleLabel.Text = "!! EXPOSED !!"
	elseif percent > 0.4 then
		targetColor = COLORS.CAUTION
		titleLabel.Text = "SUSPICION: HIGH"
	else
		targetColor = COLORS.SAFE
		titleLabel.Text = "SUSPICION: CLEAR"
	end


	fillBar.BackgroundColor3 = targetColor
	titleLabel.TextColor3 = targetColor


	if neonGlow then
		neonGlow.Visible = true
		neonGlow.BackgroundTransparency = 1 


		if glowStroke then
			glowStroke.Color = targetColor
		end


		if uiGradient then
			uiGradient.Color = ColorSequence.new(targetColor)
		end
	end
end)
-- Auto decay of the suspicion bar 
task.spawn(function()
	while true do
		task.wait(1) -- Every 1 second
		-- If suspicion is above 0, lower it by 1 point (Tuning: Section 2.7.3)
		if SuspicionManager.Get() > 0 then
			SuspicionManager.Reduce(1) 
		end
	end
end)

UpdateEvent.OnClientEvent:Connect(function(amount)
	-- This adds the suspicion to your local UI copy of the manager
	SuspicionManager.Add(amount)
end)
