local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraMetadata = require(Shared:WaitForChild("CameraMetadata"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameCamera = Workspace.CurrentCamera

local openEvent = ReplicatedStorage:WaitForChild("OpenCameraMonitor")

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local monitorOpen = false
local currentIndex = 1
local renderConnection = nil

local cameraPoints = {}

local screenGui
local mainFrame
local titleLabel
local locationLabel
local leftButton
local rightButton
local closeButton

local function refreshCharacter(newCharacter)
	character = newCharacter or player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")

	if not monitorOpen then
		gameCamera.CameraSubject = humanoid
	end
end

player.CharacterAdded:Connect(refreshCharacter)

local function collectCameras()
	cameraPoints = {}

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "Camera" then
			local lens = obj:FindFirstChild("Lens", true)

			if lens and lens:IsA("BasePart") then
				table.insert(cameraPoints, {
					cameraModel = obj,
					viewPart = lens,
					location = CameraMetadata.GetLocationLabel(obj),
				})
			else
				warn("[Monitor] No valid Lens found in", obj:GetFullName())
			end
		end
	end

	table.sort(cameraPoints, function(a, b)
		if a.location == b.location then
			return a.cameraModel:GetFullName() < b.cameraModel:GetFullName()
		end

		return a.location < b.location
	end)
end

local function updateLabels()
	if #cameraPoints == 0 then
		titleLabel.Text = "NO CAMERAS"
		locationLabel.Text = "LOCATION UNAVAILABLE"
		return
	end

	local data = cameraPoints[currentIndex]
	titleLabel.Text = "CAMERA " .. currentIndex .. " / " .. #cameraPoints
	locationLabel.Text = string.upper((data and data.location) or "Unknown Location")
end

local function applyCurrentCamera()
	local data = cameraPoints[currentIndex]
	if not data or not data.viewPart or not data.viewPart.Parent then
		return
	end

	gameCamera.CameraType = Enum.CameraType.Scriptable
	gameCamera.CFrame = data.viewPart.CFrame
	updateLabels()
end

local function nextCamera()
	if #cameraPoints == 0 then
		return
	end

	currentIndex += 1
	if currentIndex > #cameraPoints then
		currentIndex = 1
	end

	applyCurrentCamera()
end

local function previousCamera()
	if #cameraPoints == 0 then
		return
	end

	currentIndex -= 1
	if currentIndex < 1 then
		currentIndex = #cameraPoints
	end

	applyCurrentCamera()
end

local function closeMonitor()
	monitorOpen = false

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	screenGui.Enabled = false
	gameCamera.CameraType = Enum.CameraType.Custom

	if humanoid then
		gameCamera.CameraSubject = humanoid
	end
end

local function openMonitor()
	collectCameras()

	if #cameraPoints == 0 then
		warn("No cameras found. Expected a model named Camera containing a part named Lens.")
		return
	end

	if currentIndex > #cameraPoints then
		currentIndex = 1
	end

	monitorOpen = true
	screenGui.Enabled = true

	applyCurrentCamera()

	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		if not monitorOpen then
			return
		end

		local data = cameraPoints[currentIndex]
		if data and data.viewPart and data.viewPart.Parent then
			gameCamera.CFrame = data.viewPart.CFrame
		end
	end)
end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "CameraMonitorGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 420, 0, 132)
mainFrame.Position = UDim2.new(0.5, -210, 1, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 0, 40)
titleLabel.Position = UDim2.new(0, 60, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CAMERA"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

locationLabel = Instance.new("TextLabel")
locationLabel.Size = UDim2.new(1, -120, 0, 22)
locationLabel.Position = UDim2.new(0, 60, 0, 44)
locationLabel.BackgroundTransparency = 1
locationLabel.Text = "LOCATION"
locationLabel.TextColor3 = Color3.fromRGB(180, 225, 255)
locationLabel.TextScaled = true
locationLabel.Font = Enum.Font.SourceSansSemibold
locationLabel.Parent = mainFrame

leftButton = Instance.new("TextButton")
leftButton.Size = UDim2.new(0, 80, 0, 40)
leftButton.Position = UDim2.new(0, 10, 0, 80)
leftButton.Text = "<"
leftButton.TextScaled = true
leftButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
leftButton.TextColor3 = Color3.new(1, 1, 1)
leftButton.Parent = mainFrame

rightButton = Instance.new("TextButton")
rightButton.Size = UDim2.new(0, 80, 0, 40)
rightButton.Position = UDim2.new(1, -90, 0, 80)
rightButton.Text = ">"
rightButton.TextScaled = true
rightButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
rightButton.TextColor3 = Color3.new(1, 1, 1)
rightButton.Parent = mainFrame

closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -50, 0, 10)
closeButton.Text = "X"
closeButton.TextScaled = true
closeButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Parent = mainFrame

leftButton.MouseButton1Click:Connect(previousCamera)
rightButton.MouseButton1Click:Connect(nextCamera)
closeButton.MouseButton1Click:Connect(closeMonitor)

openEvent.OnClientEvent:Connect(function()
	if monitorOpen then
		closeMonitor()
	else
		openMonitor()
	end
end)
