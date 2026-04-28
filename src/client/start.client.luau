-- MODERN TITLE SCREEN - Full responsive design with working popup modals
-- Drop into StarterPlayerScripts or StarterGui

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Attempt to load ObjectiveManager for chapters
local ObjectiveManager
pcall(function()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))
end)

local activePopup = nil
local RESTORE_STATE_ATTRIBUTE = "HackTabletRestoreBlob"
local LOAD_SCENARIO_REMOTE_NAME = "LoadScenario"
local LOAD_REMOTE_NAME = "LoadSavedProgress"
local SAVE_STATUS_REMOTE_NAME = "GetSavedProgressStatus"
local CLEAR_SAVE_REMOTE_NAME = "ClearSavedProgress"
local START_OVER_REMOTE_NAME = "StartOverProgress"
local CLEANUP_REMOTE_NAME = "Cleanup"
local NEWS_CUTSCENE_REMOTE_NAME = "StartNewsCutscene"
local NEWS_CUTSCENE_STARTED_ATTRIBUTE = "NewsCutsceneStarted"
local NEWS_CUTSCENE_COMPLETED_ATTRIBUTE = "NewsCutsceneCompleted"
local NEWS_CUTSCENE_TIMEOUT = 75
local DISCLAIMER_REMOTE_NAME = "DisclaimerCompleted"
local DISCLAIMER_AUDIO_ID = "rbxassetid://104592562370100"
local DISCLAIMER_AUDIO_FALLBACK_DURATION = 28
local SCENARIO_ORDER = {
	"Chapter1_Recon",
	"Chapter2_SSH",
	"Chapter3_Malware",
	"Chapter4_IncidentResponse",
}

local DISCLAIMER_TEXT = [[CYBERSECURITY TRAINING SIMULATION

This experience contains simulated systems and scenarios designed for educational purposes only.

All activities in this game are fictional. Do not attempt to access, test, or interfere with real accounts or systems.

Unauthorized access to real systems is illegal.

Cybersecurity professionals always obtain permission before testing systems and use their skills to protect and defend.
]]

---------------------------------------------------------
-- COLOR & DESIGN TOKENS
---------------------------------------------------------
local COLORS = {
	PRIMARY = Color3.fromRGB(14, 165, 233),
	ACCENT = Color3.fromRGB(168, 85, 247),
	DARK_BG = Color3.fromRGB(8, 12, 20),
	CARD_BG = Color3.fromRGB(15, 23, 35),
	TEXT_PRIMARY = Color3.fromRGB(240, 246, 255),
	TEXT_SECONDARY = Color3.fromRGB(148, 163, 184),
	SUCCESS = Color3.fromRGB(34, 197, 94),
	WARNING = Color3.fromRGB(250, 204, 21),
	DANGER = Color3.fromRGB(239, 68, 68),
	DISABLED = Color3.fromRGB(64, 64, 64),
}

---------------------------------------------------------
-- AUDIO SETTINGS
-- Optional tagging:
-- sound:SetAttribute("AudioCategory", "Music") --> affected by Master only
-- sound:SetAttribute("AudioCategory", "SFX")   --> affected by Master + SFX
---------------------------------------------------------
local MASTER_VOLUME_ATTRIBUTE = "MasterVolume"
local SFX_VOLUME_ATTRIBUTE = "SFXVolume"
local BASE_VOLUME_ATTRIBUTE = "BaseVolume"
local AUDIO_CATEGORY_ATTRIBUTE = "AudioCategory"

local managedSounds = {}
local managedSoundConnections = {}
local lastAppliedVolumes = {}

local function normalizePercentValue(value, fallback)
	if typeof(value) ~= "number" then
		return fallback
	end

	if value <= 1 then
		return math.clamp(math.floor(value * 100 + 0.5), 0, 100)
	end

	return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function readPercentAttribute(attributeName, fallback)
	return normalizePercentValue(SoundService:GetAttribute(attributeName), fallback)
end

local function writePercentAttribute(attributeName, value)
	SoundService:SetAttribute(attributeName, math.clamp(math.floor(value + 0.5), 0, 100))
end

local function contains(text, fragment)
	return string.find(text, fragment, 1, true) ~= nil
end

local function getSoundCategory(sound)
	local explicit = sound:GetAttribute(AUDIO_CATEGORY_ATTRIBUTE)
	if typeof(explicit) == "string" then
		local lowered = string.lower(explicit)

		if lowered == "music" or lowered == "bgm" or lowered == "ambient" or lowered == "ambience" then
			return "GENERAL"
		end

		if lowered == "sfx" or lowered == "fx" or lowered == "soundeffect" then
			return "SFX"
		end
	end

	if sound.SoundGroup then
		local groupName = string.lower(sound.SoundGroup.Name)
		if contains(groupName, "music") or contains(groupName, "bgm") or contains(groupName, "ambient") then
			return "GENERAL"
		end
	end

	local name = string.lower(sound.Name)
	local parentName = sound.Parent and string.lower(sound.Parent.Name) or ""
	local combined = name .. " " .. parentName

	if contains(combined, "music")
		or contains(combined, "theme")
		or contains(combined, "bgm")
		or contains(combined, "ambient")
		or contains(combined, "ambience")
		or contains(combined, "radio")
		or contains(combined, "song")
	then
		return "GENERAL"
	end

	if sound.Looped then
		return "GENERAL"
	end

	return "SFX"
end

local function getBaseVolume(sound)
	local base = sound:GetAttribute(BASE_VOLUME_ATTRIBUTE)
	if typeof(base) == "number" then
		return base
	end

	local masterMultiplier = readPercentAttribute(MASTER_VOLUME_ATTRIBUTE, 100) / 100
	local sfxMultiplier = readPercentAttribute(SFX_VOLUME_ATTRIBUTE, 100) / 100

	local divisor = masterMultiplier
	if getSoundCategory(sound) == "SFX" then
		divisor = divisor * sfxMultiplier
	end

	if divisor <= 0 then
		base = sound.Volume
	else
		base = sound.Volume / divisor
	end

	base = math.clamp(base, 0, 10)
	sound:SetAttribute(BASE_VOLUME_ATTRIBUTE, base)
	return base
end

local function computeFinalSoundVolume(sound)
	local baseVolume = getBaseVolume(sound)
	local masterMultiplier = readPercentAttribute(MASTER_VOLUME_ATTRIBUTE, 100) / 100
	local sfxMultiplier = readPercentAttribute(SFX_VOLUME_ATTRIBUTE, 100) / 100

	local finalVolume = baseVolume * masterMultiplier
	if getSoundCategory(sound) == "SFX" then
		finalVolume = finalVolume * sfxMultiplier
	end

	return math.clamp(finalVolume, 0, 10)
end

local function applyManagedVolume(sound)
	if not sound or not sound.Parent then
		return
	end

	local finalVolume = computeFinalSoundVolume(sound)
	lastAppliedVolumes[sound] = finalVolume
	sound.Volume = finalVolume
end

local function cleanupManagedSound(sound)
	managedSounds[sound] = nil
	lastAppliedVolumes[sound] = nil

	local connections = managedSoundConnections[sound]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	managedSoundConnections[sound] = nil
end

local function registerManagedSound(sound)
	if managedSounds[sound] then
		return
	end

	managedSounds[sound] = true
	getBaseVolume(sound)
	applyManagedVolume(sound)

	managedSoundConnections[sound] = {
		sound:GetPropertyChangedSignal("Volume"):Connect(function()
			local lastApplied = lastAppliedVolumes[sound]
			if typeof(lastApplied) == "number" and math.abs(sound.Volume - lastApplied) < 0.0001 then
				return
			end

			sound:SetAttribute(BASE_VOLUME_ATTRIBUTE, math.clamp(sound.Volume, 0, 10))
			applyManagedVolume(sound)
		end),

		sound:GetAttributeChangedSignal(AUDIO_CATEGORY_ATTRIBUTE):Connect(function()
			applyManagedVolume(sound)
		end),

		sound.AncestryChanged:Connect(function(_, parent)
			if not parent then
				cleanupManagedSound(sound)
			end
		end),
	}
end

local function applyAllManagedVolumes()
	for sound in pairs(managedSounds) do
		if sound.Parent then
			applyManagedVolume(sound)
		else
			cleanupManagedSound(sound)
		end
	end
end

local function watchSoundContainer(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("Sound") then
			registerManagedSound(descendant)
		end
	end

	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Sound") then
			task.defer(function()
				if descendant.Parent then
					registerManagedSound(descendant)
				end
			end)
		end
	end)
end

local function initializeAudioSettings()
	writePercentAttribute(MASTER_VOLUME_ATTRIBUTE, readPercentAttribute(MASTER_VOLUME_ATTRIBUTE, 100))
	writePercentAttribute(SFX_VOLUME_ATTRIBUTE, readPercentAttribute(SFX_VOLUME_ATTRIBUTE, 100))

	SoundService:GetAttributeChangedSignal(MASTER_VOLUME_ATTRIBUTE):Connect(function()
		applyAllManagedVolumes()
	end)

	SoundService:GetAttributeChangedSignal(SFX_VOLUME_ATTRIBUTE):Connect(function()
		applyAllManagedVolumes()
	end)

	watchSoundContainer(Workspace)
	watchSoundContainer(SoundService)
	watchSoundContainer(player)

	applyAllManagedVolumes()
end

initializeAudioSettings()

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title or "UNDERCOVER"),
			Text = tostring(text or ""),
			Duration = tonumber(duration) or 3,
		})
	end)
end

local function applyProperties(instance, props)
	local parent = nil

	for k, v in pairs(props or {}) do
		if k == "parent" then
			parent = v
		else
			instance[k] = v
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

local function createFrame(props)
	return applyProperties(Instance.new("Frame"), props)
end

local function createLabel(props)
	return applyProperties(Instance.new("TextLabel"), props)
end

local function createIcon(props)
	local icon = applyProperties(Instance.new("ImageLabel"), props)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.BackgroundTransparency = 1
	return icon
end

local function createButton(props)
	return applyProperties(Instance.new("TextButton"), props)
end

local function roundCorners(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function createGradient(instance, colorStart, colorEnd, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colorStart),
		ColorSequenceKeypoint.new(1, colorEnd),
	})
	gradient.Rotation = rotation or 0
	gradient.Parent = instance
	return gradient
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

local function addPadding(instance, left, right, top, bottom)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingRight = UDim.new(0, right or 0)
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingBottom = UDim.new(0, bottom or 0)
	padding.Parent = instance
	return padding
end

local function animateButtonHover(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(
			button,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundColor3 = hoverColor }
		):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(
			button,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundColor3 = normalColor }
		):Play()
	end)
end

local function closePopup(immediate)
	if activePopup and activePopup.Parent then
		local popupToClose = activePopup
		activePopup = nil

		if immediate then
			popupToClose:Destroy()
			return
		end

		local overlay = popupToClose:FindFirstChild("Overlay")
		local panel = popupToClose:FindFirstChild("Panel")

		if overlay then
			TweenService:Create(
				overlay,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			):Play()
		end

		if panel then
			TweenService:Create(
				panel,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{
					Size = panel.Size - UDim2.new(0, 20, 0, 20),
					BackgroundTransparency = 1,
				}
			):Play()

			for _, descendant in ipairs(panel:GetDescendants()) do
				if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
					TweenService:Create(
						descendant,
						TweenInfo.new(0.15),
						{
							TextTransparency = 1,
							BackgroundTransparency = math.clamp((descendant.BackgroundTransparency or 0) + 0.3, 0, 1),
						}
					):Play()
				elseif descendant:IsA("Frame") or descendant:IsA("ScrollingFrame") or descendant:IsA("ImageLabel") then
					TweenService:Create(
						descendant,
						TweenInfo.new(0.15),
						{ BackgroundTransparency = math.clamp((descendant.BackgroundTransparency or 0) + 0.3, 0, 1) }
					):Play()
				end
			end
		end

		task.delay(0.22, function()
			if popupToClose and popupToClose.Parent then
				popupToClose:Destroy()
			end
		end)
	end
end

local function makeScrollingFrame(parent)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Parent = parent
	scrollFrame.Size = UDim2.fromScale(1, 1)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.Active = true
	scrollFrame.ClipsDescendants = true
	scrollFrame.ZIndex = 84
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 15)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	addPadding(scrollFrame, 0, 8, 0, 8)

	return scrollFrame, layout
end

local function createStepVolumeControl(parent, labelText, initialValue, callback, layoutOrder)
	initialValue = math.clamp(math.floor(initialValue or 50), 0, 100)

	local container = createFrame({
		parent = parent,
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = Color3.fromRGB(10, 18, 28),
		BorderSizePixel = 0,
		ZIndex = 85,
		LayoutOrder = layoutOrder or 1,
	})
	roundCorners(container, 14)
	addStroke(container, Color3.fromRGB(60, 85, 120), 1, 0.35)

	createLabel({
		parent = container,
		Text = labelText,
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.new(0, 14, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.TEXT_PRIMARY,
		Font = Enum.Font.GothamSemibold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 86,
	})

	local controlsRow = createFrame({
		parent = container,
		Size = UDim2.new(1, -28, 0, 42),
		Position = UDim2.new(0, 14, 0, 42),
		BackgroundTransparency = 1,
		ZIndex = 85,
	})

	local minusBtn = createButton({
		parent = controlsRow,
		Text = "-",
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = COLORS.DANGER,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		AutoButtonColor = false,
		ZIndex = 87,
		Active = true,
		Selectable = true,
	})
	roundCorners(minusBtn, 10)

	local valueBox = createLabel({
		parent = controlsRow,
		Text = tostring(initialValue) .. "%",
		Size = UDim2.new(1, -108, 0, 42),
		Position = UDim2.new(0, 54, 0, 0),
		BackgroundColor3 = Color3.fromRGB(30, 42, 58),
		BorderSizePixel = 0,
		TextColor3 = COLORS.PRIMARY,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 86,
	})
	roundCorners(valueBox, 10)

	local plusBtn = createButton({
		parent = controlsRow,
		Text = "+",
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(1, -42, 0, 0),
		BackgroundColor3 = COLORS.SUCCESS,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		AutoButtonColor = false,
		ZIndex = 87,
		Active = true,
		Selectable = true,
	})
	roundCorners(plusBtn, 10)

	animateButtonHover(minusBtn, COLORS.DANGER, Color3.fromRGB(220, 38, 38))
	animateButtonHover(plusBtn, COLORS.SUCCESS, Color3.fromRGB(22, 163, 74))

	local currentValue = initialValue

	local function updateValue(newValue)
		currentValue = math.clamp(math.floor(newValue), 0, 100)
		valueBox.Text = tostring(currentValue) .. "%"

		if callback then
			callback(currentValue)
		end
	end

	minusBtn.MouseButton1Click:Connect(function()
		updateValue(currentValue - 5)
	end)

	plusBtn.MouseButton1Click:Connect(function()
		updateValue(currentValue + 5)
	end)

	return container
end

local function showPopupMessage(parent, text)
	createLabel({
		parent = parent,
		Text = text,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.TEXT_PRIMARY,
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 85,
	})
end

---------------------------------------------------------
-- MAIN SCREEN GUI
---------------------------------------------------------
local existing = playerGui:FindFirstChild("ModernTitleScreen")
if existing then
	existing:Destroy()
end

for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") and string.sub(child.Name, 1, 6) == "Popup_" then
		child:Destroy()
	end
end


local function showTrainingDisclaimer(onComplete)
	local existing = playerGui:FindFirstChild("TrainingDisclaimer")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainingDisclaimer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 250
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local root = createFrame({
		parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(5, 9, 18),
		BorderSizePixel = 0,
		Active = true,
	})
	createGradient(root, Color3.fromRGB(5, 9, 18), Color3.fromRGB(14, 25, 42), 26)

	local gridLayer = createFrame({
		parent = root,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	for index = 0, 14 do
		createFrame({
			parent = gridLayer,
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(index / 14, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(38, 58, 88),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
		})
	end
	for index = 0, 9 do
		createFrame({
			parent = gridLayer,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, index / 9, 0),
			BackgroundColor3 = Color3.fromRGB(38, 58, 88),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		})
	end

	local glowA = createFrame({
		parent = root,
		Size = UDim2.new(0, 420, 0, 420),
		Position = UDim2.new(0.08, 0, 0.22, 0),
		BackgroundColor3 = Color3.fromRGB(34, 211, 238),
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
	})
	roundCorners(glowA, 999)
	local glowB = createFrame({
		parent = root,
		Size = UDim2.new(0, 360, 0, 360),
		Position = UDim2.new(0.72, 0, 0.56, 0),
		BackgroundColor3 = Color3.fromRGB(96, 165, 250),
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
	})
	roundCorners(glowB, 999)
	TweenService:Create(glowA, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.11, 0, 0.18, 0),
		BackgroundTransparency = 0.88,
	}):Play()
	TweenService:Create(glowB, TweenInfo.new(12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.67, 0, 0.5, 0),
		BackgroundTransparency = 0.9,
	}):Play()

	local card = createFrame({
		parent = root,
		Size = UDim2.new(0.66, 0, 0.56, 0),
		Position = UDim2.new(0.5, 0, 0.52, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(9, 14, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	roundCorners(card, 26)
	addStroke(card, Color3.fromRGB(67, 142, 255), 2, 0.3)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(560, 420)
	sizeConstraint.MaxSize = Vector2.new(940, 640)
	sizeConstraint.Parent = card

	local cardInner = createFrame({
		parent = card,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = Color3.fromRGB(10, 16, 28),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	})
	roundCorners(cardInner, 22)
	createGradient(cardInner, Color3.fromRGB(12, 18, 30), Color3.fromRGB(8, 12, 20), 90)

	local eyebrow = createLabel({
		parent = cardInner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 34, 0, 28),
		Size = UDim2.new(1, -68, 0, 18),
		Text = "CYBERSECURITY TRAINING NOTICE",
		TextColor3 = Color3.fromRGB(125, 211, 252),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
	})

	local title = createLabel({
		parent = cardInner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 34, 0, 58),
		Size = UDim2.new(1, -68, 0, 42),
		Text = "CYBERSECURITY TRAINING SIMULATION",
		TextColor3 = Color3.fromRGB(240, 246, 255),
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
	})
	local titleGradient = createGradient(title, Color3.fromRGB(248, 250, 252), Color3.fromRGB(125, 211, 252), 0)
	titleGradient.Offset = Vector2.new(-1, 0)
	TweenService:Create(titleGradient, TweenInfo.new(4.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()

	local divider = createFrame({
		parent = cardInner,
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(0, 34, 0, 116),
		BackgroundColor3 = Color3.fromRGB(56, 189, 248),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	})
	roundCorners(divider, 999)

	local textFrame = createFrame({
		parent = cardInner,
		Size = UDim2.new(1, -68, 1, -208),
		Position = UDim2.new(0, 34, 0, 142),
		BackgroundColor3 = Color3.fromRGB(10, 16, 26),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	roundCorners(textFrame, 18)
	addStroke(textFrame, Color3.fromRGB(44, 67, 102), 1, 0.38)

	local textGlow = createFrame({
		parent = textFrame,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -60),
		Size = UDim2.new(1.2, 0, 0, 120),
		BackgroundColor3 = Color3.fromRGB(59, 130, 246),
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
	})
	roundCorners(textGlow, 999)
	TweenService:Create(textGlow, TweenInfo.new(8.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.5, 0, 1, -40),
		BackgroundTransparency = 0.9,
	}):Play()

	local paragraphTexts = {
		"This experience contains simulated systems and scenarios designed for educational purposes only.",
		"All activities in this game are fictional. Do not attempt to access, test, or interfere with real accounts or systems.",
		"Unauthorized access to real systems is illegal.",
		"Cybersecurity professionals always obtain permission before testing systems and use their skills to protect and defend.",
	}
	local paragraphDelays = { 1.6, 7.4, 14.6, 19.4 }
	local paragraphLabels = {}
	for index, paragraph in ipairs(paragraphTexts) do
		local label = createLabel({
			parent = textFrame,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 20, 0, 18 + ((index - 1) * 72)),
			Size = UDim2.new(1, -40, 0, index == 2 and 78 or 56),
			Text = paragraph,
			TextColor3 = index == 3 and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(219, 234, 254),
			Font = Enum.Font.GothamMedium,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTransparency = 1,
		})
		local accent = createFrame({
			parent = textFrame,
			Size = UDim2.new(0, 0, 0, 2),
			Position = UDim2.new(0, 20, 0, 18 + ((index - 1) * 72) - 8),
			BackgroundColor3 = index == 3 and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(56, 189, 248),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
		})
		roundCorners(accent, 999)
		paragraphLabels[#paragraphLabels + 1] = {
			label = label,
			accent = accent,
			delay = paragraphDelays[index],
		}
	end

	local footerLabel = createLabel({
		parent = cardInner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 34, 1, -58),
		Size = UDim2.new(1, -68, 0, 24),
		Text = "Voice briefing in progress...",
		TextColor3 = Color3.fromRGB(148, 163, 184),
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
	})

	local continuePrompt = createLabel({
		parent = cardInner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 34, 1, -90),
		Size = UDim2.new(1, -68, 0, 22),
		Text = "PRESS ANY KEY OR CLICK ANYWHERE TO CONTINUE",
		TextColor3 = Color3.fromRGB(125, 211, 252),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
	})

	local disclaimerAudio = SoundService:FindFirstChild("TrainingDisclaimerAudio")
	if disclaimerAudio then
		disclaimerAudio:Destroy()
	end
	disclaimerAudio = Instance.new("Sound")
	disclaimerAudio.Name = "TrainingDisclaimerAudio"
	disclaimerAudio.SoundId = DISCLAIMER_AUDIO_ID
	disclaimerAudio.Volume = 0.65
	disclaimerAudio.Looped = false
	disclaimerAudio.Parent = SoundService

	local readyToDismiss = false
	local dismissed = false
	local inputConnection = nil

	local function unlockContinue()
		if readyToDismiss then
			return
		end
		readyToDismiss = true
		footerLabel.Text = "Voice briefing complete."
		TweenService:Create(continuePrompt, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		TweenService:Create(footerLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.18 }):Play()
		TweenService:Create(continuePrompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.35 }):Play()
	end

	local function dismiss()
		if dismissed or not readyToDismiss then
			return
		end
		dismissed = true
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
		if remotes then
			local completedRemote = remotes:FindFirstChild(DISCLAIMER_REMOTE_NAME)
			if completedRemote and completedRemote:IsA("RemoteEvent") then
				completedRemote:FireServer()
			end
		end
		if disclaimerAudio and disclaimerAudio.Parent then
			disclaimerAudio:Stop()
			disclaimerAudio:Destroy()
		end
		TweenService:Create(root, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.48, 0),
		}):Play()
		for _, descendant in ipairs(card:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
			elseif descendant:IsA("Frame") then
				TweenService:Create(descendant, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = math.clamp((descendant.BackgroundTransparency or 0) + 0.45, 0, 1),
				}):Play()
			end
		end
		task.delay(0.46, function()
			if gui.Parent then
				gui:Destroy()
			end
			if onComplete then
				onComplete()
			end
		end)
	end

	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dismiss()
		end
	end)

	inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter or input.KeyCode == Enum.KeyCode.Space then
			dismiss()
		elseif input.UserInputType == Enum.UserInputType.Keyboard and readyToDismiss then
			dismiss()
		end
	end)

	disclaimerAudio.Ended:Connect(unlockContinue)
	task.delay(DISCLAIMER_AUDIO_FALLBACK_DURATION + 0.5, unlockContinue)
	disclaimerAudio:Play()

	task.spawn(function()
		TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.02,
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}):Play()
		TweenService:Create(eyebrow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		TweenService:Create(title, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		TweenService:Create(divider, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 180, 0, 2) }):Play()
		TweenService:Create(footerLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.18 }):Play()
		for _, entry in ipairs(paragraphLabels) do
			task.delay(entry.delay, function()
				if dismissed then
					return
				end
				TweenService:Create(entry.label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
				TweenService:Create(entry.accent, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 84, 0, 2) }):Play()
			end)
		end
	end)
end


local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModernTitleScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui
screenGui.Enabled = false

-- Background with gradient
local bgFrame = createFrame({
	parent = screenGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.DARK_BG,
	BorderSizePixel = 0,
})
createGradient(bgFrame, COLORS.DARK_BG, Color3.fromRGB(30, 20, 50), 25)

-- Decorative glow blobs
local glowA = createFrame({
	parent = bgFrame,
	Size = UDim2.new(0, 320, 0, 320),
	Position = UDim2.new(0.12, 0, 0.15, 0),
	BackgroundColor3 = COLORS.PRIMARY,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
})
roundCorners(glowA, 999)

local glowB = createFrame({
	parent = bgFrame,
	Size = UDim2.new(0, 360, 0, 360),
	Position = UDim2.new(0.68, 0, 0.52, 0),
	BackgroundColor3 = COLORS.ACCENT,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
})
roundCorners(glowB, 999)

local noiseLabel = createLabel({
	parent = bgFrame,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0.96,
	Text = "",
	BorderSizePixel = 0,
})
noiseLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

---------------------------------------------------------
-- MAIN PANEL
---------------------------------------------------------
local mainPanel = createFrame({
	parent = screenGui,
	Size = UDim2.new(0, 500, 0, 700),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.CARD_BG,
	BorderSizePixel = 0,
})
roundCorners(mainPanel, 20)
addStroke(mainPanel, COLORS.PRIMARY, 2, 0.45)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(360, 520)
sizeConstraint.MaxSize = Vector2.new(540, 760)
sizeConstraint.Parent = mainPanel

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 500 / 700
aspect.AspectType = Enum.AspectType.ScaleWithParentSize
aspect.DominantAxis = Enum.DominantAxis.Height
aspect.Parent = mainPanel

---------------------------------------------------------
-- HEADER
---------------------------------------------------------
local header = createFrame({
	parent = mainPanel,
	Size = UDim2.new(1, 0, 0, 110),
	BackgroundColor3 = COLORS.PRIMARY,
	BorderSizePixel = 0,
})
roundCorners(header, 20)
createGradient(header, COLORS.PRIMARY, Color3.fromRGB(96, 165, 250), 0)

createLabel({
	parent = header,
	Text = "UNDERCOVER",
	Size = UDim2.new(1, -40, 0, 42),
	Position = UDim2.new(0, 20, 0, 16),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.DARK_BG,
	Font = Enum.Font.GothamBlack,
	TextSize = 34,
	TextScaled = false,
	TextXAlignment = Enum.TextXAlignment.Center,
})

createLabel({
	parent = header,
	Text = "DATA COMPROMISED",
	Size = UDim2.new(1, -40, 0, 24),
	Position = UDim2.new(0, 20, 0, 60),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.DARK_BG,
	Font = Enum.Font.GothamSemibold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
})

---------------------------------------------------------
-- BODY CONTENT
---------------------------------------------------------
local body = createFrame({
	parent = mainPanel,
	Size = UDim2.new(1, -40, 1, -150),
	Position = UDim2.new(0, 20, 0, 126),
	BackgroundTransparency = 1,
})
local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, 16)
bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = body

local buttonContainer = createFrame({
	parent = body,
	Size = UDim2.new(1, 0, 0, 274),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
})
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonContainer

local function createNavButton(text)
	local btn = createButton({
		parent = buttonContainer,
		Text = text,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = COLORS.PRIMARY,
		BorderSizePixel = 0,
		TextColor3 = COLORS.DARK_BG,
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		AutoButtonColor = false,
	})
	roundCorners(btn, 12)
	animateButtonHover(btn, COLORS.PRIMARY, COLORS.ACCENT)
	return btn
end

local startBtn = createNavButton("START MISSION")
local loadProgressBtn = createNavButton("CONTINUE")
local settingsBtn = createNavButton("SETTINGS")
local chaptersBtn = createNavButton("CHAPTERS")
local aboutBtn = createNavButton("ABOUT")

local function getRemotesFolder()
	return ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
end

local function getRemoteFunction(name)
	local remotes = getRemotesFolder()
	local remote = remotes and remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	return nil
end

local function setContinueButtonState(hasSave)
	local available = hasSave == true
	loadProgressBtn:SetAttribute("HasSavedProgress", available)
	loadProgressBtn.Text = available and "CONTINUE" or "NO SAVE FOUND"
	loadProgressBtn.Active = available
	loadProgressBtn.Selectable = available
	loadProgressBtn.BackgroundColor3 = available and COLORS.PRIMARY or COLORS.DISABLED
	loadProgressBtn.TextColor3 = available and COLORS.DARK_BG or COLORS.TEXT_SECONDARY
end

local function refreshContinueButtonState()
	if player:GetAttribute("HasSavedProgress") == true then
		setContinueButtonState(true)
	end

	local statusRemote = getRemoteFunction(SAVE_STATUS_REMOTE_NAME)
	if not statusRemote then
		setContinueButtonState(player:GetAttribute("HasSavedProgress") == true)
		return
	end

	local ok, result = pcall(function()
		return statusRemote:InvokeServer()
	end)

	if ok and type(result) == "table" then
		setContinueButtonState(result.hasSave == true)
	else
		setContinueButtonState(true)
	end
end

---------------------------------------------------------
-- POPUP CREATOR
---------------------------------------------------------
local function createPopupPanel(title, contentSize)
	closePopup()

	local popup = Instance.new("ScreenGui")
	popup.Name = "Popup_" .. title
	popup.IgnoreGuiInset = true
	popup.ResetOnSpawn = false
	popup.DisplayOrder = 100
	popup.ZIndexBehavior = Enum.ZIndexBehavior.Global
	popup.Parent = playerGui

	local overlay = createButton({
		parent = popup,
		Text = "",
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 50,
		Active = true,
		Selectable = false,
	})
	TweenService:Create(
		overlay,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.38 }
	):Play()

	local panel = createFrame({
		parent = popup,
		Name = "Panel",
		Size = contentSize - UDim2.new(0, 20, 0, 20),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.CARD_BG,
		BorderSizePixel = 0,
		ZIndex = 60,
	})
	roundCorners(panel, 20)
	addStroke(panel, COLORS.PRIMARY, 2, 0.45)

	TweenService:Create(
		panel,
		TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = contentSize }
	):Play()

	local popupHeader = createFrame({
		parent = panel,
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = COLORS.PRIMARY,
		BorderSizePixel = 0,
		ZIndex = 70,
	})
	roundCorners(popupHeader, 20)
	createGradient(popupHeader, COLORS.PRIMARY, Color3.fromRGB(96, 165, 250), 0)

	createLabel({
		parent = popupHeader,
		Text = title,
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.DARK_BG,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 71,
	})

	local backBtn = createButton({
		parent = popupHeader,
		Text = "BACK",
		Size = UDim2.new(0, 78, 0, 38),
		Position = UDim2.new(1, -90, 0.5, -19),
		BackgroundColor3 = COLORS.DARK_BG,
		BorderSizePixel = 0,
		TextColor3 = COLORS.PRIMARY,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		AutoButtonColor = false,
		ZIndex = 72,
		Active = true,
		Selectable = true,
	})
	roundCorners(backBtn, 10)
	animateButtonHover(backBtn, COLORS.DARK_BG, Color3.fromRGB(16, 28, 44))

	local contentArea = createFrame({
		parent = panel,
		Size = UDim2.new(1, -40, 1, -100),
		Position = UDim2.new(0, 20, 0, 80),
		BackgroundTransparency = 1,
		ZIndex = 80,
	})
	contentArea.ClipsDescendants = false

	overlay.MouseButton1Click:Connect(function()
		closePopup()
	end)

	backBtn.MouseButton1Click:Connect(function()
		closePopup()
	end)

	activePopup = popup
	return popup, contentArea
end

---------------------------------------------------------
-- BUTTON EVENTS
---------------------------------------------------------
local function getChapterPopupData()
	local objectiveChapters = ObjectiveManager and ObjectiveManager.Get("ChapterObjectives") or nil
	if type(objectiveChapters) == "table" and #objectiveChapters > 0 then
		local chapters = {}
		for index, chapter in ipairs(objectiveChapters) do
			if type(chapter) == "table" then
				chapters[#chapters + 1] = {
					id = tostring(chapter.id or SCENARIO_ORDER[index] or "Chapter1_Recon"),
					name = tostring(chapter.title or chapter.text or ("Chapter " .. index)),
					number = index,
					locked = chapter.unlocked == false or tostring(chapter.status or "") == "Locked",
					status = tostring(chapter.status or "Not Started"),
				}
			end
		end
		if #chapters > 0 then
			return chapters
		end
	end

	return {
		{ id = "Chapter1_Recon", name = "Chapter 1: Active Reconnaissance", number = 1, locked = false, status = "In Progress" },
		{ id = "Chapter2_SSH", name = "Chapter 2: File System Forensics", number = 2, locked = true, status = "Locked" },
		{ id = "Chapter3_Malware", name = "Chapter 3: Malware Discovery", number = 3, locked = true, status = "Locked" },
		{ id = "Chapter4_IncidentResponse", name = "Chapter 4: Incident Response", number = 4, locked = true, status = "Locked" },
	}
end

local function getDefaultStartScenarioId()
	local chapters = getChapterPopupData()
	for _, chapterData in ipairs(chapters) do
		if not chapterData.locked and tostring(chapterData.status or "") ~= "Completed" then
			return tostring(chapterData.id or SCENARIO_ORDER[1])
		end
	end

	return SCENARIO_ORDER[1]
end

local missionStartInProgress = false
local newsCutsceneRequestedThisSession = false

local function playNewsCutsceneBeforeMission()
	if newsCutsceneRequestedThisSession
		or player:GetAttribute(NEWS_CUTSCENE_STARTED_ATTRIBUTE) == true
		or player:GetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE) == true then
		return true
	end

	local event = ReplicatedStorage:FindFirstChild(NEWS_CUTSCENE_REMOTE_NAME)
	if not event or not event:IsA("RemoteEvent") then
		return true
	end

	newsCutsceneRequestedThisSession = true
	player:SetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE, false)

	local completed = player:GetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE) == true
	local connection
	connection = player:GetAttributeChangedSignal(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE):Connect(function()
		if player:GetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE) == true then
			completed = true
		end
	end)

	event:FireServer()

	local startedAt = os.clock()
	while not completed and os.clock() - startedAt < NEWS_CUTSCENE_TIMEOUT do
		RunService.Heartbeat:Wait()
	end

	if connection then
		connection:Disconnect()
	end

	if not completed then
		warn("[ModernTitleScreen] News cutscene timed out; continuing mission start.")
		player:SetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE, true)
	end

	return true
end

local function startMissionFlow(scenarioId)
	if missionStartInProgress then
		return
	end

	missionStartInProgress = true
	scenarioId = tostring(scenarioId or getDefaultStartScenarioId())
	local loadScenarioRemote = getRemoteFunction(LOAD_SCENARIO_REMOTE_NAME)
	if not loadScenarioRemote then
		notify("UNDERCOVER", "Mission start is unavailable right now.", 3)
		missionStartInProgress = false
		return
	end

	-- Close instantly so button press feels immediate.
	screenGui.Enabled = false
	closePopup(true)

	playNewsCutsceneBeforeMission()

	local okLoad, result, err = pcall(function()
		return loadScenarioRemote:InvokeServer(scenarioId)
	end)
	if not okLoad or type(result) ~= "table" then
		screenGui.Enabled = true
		notify("UNDERCOVER", tostring(err or "Could not start that chapter."), 3)
		missionStartInProgress = false
		return
	end

	player:SetAttribute(RESTORE_STATE_ATTRIBUTE, nil)
	notify("UNDERCOVER", "Check your tablet for instructions.", 3)
	missionStartInProgress = false
end

startBtn.MouseButton1Click:Connect(function()
	startMissionFlow()
end)

loadProgressBtn.MouseButton1Click:Connect(function()
	if loadProgressBtn:GetAttribute("HasSavedProgress") == false then
		notify("UNDERCOVER", "No saved progress found.", 3)
		return
	end

	local loadRemote = getRemoteFunction(LOAD_REMOTE_NAME)
	if not loadRemote then
		notify("UNDERCOVER", "Continue is unavailable right now.", 3)
		return
	end

	local originalText = loadProgressBtn.Text
	loadProgressBtn.Text = "Continuing..."
	loadProgressBtn.Active = false
	loadProgressBtn.Selectable = false
	screenGui.Enabled = false
	closePopup(true)

	local ok, result = pcall(function()
		return loadRemote:InvokeServer()
	end)

	if not ok or type(result) ~= "table" or not result.success then
		local message = type(result) == "table" and result.message or "Could not continue from your saved progress."
		screenGui.Enabled = true
		refreshContinueButtonState()
		notify("UNDERCOVER", message, 3)
		return
	end

	setContinueButtonState(true)
	loadProgressBtn.Text = originalText

	if type(result.clientState) == "table" then
		local encodedOk, encodedState = pcall(function()
			return HttpService:JSONEncode(result.clientState)
		end)
		if encodedOk and type(encodedState) == "string" then
			player:SetAttribute(RESTORE_STATE_ATTRIBUTE, encodedState)
		end
	end

	notify("UNDERCOVER", tostring(result.message or "Continuing from saved progress."), 3)
end)

task.defer(refreshContinueButtonState)

---------------------------------------------------------
-- POPUP: SETTINGS
---------------------------------------------------------
settingsBtn.MouseButton1Click:Connect(function()
	local _, contentArea = createPopupPanel("SETTINGS", UDim2.new(0, 470, 0, 550))

	local ok, err = pcall(function()
		local scrollFrame = makeScrollingFrame(contentArea)

		local masterVolumePercent = readPercentAttribute(MASTER_VOLUME_ATTRIBUTE, 100)
		createStepVolumeControl(scrollFrame, "Master Volume", masterVolumePercent, function(value)
			writePercentAttribute(MASTER_VOLUME_ATTRIBUTE, value)
		end, 1)

		local sfxVolumePercent = readPercentAttribute(SFX_VOLUME_ATTRIBUTE, 100)
		createStepVolumeControl(scrollFrame, "SFX Volume", sfxVolumePercent, function(value)
			writePercentAttribute(SFX_VOLUME_ATTRIBUTE, value)
		end, 2)

		createLabel({
			parent = scrollFrame,
			Text = "PROGRESS",
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.TEXT_PRIMARY,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 3,
			ZIndex = 90,
		})

		createLabel({
			parent = scrollFrame,
			Text = "Delete your saved progress and return to a clean start screen state.",
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.TEXT_SECONDARY,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 4,
			ZIndex = 90,
		})

		local startOverBtn = createButton({
			parent = scrollFrame,
			Text = "START OVER",
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = COLORS.DANGER,
			BorderSizePixel = 0,
			TextColor3 = COLORS.TEXT_PRIMARY,
			Font = Enum.Font.GothamSemibold,
			TextSize = 15,
			AutoButtonColor = false,
			LayoutOrder = 5,
			ZIndex = 90,
		})
		roundCorners(startOverBtn, 12)
		animateButtonHover(startOverBtn, COLORS.DANGER, Color3.fromRGB(220, 38, 38))
		startOverBtn.MouseButton1Click:Connect(function()
			local startOverRemote = getRemoteFunction(START_OVER_REMOTE_NAME)
			if not startOverRemote then
				notify("UNDERCOVER", "Start Over is unavailable right now.", 3)
				return
			end

			startOverBtn.Text = "Clearing Save..."
			startOverBtn.Active = false
			startOverBtn.Selectable = false

			local okReset, resetResult = pcall(function()
				return startOverRemote:InvokeServer()
			end)

			startOverBtn.Text = "START OVER"
			startOverBtn.Active = true
			startOverBtn.Selectable = true

			if not okReset or type(resetResult) ~= "table" or not resetResult.success then
				notify("UNDERCOVER", type(resetResult) == "table" and tostring(resetResult.message or "Could not start over.") or "Could not start over.", 3)
				return
			end

			player:SetAttribute(RESTORE_STATE_ATTRIBUTE, nil)
			refreshContinueButtonState()
			notify("UNDERCOVER", tostring(resetResult.message or "Saved progress removed."), 3)
		end)
	end)

	if not ok then
		warn("[ModernTitleScreen] Failed to build SETTINGS popup:", err)
		showPopupMessage(contentArea, "SETTINGS FAILED TO LOAD.\nCHECK OUTPUT FOR DETAILS.")
	end
end)

---------------------------------------------------------
-- POPUP: CHAPTERS
---------------------------------------------------------
chaptersBtn.MouseButton1Click:Connect(function()
	local _, contentArea = createPopupPanel("CHAPTERS", UDim2.new(0, 480, 0, 550))
	local scrollFrame = makeScrollingFrame(contentArea)

	local chapters = getChapterPopupData()

	for _, chapterData in ipairs(chapters) do
		local chapterBtn = createButton({
			parent = scrollFrame,
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = chapterData.locked and COLORS.DISABLED or COLORS.PRIMARY,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = not chapterData.locked,
			ZIndex = 85,
		})
		roundCorners(chapterBtn, 12)

		createLabel({
			parent = chapterBtn,
			Text = chapterData.name,
			Size = UDim2.new(1, -110, 1, 0),
			Position = UDim2.new(0, 16, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = chapterData.locked and COLORS.TEXT_PRIMARY or COLORS.DARK_BG,
			Font = Enum.Font.GothamSemibold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 86,
		})

		if chapterData.locked then
			createIcon({
				parent = chapterBtn,
				Image = "rbxassetid://18209587336",
				Size = UDim2.new(0, 36, 0, 36),
				Position = UDim2.new(1, -54, 0.5, -18),
				ZIndex = 86,
			})

			createLabel({
				parent = chapterBtn,
				Text = "LOCKED",
				Size = UDim2.new(0, 88, 0, 28),
				Position = UDim2.new(1, -100, 0.5, -14),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.DANGER,
				Font = Enum.Font.GothamBlack,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 86,
			})
		else
			createIcon({
				parent = chapterBtn,
				Image = "rbxassetid://18209574864",
				Size = UDim2.new(0, 36, 0, 36),
				Position = UDim2.new(1, -54, 0.5, -18),
				ZIndex = 86,
			})

			animateButtonHover(chapterBtn, COLORS.PRIMARY, COLORS.ACCENT)

			local statusText = tostring(chapterData.status or "Ready")
			createLabel({
				parent = chapterBtn,
				Text = string.upper(statusText == "Not Started" and "READY" or statusText),
				Size = UDim2.new(0, 96, 0, 28),
				Position = UDim2.new(1, -112, 0.5, -14),
				BackgroundTransparency = 1,
				TextColor3 = statusText == "Completed" and COLORS.SUCCESS or (statusText == "In Progress" and COLORS.WARNING or COLORS.DARK_BG),
				Font = Enum.Font.GothamBlack,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 86,
			})

			chapterBtn.MouseButton1Click:Connect(function()
				startMissionFlow(chapterData.id)
			end)
		end
	end
end)

---------------------------------------------------------
-- POPUP: ABOUT
---------------------------------------------------------
aboutBtn.MouseButton1Click:Connect(function()
	local _, contentArea = createPopupPanel("ABOUT", UDim2.new(0, 480, 0, 550))

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Parent = contentArea
	scrollFrame.Size = UDim2.fromScale(1, 1)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 620)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollFrame.Active = true
	scrollFrame.ZIndex = 84

	createLabel({
		parent = scrollFrame,
		Text = [[MISSION BRIEFING

You are an undercover cybersecurity professional hired by a federal agency to investigate a critical security breach.

THE SITUATION
A major streaming company is experiencing a data leak. Someone inside the organization is systematically stealing and leaking confidential information. This is not a random hack—it is an inside job.

YOUR OBJECTIVES
• WHO - Identify the insider responsible for the leak
• WHAT - Determine what data was compromised
• HOW - Uncover the methods and tools they are using

YOUR TOOLS
→ Ghost Key: Steal access codes from guards
→ HackOS Tablet: Network analysis and system penetration
→ Your wits: Use reconnaissance to piece it together

TIME IS CRITICAL
The leak is accelerating. More data goes out every day. You have limited time to stop it before the damage becomes irreversible.

RULES OF ENGAGEMENT
Stay hidden. Avoid detection. Use minimal force. The mission depends on your discretion.

Good luck, Agent.]],
		Size = UDim2.new(1, -8, 0, 620),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.TEXT_PRIMARY,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 85,
	})
end)

---------------------------------------------------------
-- INITIAL ANIMATION
---------------------------------------------------------
mainPanel.BackgroundTransparency = 1
header.BackgroundTransparency = 1

for _, obj in ipairs(mainPanel:GetDescendants()) do
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		obj.TextTransparency = 1
	end
end

TweenService:Create(
	mainPanel,
	TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 0 }
):Play()

TweenService:Create(
	header,
	TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 0 }
):Play()

for _, obj in ipairs(mainPanel:GetDescendants()) do
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		TweenService:Create(
			obj,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		):Play()
	end
end

-- Back to Menu Button (only for popups)
local function createBackToMenuButton(parent)
	local btn = createButton({
		parent = parent,
		Text = "BACK TO MENU",
		Size = UDim2.new(0, 180, 0, 38),
		Position = UDim2.new(0, 20, 1, -58),
		BackgroundColor3 = COLORS.CARD_BG,
		BorderSizePixel = 0,
		TextColor3 = COLORS.PRIMARY,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		AutoButtonColor = false,
		ZIndex = 10,
	})
	roundCorners(btn, 10)
	addStroke(btn, COLORS.PRIMARY, 2, 0.7)
	animateButtonHover(btn, COLORS.CARD_BG, COLORS.PRIMARY)
	btn.MouseButton1Click:Connect(function()
		closePopup()
		screenGui.Enabled = true
	end)
	return btn
end

-- Patch popups to include the button
local oldCreatePopupPanel = createPopupPanel
createPopupPanel = function(title, contentSize)
	local popup, contentArea = oldCreatePopupPanel(title, contentSize)
	createBackToMenuButton(contentArea)
	return popup, contentArea
end

-- Back to menu uses StarterGui > MenuGui > Menu when present.
local backToMenuBtn = nil
local fallbackBackGui = nil

local function fireBackToMenuCleanup()
	local remotes = getRemotesFolder()
	local cleanupRemote = remotes and remotes:FindFirstChild(CLEANUP_REMOTE_NAME)
	if cleanupRemote and cleanupRemote:IsA("RemoteEvent") then
		cleanupRemote:FireServer()
	end
end

local function positionBackToMenuButton(button)
	if not button or not button:IsA("GuiButton") then
		return
	end

	local parentGui = button:FindFirstAncestorOfClass("ScreenGui")
	if parentGui then
		parentGui.ResetOnSpawn = false
		parentGui.DisplayOrder = math.max(parentGui.DisplayOrder, 1000)
	end

	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -44, 0, 38)
	button.Size = UDim2.new(0, 160, 0, 40)
	button.ZIndex = math.max(button.ZIndex, 1000)
	button.Visible = false
end

local function createFallbackBackButton()
	fallbackBackGui = Instance.new("ScreenGui")
	fallbackBackGui.Name = "GlobalBackButtonGui"
	fallbackBackGui.ResetOnSpawn = false
	fallbackBackGui.IgnoreGuiInset = true
	fallbackBackGui.DisplayOrder = 1000
	fallbackBackGui.Parent = playerGui

	local button = createButton({
		parent = fallbackBackGui,
		Text = "BACK TO MENU",
		BackgroundColor3 = COLORS.CARD_BG,
		BorderSizePixel = 0,
		TextColor3 = COLORS.PRIMARY,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		AutoButtonColor = false,
	})
	roundCorners(button, 10)
	addStroke(button, COLORS.PRIMARY, 2, 0.7)
	animateButtonHover(button, COLORS.CARD_BG, COLORS.PRIMARY)
	return button
end

local function getBackToMenuButton()
	local menuGui = playerGui:FindFirstChild("MenuGui")
	local menuButton = menuGui and menuGui:FindFirstChild("Menu")
	if menuButton and menuButton:IsA("GuiButton") then
		if fallbackBackGui then
			fallbackBackGui:Destroy()
			fallbackBackGui = nil
		end
		return menuButton
	end

	return createFallbackBackButton()
end

backToMenuBtn = getBackToMenuButton()
positionBackToMenuButton(backToMenuBtn)

if backToMenuBtn then
	backToMenuBtn.MouseButton1Click:Connect(function()
		fireBackToMenuCleanup()
		backToMenuBtn.Visible = false
		refreshContinueButtonState()
		screenGui.Enabled = true
	end)
end

screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		if backToMenuBtn then
			backToMenuBtn.Visible = false
		end
		refreshContinueButtonState()
	elseif backToMenuBtn then
		backToMenuBtn.Visible = true
	end
end)

showTrainingDisclaimer(function()
	screenGui.Enabled = true
	mainPanel.Position = UDim2.fromScale(0.5, 0.53)
	TweenService:Create(
		mainPanel,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	):Play()
end)
