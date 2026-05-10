-- CyberScenarioManager.server.luau

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))
local SuspicionManager = require(Shared:WaitForChild("SuspicionManager"))
local KeycardCopier = require(ServerScriptService:WaitForChild("Server"):WaitForChild("KeycardCopier"))

local MISTAKE_SUSPICION = 2
local PROGRESS_STORE_NAME = "PlayerProgress_v2"
local PROGRESS_STORE = DataStoreService:GetDataStore(PROGRESS_STORE_NAME)
local MAX_SUSPICION = 100
local MAX_TIMES_LEAKED = 999
local MAX_TEXT_INPUT_LENGTH = 256
local MAX_CLIENT_STATE_JSON_LENGTH = 20000
local MAX_SAVE_TIMESTAMP = 4102444800
local MAX_TIMER_ELAPSED = 60 * 60 * 24
local POSITION_COMPONENT_LIMIT = 100000
local SAVE_WRITE_ATTEMPTS = 3
local FINAL_SAVE_WRITE_ATTEMPTS = 5
local SAVE_WRITE_RETRY_BASE_DELAY = 0.35
local BACKGROUND_SAVE_RETRY_ATTEMPTS = 6
local BACKGROUND_SAVE_RETRY_DELAY = 5
local NEWS_CUTSCENE_STARTED_ATTRIBUTE = "NewsCutsceneStarted"
local NEWS_CUTSCENE_COMPLETED_ATTRIBUTE = "NewsCutsceneCompleted"
local PHONE_INTRO_COMPLETED_ATTRIBUTE = "PhoneIntroCallCompleted"
local SAVE_ATTRIBUTE_KEYS = {
    "CurrentChapter",
    "RecoveredAdminCredentials",
    PHONE_INTRO_COMPLETED_ATTRIBUTE,
    "HasSpokenToAgentRay",
    "AgentRayToolsReceived",
    "AgentRayDialogueSeen",
    "HasKeycardData",
    "UnlockedSlidingDoor",
    "TimesLeaked",
    "Suspicion",
}
local PROGRESSION_SAVE_ATTRIBUTE_SET = {
    RecoveredAdminCredentials = true,
    [PHONE_INTRO_COMPLETED_ATTRIBUTE] = true,
    HasSpokenToAgentRay = true,
    AgentRayToolsReceived = true,
    AgentRayDialogueSeen = true,
    HasKeycardData = true,
    UnlockedSlidingDoor = true,
}
local RESTORE_STATE_ATTRIBUTE = "HackTabletRestoreBlob"
local RUNTIME_RESET_ATTRIBUTES = {
    [RESTORE_STATE_ATTRIBUTE] = nil,
    ["Obj_Admin"] = nil,
    ["HasKeycardData"] = nil,
    ["UnlockedSlidingDoor"] = nil,
    ["HasSpokenToAgentRay"] = nil,
    ["AgentRayToolsReceived"] = nil,
    ["AgentRayDialogueSeen"] = nil,
    ["AgentRayDialogueActive"] = false,
    ["AgentRayDialogueComplete"] = false,
    ["WannaWailActive"] = false,
    ["WannaWailInfectedCount"] = 0,
    ["WannaWailLastMachine"] = "",
    ["WannaWailSourceBlocked"] = false,
    ["WannaWailFirewallRuleAdded"] = false,
    ["WannaWailProcessKilled"] = false,
    ["WannaWailLoaderRemoved"] = false,
    ["WannaWailContained"] = false,
    [NEWS_CUTSCENE_STARTED_ATTRIBUTE] = false,
    [NEWS_CUTSCENE_COMPLETED_ATTRIBUTE] = false,
    [PHONE_INTRO_COMPLETED_ATTRIBUTE] = false,
}
local REMOTE_COOLDOWNS = {
    LoadScenario = 0.25,
    CheckSolution = 0.08,
    GetHint = 0.1,
    GetSessionInfo = 0.1,
    SaveProgress = 3,
    FlushProgress = 0.5,
    ProgressSaved = 0.5,
    LoadSavedProgress = 2,
    GetSavedProgressStatus = 0.5,
    ClearSavedProgress = 1,
    StartOverProgress = 1,
    Cleanup = 0.5,
}

local fallbackProgressCache = {}
local pendingPersistentSaves = {}
local backgroundSaveRetryActive = {}
local progressAttributeSaveQueued = {}
local progressAttributeConnections = {}
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

local FlushProgressRemote = remotesFolder:FindFirstChild("FlushProgress")
if not FlushProgressRemote then
    FlushProgressRemote = Instance.new("RemoteFunction")
    FlushProgressRemote.Name = "FlushProgress"
    FlushProgressRemote.Parent = remotesFolder
end

local ProgressSavedRemote = remotesFolder:FindFirstChild("ProgressSaved")
if not ProgressSavedRemote then
    ProgressSavedRemote = Instance.new("RemoteEvent")
    ProgressSavedRemote.Name = "ProgressSaved"
    ProgressSavedRemote.Parent = remotesFolder
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

local function sanitizeClientState(clientState)
    if type(clientState) ~= "table" then
        return nil
    end

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(clientState)
    end)
    if not okEncode or type(encoded) ~= "string" or #encoded > MAX_CLIENT_STATE_JSON_LENGTH then
        return nil
    end

    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(encoded)
    end)
    if okDecode and type(decoded) == "table" then
        return decoded
    end

    return nil
end

local function extractChapterNumber(scenarioId)
    local chapterNumber = tostring(scenarioId or ""):match("Chapter(%d+)")
    return tonumber(chapterNumber)
end

local function buildSaveKey(player)
    return ("player_%d_progress"):format(player.UserId)
end

local function encodeForLog(value)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(value)
    end)

    if ok then
        return encoded
    end

    return tostring(value)
end

local function summarizeScenarioProgress(progress)
    progress = type(progress) == "table" and progress or {}
    local activeSession = type(progress.activeSession) == "table" and progress.activeSession or nil
    local completedIds = {}

    if type(progress.completedScenarios) == "table" then
        for scenarioId, completed in pairs(progress.completedScenarios) do
            if completed == true then
                table.insert(completedIds, tostring(scenarioId))
            end
        end
        table.sort(completedIds)
    end

    return {
        activeScenarioId = activeSession and activeSession.scenarioId or nil,
        currentStep = activeSession and activeSession.currentStep or nil,
        completedScenarios = completedIds,
    }
end

local function summarizeSavedPayload(payload)
    payload = type(payload) == "table" and payload or {}

    return {
        version = payload.version,
        savedAt = payload.savedAt,
        timerElapsed = payload.timerElapsed,
        attributes = payload.attributes,
        scenarioProgress = summarizeScenarioProgress(payload.scenarioProgress),
        hasPosition = type(payload.position) == "table",
        hasClientState = type(payload.clientState) == "table",
    }
end

local function logProgress(eventName, player, details)
    details = type(details) == "table" and details or {}
    details.userId = player and player.UserId or nil
    details.name = player and player.Name or nil

    print(("[ProgressPersistence] %s %s"):format(eventName, encodeForLog(details)))
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

local AGENT_TOOL_NAMES = {
    "HackTablet",
    "GhostKey",
}

local function hasAgentTool(player)
    if not player then
        return false
    end

    for _, container in ipairs({
        player.Character,
        player:FindFirstChildOfClass("Backpack"),
        player:FindFirstChild("StarterGear"),
    }) do
        if container then
            for _, toolName in ipairs(AGENT_TOOL_NAMES) do
                local tool = container:FindFirstChild(toolName)
                if tool and tool:IsA("Tool") then
                    return true
                end
            end
        end
    end

    return false
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
    attributes[PHONE_INTRO_COMPLETED_ATTRIBUTE] = sanitizeBoolean(player:GetAttribute(PHONE_INTRO_COMPLETED_ATTRIBUTE))
    local hasSavedAgentTools = hasAgentTool(player)
    attributes.HasSpokenToAgentRay = sanitizeBoolean(player:GetAttribute("HasSpokenToAgentRay")) or hasSavedAgentTools
    attributes.AgentRayToolsReceived = sanitizeBoolean(player:GetAttribute("AgentRayToolsReceived")) or hasSavedAgentTools
    attributes.AgentRayDialogueSeen = sanitizeBoolean(player:GetAttribute("AgentRayDialogueSeen"))
    attributes.HasKeycardData = KeycardCopier.hasKeycardData(player)
        or sanitizeBoolean(player:GetAttribute("HasKeycardData"))
    attributes.UnlockedSlidingDoor = KeycardCopier.hasSlidingDoorAccess(player)
        or sanitizeBoolean(player:GetAttribute("UnlockedSlidingDoor"))
    attributes.TimesLeaked = sanitizeInteger(player:GetAttribute("TimesLeaked"), 0, MAX_TIMES_LEAKED, 0)
    -- Save server-owned mission and inventory mirrors; client-only UI state is kept in clientState.
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

local function hasProgressionAttributes(attributes)
    if type(attributes) ~= "table" then
        return false
    end

    for attributeName in pairs(PROGRESSION_SAVE_ATTRIBUTE_SET) do
        if sanitizeBoolean(attributes[attributeName]) then
            return true
        end
    end

    return false
end

local function hasSaveablePayload(payload)
    if type(payload) ~= "table" then
        return false
    end

    if CyberScenarioManager.HasProgressSnapshot(payload.scenarioProgress) then
        return true
    end

    return hasProgressionAttributes(payload.attributes)
end

local function restoreKeycardProgressState(player)
    if player:GetAttribute("HasKeycardData") == true then
        KeycardCopier.syncLegacyKeycardData(player)
    else
        KeycardCopier.clearKeycardData(player)
    end

    if player:GetAttribute("UnlockedSlidingDoor") == true then
        KeycardCopier.syncLegacySlidingDoorAccess(player)
    else
        KeycardCopier.clearSlidingDoorAccess(player)
    end
end

local function verifyKeycardDataForContinue(player, payload)
    local savedAttributes = type(payload) == "table" and type(payload.attributes) == "table"
        and payload.attributes
        or {}
    local shouldHaveKeycardData = sanitizeBoolean(savedAttributes.HasKeycardData)
        or player:GetAttribute("HasKeycardData") == true
        or KeycardCopier.hasKeycardData(player)

    if shouldHaveKeycardData then
        player:SetAttribute("HasKeycardData", true)
        if not KeycardCopier.hasKeycardData(player) then
            KeycardCopier.syncLegacyKeycardData(player)
        end
    else
        KeycardCopier.clearKeycardData(player)
    end

    local shouldHaveSlidingDoorAccess = sanitizeBoolean(savedAttributes.UnlockedSlidingDoor)
        or player:GetAttribute("UnlockedSlidingDoor") == true
        or KeycardCopier.hasSlidingDoorAccess(player)

    if shouldHaveSlidingDoorAccess then
        player:SetAttribute("UnlockedSlidingDoor", true)
        if not KeycardCopier.hasSlidingDoorAccess(player) then
            KeycardCopier.syncLegacySlidingDoorAccess(player)
        end
    else
        KeycardCopier.clearSlidingDoorAccess(player)
    end

    return {
        hasKeycardData = KeycardCopier.hasKeycardData(player),
        unlockedSlidingDoor = KeycardCopier.hasSlidingDoorAccess(player),
    }
end

local function restoreAgentRayTools(player)
    if player:GetAttribute("HasSpokenToAgentRay") ~= true
        and player:GetAttribute("AgentRayToolsReceived") ~= true
    then
        return
    end

    task.spawn(function()
        local deadline = os.clock() + 5
        while player.Parent and os.clock() < deadline do
            local giver = _G.AgentRayToolGiver
            local grant = giver and (giver.EnsureTools or giver.GrantTools or giver.GiveTools)
            if typeof(grant) == "function" then
                local ok, err = pcall(grant, player)
                local errorMessage = nil
                if not ok then
                    errorMessage = tostring(err)
                end
                logProgress("tool_restore", player, {
                    key = buildSaveKey(player),
                    store = PROGRESS_STORE_NAME,
                    ok = ok,
                    error = errorMessage,
                    hasSpokenToAgentRay = player:GetAttribute("HasSpokenToAgentRay") == true,
                    agentRayToolsReceived = player:GetAttribute("AgentRayToolsReceived") == true,
                })
                return
            end

            task.wait(0.1)
        end

        logProgress("tool_restore_failed", player, {
            key = buildSaveKey(player),
            store = PROGRESS_STORE_NAME,
            error = "AgentRayToolGiver was not ready.",
        })
    end)
end

local function restorePersistentRuntimeState(player)
    restoreKeycardProgressState(player)
    restoreAgentRayTools(player)
end

local function skipNewsCutsceneForContinue(player)
    player:SetAttribute(PHONE_INTRO_COMPLETED_ATTRIBUTE, true)
    player:SetAttribute(NEWS_CUTSCENE_STARTED_ATTRIBUTE, false)
    player:SetAttribute(NEWS_CUTSCENE_COMPLETED_ATTRIBUTE, true)
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
        return false
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
        return true
    end

    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        task.wait()
        moveCharacter(character)
    end)

    return true
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
        clientState = sanitizeClientState(payload.clientState),
    }
end

local function readSavedProgress(player, reason)
    local fallback = sanitizeSavedPayload(fallbackProgressCache[player.UserId])
    local key = buildSaveKey(player)
    local ok, payload = pcall(function()
        return PROGRESS_STORE:GetAsync(key)
    end)
    local shouldLog = reason ~= "status"

    if ok then
        local sanitizedPayload = sanitizeSavedPayload(payload)
        if sanitizedPayload then
            -- Prefer the freshest trusted snapshot so Continue works immediately after a save.
            if fallback and (fallback.savedAt or 0) > (sanitizedPayload.savedAt or 0) then
                fallbackProgressCache[player.UserId] = fallback
                if shouldLog then
                    logProgress("load_payload_after_read", player, {
                        reason = reason,
                        key = key,
                        store = PROGRESS_STORE_NAME,
                        source = "fallback-newer-than-datastore",
                        payload = summarizeSavedPayload(fallback),
                    })
                end
                return fallback, true
            end

            fallbackProgressCache[player.UserId] = sanitizedPayload
            if shouldLog then
                logProgress("load_payload_after_read", player, {
                    reason = reason,
                    key = key,
                    store = PROGRESS_STORE_NAME,
                    source = "datastore",
                    payload = summarizeSavedPayload(sanitizedPayload),
                })
            end
            return sanitizedPayload, true
        end
    end

    if fallback then
        fallbackProgressCache[player.UserId] = fallback
        if shouldLog then
            logProgress("load_payload_after_read", player, {
                reason = reason,
                key = key,
                store = PROGRESS_STORE_NAME,
                source = "fallback",
                payload = summarizeSavedPayload(fallback),
            })
        end
        return fallback, false
    end

    if shouldLog then
        local readError = nil
        if not ok then
            readError = tostring(payload)
        end

        logProgress("load_payload_after_read", player, {
            reason = reason,
            key = key,
            store = PROGRESS_STORE_NAME,
            source = ok and "datastore-empty" or "datastore-error",
            error = readError,
            payload = nil,
        })
    end

    return nil, ok
end

local function writeTrustedPayloadOnce(key, trustedPayload)
    local ok, result = pcall(function()
        return PROGRESS_STORE:UpdateAsync(key, function(existingPayload)
            local sanitizedExisting = sanitizeSavedPayload(existingPayload)
            if sanitizedExisting and sanitizedExisting.savedAt > trustedPayload.savedAt then
                return sanitizedExisting
            end
            if trustedPayload.clientState == nil and sanitizedExisting and sanitizedExisting.clientState then
                trustedPayload.clientState = sanitizedExisting.clientState
            end
            return trustedPayload
        end)
    end)

    if not ok then
        return false, result
    end

    return true, sanitizeSavedPayload(result) or trustedPayload
end

local function writeTrustedPayloadWithRetries(player, key, trustedPayload, reason, attempts)
    local lastError = nil
    attempts = math.max(1, attempts or SAVE_WRITE_ATTEMPTS)

    for attempt = 1, attempts do
        local ok, result = writeTrustedPayloadOnce(key, trustedPayload)
        if ok then
            if attempt > 1 then
                logProgress("save_write_retry_succeeded", player, {
                    reason = reason,
                    key = key,
                    store = PROGRESS_STORE_NAME,
                    attempt = attempt,
                    payload = summarizeSavedPayload(result),
                })
            end
            return true, result
        end

        lastError = result
        logProgress("save_write_attempt_failed", player, {
            reason = reason,
            key = key,
            store = PROGRESS_STORE_NAME,
            attempt = attempt,
            error = tostring(result),
        })

        if attempt < attempts then
            task.wait(SAVE_WRITE_RETRY_BASE_DELAY * attempt)
        end
    end

    return false, lastError
end

local function fireProgressSaved(player, details)
    if not player or not player.Parent or not ProgressSavedRemote then
        return
    end

    details = type(details) == "table" and details or {}
    ProgressSavedRemote:FireClient(player, details)
end

local function startBackgroundSaveRetry(player, key, reason)
    if not player or backgroundSaveRetryActive[player.UserId] then
        return
    end

    backgroundSaveRetryActive[player.UserId] = true
    task.spawn(function()
        while player.Parent and pendingPersistentSaves[player.UserId] do
            task.wait(BACKGROUND_SAVE_RETRY_DELAY)

            local pending = sanitizeSavedPayload(pendingPersistentSaves[player.UserId])
            if not pending then
                pendingPersistentSaves[player.UserId] = nil
                break
            end

            for attempt = 1, BACKGROUND_SAVE_RETRY_ATTEMPTS do
                if not player.Parent then
                    break
                end

                local ok, result = writeTrustedPayloadOnce(key, pending)
                if ok then
                    local sanitizedResult = sanitizeSavedPayload(result) or pending
                    fallbackProgressCache[player.UserId] = sanitizedResult
                    pendingPersistentSaves[player.UserId] = nil
                    player:SetAttribute("HasSavedProgress", true)
                    logProgress("save_background_retry_succeeded", player, {
                        reason = reason,
                        key = key,
                        store = PROGRESS_STORE_NAME,
                        attempt = attempt,
                        payload = summarizeSavedPayload(sanitizedResult),
                    })
                    fireProgressSaved(player, {
                        success = true,
                        persistent = true,
                        syncStatus = "persistent",
                        reason = reason,
                        savedAt = sanitizedResult.savedAt,
                        message = "Progress saved.",
                    })
                    break
                end

                logProgress("save_background_retry_failed", player, {
                    reason = reason,
                    key = key,
                    store = PROGRESS_STORE_NAME,
                    attempt = attempt,
                    error = tostring(result),
                })

                task.wait(BACKGROUND_SAVE_RETRY_DELAY * attempt)
            end
        end

        backgroundSaveRetryActive[player.UserId] = nil
    end)
end

local function writeSavedProgress(player, payload, reason)
    local trustedPayload = sanitizeSavedPayload(payload)
    if not trustedPayload then
        return false, "Invalid save payload."
    end

    local key = buildSaveKey(player)
    local fallback = sanitizeSavedPayload(fallbackProgressCache[player.UserId])
    if trustedPayload.clientState == nil and fallback and fallback.clientState then
        trustedPayload.clientState = fallback.clientState
    end
    fallbackProgressCache[player.UserId] = trustedPayload

    logProgress("save_payload_before_write", player, {
        reason = reason,
        key = key,
        store = PROGRESS_STORE_NAME,
        payload = summarizeSavedPayload(trustedPayload),
    })

    local ok, result = writeTrustedPayloadWithRetries(player, key, trustedPayload, reason, SAVE_WRITE_ATTEMPTS)
    if not ok then
        pendingPersistentSaves[player.UserId] = trustedPayload
        startBackgroundSaveRetry(player, key, reason)
        return false, result
    end

    local sanitizedResult = sanitizeSavedPayload(result) or trustedPayload
    fallbackProgressCache[player.UserId] = sanitizedResult
    pendingPersistentSaves[player.UserId] = nil
    return true, sanitizedResult
end

local function clearSavedProgress(player)
    fallbackProgressCache[player.UserId] = nil
    pendingPersistentSaves[player.UserId] = nil

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

local function getMissionTimer(timeoutSeconds)
    if _G.MissionTimer then
        return _G.MissionTimer
    end

    local deadline = os.clock() + (timeoutSeconds or 5)
    while os.clock() < deadline do
        if _G.MissionTimer then
            return _G.MissionTimer
        end
        task.wait(0.1)
    end

    return nil
end

local function isPlayerInGame(player)
    return CyberScenarioManager.GetSessionInfo(player) ~= nil
end

local function isMissionTimerRunning(player)
    local missionTimer = _G.MissionTimer
    if missionTimer and missionTimer.isMissionActive and missionTimer.isMissionActive(player) then
        return true
    end

    return false
end

local function isRunActive(player)
    return isPlayerInGame(player) or isMissionTimerRunning(player)
end

local function buildSavePayload(player, clientState)
    local trustedScenarioProgress = CyberScenarioManager.ExportProgress(player)
    local missionTimer = getMissionTimer(0)
    local timerElapsed = 0
    if missionTimer and missionTimer.getElapsed then
        timerElapsed = sanitizeTimerElapsed(missionTimer.getElapsed(player))
    end

    return {
        version = 2,
        savedAt = os.time(),
        timerElapsed = timerElapsed,
        attributes = captureTrustedAttributes(player, trustedScenarioProgress),
        scenarioProgress = trustedScenarioProgress,
        position = capturePlayerPosition(player),
        clientState = sanitizeClientState(clientState),
    }
end

local function saveCurrentProgress(player, reason, clientState)
    local payload = buildSavePayload(player, clientState)
    if not hasSaveablePayload(payload) then
        logProgress("save_skipped", player, {
            reason = reason,
            key = buildSaveKey(player),
            store = PROGRESS_STORE_NAME,
            message = "No active mission or inventory progress.",
            payload = summarizeSavedPayload(payload),
        })
        return false, "No mission or inventory progress to save.", payload, "empty"
    end

    local persistent, resultOrError = writeSavedProgress(player, payload, reason)
    local hasSavedProgress = persistent == true or fallbackProgressCache[player.UserId] ~= nil
    player:SetAttribute("HasSavedProgress", hasSavedProgress)

    local syncStatus = persistent and "persistent" or "queued"
    return persistent, resultOrError, payload, syncStatus
end

local function saveCurrentProgressBlocking(player, reason)
    local payload = buildSavePayload(player)
    if not hasSaveablePayload(payload) then
        local cachedPayload = sanitizeSavedPayload(pendingPersistentSaves[player.UserId])
            or sanitizeSavedPayload(fallbackProgressCache[player.UserId])
        if cachedPayload and hasSaveablePayload(cachedPayload) then
            payload = cachedPayload
            logProgress("save_final_flush_using_cached_payload", player, {
                reason = reason,
                key = buildSaveKey(player),
                store = PROGRESS_STORE_NAME,
                payload = summarizeSavedPayload(payload),
            })
        else
            logProgress("save_skipped", player, {
                reason = reason,
                key = buildSaveKey(player),
                store = PROGRESS_STORE_NAME,
                message = "No active mission or inventory progress.",
                payload = summarizeSavedPayload(payload),
            })
            return false, "No mission or inventory progress to save.", payload, "empty"
        end
    end

    local trustedPayload = sanitizeSavedPayload(payload)
    local key = buildSaveKey(player)
    local fallback = sanitizeSavedPayload(fallbackProgressCache[player.UserId])
    if trustedPayload.clientState == nil and fallback and fallback.clientState then
        trustedPayload.clientState = fallback.clientState
    end

    fallbackProgressCache[player.UserId] = trustedPayload
    logProgress("save_payload_before_write", player, {
        reason = reason,
        key = key,
        store = PROGRESS_STORE_NAME,
        payload = summarizeSavedPayload(trustedPayload),
    })

    local persistent, resultOrError = writeTrustedPayloadWithRetries(
        player,
        key,
        trustedPayload,
        reason,
        FINAL_SAVE_WRITE_ATTEMPTS
    )

    if persistent then
        local sanitizedResult = sanitizeSavedPayload(resultOrError) or trustedPayload
        fallbackProgressCache[player.UserId] = sanitizedResult
        pendingPersistentSaves[player.UserId] = nil
        if player.Parent then
            player:SetAttribute("HasSavedProgress", true)
        end
        return true, sanitizedResult, trustedPayload, "persistent"
    end

    pendingPersistentSaves[player.UserId] = trustedPayload
    if player.Parent then
        player:SetAttribute("HasSavedProgress", true)
    end

    logProgress("save_final_flush_failed", player, {
        reason = reason,
        key = key,
        store = PROGRESS_STORE_NAME,
        error = tostring(resultOrError),
        payload = summarizeSavedPayload(trustedPayload),
    })

    return false, resultOrError, trustedPayload, "queued"
end

local function getSaveMessage(syncStatus)
    if syncStatus == "persistent" then
        return "Progress saved."
    end

    if syncStatus == "queued" then
        return "Progress saved. Cloud sync is retrying."
    end

    return "No mission progress to save."
end

local function buildDefaultContinueClientState()
    return {
        browserState = {
            adminLoggedIn = false,
            currentUrl = "about:blank",
            stickyNoteInspected = false,
            adminTab = "database",
            blockedIPs = {},
            selectedMailId = "",
            visiblePanel = "missions",
        },
        terminalState = {
            currentHost = "local",
            currentDir = "/",
            connectedHost = nil,
            sshSession = false,
            scanCache = nil,
            sniffCache = nil,
            lastAttackerIP = "203.44.18.77",
        },
        packetCapture = {
            targetIP = "",
            targetLabel = "",
        },
        openFiles = {},
    }
end

local function resolveCompletedProgressContinue(player, payload)
    local nextScenarioId = CyberScenarioManager.ResolveNextScenarioAfterCompletedProgress(payload.scenarioProgress)
    if not nextScenarioId then
        return nil
    end

    local safeScenarioId, validationError = CyberScenarioManager.CanLoadScenario(player, nextScenarioId)
    if not safeScenarioId then
        return nil, validationError
    end

    local result, err = CyberScenarioManager.LoadScenario(player, safeScenarioId)
    if type(result) ~= "table" then
        return nil, err
    end

    local chapterNumber = extractChapterNumber(safeScenarioId)
    if chapterNumber then
        player:SetAttribute("CurrentChapter", chapterNumber)
    end

    return CyberScenarioManager.GetSessionInfo(player), nil, safeScenarioId
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
            local trapCause = result.popupThrottleKey or "ClickedPhish"
            require(game.ServerScriptService.Server.DecisionTracker).LogDecision(player, trapCause, true)
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
        local DecisionTracker = require(game.ServerScriptService.Server.DecisionTracker)
        local finalStats = DecisionTracker.GetAllDecisions(player)
        game.ReplicatedStorage.ShowMissionReview:FireClient(player, finalStats)
    end

    if type(result) == "table"
        and result.success == true
        and (result.stepComplete == true or result.chapterComplete == true)
    then
        local sessionInfo = CyberScenarioManager.GetSessionInfo(player)
        logProgress("objective_completion", player, {
            scenarioId = result.completedScenarioId or (sessionInfo and sessionInfo.scenarioId) or nil,
            stepIndex = result.stepIndex,
            totalSteps = result.totalSteps,
            stepComplete = result.stepComplete == true,
            chapterComplete = result.chapterComplete == true,
            nextStep = sessionInfo and sessionInfo.currentStep or nil,
        })

        local persistent, saveResult, _, syncStatus = saveCurrentProgress(player, "objective-completion")
        result.savePersistent = persistent == true
        result.saveSyncStatus = syncStatus
        if persistent ~= true then
            result.saveWarning = tostring(saveResult)
        end
        fireProgressSaved(player, {
            success = syncStatus ~= "empty",
            persistent = persistent == true,
            syncStatus = syncStatus,
            reason = "objective-completion",
            savedAt = type(saveResult) == "table" and saveResult.savedAt or nil,
            message = getSaveMessage(syncStatus),
            warning = persistent ~= true and tostring(saveResult) or nil,
        })
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

SaveProgressRemote.OnServerInvoke = function(player, clientState)
    if not withinCooldown(player, "SaveProgress") then
        return {
            success = false,
            persistent = false,
            message = "Please wait before saving again.",
        }
    end

    local persistent, resultOrError, _, syncStatus = saveCurrentProgress(player, "manual-save", clientState)
    local hasSavedProgress = persistent == true or fallbackProgressCache[player.UserId] ~= nil
    player:SetAttribute("HasSavedProgress", hasSavedProgress)
    local message = getSaveMessage(syncStatus)

    local warning = nil
    if not persistent then
        warning = tostring(resultOrError)
    end

    fireProgressSaved(player, {
        success = hasSavedProgress,
        persistent = persistent == true,
        syncStatus = syncStatus,
        reason = "manual-save",
        savedAt = type(resultOrError) == "table" and resultOrError.savedAt or nil,
        message = message,
        warning = warning,
    })

    return {
        success = hasSavedProgress,
        persistent = persistent,
        syncStatus = syncStatus,
        message = message,
        warning = warning,
    }
end

FlushProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "FlushProgress") then
        return {
            success = false,
            persistent = false,
            message = "Please wait before flushing progress again.",
        }
    end

    local persistent, resultOrError, _, syncStatus = saveCurrentProgress(player, "transition-flush")
    local hasSavedProgress = persistent == true or fallbackProgressCache[player.UserId] ~= nil
    local warning = nil
    if persistent ~= true then
        warning = tostring(resultOrError)
    end
    local message = syncStatus == "empty" and "No progress to flush." or getSaveMessage(syncStatus)

    fireProgressSaved(player, {
        success = hasSavedProgress,
        persistent = persistent == true,
        syncStatus = syncStatus,
        reason = "transition-flush",
        savedAt = type(resultOrError) == "table" and resultOrError.savedAt or nil,
        message = message,
        warning = warning,
    })

    return {
        success = hasSavedProgress,
        persistent = persistent,
        syncStatus = syncStatus,
        message = message,
        warning = warning,
    }
end

ProgressSavedRemote.OnServerEvent:Connect(function(player, clientState)
    if not withinCooldown(player, "ProgressSaved") then
        return
    end

    local persistent, resultOrError, _, syncStatus = saveCurrentProgress(player, "progress-saved-event", clientState)
    local hasSavedProgress = persistent == true or fallbackProgressCache[player.UserId] ~= nil
    fireProgressSaved(player, {
        success = hasSavedProgress,
        persistent = persistent == true,
        syncStatus = syncStatus,
        reason = "progress-saved-event",
        savedAt = type(resultOrError) == "table" and resultOrError.savedAt or nil,
        message = getSaveMessage(syncStatus),
        warning = persistent ~= true and tostring(resultOrError) or nil,
    })
end)

local function disconnectProgressAttributeWatchers(player)
    local connections = progressAttributeConnections[player.UserId]
    if not connections then
        return
    end

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    progressAttributeConnections[player.UserId] = nil
end

local function scheduleProgressAttributeSave(player, attributeName)
    if not player or not player.Parent then
        return
    end

    local userId = player.UserId
    if progressAttributeSaveQueued[userId] then
        return
    end

    progressAttributeSaveQueued[userId] = attributeName or true
    task.delay(0.35, function()
        progressAttributeSaveQueued[userId] = nil
        if not player.Parent then
            return
        end

        local persistent, resultOrError, _, syncStatus = saveCurrentProgress(
            player,
            "progress-attribute-" .. tostring(attributeName or "changed")
        )
        local hasSavedProgress = persistent == true or fallbackProgressCache[userId] ~= nil
        if syncStatus ~= "empty" then
            fireProgressSaved(player, {
                success = hasSavedProgress,
                persistent = persistent == true,
                syncStatus = syncStatus,
                reason = "progress-attribute",
                attribute = attributeName,
                savedAt = type(resultOrError) == "table" and resultOrError.savedAt or nil,
                message = getSaveMessage(syncStatus),
                warning = persistent ~= true and tostring(resultOrError) or nil,
            })
        end
    end)
end

local function watchProgressAttributes(player)
    disconnectProgressAttributeWatchers(player)

    local connections = {}
    progressAttributeConnections[player.UserId] = connections
    for attributeName in pairs(PROGRESSION_SAVE_ATTRIBUTE_SET) do
        table.insert(connections, player:GetAttributeChangedSignal(attributeName):Connect(function()
            scheduleProgressAttributeSave(player, attributeName)
        end))
    end
end

LoadSavedProgressRemote.OnServerInvoke = function(player)
    if not withinCooldown(player, "LoadSavedProgress") then
        return {
            success = false,
            message = "Please wait before loading again.",
        }
    end

    if isPlayerInGame(player) then
        return {
            success = false,
            message = "Continue is disabled while a mission is already loaded.",
        }
    end

    if isMissionTimerRunning(player) then
        return {
            success = false,
            message = "Continue is disabled while the mission timer is running.",
        }
    end

    local payload = readSavedProgress(player, "continue")
    if type(payload) ~= "table" then
        return {
            success = false,
            message = "No saved progress found.",
        }
    end

    applyPlayerAttributes(player, payload.attributes)
    restorePersistentRuntimeState(player)
    local keycardRestoreState = verifyKeycardDataForContinue(player, payload)
    local sessionInfo = CyberScenarioManager.ImportProgress(player, payload.scenarioProgress)
    local autoStartedScenarioId = nil
    local autoStartWarning = nil
    if not sessionInfo then
        sessionInfo, autoStartWarning, autoStartedScenarioId = resolveCompletedProgressContinue(player, payload)
    end
    local positionQueued = applyPlayerPosition(player, payload.position)
    player:SetAttribute("HasSavedProgress", true)
    skipNewsCutsceneForContinue(player)
    if sessionInfo then
        local missionTimer = getMissionTimer()
        if missionTimer and missionTimer.startMission then
            missionTimer.startMission(player, payload.timerElapsed)
        end
    end

    local clientState = sanitizeClientState(payload.clientState) or buildDefaultContinueClientState()
    logProgress("continue_spawn_resolution", player, {
        key = buildSaveKey(player),
        restoredSession = sessionInfo ~= nil,
        scenarioId = sessionInfo and sessionInfo.scenarioId or nil,
        currentStep = sessionInfo and sessionInfo.currentStep or nil,
        autoStartedScenarioId = autoStartedScenarioId,
        autoStartWarning = autoStartWarning,
        positionQueued = positionQueued == true,
        hasKeycardData = keycardRestoreState.hasKeycardData == true,
        unlockedSlidingDoor = keycardRestoreState.unlockedSlidingDoor == true,
        hasClientState = type(clientState) == "table",
    })

    return {
        success = true,
        message = "Saved progress loaded.",
        sessionInfo = sessionInfo,
        timerElapsed = payload.timerElapsed,
        savedAt = payload.savedAt,
        clientState = clientState,
        autoStartedScenarioId = autoStartedScenarioId,
        hasKeycardData = keycardRestoreState.hasKeycardData == true,
        unlockedSlidingDoor = keycardRestoreState.unlockedSlidingDoor == true,
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

    local payload = readSavedProgress(player, "status")
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

    saveCurrentProgress(player, "cleanup-before-menu")

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

local function connectPersistencePlayer(player)
    player:SetAttribute("HasSavedProgress", false)
    watchProgressAttributes(player)
    task.spawn(function()
        local payload = readSavedProgress(player, "join-status")
        if player.Parent then
            player:SetAttribute("HasSavedProgress", type(payload) == "table")
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    connectPersistencePlayer(player)
end

Players.PlayerAdded:Connect(connectPersistencePlayer)

Players.PlayerRemoving:Connect(function(player)
    saveCurrentProgressBlocking(player, "player-removing")
    CyberScenarioManager.Cleanup(player)
    disconnectProgressAttributeWatchers(player)
    fallbackProgressCache[player.UserId] = nil
    pendingPersistentSaves[player.UserId] = nil
    progressAttributeSaveQueued[player.UserId] = nil
    remoteCooldowns[player.UserId] = nil
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveCurrentProgressBlocking(player, "bind-to-close")
        CyberScenarioManager.Cleanup(player)
    end
end)
