local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local humanoid
local crouching = false

local walkTrack
local idleTrack

local CROUCH_SPEED = 6
local NORMAL_SPEED = 16

local WALK_ANIM = "rbxassetid://89110259028624"
local IDLE_ANIM = "rbxassetid://88755635491494"

local function stopAll()
	if walkTrack and walkTrack.IsPlaying then walkTrack:Stop() end
	if idleTrack and idleTrack.IsPlaying then idleTrack:Stop() end
end

local function startCrouch()
	if not humanoid then return end
	crouching = true
	humanoid.WalkSpeed = CROUCH_SPEED
end

local function stopCrouch()
	if not humanoid then return end
	crouching = false
	humanoid.WalkSpeed = NORMAL_SPEED
	stopAll()
end

local function setupCharacter(character)
	humanoid = character:WaitForChild("Humanoid")

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	-- Walk animation
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = WALK_ANIM
	walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement

	-- Idle animation
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = IDLE_ANIM
	idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Movement

	stopCrouch()
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

-- Toggle crouch
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not humanoid then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		if crouching then
			stopCrouch()
		else
			startCrouch()
		end
	end
end)

-- Handle animation switching
RunService.RenderStepped:Connect(function()
	if not humanoid or not crouching then return end

	local moving = humanoid.MoveDirection.Magnitude > 0.1

	if moving then
		if idleTrack.IsPlaying then idleTrack:Stop() end
		if not walkTrack.IsPlaying then walkTrack:Play() end
	else
		if walkTrack.IsPlaying then walkTrack:Stop() end
		if not idleTrack.IsPlaying then idleTrack:Play() end
	end
end)