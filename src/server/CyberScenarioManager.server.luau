-- CyberScenarioManager.server.luau

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))
local SuspicionManager = require(Shared:WaitForChild("SuspicionManager"))
local KeycardCopier = require(ServerScriptService:WaitForChild("Server"):WaitForChild("KeycardCopier"))

local MISTAKE_SUSPICION = 2
local PROGRESS_STORE = DataStoreService:GetDataStore("PlayerProgress_v1")
local MAX_SUSPICION = 100
local MAX_TIMES_LEAKED = 999
local MAX_TEXT_INPUT_LENGTH = 256
local MAX_SAVE_TIMESTAMP = 4102444800
local MAX_TIMER_ELAPSED = 60 * 60 * 24
local POSITION_COMPONENT_LIMIT = 100000
local SAVE_ATTRIBUTE_KEYS = {
    "CurrentChapter",
    "RecoveredAdminCredentials",
    "TimesLeaked",
    "Suspicion",
}
local RESTORE_STATE_ATTRIBUTE = "HackTabletRestoreBlob"
local RUNTIME_RESET_ATTRIBUTES = {
    [RESTORE_STATE_ATTRIBUTE] = nil,
    ["Obj_Admin"] = nil,
    ["HasKeycardData"] = nil,
    ["UnlockedSlidingDoor"] = nil,
    ["HasSpokenToAgentRay"] = nil,
    ["WannaWailActive"] = false,
    ["WannaWailInfectedCount"] = 0,
    ["WannaWailLastMachine"] = "",
    ["WannaWailSourceBlocked"] = false,
    ["WannaWailFirewallRuleAdded"] = false,
    ["WannaWailProcessKilled"] = false,
    ["WannaWailLoaderRemoved"] = false,
    ["WannaWailContained"] = false,
}
local REMOTE_COOLDOWNS = {
    LoadScenario = 0.25,
    CheckSolution = 0.08,
    GetHint = 0.1,
    GetSessionInfo = 0.1,
    SaveProgress = 3,
    LoadSavedProgress = 2,
    GetSavedProgressStatus = 0.5,
    ClearSavedProgress = 1,
    StartOverProgress = 1,
    Cleanup = 0.5,
}

local fallbackProgressCache = {}
local remoteCooldowns = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local LoadScenarioRemote = remotesFolder:FindFirstChild("LoadScenario")
if not LoadScenarioRemote then
    LoadScenarioRemote = Instance.new("RemoteFunction")
    LoadScenarioRemote.Name = "LoadScenario"
    LoadScenarioRemote.Parent = remotesFolder
end

local CheckSolutionRemote = remotesFolder:FindFirstChild("CheckSolution")
if not CheckSolutionRemote then
    CheckSolutionRemote = Instance.new("RemoteFunction")
    CheckSolutionRemote.Name = "CheckSolution"
    CheckSolutionRemote.Parent = remotesFolder
end

local GetHintRemote = remotesFolder:FindFirstChild("GetHint")
if not GetHintRemote then
    GetHintRemote = Instance.new("RemoteFunction")
    GetHintRemote.Name = "GetHint"
    GetHintRemote.Parent = remotesFolder
end

local GetSessionInfoRemote = remotesFolder:FindFirstChild("GetSessionInfo")
if not GetSessionInfoRemote then
    GetSessionInfoRemote = Instance.new("RemoteFunction")
    GetSessionInfoRemote.Name = "GetSessionInfo"
    GetSessionInfoRemote.Parent = remotesFolder
end

local CleanupRemote = remotesFolder:FindFirstChild("Cleanup")
if not CleanupRemote then
    CleanupRemote = Instance.new("RemoteEvent")
    CleanupRemote.Name = "Cleanup"
    CleanupRemote.Parent = remotesFolder
end

local SaveProgressRemote = remotesFolder:FindFirstChild("SaveProgress")
if not SaveProgressRemote then
    SaveProgressRemote = Instance.new("RemoteFunction")
    SaveProgressRemote.Name = "SaveProgress"
    SaveProgressRemote.Parent = remotesFolder
end

local LoadSavedProgressRemote = remotesFolder:FindFirstChild("LoadSavedProgress")
if not LoadSavedProgressRemote then
    LoadSavedProgressRemote = Instance.new("RemoteFunction")
    LoadSavedProgressRemote.Name = "LoadSavedProgress"
    LoadSavedProgressRemote.Parent = remotesFolder
end

local GetSavedProgressStatusRemote = remotesFolder:FindFirstChild("GetSavedProgressStatus")
if not GetSavedProgressStatusRemote then
    GetSavedProgressStatusRemote = Instance.new("RemoteFunction")
    GetSavedProgressStatusRemote.Name = "GetSavedProgressStatus"
    GetSavedProgressStatusRemote.Parent = remotesFolder
end

local ClearSavedProgressRemote = remotesFolder:FindFirstChild("ClearSavedProgress")
if not ClearSavedProgressRemote then
    ClearSavedProgressRemote = Instance.new("RemoteFunction")
    ClearSavedProgressRemote.Name = "ClearSavedProgress"
    ClearSavedProgressRemote.Parent = remotesFolder
end

local StartOverProgressRemote = remotesFolder:FindFirstChild("StartOverProgress")
if not StartOverProgressRemote then
    StartOverProgressRemote = Instance.new("RemoteFunction")
    StartOverProgressRemote.Name = "StartOverProgress"
    StartOverProgressRemote.Parent = remotesFolder
end

local function isFiniteNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    return n
end

local function sanitizeInteger(value, minimum, maximum, defaultValue)
    local n = isFiniteNumber(value)
    if not n then
        return defaultValue
    end

    n = math.floor(n)
    if minimum ~= nil and n < minimum then
        n = minimum
    end
    if maximum ~= nil and n > maximum then
        n = maximum
    end

    return n
end

local function sanitizeTimerElapsed(value)
    local n = isFiniteNumber(value)
    if not n or n < 0 then
        return 0
    end

    return math.floor(math.min(n, MAX_TIMER_ELAPSED) * 100 + 0.5) / 100
end

local function sanitizeBoolean(value)
    return value == true
end

local function sanitizeScenarioProgressSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {
            activeSession = nil,
            completedScenarios = {},
        }
    end

    local activeSession = nil
    if type(snapshot.activeSession) == "table" then
        activeSession = {
            scenarioId = type(snapshot.activeSession.scenarioId) == "string" and snapshot.activeSession.scenarioId or nil,
            currentStep = sanitizeInteger(snapshot.activeSession.currentStep, 1, 1000, 1),
            startTime = sanitizeInteger(snapshot.activeSession.startTime, 0, MAX_SAVE_TIMESTAMP, os.time()),
            stepState = type(snapshot.activeSession.stepState) == "table" and snapshot.activeSession.stepState or {},
        }
    end

    return {
        activeSession = activeSession,
        completedScenarios = type(snapshot.completedScenarios) == "table" and snapshot.completedScenarios or {},
    }
end

local function sanitizeSavedPosition(savedPosition)
    if type(savedPosition) ~= "table" or #savedPosition ~= 12 then
        return nil
    end

    local sanitized = table.create(12)
    for index = 1, 12 do
        local component = isFiniteNumber(savedPosition[index])
        if not component or math.abs(component) > POSITION_COMPONENT_LIMIT then
            return nil
        end
        sanitized[index] = component
    end

    return sanitized
end

local function extractChapterNumber(scenarioId)
    local chapterNumber = tostring(scenarioId or ""):match("Chapter(%d+)")
    return tonumber(chapterNumber)
end

local function buildSaveKey(player)
    return ("player_%d_progress"):format(player.UserId)
end

local function withinCooldown(player, remoteName)
    remoteCooldowns[player.UserId] = remoteCooldowns[player.UserId] or {}
    local now = os.clock()
    local cooldown = REMOTE_COOLDOWNS[remoteName] or 0
    local last = remoteCooldowns[player.UserId][remoteName] or 0
    if now - last < cooldown then
        return false
    end

    remoteCooldowns[player.UserId][remoteName] = now
    return true
end

local function sanitizeAttributeValue(attributeName, value)
    if attributeName == "CurrentChapter" then
        return sanitizeInteger(value, 1, 4, 1)
    end

    if attributeName == "TimesLeaked" then
        return sanitizeInteger(value, 0, MAX_TIMES_LEAKED, 0)
    end

    if attributeName == "Suspicion" then
        return sanitizeInteger(value, 0, MAX_SUSPICION, 0)
    end

    return sanitizeBoolean(value)
end

local function captureTrustedAttributes(player, scenarioProgress)
    local attributes = {}
    local currentChapter = sanitizeInteger(player:GetAttribute("CurrentChapter"), 1, 4, 1)
    local activeScenarioId = type(scenarioProgress) == "table"
        and type(scenarioProgress.activeSession) == "table"
        and scenarioProgress.activeSession.scenarioId
        or nil
    local activeChapter = extractChapterNumber(activeScenarioId)
    if activeChapter then
        currentChapter = activeChapter
    end

    attributes.CurrentChapter = currentChapter
    attributes.RecoveredAdminCredentials = sanitizeBoolean(player:GetAttribute("RecoveredAdminCredentials"))
    attributes.TimesLeaked = sanitizeInteger(player:GetAttribute("TimesLeaked"), 0, MAX_TIMES_LEAKED, 0)
    -- Save only server-owned progression flags here. Client-facing admin and door flags are ignored.
    attributes.Suspicion = sanitizeInteger(SuspicionManager.Get(player), 0, MAX_SUSPICION, 0)
    return attributes
end

local function applyPlayerAttributes(player, saved)
    saved = type(saved) == "table" and saved or {}

    for _, attributeName in ipairs(SAVE_ATTRIBUTE_KEYS) do
        local value = sanitizeAttributeValue(attributeName, saved[attributeName])
        if attributeName == "Suspicion" then
            SuspicionManager.Set(value, player)
        else
            player:SetAttribute(attributeName, value)
        end
    end
end

local function capturePlayerPosition(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local components = { root.CFrame:GetComponents() }
    return sanitizeSavedPosition(components)
end

local function applyPlayerPosition(player, savedPosition)
    local sanitizedPosition = sanitizeSavedPosition(savedPosition)
    if not sanitizedPosition then
        return
    end

    local function moveCharacter(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return false
        end

        root.CFrame = CFrame.new(table.unpack(sanitizedPosition))
        return true
    end

    if moveCharacter(player.Character) then
        return
    end

    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        task.wait()
        moveCharacter(character)
    end)
end

local function sanitizeSavedPayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    return {
        version = sanitizeInteger(payload.version, 1, 10, 2),
        savedAt = sanitizeInteger(payload.savedAt, 0, MAX_SAVE_TIMESTAMP, 0),
        timerElapsed = sanitizeTimerElapsed(payload.timerElapsed),
        attributes = type(payload.attributes) == "table" and payload.attributes or {},
        scenarioProgress = sanitizeScenarioProgressSnapshot(payload.scenarioProgress),
        position = sanitizeSavedPosition(payload.position),
    }
end

local function readSavedProgress(player)
    local fallback = sanitizeSavedPayload(fallbackProgressCache[player.UserId])
    local key = buildSaveKey(player)
    local ok, payload = pcall(function()
        return PROGRESS_STORE:GetAsync(key)
    end)

    if ok then
        local sanitizedPayload = sanitizeSavedPayload(payload)
        if sanitizedPayload then
            -- Prefer the freshest trusted snapshot so Continue works immediately after a save.
            if fallback and (fallback.savedAt or 0) > (sanitizedPayload.savedAt or 0) then
                fallbackProgressCache[player.UserId] = fallback
                return fallback, true
            end

            fallbackProgressCache[player.UserId] = sanitizedPayload
            return sanitizedPayload, true
        end
    end

    if fallback then
        fallbackProgressCache[player.UserId] = fallback
        return fallback, false
    end

    return nil, ok
end

local function writeSavedProgress(player, payload)
    local trustedPayload = sanitizeSavedPayload(payload)
    if not trustedPayload then
        return false, "Invalid save payload."
    end

    local key = buildSaveKey(player)
    local ok, result = pcall(function()
        return PROGRESS_STORE:UpdateAsync(key, function(existingPayload)
            local sanitizedExisting = sanitizeSavedPayload(existingPayload)
            if sanitizedExisting and sanitizedExisting.savedAt > trustedPayload.savedAt then
                return sanitizedExisting
            end
            return trustedPayload
        end)
    end)

    if not ok then
        fallbackProgressCache[player.UserId] = trustedPayload
        return false, result
    end

    local sanitizedResult = sanitizeSavedPayload(result) or trustedPayload
    fallbackProgressCache[player.UserId] = sanitizedResult
    return true, sanitizedResult
end

local function clearSavedProgress(player)
    fallbackProgressCache[player.UserId] = nil

    local ok, err = pcall(function()
        PROGRESS_STORE:RemoveAsync(buildSaveKey(player))
    end)

    return ok, err
end

local function resetRuntimeState(player)
    applyPlayerAttributes(player, {})
    KeycardCopier.resetAccess(player)

    for attributeName, value in pairs(RUNTIME_RESET_ATTRIBUTES) do
        player:SetAttribute(attributeName, value)
    end

    CyberScenarioManager.ResetProgress(player)
    if _G.MissionController and _G.MissionController.ResetMission then
        _G.MissionController.ResetMission(player)
    end
end

local function getMissionTimer()
    local deadline = os.clock() + 5
    while os.clock() < deadline do
        if _G.MissionTimer then
            return _G.MissionTimer
        end
        task.wait(0.1)
    end

    return nil
end

local function isRunActive(player)
    local missionTimer = _G.MissionTimer
    if missionTimer and missionTimer.isMissionActive and missionTimer.isMissionActive(player) then
        return true
    end

    return CyberScenarioManager.GetSessionInfo(player) ~= nil
end

local function sanitizeSolutionInput(input)
    if type(input) ~= "string" then
        return nil
    end

    local trimmed = input:match("^%s*(.-)%s*$")
    if trimmed == "" or #trimmed > MAX_TEXT_INPUT_LENGTH or trimmed:find("%c") then
        return nil
    end

    return trimmed
end

LoadScenarioRemote.OnServerInvoke = function(player, scenarioId)
    if not withinCooldown(player, "LoadScenario") then
        return nil, "Please wait a moment before starting another chapter."
    end

    local safeScenarioId, validationError = CyberScenarioManager.CanLoadScenario(player, scenarioId)
    if not safeScenarioId then
        return nil, validationError or "Invalid chapter request."
    end

    local result, err = CyberScenarioManager.LoadScenario(player, safeScenarioId)
    if type(result) == "table" then
        local missionTimer = getMissionTimer()
        if missionTimer and missionTimer.startMission then
            missionTimer.startMission(player)
        end
    end

    local chapterNumber = extractChapterNumber(safeScenarioId)
    if chapterNumber then
        player:SetAttribute("CurrentChapter", chapterNumber)
    end
    return result, err
end

CheckSolutionRemote.OnServerInvoke = function(player, input)
    if not withinCooldown(player, "CheckSolution") then
        return {
            success = false,
            output = "[!] Slow down and try again.",
            feedback = "Please wait a moment.",
        }
    end

    local safeInput = sanitizeSolutionInput(input)
    if not safeInput then
        return {
            success = false,
            output = "[!] Invalid request.",
            feedback = "Invalid input.",
        }
    end

    local result = CyberScenarioManager.CheckSolution(player, safeInput)

    if type(result) == "table" and result.lessonId then
        local popupSent = LessonManager.TriggerMistake(player, result.lessonId, {
            throttleKey = result.popupThrottleKey or result.lessonId,
            throttleWindow = result.popupThrottleWindow or 2,
        })

        if popupSent then
            SuspicionManager.Add(MISTAKE_SUSPICION, player)
        end
    elseif type(result) == "table" and result.popupTitle and result.popupMessage then
        local notificationSent = LessonManager.TriggerNotification(player, result.popupTitle, result.popupMessage, {
            throttleKey = result.popupThrottleKey,
            throttleWindow = result.popupThrottleWindow,
            duration = 3,
        })

        if notificationSent then
            -- Suspicion follows the same server-side notification throttle path.
            SuspicionManager.Add(MISTAKE_SUSPICION, player)
        end
    end

    if type(result) == "table"
        and result.success == true
        and result.chapterComplete == true
        and result.completedScenarioId == "Chapter4_IncidentResponse"
        and _G.MissionTimer
        and _G.MissionTimer.completeMission
    then
        -- Only a verified Chapter 4 completion should finalize the timed run.
        _G.MissionTimer.completeMission(player)
    end

    return result
end

GetHintRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "GetHint") then
        return "[!] Please wait a moment before requesting another hint."
    end

    return CyberScenarioManager.GetHint(player)
end

GetSessionInfoRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "GetSessionInfo") then
        return CyberScenarioManager.GetSessionInfo(player)
    end

    return CyberScenarioManager.GetSessionInfo(player)
end

SaveProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "SaveProgress") then
        return {
            success = false,
            persistent = false,
            message = "Please wait before saving again.",
        }
    end

    local trustedScenarioProgress = CyberScenarioManager.ExportProgress(player)
    local missionTimer = getMissionTimer()
    local timerElapsed = 0
    if missionTimer and missionTimer.getElapsed then
        timerElapsed = sanitizeTimerElapsed(missionTimer.getElapsed(player))
    end

    local payload = {
        version = 2,
        savedAt = os.time(),
        timerElapsed = timerElapsed,
        attributes = captureTrustedAttributes(player, trustedScenarioProgress),
        scenarioProgress = trustedScenarioProgress,
        position = capturePlayerPosition(player),
    }

    local persistent, resultOrError = writeSavedProgress(player, payload)
    local hasSavedProgress = persistent == true or fallbackProgressCache[player.UserId] ~= nil
    player:SetAttribute("HasSavedProgress", hasSavedProgress)
    local message
    if persistent then
        message = "Progress saved."
    else
        message = "Progress saved for this session only."
    end

    local warning = nil
    if not persistent then
        warning = tostring(resultOrError)
    end

    return {
        success = true,
        persistent = persistent,
        message = message,
        warning = warning,
    }
end

LoadSavedProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "LoadSavedProgress") then
        return {
            success = false,
            message = "Please wait before loading again.",
        }
    end

    if isRunActive(player) then
        return {
            success = false,
            message = "Saved progress can only be loaded from the start menu.",
        }
    end

    local payload = readSavedProgress(player)
    if type(payload) ~= "table" then
        return {
            success = false,
            message = "No saved progress found.",
        }
    end

    applyPlayerAttributes(player, payload.attributes)
    local sessionInfo = CyberScenarioManager.ImportProgress(player, payload.scenarioProgress)
    applyPlayerPosition(player, payload.position)
    player:SetAttribute("HasSavedProgress", true)
    if sessionInfo then
        local missionTimer = getMissionTimer()
        if missionTimer and missionTimer.startMission then
            missionTimer.startMission(player, payload.timerElapsed)
        end
    end

    return {
        success = true,
        message = "Saved progress loaded.",
        sessionInfo = sessionInfo,
        timerElapsed = payload.timerElapsed,
        savedAt = payload.savedAt,
    }
end

GetSavedProgressStatusRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "GetSavedProgressStatus") then
        local fallback = sanitizeSavedPayload(fallbackProgressCache[player.UserId])
        local hasFallback = type(fallback) == "table"
        return {
            success = true,
            hasSave = hasFallback,
            message = hasFallback and "Saved progress available." or "No saved progress found.",
        }
    end

    local payload = readSavedProgress(player)
    local hasSave = type(payload) == "table" or player:GetAttribute("HasSavedProgress") == true
    player:SetAttribute("HasSavedProgress", hasSave)

    return {
        success = true,
        hasSave = hasSave,
        message = hasSave and "Saved progress available." or "No saved progress found.",
    }
end

ClearSavedProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "ClearSavedProgress") then
        return {
            success = false,
            persistent = false,
            message = "Please wait before clearing the save again.",
        }
    end

    local persistent, err = clearSavedProgress(player)
    player:SetAttribute("HasSavedProgress", false)

    local message
    if persistent then
        message = "Saved progress cleared."
    else
        message = "Saved progress cleared for this session only."
    end

    local warning = nil
    if not persistent then
        warning = tostring(err)
    end

    return {
        success = true,
        persistent = persistent,
        message = message,
        warning = warning,
    }
end

StartOverProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "StartOverProgress") then
        return {
            success = false,
            persistent = false,
            message = "Please wait before starting over again.",
        }
    end

    if isRunActive(player) then
        return {
            success = false,
            persistent = false,
            message = "Start Over is disabled during an active mission.",
        }
    end

    local persistent, err = clearSavedProgress(player)
    resetRuntimeState(player)
    player:SetAttribute("HasSavedProgress", false)

    local message
    if persistent then
        message = "Progress reset."
    else
        message = "Progress reset for this session."
    end

    local warning = nil
    if not persistent then
        warning = tostring(err)
    end

    return {
        success = true,
        persistent = persistent,
        message = message,
        warning = warning,
    }
end

CleanupRemote.OnServerEvent:Connect(function(player)
    if not withinCooldown(player, "Cleanup") then
        return
    end

    local missionTimer = getMissionTimer()
    if missionTimer and missionTimer.isMissionActive and missionTimer.isMissionActive(player) then
        if missionTimer.resetMission then
            missionTimer.resetMission(player)
        elseif missionTimer.endMission then
            missionTimer.endMission(player, "reset")
        end
    end

    CyberScenarioManager.Cleanup(player)
end)

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("HasSavedProgress", false)
end)

Players.PlayerRemoving:Connect(function(player)
    CyberScenarioManager.Cleanup(player)
    fallbackProgressCache[player.UserId] = nil
    remoteCooldowns[player.UserId] = nil
end)
