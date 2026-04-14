-- MODERN TITLE SCREEN - Full responsive design with working popup modals
-- Drop into StarterPlayerScripts or StarterGui

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

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

local function closePopup()
	if activePopup and activePopup.Parent then
		local popupToClose = activePopup
		activePopup = nil

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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModernTitleScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

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
local loadProgressBtn = createNavButton("Load Saved Progress")
local settingsBtn = createNavButton("SETTINGS")
local chaptersBtn = createNavButton("CHAPTERS")
local aboutBtn = createNavButton("ABOUT")

---------------------------------------------------------
-- CYBERSECURITY FACT TICKER
---------------------------------------------------------
local tickerCard = createFrame({
	parent = body,
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundColor3 = Color3.fromRGB(11, 18, 28),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	LayoutOrder = 2,
})
roundCorners(tickerCard, 14)
addStroke(tickerCard, Color3.fromRGB(60, 85, 120), 1, 0.7)

createLabel({
	parent = tickerCard,
	Text = "CYBER FACTS",
	Size = UDim2.new(0, 110, 1, 0),
	Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.PRIMARY,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local factsViewport = createFrame({
	parent = tickerCard,
	Size = UDim2.new(1, -130, 1, 0),
	Position = UDim2.new(0, 120, 0, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
})
factsViewport.ZIndex = 2

local cyberFacts = {
	"Use strong passwords with letters, numbers, and symbols.",
	"Never share your password with strangers online.",
	"Think before you click links in messages or emails.",
	"A scam tries to trick you into giving away information.",
	"Two-factor login adds an extra layer of protection.",
	"Public Wi-Fi can be risky if you send private info.",
	"Updates help fix security holes in apps and devices.",
	"Only download games and apps from trusted places.",
	"Do not talk to suspicious people online.",
	"Personal information includes your name, school, and address.",
	"If something feels weird online, tell a trusted adult.",
}

local separator = "   |   "
local tickerText = table.concat(cyberFacts, separator) .. separator
local tickerFont = Enum.Font.GothamSemibold
local tickerTextSize = 13
local tickerBounds = TextService:GetTextSize(tickerText, tickerTextSize, tickerFont, Vector2.new(100000, 50))
local tickerWidth = tickerBounds.X + 40
local tickerSpeed = 70

local tickerLabel1 = createLabel({
	parent = factsViewport,
	Text = tickerText,
	Size = UDim2.new(0, tickerWidth, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.TEXT_PRIMARY,
	Font = tickerFont,
	TextSize = tickerTextSize,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 3,
})

local tickerLabel2 = createLabel({
	parent = factsViewport,
	Text = tickerText,
	Size = UDim2.new(0, tickerWidth, 1, 0),
	Position = UDim2.new(0, tickerWidth, 0, 0),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.TEXT_PRIMARY,
	Font = tickerFont,
	TextSize = tickerTextSize,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 3,
})

RunService.RenderStepped:Connect(function(dt)
	if not screenGui.Parent then
		return
	end

	local moveAmount = tickerSpeed * dt
	local x1 = tickerLabel1.Position.X.Offset - moveAmount
	local x2 = tickerLabel2.Position.X.Offset - moveAmount

	if x1 <= -tickerWidth then
		x1 = x2 + tickerWidth
	end

	if x2 <= -tickerWidth then
		x2 = x1 + tickerWidth
	end

	tickerLabel1.Position = UDim2.new(0, x1, 0, 0)
	tickerLabel2.Position = UDim2.new(0, x2, 0, 0)
end)

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
local function startMissionFlow()
	screenGui.Enabled = false
	closePopup()

	local evt = ReplicatedStorage:FindFirstChild("StartNewsCutscene")
	if evt then
		evt:FireServer()
	end
end

startBtn.MouseButton1Click:Connect(startMissionFlow)

loadProgressBtn.MouseButton1Click:Connect(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local loadRemote = remotes and remotes:FindFirstChild("LoadSavedProgress")
	if not loadRemote then
		notify("UNDERCOVER", "Saved progress is unavailable right now.", 3)
		return
	end

	local originalText = loadProgressBtn.Text
	loadProgressBtn.Text = "Loading..."
	loadProgressBtn.Active = false

	local ok, result = pcall(function()
		return loadRemote:InvokeServer()
	end)

	loadProgressBtn.Text = originalText
	loadProgressBtn.Active = true

	if not ok or type(result) ~= "table" or not result.success then
		local message = type(result) == "table" and result.message or "Could not load saved progress."
		notify("UNDERCOVER", message, 3)
		return
	end

	if type(result.clientState) == "table" then
		local encodedOk, encodedState = pcall(function()
			return HttpService:JSONEncode(result.clientState)
		end)
		if encodedOk and type(encodedState) == "string" then
			player:SetAttribute(RESTORE_STATE_ATTRIBUTE, encodedState)
		end
	end

	closePopup()
	screenGui.Enabled = false
	notify("UNDERCOVER", tostring(result.message or "Saved progress loaded."), 3)
end)

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

	local chapters = {
		{ name = "Chapter 1: Infiltration", number = 1, locked = false },
		{ name = "Chapter 2: Investigation", number = 2, locked = true },
		{ name = "Chapter 3: Discovery", number = 3, locked = true },
		{ name = "Chapter 4: Confrontation", number = 4, locked = true },
	}

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

			chapterBtn.MouseButton1Click:Connect(function()
				print("Starting " .. chapterData.name)
				closePopup()
				screenGui.Enabled = false

				local evt = ReplicatedStorage:FindFirstChild("StartNewsCutscene")
				if evt then
					evt:FireServer()
				end
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
tickerCard.BackgroundTransparency = 1

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

TweenService:Create(
	tickerCard,
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

-- GLOBAL BACK TO MENU BUTTON (top left, always on top)
local globalBackBtn = nil
local function ensureGlobalBackBtn()
	if globalBackBtn and globalBackBtn.Parent then return end
	globalBackBtn = createButton({
		parent = playerGui,
		Text = "BACK TO MENU",
		Size = UDim2.new(0, 160, 0, 40),
		Position = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = COLORS.CARD_BG,
		BorderSizePixel = 0,
		TextColor3 = COLORS.PRIMARY,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		AutoButtonColor = false,
		ZIndex = 1000,
		Visible = false,
	})
	roundCorners(globalBackBtn, 10)
	addStroke(globalBackBtn, COLORS.PRIMARY, 2, 0.7)
	animateButtonHover(globalBackBtn, COLORS.CARD_BG, COLORS.PRIMARY)
	globalBackBtn.MouseButton1Click:Connect(function()
		globalBackBtn.Visible = false
		screenGui.Enabled = true
	end)
end

ensureGlobalBackBtn()

screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not globalBackBtn or not globalBackBtn.Parent then ensureGlobalBackBtn() end
	if screenGui.Enabled then
		globalBackBtn.Visible = false
	else
		globalBackBtn.Visible = true
	end
end)

-- Connect Menu button in MenuGui to show main menu
local menuBtn = nil
pcall(function()
	menuBtn = playerGui:WaitForChild("MenuGui"):WaitForChild("Menu")
end)
if menuBtn then
	menuBtn.MouseButton1Click:Connect(function()
		local screenGui = playerGui:FindFirstChild("ModernTitleScreen")
		if screenGui then
			screenGui.Enabled = true
		end
	end)
end
