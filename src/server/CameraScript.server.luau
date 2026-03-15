local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedRoot = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(sharedRoot:WaitForChild("SuspicionManager"))

local cameraRoot = Workspace:WaitForChild("Camera")

local DEFAULT_SWEEP_ANGLE = 60
local DEFAULT_SWEEP_SPEED = 45
local DEFAULT_TRACK_SPEED = 140
local DEFAULT_VISION_RANGE = 85
local DEFAULT_VISION_ANGLE = 50
local UPDATE_RATE = 0.1

local SUSPICION_TICK_SEEN = 1
local SUSPICION_TICK_RATE = 0.25
local SUSPICION_PUSH_INTERVAL = 0.5

local pendingSuspicion = {}

local function queueSuspicion(player, amount)
	if not player or not player.UserId then
		return
	end

	local uid = player.UserId
	pendingSuspicion[uid] = (pendingSuspicion[uid] or 0) + (amount or 0)
end

task.spawn(function()
	while task.wait(SUSPICION_PUSH_INTERVAL) do
		for uid, delta in pairs(pendingSuspicion) do
			if delta and delta > 0 then
				local player = Players:GetPlayerByUserId(uid)
				if player then
					SuspicionManager.Add(delta, player)
				end
				pendingSuspicion[uid] = 0
			end
		end
	end
end)

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.FilterDescendantsInstances = {cameraRoot}

local function safeAlive(humanoid)
	return humanoid and humanoid.Health > 0 and humanoid.Parent
end

local function getCharacterState(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart and safeAlive(humanoid) then
		return character, rootPart, humanoid
	end

	return character, nil, humanoid
end

local function getNumberAttribute(instance, name, fallback)
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function normalizeAngle(angle)
	while angle > math.pi do
		angle -= math.pi * 2
	end

	while angle < -math.pi do
		angle += math.pi * 2
	end

	return angle
end

local function sign(value)
	if value > 0 then
		return 1
	elseif value < 0 then
		return -1
	end

	return 0
end

local function moveAngleToward(current, target, maxStep)
	local delta = normalizeAngle(target - current)
	if math.abs(delta) <= maxStep then
		return target
	end

	return current + sign(delta) * maxStep
end

local function hasDirectBasePart(model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			return true
		end
	end

	return false
end

local function collectCameraInstances(instance, results)
	if instance:IsA("BasePart") then
		table.insert(results, instance)
		return
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart or hasDirectBasePart(instance) then
			table.insert(results, instance)
			return
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		collectCameraInstances(child, results)
	end
end

local function resolvePivotPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	if instance.PrimaryPart then
		return instance.PrimaryPart
	end

	for _, preferredName in ipairs({"Pivot", "Head", "Lens", "Camera", "Base"}) do
		local part = instance:FindFirstChild(preferredName, true)
		if part and part:IsA("BasePart") then
			instance.PrimaryPart = part
			return part
		end
	end

	local firstPart = instance:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		instance.PrimaryPart = firstPart
	end

	return firstPart
end

local function setPartCFrame(instance, pivotPart, pivotOffset, targetPartCFrame)
	if instance:IsA("BasePart") then
		instance.CFrame = targetPartCFrame
		return
	end

	if instance:IsA("Model") and pivotPart then
		instance:PivotTo(targetPartCFrame * pivotOffset)
	end
end

local function getYawToPosition(basePartCFrame, targetPosition)
	local localPosition = basePartCFrame:PointToObjectSpace(targetPosition)
	return math.atan2(-localPosition.X, -localPosition.Z)
end

local function hasLineOfSight(origin, targetPosition, targetCharacter)
	local ray = Workspace:Raycast(origin, targetPosition - origin, sightParams)
	if not ray then
		return true
	end

	return ray.Instance and targetCharacter and ray.Instance:IsDescendantOf(targetCharacter)
end

local function canSeePlayer(state, playerRoot)
	if not playerRoot then
		return false
	end

	local cameraCFrame = state.pivotPart.CFrame
	local offset = playerRoot.Position - cameraCFrame.Position
	local distance = offset.Magnitude
	if distance > state.visionRange or distance <= 0 then
		return false
	end

	local direction = offset.Unit
	if cameraCFrame.LookVector:Dot(direction) < state.visionDot then
		return false
	end

	return hasLineOfSight(cameraCFrame.Position, playerRoot.Position, playerRoot.Parent)
end

local function canTrackPlayer(state, playerRoot)
	if not playerRoot then
		return false
	end

	local offset = playerRoot.Position - state.pivotPart.Position
	if offset.Magnitude > state.visionRange then
		return false
	end

	local targetYaw = getYawToPosition(state.basePartCFrame, playerRoot.Position)
	if math.abs(targetYaw) > state.sweepAngle then
		return false
	end

	return hasLineOfSight(state.pivotPart.Position, playerRoot.Position, playerRoot.Parent)
end

local function findNearestVisiblePlayer(state)
	local nearestPlayer, nearestRoot
	local shortestDistance = state.visionRange + 1

	for _, player in ipairs(Players:GetPlayers()) do
		local _, playerRoot = getCharacterState(player)
		if playerRoot and canSeePlayer(state, playerRoot) then
			local distance = (playerRoot.Position - state.pivotPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestPlayer = player
				nearestRoot = playerRoot
			end
		end
	end

	return nearestPlayer, nearestRoot
end

local function buildCameraState(instance)
	local pivotPart = resolvePivotPart(instance)
	if not pivotPart then
		warn(("[CameraScript] No rotatable BasePart found for %s"):format(instance:GetFullName()))
		return nil
	end

	local pivotOffset = CFrame.new()
	if instance:IsA("Model") then
		pivotOffset = pivotPart.CFrame:ToObjectSpace(instance:GetPivot())
	end

	return {
		instance = instance,
		pivotPart = pivotPart,
		pivotOffset = pivotOffset,
		basePartCFrame = pivotPart.CFrame,
		currentYaw = 0,
		sweepDirection = 1,
		targetPlayer = nil,
		nextSuspicionAt = 0,
		sweepAngle = math.rad(getNumberAttribute(instance, "SweepAngle", DEFAULT_SWEEP_ANGLE)),
		sweepSpeed = math.rad(getNumberAttribute(instance, "SweepSpeed", DEFAULT_SWEEP_SPEED)),
		trackSpeed = math.rad(getNumberAttribute(instance, "TrackSpeed", DEFAULT_TRACK_SPEED)),
		visionRange = getNumberAttribute(instance, "VisionRange", DEFAULT_VISION_RANGE),
		visionDot = math.cos(math.rad(getNumberAttribute(instance, "VisionAngle", DEFAULT_VISION_ANGLE))),
	}
end

local function applyYaw(state)
	local targetPartCFrame = state.basePartCFrame * CFrame.Angles(0, state.currentYaw, 0)
	setPartCFrame(state.instance, state.pivotPart, state.pivotOffset, targetPartCFrame)
end

local function updateTrackedTarget(state, now, deltaTime)
	local _, targetRoot, targetHumanoid = getCharacterState(state.targetPlayer)
	if not targetRoot or not safeAlive(targetHumanoid) or not canTrackPlayer(state, targetRoot) then
		state.targetPlayer = nil
		return false
	end

	local targetYaw = math.clamp(getYawToPosition(state.basePartCFrame, targetRoot.Position), -state.sweepAngle, state.sweepAngle)
	state.currentYaw = moveAngleToward(state.currentYaw, targetYaw, state.trackSpeed * deltaTime)
	applyYaw(state)

	if canSeePlayer(state, targetRoot) and now >= state.nextSuspicionAt then
		queueSuspicion(state.targetPlayer, SUSPICION_TICK_SEEN)
		state.nextSuspicionAt = now + SUSPICION_TICK_RATE
	end

	return true
end

local function updateSweep(state, deltaTime)
	state.currentYaw += state.sweepDirection * state.sweepSpeed * deltaTime

	if state.currentYaw >= state.sweepAngle then
		state.currentYaw = state.sweepAngle
		state.sweepDirection = -1
	elseif state.currentYaw <= -state.sweepAngle then
		state.currentYaw = -state.sweepAngle
		state.sweepDirection = 1
	end

	applyYaw(state)
end

local cameras = {}
collectCameraInstances(cameraRoot, cameras)

local cameraStates = {}
for _, cameraInstance in ipairs(cameras) do
	local state = buildCameraState(cameraInstance)
	if state then
		table.insert(cameraStates, state)
	end
end

if #cameraStates == 0 then
	warn("[CameraScript] No camera parts or models were found under Workspace.Camera")
	return
end

local lastUpdate = os.clock()

while true do
	task.wait(UPDATE_RATE)

	local now = os.clock()
	local deltaTime = math.max(now - lastUpdate, 0)
	lastUpdate = now

	for _, state in ipairs(cameraStates) do
		if not updateTrackedTarget(state, now, deltaTime) then
			updateSweep(state, deltaTime)

			local player, playerRoot = findNearestVisiblePlayer(state)
			if player and playerRoot then
				state.targetPlayer = player

				local targetYaw = math.clamp(getYawToPosition(state.basePartCFrame, playerRoot.Position), -state.sweepAngle, state.sweepAngle)
				state.currentYaw = moveAngleToward(state.currentYaw, targetYaw, state.trackSpeed * deltaTime)
				applyYaw(state)

				if now >= state.nextSuspicionAt and canSeePlayer(state, playerRoot) then
					queueSuspicion(player, SUSPICION_TICK_SEEN)
					state.nextSuspicionAt = now + SUSPICION_TICK_RATE
				end
			end
		end
	end
end
