local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedRoot = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(sharedRoot:WaitForChild("SuspicionManager"))

local SuspicionController = {}

local COLORS = {
	SAFE = Color3.fromRGB(0, 255, 150),
	CAUTION = Color3.fromRGB(255, 200, 0),
	DANGER = Color3.fromRGB(255, 50, 50),
}

local initialized = false
local uiRefs

local function getUiRefs()
	if uiRefs and uiRefs.fillBar and uiRefs.fillBar.Parent then
		return uiRefs
	end

	local background = playerGui:FindFirstChild("BackgroundBar", true)
	if not background then
		return nil
	end

	local fillBar = background:FindFirstChild("FillBar", true)
	local titleLabel = background:FindFirstChild("TitleLabel", true)
	if not fillBar or not titleLabel then
		return nil
	end

	local screenGui = background:FindFirstAncestorOfClass("ScreenGui")
	local neonGlow = screenGui and screenGui:FindFirstChild("NeonGlow", true)
	local glowStroke = neonGlow and neonGlow:FindFirstChild("UIStroke", true)
	local uiGradient = glowStroke and glowStroke:FindFirstChild("UIGradient", true)

	uiRefs = {
		fillBar = fillBar,
		titleLabel = titleLabel,
		neonGlow = neonGlow,
		glowStroke = glowStroke,
		uiGradient = uiGradient,
	}

	return uiRefs
end

local function waitForUiRefs(timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	local refs = getUiRefs()

	while not refs and os.clock() < deadline do
		task.wait(0.1)
		refs = getUiRefs()
	end

	return refs
end

local function updateUi(newValue)
	local refs = getUiRefs()
	if not refs then
		return
	end

	local percent = math.clamp(newValue / 100, 0, 1)
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(refs.fillBar, tweenInfo, { Size = UDim2.new(percent, 0, 1, 0) }):Play()

	local targetColor
	if percent > 0.8 then
		targetColor = COLORS.DANGER
		refs.titleLabel.Text = "!! EXPOSED !!"
	elseif percent > 0.4 then
		targetColor = COLORS.CAUTION
		refs.titleLabel.Text = "SUSPICION: HIGH"
	else
		targetColor = COLORS.SAFE
		refs.titleLabel.Text = "SUSPICION: CLEAR"
	end

	refs.fillBar.BackgroundColor3 = targetColor
	refs.titleLabel.TextColor3 = targetColor

	if refs.neonGlow then
		refs.neonGlow.Visible = true
		refs.neonGlow.BackgroundTransparency = 1
	end

	if refs.glowStroke then
		refs.glowStroke.Color = targetColor
	end

	if refs.uiGradient then
		refs.uiGradient.Color = ColorSequence.new(targetColor)
	end
end

local function startDecayLoop()
	task.spawn(function()
		while true do
			task.wait(1)

			if SuspicionManager.Get() > 0 then
				SuspicionManager.Reduce(1)
			end
		end
	end)
end

function SuspicionController.init()
	if initialized then
		return SuspicionController
	end

	initialized = true

	if not waitForUiRefs(10) then
		warn("[SuspicionController] Suspicion UI was not found in PlayerGui.")
	end

	SuspicionManager.Changed:Connect(updateUi)
	updateUi(SuspicionManager.Get())
	startDecayLoop()

	return SuspicionController
end

return SuspicionController
