-- Auto Door Open Script using ProximityPrompt

local TweenService = game:GetService("TweenService")

local DOOR_MODEL_NAME = "Sliding Door"

local model = script.Parent
local prompt = model:WaitForChild("ProximityPrompt")

local tweeninfo = TweenInfo.new(1)

-- Create sound
local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://3272349456"
sound.Volume = 1
sound.Parent = model

local function findDoorModel()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == DOOR_MODEL_NAME then
			return obj
		end
	end
	return nil
end

local doorModel = findDoorModel()
if not doorModel then
	warn("Door model not found in Workspace: " .. DOOR_MODEL_NAME)
	return
end

local leftDoor = doorModel:WaitForChild("DoorLeft")
local rightDoor = doorModel:WaitForChild("DoorRight")

leftDoor.Anchored = true
rightDoor.Anchored = true

local leftGoalOpen = {}
local leftGoalClosed = {}
local rightGoalOpen = {}
local rightGoalClosed = {}

leftGoalClosed.CFrame = leftDoor.CFrame
rightGoalClosed.CFrame = rightDoor.CFrame

leftGoalOpen.CFrame = leftDoor.CFrame * CFrame.new(leftDoor.Size.X, 0, 0)
rightGoalOpen.CFrame = rightDoor.CFrame * CFrame.new(-rightDoor.Size.X, 0, 0)

local leftTweenOpen = TweenService:Create(leftDoor, tweeninfo, leftGoalOpen)
local leftTweenClose = TweenService:Create(leftDoor, tweeninfo, leftGoalClosed)

local rightTweenOpen = TweenService:Create(rightDoor, tweeninfo, rightGoalOpen)
local rightTweenClose = TweenService:Create(rightDoor, tweeninfo, rightGoalClosed)

local isOpen = false

local function playSound()
	sound:Stop()
	sound:Play()
end

local function openDoor()
	playSound()
	leftTweenOpen:Play()
	rightTweenOpen:Play()
	isOpen = true
end

local function closeDoor()
	playSound()
	leftTweenClose:Play()
	rightTweenClose:Play()
	isOpen = false
end

prompt.Triggered:Connect(function()
	if isOpen then
		closeDoor()
	else
		openDoor()
	end
end)
