-- Phone cutscene: conversation between the agent and player.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerName = Player.Name
local PlayerGui = Player:WaitForChild("PlayerGui")
local Mouse = Player:GetMouse()
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = Workspace.CurrentCamera
local PhoneCallRequested = ReplicatedStorage:WaitForChild("PhoneCallRequested", 20)

local TypingSpeed = 0.018
local FadeUI = 0.2
local AdvanceKeys = { Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA }
local PHONE_CUTSCENE_STARTED_ATTRIBUTE = "PhoneCutsceneStarted"
local PHONE_CUTSCENE_COMPLETED_ATTRIBUTE = "PhoneCutsceneCompleted"

local NewsReady = false
local maybeStartRinging

local function updateNewsReady()
	NewsReady = Player:GetAttribute("NewsCutsceneCompleted") == true
end

updateNewsReady()

Player:GetAttributeChangedSignal("NewsCutsceneCompleted"):Connect(function()
	updateNewsReady()
	if NewsReady and maybeStartRinging then
		maybeStartRinging()
	end
end)

local function hasNewsFinished()
	return NewsReady
end

local function hasPhoneCutsceneStarted()
	return Player:GetAttribute(PHONE_CUTSCENE_STARTED_ATTRIBUTE) == true
		or Player:GetAttribute(PHONE_CUTSCENE_COMPLETED_ATTRIBUTE) == true
end

local SpawnCF
local function captureSpawnCF(char)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		SpawnCF = hrp.CFrame
	end
end

captureSpawnCF(Character)

Player.CharacterAdded:Connect(function(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	captureSpawnCF(char)
end)

local Conversation = {
	{ speaker = "Unknown Caller", text = "Hello. Am I speaking with " .. PlayerName .. "?" },
	{ speaker = PlayerName, text = "This is " .. PlayerName .. ". Identify yourself." },
	{ speaker = "Special Agent Ray", text = "This is Special Agent Ray. I am coordinating a federal inquiry into Bloxplay." },
	{ speaker = "Special Agent Ray", text = "The matter involves internal policy violations and possible exposure of sensitive material." },
	{ speaker = PlayerName, text = "Understood. What is my objective?" },
	{ speaker = "Special Agent Ray", text = "Meet me at the Cafe to get these tools. Once you have them, investigate discreetly and document any evidence you find." },
	{ speaker = "Special Agent Ray", text = "If security identifies you, the operation is compromised. Keep a low profile and move deliberately." },
	{ speaker = PlayerName, text = "Copy that. I will meet you at the Cafe before moving on the objective." },
	{ speaker = "Special Agent Ray", text = "Good. Maintain radio silence unless the channel is clear. You have two days before the situation escalates beyond containment." },
	{ speaker = PlayerName, text = "Acknowledged. Beginning the investigation." },
}

local function createPhoneUI()
	local scene = Instance.new("ScreenGui")
	scene.Name = "PhoneScene"
	scene.IgnoreGuiInset = true
	scene.ResetOnSpawn = false
	scene.DisplayOrder = 100
	scene.Enabled = false
	scene.Parent = PlayerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.fromRGB(2, 6, 10)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = scene

	local shadow = Instance.new("Frame")
	shadow.Name = "PanelShadow"
	shadow.AnchorPoint = Vector2.new(0.5, 1)
	shadow.Position = UDim2.fromScale(0.5, 1.045)
	shadow.Size = UDim2.fromScale(0.88, 0.34)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.Parent = scene

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, 1.035)
	root.Size = UDim2.fromScale(0.88, 0.34)
	root.BackgroundColor3 = Color3.fromRGB(12, 16, 20)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = scene

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 132, 170)
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = root

	local rootGradient = Instance.new("UIGradient")
	rootGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 25)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 31, 37)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 13, 18)),
	})
	rootGradient.Rotation = 18
	rootGradient.Parent = root

	local topGlow = Instance.new("Frame")
	topGlow.Name = "TopGlow"
	topGlow.BackgroundColor3 = Color3.fromRGB(65, 150, 205)
	topGlow.BackgroundTransparency = 0.86
	topGlow.BorderSizePixel = 0
	topGlow.Size = UDim2.new(1, 0, 0, 64)
	topGlow.Parent = root

	local topGlowGradient = Instance.new("UIGradient")
	topGlowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	topGlowGradient.Rotation = 90
	topGlowGradient.Parent = topGlow

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = root

	local titleRow = Instance.new("Frame")
	titleRow.Name = "Header"
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, 0, 0, 62)
	titleRow.Parent = root

	local caller = Instance.new("TextLabel")
	caller.Name = "Caller"
	caller.BackgroundTransparency = 1
	caller.Text = "UNKNOWN CALLER"
	caller.TextColor3 = Color3.fromRGB(220, 235, 245)
	caller.Font = Enum.Font.GothamBold
	caller.TextSize = 21
	caller.TextTruncate = Enum.TextTruncate.AtEnd
	caller.TextXAlignment = Enum.TextXAlignment.Left
	caller.Position = UDim2.fromOffset(22, 0)
	caller.Size = UDim2.new(0.58, -22, 0, 26)
	caller.Parent = titleRow

	local signalDot = Instance.new("Frame")
	signalDot.Name = "SignalDot"
	signalDot.AnchorPoint = Vector2.new(0, 0.5)
	signalDot.Position = UDim2.new(0, 0, 0, 13)
	signalDot.Size = UDim2.fromOffset(9, 9)
	signalDot.BackgroundColor3 = Color3.fromRGB(88, 190, 235)
	signalDot.BackgroundTransparency = 0.08
	signalDot.BorderSizePixel = 0
	signalDot.Parent = titleRow

	local signalDotCorner = Instance.new("UICorner")
	signalDotCorner.CornerRadius = UDim.new(1, 0)
	signalDotCorner.Parent = signalDot

	local agencyTag = Instance.new("TextLabel")
	agencyTag.Name = "AgencyTag"
	agencyTag.BackgroundTransparency = 1
	agencyTag.Text = "SECURE FEDERAL FIELD LINE"
	agencyTag.TextColor3 = Color3.fromRGB(168, 194, 212)
	agencyTag.Font = Enum.Font.GothamMedium
	agencyTag.TextSize = 13
	agencyTag.TextTruncate = Enum.TextTruncate.AtEnd
	agencyTag.TextXAlignment = Enum.TextXAlignment.Left
	agencyTag.Position = UDim2.fromOffset(22, 28)
	agencyTag.Size = UDim2.new(0.58, -22, 0, 18)
	agencyTag.Parent = titleRow

	local casePill = Instance.new("Frame")
	casePill.Name = "CasePill"
	casePill.AnchorPoint = Vector2.new(1, 0)
	casePill.Position = UDim2.new(1, 0, 0, 0)
	casePill.Size = UDim2.fromOffset(138, 30)
	casePill.BackgroundColor3 = Color3.fromRGB(46, 40, 24)
	casePill.BackgroundTransparency = 0.1
	casePill.BorderSizePixel = 0
	casePill.Parent = titleRow

	local casePillCorner = Instance.new("UICorner")
	casePillCorner.CornerRadius = UDim.new(0, 6)
	casePillCorner.Parent = casePill

	local casePillStroke = Instance.new("UIStroke")
	casePillStroke.Color = Color3.fromRGB(190, 160, 88)
	casePillStroke.Thickness = 1
	casePillStroke.Transparency = 0.45
	casePillStroke.Parent = casePill

	local caseLabel = Instance.new("TextLabel")
	caseLabel.Name = "CaseLabel"
	caseLabel.BackgroundTransparency = 1
	caseLabel.Text = "CASE BXP-204"
	caseLabel.TextColor3 = Color3.fromRGB(230, 205, 130)
	caseLabel.Font = Enum.Font.GothamSemibold
	caseLabel.TextSize = 13
	caseLabel.TextXAlignment = Enum.TextXAlignment.Center
	caseLabel.Size = UDim2.fromScale(1, 1)
	caseLabel.Parent = casePill

	local waveBox = Instance.new("Frame")
	waveBox.Name = "SignalWave"
	waveBox.AnchorPoint = Vector2.new(1, 0)
	waveBox.Position = UDim2.new(1, 0, 0, 38)
	waveBox.Size = UDim2.fromOffset(138, 20)
	waveBox.BackgroundTransparency = 1
	waveBox.Parent = titleRow

	local waveBars = {}
	for index = 1, 8 do
		local baseHeight = 5 + ((index % 4) * 2)
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. index
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0, 8 + ((index - 1) * 17), 1, -2)
		bar.Size = UDim2.fromOffset(5, baseHeight)
		bar.BackgroundColor3 = Color3.fromRGB(95, 190, 220)
		bar.BackgroundTransparency = 0.38
		bar.BorderSizePixel = 0
		bar:SetAttribute("BaseHeight", baseHeight)
		bar.Parent = waveBox

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = bar

		table.insert(waveBars, bar)
	end

	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.fromRGB(42, 94, 135)
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(0, 72)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = root

	local messageRail = Instance.new("Frame")
	messageRail.Name = "MessageRail"
	messageRail.BackgroundColor3 = Color3.fromRGB(88, 190, 235)
	messageRail.BackgroundTransparency = 0.25
	messageRail.BorderSizePixel = 0
	messageRail.Position = UDim2.fromOffset(0, 94)
	messageRail.Size = UDim2.new(0, 3, 1, -140)
	messageRail.Parent = root

	local messageRailCorner = Instance.new("UICorner")
	messageRailCorner.CornerRadius = UDim.new(1, 0)
	messageRailCorner.Parent = messageRail

	local speaker = Instance.new("TextLabel")
	speaker.Name = "Speaker"
	speaker.BackgroundTransparency = 1
	speaker.Position = UDim2.fromOffset(14, 86)
	speaker.Size = UDim2.new(1, -14, 0, 28)
	speaker.Font = Enum.Font.GothamSemibold
	speaker.TextColor3 = Color3.fromRGB(230, 205, 130)
	speaker.TextSize = 18
	speaker.TextTruncate = Enum.TextTruncate.AtEnd
	speaker.TextXAlignment = Enum.TextXAlignment.Left
	speaker.Parent = root

	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(14, 118)
	line.Size = UDim2.new(1, -14, 1, -164)
	line.TextWrapped = true
	line.TextScaled = true
	line.Font = Enum.Font.Gotham
	line.TextColor3 = Color3.fromRGB(235, 235, 245)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Parent = root

	local lineTextConstraint = Instance.new("UITextSizeConstraint")
	lineTextConstraint.MinTextSize = 14
	lineTextConstraint.MaxTextSize = 22
	lineTextConstraint.Parent = line

	local hint = Instance.new("TextLabel")
	hint.Name = "AdvanceHint"
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, 0, 1, 0)
	hint.Size = UDim2.new(0.45, 0, 0, 28)
	hint.BackgroundColor3 = Color3.fromRGB(22, 31, 37)
	hint.BackgroundTransparency = 0.08
	hint.BorderSizePixel = 0
	hint.Text = ""
	hint.TextColor3 = Color3.fromRGB(186, 205, 220)
	hint.Font = Enum.Font.GothamMedium
	hint.TextScaled = true
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.Parent = root

	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 6)
	hintCorner.Parent = hint

	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Color3.fromRGB(68, 132, 170)
	hintStroke.Thickness = 1
	hintStroke.Transparency = 0.65
	hintStroke.Parent = hint

	local hintConstraint = Instance.new("UITextSizeConstraint")
	hintConstraint.MinTextSize = 9
	hintConstraint.MaxTextSize = 13
	hintConstraint.Parent = hint

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local function updateScale()
		local viewportSize = Camera.ViewportSize
		uiScale.Scale = math.clamp(viewportSize.Y / 900, 0.82, 1.05)
	end

	updateScale()
	Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	local function showUI()
		scene.Enabled = true
		backdrop.Visible = true
		shadow.Visible = true
		root.Visible = true
		backdrop.BackgroundTransparency = 1
		shadow.Position = UDim2.fromScale(0.5, 1.045)
		shadow.BackgroundTransparency = 1
		root.Position = UDim2.fromScale(0.5, 1.035)
		root.BackgroundTransparency = 1
		TweenService:Create(
			backdrop,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.46 }
		):Play()
		TweenService:Create(
			shadow,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.976), BackgroundTransparency = 0.66 }
		):Play()
		TweenService:Create(
			root,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.965), BackgroundTransparency = 0.02 }
		):Play()
	end

	local function hideUI()
		TweenService:Create(
			backdrop,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			shadow,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 1.045), BackgroundTransparency = 1 }
		):Play()
		local tween = TweenService:Create(
			root,
			TweenInfo.new(FadeUI, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 1.035), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		root.Visible = false
		shadow.Visible = false
		backdrop.Visible = false
		scene.Enabled = false
	end

	return {
		Scene = scene,
		Root = root,
		Stroke = stroke,
		SignalDot = signalDot,
		WaveBars = waveBars,
		Caller = caller,
		Speaker = speaker,
		Line = line,
		Hint = hint,
		Show = showUI,
		Hide = hideUI,
	}
end

local Typing = false
local LineComplete = false
local WaitForAdvance = nil

local function typeText(setter, text)
	Typing = true
	LineComplete = false
	setter("")

	for i = 1, #text do
		if not Typing then
			setter(text)
			LineComplete = true
			return
		end

		setter(string.sub(text, 1, i))
		task.wait(TypingSpeed)
	end

	Typing = false
	LineComplete = true
end

local PhoneModel
local RingSound
local RingLight
local RingHintGui
local RingHintLabel
local RingHintTween
local Ringing = false
local PhoneAnimationToken = 0
local PhoneAnimationBaseCF

local RingMessages = {
	"Secure federal line ringing.",
	"Field office request incoming.",
	"Unlisted channel active. Answer when ready.",
	"Case briefing available.",
	"Incoming call from a restricted line.",
}

local function findPhone()
	local direct = Workspace:FindFirstChild("Phone")
	if direct and (direct:IsA("Model") or direct:IsA("BasePart")) then
		return direct
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "Phone" then
			return descendant
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Phone" then
			return descendant
		end
	end

	return nil
end

local function waitForPhone()
	local phone = findPhone()
	while not phone do
		local added = Workspace.DescendantAdded:Wait()
		if added.Name == "Phone" and (added:IsA("Model") or added:IsA("BasePart")) then
			phone = added
		else
			phone = findPhone()
		end
	end

	return phone
end

PhoneModel = waitForPhone()

local function ensureClickDetectors(model)
	if model:IsA("BasePart") then
		local clickDetector = model:FindFirstChildOfClass("ClickDetector")
		if not clickDetector then
			clickDetector = Instance.new("ClickDetector")
			clickDetector.Parent = model
		end
		clickDetector.MaxActivationDistance = 24
		return
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local clickDetector = descendant:FindFirstChildOfClass("ClickDetector")
			if not clickDetector then
				clickDetector = Instance.new("ClickDetector")
				clickDetector.Parent = descendant
			end
			clickDetector.MaxActivationDistance = 24
		end
	end
end

ensureClickDetectors(PhoneModel)

local function ensureRingSound()
	if RingSound and RingSound.Parent then
		return RingSound
	end

	local basePart
	for _, descendant in ipairs(PhoneModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			basePart = descendant
			break
		end
	end

	basePart = basePart or PhoneModel

	local sound = basePart:FindFirstChild("PhoneRing")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "PhoneRing"
		sound.Parent = basePart
	end

	sound.SoundId = "rbxassetid://9117305779"
	sound.Volume = 0.6
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.Linear

	RingSound = sound
	return sound
end

local function findRingLight()
	if RingLight and RingLight.Parent then
		return RingLight
	end

	RingLight = PhoneModel:FindFirstChild("RingLight", true)
	return RingLight
end

local function setRingLight(on)
	local light = findRingLight()
	if not light then
		return
	end

	if light:IsA("BasePart") then
		light.Transparency = on and 0 or 1
	elseif light:IsA("Light") then
		light.Enabled = on
	end
end

local function ensureRingHintUI()
	if RingHintGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PhoneRingHintGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.96)
	label.Size = UDim2.fromScale(0.7, 0.05)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 230, 240)
	label.TextStrokeTransparency = 0.4
	label.Visible = false
	label.Parent = gui

	RingHintGui = gui
	RingHintLabel = label
end

local function stopRinging()
	if not Ringing then
		return
	end

	Ringing = false
	PhoneAnimationToken = PhoneAnimationToken + 1
	if PhoneAnimationBaseCF and PhoneModel then
		if PhoneModel:IsA("BasePart") then
			PhoneModel.CFrame = PhoneAnimationBaseCF
		else
			PhoneModel:PivotTo(PhoneAnimationBaseCF)
		end
	end
	if RingHintTween then
		RingHintTween:Cancel()
		RingHintTween = nil
	end
	if RingSound and RingSound.IsPlaying then
		RingSound:Stop()
	end
	setRingLight(false)
	if RingHintLabel then
		RingHintLabel.Visible = false
	end
end

local function startPhoneAnimation()
	PhoneAnimationToken = PhoneAnimationToken + 1
	local token = PhoneAnimationToken

	if PhoneModel:IsA("BasePart") then
		PhoneAnimationBaseCF = PhoneModel.CFrame
	else
		PhoneAnimationBaseCF = PhoneModel:GetPivot()
	end

	task.spawn(function()
		local step = 0
		while Ringing and PhoneAnimationToken == token and PhoneModel and PhoneModel.Parent do
			step = step + 1
			local direction = -1
			if step % 2 == 0 then
				direction = 1
			end

			local angle = math.rad(1.8 * direction)
			local lift = 0
			if step % 4 == 0 then
				lift = 0.035
			end

			local targetCF = PhoneAnimationBaseCF * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, angle)

			if PhoneModel:IsA("BasePart") then
				PhoneModel.CFrame = targetCF
			else
				PhoneModel:PivotTo(targetCF)
			end

			task.wait(0.07)
		end

		if PhoneAnimationToken == token and PhoneAnimationBaseCF and PhoneModel and PhoneModel.Parent then
			if PhoneModel:IsA("BasePart") then
				PhoneModel.CFrame = PhoneAnimationBaseCF
			else
				PhoneModel:PivotTo(PhoneAnimationBaseCF)
			end
		end
	end)
end

local function startRinging()
	if Ringing or not hasNewsFinished() or hasPhoneCutsceneStarted() then
		return
	end

	Ringing = true
	ensureRingSound()
	ensureRingHintUI()
	findRingLight()
	startPhoneAnimation()

	if RingHintLabel then
		RingHintLabel.Visible = true
		RingHintLabel.TextTransparency = 0.05
		RingHintLabel.Position = UDim2.fromScale(0.5, 0.96)

		RingHintTween = TweenService:Create(
			RingHintLabel,
			TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{
				TextTransparency = 0.42,
				TextStrokeTransparency = 0.78,
				Position = UDim2.fromScale(0.5, 0.952),
			}
		)
		RingHintTween:Play()

		task.spawn(function()
			while Ringing and RingHintLabel and RingHintLabel.Parent do
				RingHintLabel.Text = RingMessages[math.random(1, #RingMessages)]
				task.wait(2.5)
			end
		end)
	end

	task.spawn(function()
		while Ringing and RingSound and RingSound.Parent do
			for _ = 1, 2 do
				if not Ringing then
					break
				end

				RingSound:Play()
				setRingLight(true)
				task.wait(0.5)
				setRingLight(false)
				task.wait(0.2)
			end

			if not Ringing then
				break
			end

			task.wait(1.8)
		end

		setRingLight(false)
		PhoneAnimationToken = PhoneAnimationToken + 1
		if PhoneAnimationBaseCF and PhoneModel and PhoneModel.Parent then
			if PhoneModel:IsA("BasePart") then
				PhoneModel.CFrame = PhoneAnimationBaseCF
			else
				PhoneModel:PivotTo(PhoneAnimationBaseCF)
			end
		end
		if RingHintLabel then
			if RingHintTween then
				RingHintTween:Cancel()
				RingHintTween = nil
			end
			RingHintLabel.Visible = false
			RingHintLabel.TextTransparency = 0
			RingHintLabel.TextStrokeTransparency = 0.4
			RingHintLabel.Position = UDim2.fromScale(0.5, 0.96)
		end
	end)
end

maybeStartRinging = startRinging

if hasNewsFinished() then
	startRinging()
end

local UI = createPhoneUI()
local InCall = false
local CallPulseTweens = {}

local function stopCallAnimation()
	for _, tween in ipairs(CallPulseTweens) do
		tween:Cancel()
	end

	table.clear(CallPulseTweens)

	if UI.Stroke then
		UI.Stroke.Transparency = 0.18
	end
	if UI.SignalDot then
		UI.SignalDot.BackgroundTransparency = 0.15
		UI.SignalDot.Size = UDim2.fromOffset(9, 9)
	end
	if UI.WaveBars then
		for _, bar in ipairs(UI.WaveBars) do
			local baseHeight = bar:GetAttribute("BaseHeight") or 8
			bar.Size = UDim2.fromOffset(5, baseHeight)
			bar.BackgroundTransparency = 0.38
		end
	end
end

local function startCallAnimation()
	stopCallAnimation()

	if UI.Stroke then
		local strokeTween = TweenService:Create(
			UI.Stroke,
			TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.04 }
		)
		table.insert(CallPulseTweens, strokeTween)
		strokeTween:Play()
	end

	if UI.SignalDot then
		local dotTween = TweenService:Create(
			UI.SignalDot,
			TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.58, Size = UDim2.fromOffset(12, 12) }
		)
		table.insert(CallPulseTweens, dotTween)
		dotTween:Play()
	end

	if UI.WaveBars then
		for index, bar in ipairs(UI.WaveBars) do
			local baseHeight = bar:GetAttribute("BaseHeight") or 8
			local targetHeight = baseHeight + 8 + ((index % 3) * 3)
			local waveTween = TweenService:Create(
				bar,
				TweenInfo.new(0.42 + (index * 0.035), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, index * 0.035),
				{ BackgroundTransparency = 0.08, Size = UDim2.fromOffset(5, targetHeight) }
			)
			table.insert(CallPulseTweens, waveTween)
			waveTween:Play()
		end
	end
end

local function runCall(lines, callerName)
	if InCall or not hasNewsFinished() or hasPhoneCutsceneStarted() then
		return
	end

	InCall = true
	Player:SetAttribute(PHONE_CUTSCENE_STARTED_ATTRIBUTE, true)

	local hrp = Character:FindFirstChild("HumanoidRootPart")
	if hrp and SpawnCF then
		hrp.CFrame = SpawnCF + Vector3.new(0, 0.5, 0)
	end

	stopRinging()

	UI.Caller.Text = callerName or "Unknown Caller"
	UI.Show()
	startCallAnimation()

	ContextActionService:BindAction("PhoneAdvance", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if WaitForAdvance then
			WaitForAdvance()
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end, true, table.unpack(AdvanceKeys))

	local index = 1
	local function setLine(text)
		UI.Line.Text = text
	end

	while index <= #lines do
		local data = lines[index]
		UI.Speaker.Text = data.speaker or ""
		UI.Hint.Text = "Press E / Space / Enter to continue"

		Typing = true
		LineComplete = false
		local proceed = false

		WaitForAdvance = function()
			if Typing then
				Typing = false
			elseif LineComplete then
				proceed = true
			end
		end

		typeText(setLine, data.text or "")

		while not proceed do
			RunService.Heartbeat:Wait()
		end

		index = index + 1
		setLine("")
	end

	ContextActionService:UnbindAction("PhoneAdvance")
	WaitForAdvance = nil
	UI.Hint.Text = ""
	stopCallAnimation()
	UI.Hide()

	Player:SetAttribute(PHONE_CUTSCENE_COMPLETED_ATTRIBUTE, true)
	InCall = false
end

local Debounce = false
local connectedDetectors = {}

local function isPhoneTarget(instance)
	return instance ~= nil and (instance == PhoneModel or instance:IsDescendantOf(PhoneModel))
end

local function canReachPhoneTarget(instance)
	local root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not root or not instance or not instance:IsA("BasePart") then
		return false
	end

	return (root.Position - instance.Position).Magnitude <= 24
end

local function tryStartPhoneCall()
	if Debounce or InCall or not hasNewsFinished() or hasPhoneCutsceneStarted() then
		return
	end

	Debounce = true
	runCall(Conversation, "UNKNOWN CALLER")
	Debounce = false
end

if PhoneCallRequested and PhoneCallRequested:IsA("RemoteEvent") then
	PhoneCallRequested.OnClientEvent:Connect(tryStartPhoneCall)
end

local function connectDetector(clickDetector)
	if connectedDetectors[clickDetector] then
		return
	end

	connectedDetectors[clickDetector] = true
	clickDetector.MouseClick:Connect(function(player)
		if player and player ~= Player then
			return
		end

		tryStartPhoneCall()
	end)
end

local function connectPhoneDetectors()
	ensureClickDetectors(PhoneModel)

	if PhoneModel:IsA("BasePart") then
		local clickDetector = PhoneModel:FindFirstChildOfClass("ClickDetector")
		if clickDetector then
			connectDetector(clickDetector)
		end
		return
	end

	for _, descendant in ipairs(PhoneModel:GetDescendants()) do
		if descendant:IsA("ClickDetector") then
			descendant.MaxActivationDistance = 24
			connectDetector(descendant)
		end
	end
end

connectPhoneDetectors()

PhoneModel.DescendantAdded:Connect(function(instance)
	if instance:IsA("BasePart") then
		local clickDetector = instance:FindFirstChildOfClass("ClickDetector")
		if not clickDetector then
			clickDetector = Instance.new("ClickDetector")
			clickDetector.Parent = instance
		end

		clickDetector.MaxActivationDistance = 24
		connectDetector(clickDetector)
	elseif instance:IsA("ClickDetector") then
		instance.MaxActivationDistance = 24
		connectDetector(instance)
	end
end)

task.spawn(function()
	while PhoneModel and PhoneModel.Parent do
		connectPhoneDetectors()
		task.wait(1)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local isPrimaryClick = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if not isPrimaryClick then
		return
	end

	local target = Mouse.Target
	if not isPhoneTarget(target) or not canReachPhoneTarget(target) then
		return
	end

	tryStartPhoneCall()
end)
