-- GuardOutside (Patrol + State Machine Chase/Search/Return + Batched Suspicion + Distract)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(sharedRoot:WaitForChild("SuspicionManager"))

local GUARD = Workspace:WaitForChild("GuardOutside")
local RIG = GUARD:WaitForChild("Rig")
local HUMANOID = RIG:WaitForChild("Humanoid")
local HRP = RIG:WaitForChild("HumanoidRootPart")

local State = {
    PATROL = "PATROL",
    CHASE = "CHASE",
    SEARCH = "SEARCH",
    RETURN = "RETURN",
}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local DistractRemote = remotesFolder:FindFirstChild("DistractOutGuard")
if DistractRemote and not DistractRemote:IsA("RemoteFunction") then
    DistractRemote:Destroy()
    DistractRemote = nil
end
DistractRemote = DistractRemote or Instance.new("RemoteFunction")
DistractRemote.Name = "DistractOutGuard"
DistractRemote.Parent = remotesFolder

local GuardDialogueRemote = remotesFolder:FindFirstChild("GuardDialogue") or Instance.new("RemoteEvent")
GuardDialogueRemote.Name = "GuardDialogue"
GuardDialogueRemote.Parent = remotesFolder

-- === SETTINGS ===
local HEARTBEAT_INTERVAL = 0.5
local PATROL_SPEED = 8
local CHASE_SPEED = 13
local VISION_RANGE = 60
local VISION_ANGLE = math.cos(math.rad(60))
local CHASE_TIMEOUT = 4
local SEARCH_DURATION = 2.5
local SEARCH_ROTATION_STEP = math.rad(35)
local CAPTURE_DISTANCE = 4
local RETURN_REACHED_DISTANCE = 4
local MOVE_TIMEOUT = 8
local PATROL_PAUSE_DURATION = 0
local MOVE_TARGET_EPSILON = 2

-- Suspicion tuning (Outside)
local SUSPICION_PER_TICK = 1.2
local SUSPICION_TICK_RATE = 0.35

-- Distraction tuning
local DISTRACT_DURATION = 15
local DISTRACT_COOLDOWN = 20
local DISTRACT_MAX_RANGE = 160
local HACK_TABLET_NAME = "HackTablet"
local PHONE_ANIM_ID = "rbxassetid://85133448172500"

local DISTRACT_LINES = {
    "I don't get paid enough for this.",
    "You gotta be kidding me.",
    "My paycheck supports this apparently.",
    "Man, this job is exhausting.",
    "Seriously?",
    "This better be worth it.",
    "Bro...",
    "Wohoo! I'm getting a promotion... SERIOUSLY?!",
    "If this is another false alarm, I'm clocking out emotionally.",
    "Who keeps pressing the chaos button around here?",
    "My back hurts and my patience has left the building.",
    "I signed up for security, not cardio and confusion.",
    "At this point I'm guarding my last nerve.",
    "If annoyance paid overtime, I'd be rich.",
    "Somebody better be in danger because I just spilled my coffee.",
    "I swear this place is haunted by bad decisions.",
    "One more prank and I'm filing a strongly worded report.",
    "Do I look like a one-man emergency hotline?"
}

local CHASE_LINES = {
    "Hey! You! Stop!",
    "Running just makes my shift longer.",
    "I have eyes on you!",
    "Get back here!",
    "Security breach outside!",
}

local GIVE_UP_LINES = {
    "Lost them. Returning to patrol.",
    "Must have been the wind.",
    "Area clear, I guess.",
    "I am too tired for false alarms.",
    "Back to my route.",
}

-- === SUSPICION THROTTLE/BATCH ===
local SUSPICION_PUSH_INTERVAL = 0.5
local pendingSuspicion = {}

local function queueSuspicion(player, amount)
    if not player or not player.UserId then
        return
    end

    local uid = player.UserId
    pendingSuspicion[uid] = (pendingSuspicion[uid] or 0) + (amount or 0)
end

local function flushSuspicion(player)
    if not player or not player.UserId then
        return
    end

    local uid = player.UserId
    local delta = pendingSuspicion[uid] or 0
    if delta > 0 then
        SuspicionManager.Add(delta, player)
        pendingSuspicion[uid] = 0
    end
end

task.spawn(function()
    while task.wait(SUSPICION_PUSH_INTERVAL) do
        for uid, delta in pairs(pendingSuspicion) do
            if delta and delta > 0 then
                local ply = Players:GetPlayerByUserId(uid)
                if ply then
                    SuspicionManager.Add(delta, ply)
                end
                pendingSuspicion[uid] = 0
            end
        end
    end
end)

-- === ANIMATIONS ===
local WALK_ANIM_ID = "http://www.roblox.com/asset/?id=913402848"
local Animator = HUMANOID:FindFirstChildOfClass("Animator") or Instance.new("Animator")
Animator.Parent = HUMANOID

local WalkTrack do
    local anim = Instance.new("Animation")
    anim.AnimationId = WALK_ANIM_ID
    WalkTrack = Animator:LoadAnimation(anim)
    WalkTrack.Priority = Enum.AnimationPriority.Movement
end

local PhoneTrack do
    local anim = Instance.new("Animation")
    anim.AnimationId = PHONE_ANIM_ID
    PhoneTrack = Animator:LoadAnimation(anim)
    PhoneTrack.Priority = Enum.AnimationPriority.Action
    PhoneTrack.Looped = false
end

local function playWalk()
    if WalkTrack then
        if not WalkTrack.IsPlaying then
            WalkTrack:Play(0.1)
        end
        WalkTrack:AdjustSpeed(1)
    end
end

local function stopWalk()
    if WalkTrack and WalkTrack.IsPlaying then
        WalkTrack:Stop(0.1)
    end
end

-- === DISTRACTION STATE ===
local isDistracted = false
local distractionEndsAt = 0
local distractCooldownByUserId = {}

local currentPoint = 1
local currentState = State.PATROL
local stateStartTime = os.clock()
local patrolHoldUntil = 0
local activeTarget = nil
local lastSeenPos = nil
local returnTargetIndex = nil
local nextSuspicionTick = 0
local moveGoal = nil
local moveStartedAt = 0
local moveSerial = 0

local function safeAlive(h)
    return h and h.Health > 0 and h.Parent
end

local function clearMoveGoal()
    moveGoal = nil
    moveStartedAt = 0
    moveSerial = moveSerial + 1
end

local function issueMoveTo(position)
    if not position then
        return
    end

    if not moveGoal or (moveGoal - position).Magnitude > MOVE_TARGET_EPSILON then
        moveSerial = moveSerial + 1
        HUMANOID:MoveTo(position)
        moveGoal = position
        moveStartedAt = os.clock()
    end
end

local function clearActiveTarget(flushPending)
    if flushPending and activeTarget then
        flushSuspicion(activeTarget)
    end

    activeTarget = nil
    nextSuspicionTick = 0
end

local function setState(nextState)
    currentState = nextState
    stateStartTime = os.clock()
    clearMoveGoal()
end

local function showSpeechBubble(text)
    GuardDialogueRemote:FireAllClients(RIG, text)
end

local function sayRandomLine(lines)
    if not lines or #lines == 0 then
        return
    end

    showSpeechBubble(lines[math.random(1, #lines)])
end

local function startPatrol(holdDuration)
    clearActiveTarget(true)
    lastSeenPos = nil
    returnTargetIndex = nil
    patrolHoldUntil = (holdDuration and holdDuration > 0) and (os.clock() + holdDuration) or 0
    HUMANOID.WalkSpeed = PATROL_SPEED
    setState(State.PATROL)
end

local function startChase(player, playerRoot)
    activeTarget = player
    lastSeenPos = playerRoot and playerRoot.Position or lastSeenPos
    nextSuspicionTick = 0
    HUMANOID.WalkSpeed = CHASE_SPEED
    playWalk()
    setState(State.CHASE)
    sayRandomLine(CHASE_LINES)
end

local function startSearch()
    clearActiveTarget(true)
    HUMANOID.WalkSpeed = CHASE_SPEED
    setState(State.SEARCH)
end

local function startReturn()
    clearActiveTarget(true)
    returnTargetIndex = nil
    HUMANOID.WalkSpeed = PATROL_SPEED
    playWalk()
    setState(State.RETURN)
    sayRandomLine(GIVE_UP_LINES)
end

local function beginDistraction()
    if isDistracted then
        return
    end

    isDistracted = true
    distractionEndsAt = os.clock() + DISTRACT_DURATION
    startPatrol(0)
    lastSeenPos = nil

    HUMANOID.WalkSpeed = 0
    HUMANOID:Move(Vector3.zero, false)
    HUMANOID:MoveTo(HRP.Position)

    stopWalk()

    if PhoneTrack then
        if PhoneTrack.IsPlaying then
            PhoneTrack:Stop()
        end

        PhoneTrack:Play(0.1, 1, 1)

        task.spawn(function()
            local freezeAfter = 0.35
            if PhoneTrack.Length and PhoneTrack.Length > 0 then
                freezeAfter = math.min(PhoneTrack.Length * 0.45, 0.6)
            end

            task.wait(freezeAfter)

            if isDistracted and PhoneTrack.IsPlaying then
                PhoneTrack:AdjustSpeed(0)
            end
        end)
    end

    local bubbleText = DISTRACT_LINES[math.random(1, #DISTRACT_LINES)]
    showSpeechBubble(bubbleText)

    task.delay(DISTRACT_DURATION, function()
        if PhoneTrack and PhoneTrack.IsPlaying then
            PhoneTrack:Stop()
            PhoneTrack.TimePosition = 0
        end

        isDistracted = false
        distractionEndsAt = 0
        HUMANOID.WalkSpeed = PATROL_SPEED
    end)
end

local function canRequestDistraction(player)
    if not player or player.Parent ~= Players then
        return false, "Invalid player request."
    end

    local hasEquippedTablet = player:GetAttribute("HackTabletEquipped") == true
    if not hasEquippedTablet then
        local character = player.Character
        local equippedTool = character and character:FindFirstChildOfClass("Tool")
        hasEquippedTablet = equippedTool ~= nil and equippedTool.Name == HACK_TABLET_NAME
    end

    if not hasEquippedTablet then
        return false, "Equip the HackTablet before requesting a guard distraction."
    end

    if isDistracted then
        return false, "Guard is already distracted."
    end

    local character = player.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not playerRoot or (playerRoot.Position - HRP.Position).Magnitude > DISTRACT_MAX_RANGE then
        return false, "Move closer to the outside guard before sending the distraction."
    end

    local now = os.clock()
    local lastRequestedAt = distractCooldownByUserId[player.UserId] or 0
    if now - lastRequestedAt < DISTRACT_COOLDOWN then
        local remaining = math.ceil(DISTRACT_COOLDOWN - (now - lastRequestedAt))
        return false, string.format("Guard distraction is cooling down (%ds remaining).", math.max(remaining, 1))
    end

    distractCooldownByUserId[player.UserId] = now
    return true, "Outside guard distracted for 15 seconds."
end

DistractRemote.OnServerInvoke = function(player)
    local ok, message = canRequestDistraction(player)
    if not ok then
        return {
            success = false,
            message = message,
        }
    end

    beginDistraction()

    return {
        success = true,
        message = message,
        duration = DISTRACT_DURATION,
    }
end

Players.PlayerRemoving:Connect(function(player)
    distractCooldownByUserId[player.UserId] = nil
end)

-- === PATROL POINTS ===
local PatrolFolder = RIG:FindFirstChild("PatrolPoints") or GUARD:FindFirstChild("PatrolPoints")
local Waypoints = {}
if PatrolFolder then
    for _, part in ipairs(PatrolFolder:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(Waypoints, part)
        end
    end

    table.sort(Waypoints, function(a, b)
        local na = tonumber(a.Name:match("%d+")) or math.huge
        local nb = tonumber(b.Name:match("%d+")) or math.huge
        return na < nb
    end)
end

local function canSeePlayer(playerHRP)
    if not HRP or not playerHRP then
        return false
    end

    local eyePosition = HRP.Position + Vector3.new(0, 1.5, 0)
    local targetPosition = playerHRP.Position + Vector3.new(0, 1.5, 0)

    local diff = targetPosition - eyePosition
    local dist = diff.Magnitude
    if dist > VISION_RANGE then
        return false
    end

    local dir = diff.Unit
    if HRP.CFrame.LookVector:Dot(dir) < VISION_ANGLE then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { GUARD }

    local ray = Workspace:Raycast(eyePosition, dir * dist, params)
    if not ray then
        return true
    end

    local hitModel = ray.Instance and ray.Instance:FindFirstAncestorOfClass("Model")
    return hitModel and hitModel == playerHRP.Parent
end

local function findTarget()
    local nearestPlayer, nearestHRP, minDist = nil, nil, VISION_RANGE + 1

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if hrp and safeAlive(hum) then
            local dist = (hrp.Position - HRP.Position).Magnitude
            if dist < minDist and canSeePlayer(hrp) then
                minDist = dist
                nearestPlayer = player
                nearestHRP = hrp
            end
        end
    end

    return nearestPlayer, nearestHRP
end

local function getNearestWaypointIndex(position)
    if #Waypoints == 0 then
        return nil
    end

    local nearestIndex = 1
    local nearestDistance = math.huge

    for index, waypoint in ipairs(Waypoints) do
        local distance = (waypoint.Position - position).Magnitude
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = index
        end
    end

    return nearestIndex
end

local function updatePatrolState(now, visiblePlayer, visibleHRP)
    if visiblePlayer and visibleHRP then
        startChase(visiblePlayer, visibleHRP)
        return
    end

    if #Waypoints == 0 then
        stopWalk()
        clearMoveGoal()
        return
    end

    if patrolHoldUntil > now then
        stopWalk()
        clearMoveGoal()
        return
    end

    local point = Waypoints[currentPoint]
    if not point then
        stopWalk()
        clearMoveGoal()
        return
    end

    local timedOut = moveStartedAt > 0 and now - moveStartedAt > MOVE_TIMEOUT
    if timedOut then
        clearMoveGoal()
        currentPoint = (currentPoint % #Waypoints) + 1

        local nextPoint = Waypoints[currentPoint]
        if nextPoint then
            HUMANOID.WalkSpeed = PATROL_SPEED
            playWalk()
            issueMoveTo(nextPoint.Position)
        end
        return
    end

    HUMANOID.WalkSpeed = PATROL_SPEED
    playWalk()
    issueMoveTo(point.Position)
end

local function updateChaseState(now)
    local target = activeTarget
    local char = target and target.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local targetHRP = char and char:FindFirstChild("HumanoidRootPart")

    if not target or not targetHRP or not safeAlive(hum) then
        startSearch()
        return
    end

    if (HRP.Position - targetHRP.Position).Magnitude <= CAPTURE_DISTANCE then
        stopWalk()
        clearMoveGoal()
        startPatrol(0)
        return
    end

    if not canSeePlayer(targetHRP) then
        lastSeenPos = lastSeenPos or targetHRP.Position
        startSearch()
        return
    end

    -- Player is visible: refresh the chase timer so the guard keeps pursuing
    -- as long as it can see the player. The timeout only acts as a safety
    -- valve for edge cases where sight is maintained for an unusually long time.
    stateStartTime = now

    lastSeenPos = targetHRP.Position
    HUMANOID.WalkSpeed = CHASE_SPEED
    playWalk()
    issueMoveTo(targetHRP.Position)

    if now >= nextSuspicionTick then
        queueSuspicion(target, SUSPICION_PER_TICK)
        nextSuspicionTick = now + SUSPICION_TICK_RATE
    end
end

local function updateSearchState(now, visiblePlayer, visibleHRP)
    if visiblePlayer and visibleHRP then
        startChase(visiblePlayer, visibleHRP)
        return
    end

    if now - stateStartTime > SEARCH_DURATION then
        startReturn()
        return
    end

    HUMANOID.WalkSpeed = CHASE_SPEED
    if lastSeenPos and (HRP.Position - lastSeenPos).Magnitude > RETURN_REACHED_DISTANCE then
        playWalk()
        issueMoveTo(lastSeenPos)
        return
    end

    stopWalk()
    clearMoveGoal()
    HRP.CFrame = HRP.CFrame * CFrame.Angles(0, SEARCH_ROTATION_STEP, 0)
end

local function updateReturnState(now)
    if #Waypoints == 0 then
        startPatrol(0)
        return
    end

    if not returnTargetIndex or not Waypoints[returnTargetIndex] then
        returnTargetIndex = getNearestWaypointIndex(HRP.Position)
    end

    local point = returnTargetIndex and Waypoints[returnTargetIndex] or nil
    if not point then
        startPatrol(0)
        return
    end

    local timedOut = (now - stateStartTime > MOVE_TIMEOUT) or (moveStartedAt > 0 and now - moveStartedAt > MOVE_TIMEOUT)
    if timedOut then
        stopWalk()
        clearMoveGoal()
        currentPoint = returnTargetIndex
        startPatrol(0)
        return
    end

    HUMANOID.WalkSpeed = PATROL_SPEED
    playWalk()
    issueMoveTo(point.Position)
end

HUMANOID.MoveToFinished:Connect(function(reached)
    if not reached then
        return
    end

    if currentState == State.PATROL and #Waypoints > 0 then
        clearMoveGoal()
        currentPoint = (currentPoint % #Waypoints) + 1
        local nextPoint = Waypoints[currentPoint]
        if nextPoint then
            HUMANOID.WalkSpeed = PATROL_SPEED
            playWalk()
            issueMoveTo(nextPoint.Position)
        end
        return
    end

    if currentState == State.RETURN and returnTargetIndex and #Waypoints > 0 then
        clearMoveGoal()
        currentPoint = (returnTargetIndex % #Waypoints) + 1
        startPatrol(0)
        return
    end
end)

task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        if isDistracted then
            HUMANOID.WalkSpeed = 0
            HUMANOID:Move(Vector3.zero, false)
            stopWalk()
            clearMoveGoal()
        else
            local now = os.clock()
            local visiblePlayer, visibleHRP = findTarget()

            if currentState == State.PATROL then
                updatePatrolState(now, visiblePlayer, visibleHRP)
            elseif currentState == State.CHASE then
                updateChaseState(now)
            elseif currentState == State.SEARCH then
                updateSearchState(now, visiblePlayer, visibleHRP)
            elseif currentState == State.RETURN then
                updateReturnState(now)
            end
        end
    end
end)
