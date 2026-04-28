local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local KeycardCopier = require(script.Parent:WaitForChild("KeycardCopier"))

-- Reference the main model
local mainModel = workspace:WaitForChild("S.S.R. Teknikk Door")
local doorLeft = mainModel:WaitForChild("DoorLeft")
local doorRight = mainModel:WaitForChild("DoorRight")

-- Configuration
local openDistance = 15 -- Increased so it opens BEFORE you reach it
local slideAmount = 9.5    -- Increased so you can fit through easily
local tweenSpeed = 0.6  -- Lower is faster (0.6s to open/close)
local tweenInfo = TweenInfo.new(tweenSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Store original Pivot CFrames
local leftClosedPivot = doorLeft:GetPivot()
local rightClosedPivot = doorRight:GetPivot()

-- Calculate open Pivot CFrames (Adjust axis if doors move wrong way)
local leftOpenPivot = leftClosedPivot * CFrame.new(-slideAmount, 0, 0)
local rightOpenPivot = rightClosedPivot * CFrame.new(slideAmount, 0, 0)

local isOpen = false
local isAnimating = false

local function reportDoorMissionProgress(player)
	local missionController = _G.MissionController
	local method = missionController and missionController.MarkSlidingDoorUnlocked
	if typeof(method) == "function" then
		task.defer(method, player)
	end
end

-- Improved Animation Function
local function animateDoors(shouldOpen)
	isAnimating = true
	
	local startLeft = doorLeft:GetPivot()
	local startRight = doorRight:GetPivot()
	
	local targetLeft = shouldOpen and leftOpenPivot or leftClosedPivot
	local targetRight = shouldOpen and rightOpenPivot or rightClosedPivot
	
	local val = Instance.new("NumberValue")
	val.Value = 0
	
	local connection
	connection = val:GetPropertyChangedSignal("Value"):Connect(function()
		doorLeft:PivotTo(startLeft:Lerp(targetLeft, val.Value))
		doorRight:PivotTo(startRight:Lerp(targetRight, val.Value))
	end)
	
	local tween = TweenService:Create(val, tweenInfo, {Value = 1})
	tween:Play()
	
	tween.Completed:Connect(function()
		connection:Disconnect()
		val:Destroy()
		isAnimating = false
	end)
end

-- Detection Loop
while task.wait(0.2) do
	local playerNear = false
	local openingPlayer = nil
	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local distance = (char.HumanoidRootPart.Position - leftClosedPivot.Position).Magnitude
			if distance <= openDistance and KeycardCopier.hasSlidingDoorAccess(player) then
				playerNear = true
				openingPlayer = player
				break
			end
		end
	end

	if playerNear and not isOpen and not isAnimating then
		isOpen = true
		reportDoorMissionProgress(openingPlayer)
		animateDoors(true)
	elseif not playerNear and isOpen and not isAnimating then
		isOpen = false
		animateDoors(false)
	end
end
