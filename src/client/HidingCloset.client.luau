local Players = game:GetService("Players")

local prompt = script.Parent
if not prompt:IsA("ProximityPrompt") then
	return
end

local closet = prompt:FindFirstAncestorWhichIsA("Model")
local door = closet and closet:FindFirstChild("Door")
local frame = closet and closet:FindFirstChild("Frame")
local base = frame and frame:FindFirstChild("Base")
local hidingPosition = base and base:FindFirstChild("HidingPosition")
local exitPosition = base and base:FindFirstChild("ExitPosition")
local hidingUiTemplate = closet and closet:FindFirstChild("HidingUI")
local somebodyHiding = closet and closet:FindFirstChild("somebodyHiding")
local userInside = closet and closet:FindFirstChild("userInside")

if not (door and hidingPosition and exitPosition and hidingUiTemplate and somebodyHiding and userInside) then
	warn("[HidingCloset] Missing required closet children for", closet and closet:GetFullName() or prompt:GetFullName())
	return
end

local INTERACTS = {
	HIDE = "Hide",
	EXIT = "Exit",
}

local busy = false

local function playDoorSound(name)
	local sound = door:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function rotateDoor(direction)
	for _ = 1, 20 do
		door:PivotTo(door:GetPivot() * CFrame.fromEulerAngles(0, direction * 0.1, 0))
		task.wait(0.01)
	end
end

local function getWorldPosition(instance)
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function fadeHidingUi(player, targetTransparency)
	local playerGui = player:FindFirstChild("PlayerGui")
	local ui = playerGui and playerGui:FindFirstChild("HidingUI")
	local image = ui and ui:FindFirstChild("ImageLabel")
	if not image or not image:IsA("ImageLabel") then
		return
	end

	local step = image.ImageTransparency < targetTransparency and 0.1 or -0.1
	while math.abs(image.ImageTransparency - targetTransparency) > 0.05 do
		image.ImageTransparency = math.clamp(image.ImageTransparency + step, 0, 1)
		task.wait(0.025)
	end
	image.ImageTransparency = targetTransparency

	if targetTransparency >= 1 and ui then
		ui:Destroy()
	end
end

prompt.Triggered:Connect(function(triggeringPlayer)
	if busy then
		return
	end

	local player = triggeringPlayer or Players.LocalPlayer
	if not player or not player:IsA("Player") then
		return
	end

	if userInside.Value ~= "" and userInside.Value ~= player.Name then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hidePosition = getWorldPosition(hidingPosition)
	local leavePosition = getWorldPosition(exitPosition)
	if not character or not root or not hidePosition or not leavePosition then
		return
	end

	busy = true
	prompt.Enabled = false

	playDoorSound("DoorOpen")
	rotateDoor(-1)

	if prompt.ActionText == INTERACTS.HIDE then
		root.Anchored = true
		character:MoveTo(hidePosition)

		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui and not playerGui:FindFirstChild("HidingUI") then
			hidingUiTemplate:Clone().Parent = playerGui
		end

		somebodyHiding.Value = true
		userInside.Value = player.Name
	elseif prompt.ActionText == INTERACTS.EXIT then
		root.Anchored = false
		character:MoveTo(leavePosition)
		somebodyHiding.Value = false
		userInside.Value = ""
	end

	rotateDoor(1)
	playDoorSound("DoorClose")

	if prompt.ActionText == INTERACTS.HIDE then
		fadeHidingUi(player, 0.5)
		prompt.ActionText = INTERACTS.EXIT
	else
		fadeHidingUi(player, 1)
		prompt.ActionText = INTERACTS.HIDE
	end

	prompt.Enabled = true
	busy = false
end)
