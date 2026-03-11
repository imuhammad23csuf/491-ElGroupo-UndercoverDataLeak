-- This needs to open sliding doors only when a keycard is scanned
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- === CONFIG ===
local DOOR_MODEL_NAME = "Sliding Door" -- <-- change to your parent model name
local LEFT_NAME = "DoorLeft"
local RIGHT_NAME = "DoorRight"

local OPEN_TIME = 3
local TWEEN_TIME = 1
local OPEN_DISTANCE = 6

-- === GET DOOR OBJECTS ===
local doorModel = Workspace:WaitForChild(DOOR_MODEL_NAME)
local leftDoor = doorModel:WaitForChild(LEFT_NAME)
local rightDoor = doorModel:WaitForChild(RIGHT_NAME)

-- Ensure PrimaryPart + return all BaseParts for collision/anchoring changes
local function getParts(obj)
	local parts = {}
	if obj:IsA("Model") then
		if not obj.PrimaryPart then
			local pp = obj:FindFirstChildWhichIsA("BasePart", true)
			if pp then obj.PrimaryPart = pp end
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	else
		table.insert(parts, obj)
	end
	return parts
end

local function getCFrame(obj)
	if obj:IsA("Model") then
		return obj:GetPrimaryPartCFrame()
	else
		return obj.CFrame
	end
end

local function setCFrame(obj, cf)
	if obj:IsA("Model") then
		obj:SetPrimaryPartCFrame(cf)
	else
		obj.CFrame = cf
	end
end

local function setDoorPhysics(obj, anchored, canCollide)
	for _, p in ipairs(getParts(obj)) do
		p.Anchored = anchored
		p.CanCollide = canCollide
	end
end

-- Tween helper that returns a "done" signal
local function tweenAsync(obj, targetCFrame)
	local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	local proxy = Instance.new("CFrameValue")
	proxy.Value = getCFrame(obj)

	local conn = proxy:GetPropertyChangedSignal("Value"):Connect(function()
		setCFrame(obj, proxy.Value)
	end)

	local tween = TweenService:Create(proxy, tweenInfo, {Value = targetCFrame})
	local done = false

	tween.Completed:Connect(function()
		done = true
		conn:Disconnect()
		proxy:Destroy()
	end)

	tween:Play()

	return function()
		while not done do task.wait() end
	end
end

-- Prepare: anchor doors so physics won’t shove players
setDoorPhysics(leftDoor, true, true)
setDoorPhysics(rightDoor, true, true)

-- Store closed positions
local leftClosed = getCFrame(leftDoor)
local rightClosed = getCFrame(rightDoor)

-- Open positions (slide apart on X axis)
local leftOpen = leftClosed * CFrame.new(-OPEN_DISTANCE, 0, 0)
local rightOpen = rightClosed * CFrame.new(OPEN_DISTANCE, 0, 0)

while true do
	-- OPEN together (noclip during movement)
	setDoorPhysics(leftDoor, true, false)
	setDoorPhysics(rightDoor, true, false)

	local waitLeftOpen = tweenAsync(leftDoor, leftOpen)
	local waitRightOpen = tweenAsync(rightDoor, rightOpen)

	waitLeftOpen()
	waitRightOpen()

	task.wait(OPEN_TIME)

	-- CLOSE together (noclip during movement)
	local waitLeftClose = tweenAsync(leftDoor, leftClosed)
	local waitRightClose = tweenAsync(rightDoor, rightClosed)

	waitLeftClose()
	waitRightClose()

	-- collide again when closed
	setDoorPhysics(leftDoor, true, true)
	setDoorPhysics(rightDoor, true, true)

	task.wait(OPEN_TIME)
end