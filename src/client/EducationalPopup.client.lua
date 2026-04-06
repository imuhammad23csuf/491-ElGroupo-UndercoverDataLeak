local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Helper function to build UI elements in code
local function createUI(className, properties)
	local instance = Instance.new(className)
	for k, v in pairs(properties or {}) do
		instance[k] = v
	end
	return instance
end

-- 2. Build the ScreenGui and the Dark Background
local popupGui = createUI("ScreenGui", {
	Parent = playerGui,
	Name = "EducationalPopupGui",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	Enabled = false -- Hidden by default
})

local overlay = createUI("Frame", {
	Parent = popupGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.5
})

-- 3. Build the centered Pop-up Card
local card = createUI("Frame", {
	Parent = overlay,
	Size = UDim2.fromOffset(450, 250),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(20, 25, 35)
})
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = card

-- 4. Add the Text and Button
local titleText = createUI("TextLabel", {
	Parent = card,
	BackgroundTransparency = 1,
	Text = "SECURITY ALERT",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 100, 100),
	Size = UDim2.new(1, 0, 0, 50),
	Position = UDim2.new(0, 0, 0, 10)
})

local lessonText = createUI("TextLabel", {
	Parent = card,
	BackgroundTransparency = 1,
	Text = "Default educational message.",
	Font = Enum.Font.GothamMedium,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(220, 230, 240),
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, -40, 1, -130),
	Position = UDim2.new(0, 20, 0, 60)
})

local dismissBtn = createUI("TextButton", {
	Parent = card,
	Text = "I Understand",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(70, 100, 200),
	Size = UDim2.fromOffset(200, 40),
	Position = UDim2.new(0.5, -100, 1, -60)
})
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = dismissBtn

-- 5. The Logic: Make the button close the UI
dismissBtn.MouseButton1Click:Connect(function()
	popupGui.Enabled = false
end)

-- === THE TRIGGER LOGIC ===
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WaitForChild guarantees it uses the exact same one the Server uses!
local popupEvent = ReplicatedStorage:WaitForChild("ShowEducationalPopup")

popupEvent.OnClientEvent:Connect(function(title, message)
	titleText.Text = title
	lessonText.Text = message
	popupGui.Enabled = true
end)