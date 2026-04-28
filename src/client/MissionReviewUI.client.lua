print("[DIAGNOSTIC] The Mission Review UI Script has successfully turned on!")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local reviewEvent = ReplicatedStorage:WaitForChild("ShowMissionReview")

local feedbackDatabase = {
    ["ReportedPhish"] = { good = true, title = "PHISHING ESCAPED", practice = "BEST PRACTICE: You verified the sender domain." },
    ["ClickedPhish"] = { good = false, title = "SECURITY BREACH", practice = "VULNERABILITY: You clicked a malicious link." },
    
    -- Our new traps:
    ["FoundStickyNotePassword"] = { good = false, title = "PHYSICAL BREACH", practice = "VULNERABILITY: You found admin credentials left in the open. Never write passwords on sticky notes." },
    ["CaughtByCamera"] = { good = false, title = "SPOTTED", practice = "VULNERABILITY: You failed to evade the security cameras." },
	["ClonedKeycard"] = { good = true, title = "RFID CLONED", practice = "VULNERABILITY: You demonstrated how easily unsecured physical badges can be copied via proximity." },
}

-- === UI GENERATION ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MissionReviewGui"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.Enabled = false
screenGui.ResetOnSpawn = false 
screenGui.DisplayOrder = 100 

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
background.BackgroundTransparency = 0.05
background.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 100)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MISSION ETHICS REVIEW"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 40
titleLabel.Font = Enum.Font.Code
titleLabel.Parent = background

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
scrollingFrame.Position = UDim2.new(0.2, 0, 0.15, 0)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.ScrollBarThickness = 8
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Resets default canvas
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Magic trick: Auto-scales the scrollbar!
scrollingFrame.Parent = background

-- THE FIX: Properly parenting the UIListLayout
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 15)
listLayout.Parent = scrollingFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0.2, 0, 0, 50)
closeButton.Position = UDim2.new(0.4, 0, 0.85, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeButton.Text = "ACKNOWLEDGE"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.Code
closeButton.TextSize = 20
closeButton.Parent = background

closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- === TRIGGER LOGIC ===
reviewEvent.OnClientEvent:Connect(function(decisionLog)
	print("[UI SCRIPT] Received the final stats! Generating UI...")
	
	-- Wake up the UI
	screenGui.Enabled = true
	
	-- Clear old data
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	-- Build new data
	for key, value in pairs(decisionLog) do
		if feedbackDatabase[key] and value == true then
			local entry = feedbackDatabase[key]
			
			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, 0, 0, 80)
			itemFrame.BackgroundColor3 = entry.good and Color3.fromRGB(20, 50, 20) or Color3.fromRGB(50, 20, 20)
			itemFrame.Parent = scrollingFrame
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(0.9, 0, 1, 0)
			textLabel.Position = UDim2.new(0.05, 0, 0, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = entry.title .. "\n" .. entry.practice
			textLabel.TextColor3 = entry.good and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
			textLabel.TextWrapped = true
			textLabel.TextXAlignment = Enum.TextXAlignment.Left
			textLabel.Font = Enum.Font.Code
			textLabel.Parent = itemFrame
		end
	end
end)