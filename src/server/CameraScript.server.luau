local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedRoot = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(sharedRoot:WaitForChild("SuspicionManager"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))

local UPDATE_RATE = 0.03
local PUSH_INTERVAL = 0.5
local SUSPICION_TICK_RATE = 0.35
local SUSPICION_PER_TICK = 1.2

local JAM_STATE_ATTRIBUTE = "CameraNetworkJamUntil"

local DEFAULT_SWEEP_ANGLE = 60
local DEFAULT_SWEEP_SPEED = 35
local DEFAULT_TRACK_SPEED = 140
local DEFAULT_VISION_RANGE = 80
local DEFAULT_VISION_ANGLE = 55

local QUESTION_THRESHOLD = 50
local EXCLAMATION_THRESHOLD = 100
local CAMERA_LESSON_THROTTLE_SECONDS = 60

local pendingSuspicion = {}
local localSuspicionCache = {}

local function isJamActive()
    local jamUntil = ReplicatedStorage:GetAttribute(JAM_STATE_ATTRIBUTE)
    return typeof(jamUntil) == "number" and jamUntil > Workspace:GetServerTimeNow()
end

local function addPendingSuspicion(player, amount)
    if not player then
        return
    end

    local userId = player.UserId
    pcall(function()
        SuspicionManager.Add(amount, player)
    end)

    local localValue = localSuspicionCache[userId] or 0
    localSuspicionCache[userId] = localValue + amount
end

local function triggerCameraLesson(player)
    LessonManager.TriggerMistake(player, "CameraDetected", {
        throttleKey = "camera_detected",
        throttleWindow = CAMERA_LESSON_THROTTLE_SECONDS,
    })
end

task.spawn(function()
    while task.wait(PUSH_INTERVAL) do
        for userId, amount in pairs(pendingSuspicion) do
            if amount and amount > 0 then
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    pcall(function()
                        SuspicionManager.Add(amount, player)
                    end)
                end
            end
            pendingSuspicion[userId] = 0
        end
    end
end)

local function getSuspicion(player)
    if not player then
        return 0
    end

    local attr = player:GetAttribute("Suspicion")
    if typeof(attr) == "number" then
        return attr
    end

    if SuspicionManager.Get then
        local ok, result = pcall(function()
            return SuspicionManager.Get(player)
        end)
        if ok and typeof(result) == "number" then
            return result
        end
    end

    if SuspicionManager.GetSuspicion then
        local ok, result = pcall(function()
            return SuspicionManager.GetSuspicion(player)
        end)
        if ok and typeof(result) == "number" then
            return result
        end
    end

    return localSuspicionCache[player.UserId] or 0
end

local function getNumberAttribute(instance, name, fallback)
    local value = instance:GetAttribute(name)
    if typeof(value) == "number" then
        return value
    end
    return fallback
end

local function safeAlive(humanoid)
    return humanoid and humanoid.Health > 0 and humanoid.Parent
end

local function getCharacterRoot(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if root and safeAlive(humanoid) then
        return character, root, humanoid
    end

    return character, nil, humanoid
end

local function normalizeAngle(angle)
    while angle > math.pi do
        angle = angle - math.pi * 2
    end
    while angle < -math.pi do
        angle = angle + math.pi * 2
    end
    return angle
end

local function moveTowardAngle(current, target, maxStep)
    local delta = normalizeAngle(target - current)

    if math.abs(delta) <= maxStep then
        return target
    end

    if delta > 0 then
        return current + maxStep
    else
        return current - maxStep
    end
end

local function getYawToTarget(baseCFrame, worldPosition)
    local localPos = baseCFrame:PointToObjectSpace(worldPosition)
    return math.atan2(-localPos.X, -localPos.Z)
end

local function getAllCameraModels()
    local results = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Camera" then
            table.insert(results, obj)
        end
    end

    return results
end

local function createIndicator(part)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AlertIndicator"
    billboard.Size = UDim2.new(0, 60, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Name = "Icon"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextStrokeTransparency = 0.2
    label.Text = ""
    label.Parent = billboard

    return billboard, label
end

local function updateIndicator(state, player)
    if not player then
        state.billboard.Enabled = false
        state.label.Text = ""
        return
    end

    local suspicion = getSuspicion(player)

    if suspicion >= EXCLAMATION_THRESHOLD then
        state.billboard.Enabled = true
        state.label.Text = "!"
        state.label.TextColor3 = Color3.fromRGB(255, 70, 70)
    elseif suspicion >= QUESTION_THRESHOLD then
        state.billboard.Enabled = true
        state.label.Text = "?"
        state.label.TextColor3 = Color3.fromRGB(255, 230, 80)
    else
        state.billboard.Enabled = false
        state.label.Text = ""
    end
end

local ignoredInstances = getAllCameraModels()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = ignoredInstances

local function hasLineOfSight(origin, targetPosition, targetCharacter)
    local result = Workspace:Raycast(origin, targetPosition - origin, rayParams)

    if not result then
        return true
    end

    return targetCharacter and result.Instance and result.Instance:IsDescendantOf(targetCharacter)
end

local function canSeePlayer(state, playerRoot)
    if not playerRoot then
        return false
    end

    local offset = playerRoot.Position - state.lookPart.Position
    local distance = offset.Magnitude
    if distance <= 0 or distance > state.visionRange then
        return false
    end

    local direction = offset.Unit
    if state.lookPart.CFrame.LookVector:Dot(direction) < state.visionDot then
        return false
    end

    return hasLineOfSight(state.lookPart.Position, playerRoot.Position, playerRoot.Parent)
end

local function canTrackPlayer(state, playerRoot)
    if not playerRoot then
        return false
    end

    local distance = (playerRoot.Position - state.lookPart.Position).Magnitude
    if distance > state.visionRange then
        return false
    end

    local yaw = getYawToTarget(state.rotationBaseCFrame, playerRoot.Position)
    if math.abs(yaw) > state.sweepAngle then
        return false
    end

    return hasLineOfSight(state.lookPart.Position, playerRoot.Position, playerRoot.Parent)
end

local function findNearestVisiblePlayer(state)
    local bestPlayer = nil
    local bestRoot = nil
    local bestDistance = state.visionRange + 1

    for _, player in ipairs(Players:GetPlayers()) do
        local _, root = getCharacterRoot(player)
        if root and canSeePlayer(state, root) then
            local distance = (root.Position - state.lookPart.Position).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                bestPlayer = player
                bestRoot = root
            end
        end
    end

    return bestPlayer, bestRoot
end

local function collectMovingParts(model)
    local base = model:FindFirstChild("Base", true)
    if not base or not base:IsA("BasePart") then
        warn("[CCTV] Missing Base part in", model:GetFullName())
        return nil
    end

    local lens = model:FindFirstChild("Lens", true)
    if not lens or not lens:IsA("BasePart") then
        warn("[CCTV] Missing Lens part in", model:GetFullName())
        return nil
    end

    local movingParts = { base, lens }
    return base, lens, movingParts
end

local function buildRelativeOffsets(basePart, parts)
    local offsets = {}

    for _, part in ipairs(parts) do
        offsets[part] = basePart.CFrame:ToObjectSpace(part.CFrame)
    end

    return offsets
end

local function applyYaw(state)
    local rotatedBase = state.rotationBaseCFrame * CFrame.Angles(0, state.currentYaw, 0)

    for _, part in ipairs(state.movingParts) do
        if part and part.Parent then
            part.CFrame = rotatedBase * state.relativeOffsets[part]
        end
    end
end

local function buildCameraState(model)
    local basePart, lens, movingParts = collectMovingParts(model)
    if not basePart or not lens or not movingParts then
        return nil
    end

    local rotationBaseCFrame = basePart.CFrame
    local relativeOffsets = buildRelativeOffsets(basePart, movingParts)
    local billboard, label = createIndicator(lens)

    return {
        model = model,
        basePart = basePart,
        lookPart = lens,
        movingParts = movingParts,
        relativeOffsets = relativeOffsets,
        rotationBaseCFrame = rotationBaseCFrame,
        currentYaw = 0,
        sweepDirection = 1,
        targetPlayer = nil,
        nextSuspicionTick = 0,

        sweepAngle = math.rad(getNumberAttribute(model, "SweepAngle", DEFAULT_SWEEP_ANGLE)),
        sweepSpeed = math.rad(getNumberAttribute(model, "SweepSpeed", DEFAULT_SWEEP_SPEED)),
        trackSpeed = math.rad(getNumberAttribute(model, "TrackSpeed", DEFAULT_TRACK_SPEED)),
        visionRange = getNumberAttribute(model, "VisionRange", DEFAULT_VISION_RANGE),
        visionDot = math.cos(math.rad(getNumberAttribute(model, "VisionAngle", DEFAULT_VISION_ANGLE))),

        billboard = billboard,
        label = label,
    }
end

local function updateSweep(state, dt)
    state.currentYaw = state.currentYaw + state.sweepDirection * state.sweepSpeed * dt

    if state.currentYaw >= state.sweepAngle then
        state.currentYaw = state.sweepAngle
        state.sweepDirection = -1
    elseif state.currentYaw <= -state.sweepAngle then
        state.currentYaw = -state.sweepAngle
        state.sweepDirection = 1
    end

    applyYaw(state)
    updateIndicator(state, nil)
end

local function updateTracking(state, now, dt)
    local _, root, humanoid = getCharacterRoot(state.targetPlayer)

    if not root or not safeAlive(humanoid) or not canTrackPlayer(state, root) then
        state.targetPlayer = nil
        updateIndicator(state, nil)
        return false
    end

    local targetYaw = math.clamp(
        getYawToTarget(state.rotationBaseCFrame, root.Position),
        -state.sweepAngle,
        state.sweepAngle
    )

    state.currentYaw = moveTowardAngle(state.currentYaw, targetYaw, state.trackSpeed * dt)
    applyYaw(state)

    if canSeePlayer(state, root) and now >= state.nextSuspicionTick then
        triggerCameraLesson(state.targetPlayer)
        addPendingSuspicion(state.targetPlayer, SUSPICION_PER_TICK)
        state.nextSuspicionTick = now + SUSPICION_TICK_RATE
    end

    updateIndicator(state, state.targetPlayer)
    return true
end

local cameraStates = {}

for _, model in ipairs(getAllCameraModels()) do
    local state = buildCameraState(model)
    if state then
        table.insert(cameraStates, state)
    end
end

if #cameraStates == 0 then
    warn("[CCTV] No valid camera models were found in Workspace.")
    return
end

local lastTime = os.clock()

while true do
    task.wait(UPDATE_RATE)

    local now = os.clock()
    local dt = math.max(now - lastTime, 0)
    lastTime = now

    if isJamActive() then
        for _, state in ipairs(cameraStates) do
            if state.targetPlayer then
                state.targetPlayer = nil
                updateIndicator(state, nil)
            end
        end
    else
        for _, state in ipairs(cameraStates) do
            if not updateTracking(state, now, dt) then
                updateSweep(state, dt)

                local player, root = findNearestVisiblePlayer(state)
                if player and root then
                    state.targetPlayer = player

                    local targetYaw = math.clamp(
                        getYawToTarget(state.rotationBaseCFrame, root.Position),
                        -state.sweepAngle,
                        state.sweepAngle
                    )

                    state.currentYaw = moveTowardAngle(state.currentYaw, targetYaw, state.trackSpeed * dt)
                    applyYaw(state)

                    if now >= state.nextSuspicionTick and canSeePlayer(state, root) then
                        triggerCameraLesson(player)
                        addPendingSuspicion(player, SUSPICION_PER_TICK)
                        state.nextSuspicionTick = now + SUSPICION_TICK_RATE
                    end

                    updateIndicator(state, player)
                end
            end
        end
    end
end
