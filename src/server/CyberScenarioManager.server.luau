-- CyberScenarioManager.server.luau

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))
local SuspicionManager = require(Shared:WaitForChild("SuspicionManager"))

local MISTAKE_SUSPICION = 5
local PROGRESS_STORE = DataStoreService:GetDataStore("PlayerProgress_v1")
local SAVE_ATTRIBUTE_KEYS = {
    "CurrentChapter",
    "Obj_Admin",
    "RecoveredAdminCredentials",
    "TimesLeaked",
    "HasKeycardData",
    "UnlockedSlidingDoor",
    "HasSpokenToAgentRay",
    "Suspicion",
}
local RESTORE_STATE_ATTRIBUTE = "HackTabletRestoreBlob"
local RUNTIME_RESET_ATTRIBUTES = {
    [RESTORE_STATE_ATTRIBUTE] = nil,
    ["WannaWailActive"] = false,
    ["WannaWailInfectedCount"] = 0,
    ["WannaWailLastMachine"] = "",
    ["WannaWailSourceBlocked"] = false,
    ["WannaWailFirewallRuleAdded"] = false,
    ["WannaWailProcessKilled"] = false,
    ["WannaWailLoaderRemoved"] = false,
    ["WannaWailContained"] = false,
}

local fallbackProgressCache = {}

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

local function extractChapterNumber(scenarioId)
    local chapterNumber = tostring(scenarioId or ""):match("Chapter(%d+)")
    return tonumber(chapterNumber)
end

local function buildSaveKey(player)
    return ("player_%d_progress"):format(player.UserId)
end

local function capturePlayerAttributes(player)
    local saved = {}

    for _, attributeName in ipairs(SAVE_ATTRIBUTE_KEYS) do
        local value = player:GetAttribute(attributeName)
        if value ~= nil then
            saved[attributeName] = value
        end
    end

    return saved
end

local function applyPlayerAttributes(player, saved)
    saved = type(saved) == "table" and saved or {}

    for _, attributeName in ipairs(SAVE_ATTRIBUTE_KEYS) do
        player:SetAttribute(attributeName, saved[attributeName])
    end
end

local function capturePlayerPosition(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local components = { root.CFrame:GetComponents() }
    if #components ~= 12 then
        return nil
    end

    return components
end

local function applyPlayerPosition(player, savedPosition)
    if type(savedPosition) ~= "table" or #savedPosition ~= 12 then
        return
    end

    local function moveCharacter(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return false
        end

        root.CFrame = CFrame.new(table.unpack(savedPosition))
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

local function sanitizeOpenFiles(openFiles)
    if type(openFiles) ~= "table" then
        return {}
    end

    local sanitized = {}
    for _, value in ipairs(openFiles) do
        if type(value) == "string" and value ~= "" then
            sanitized[#sanitized + 1] = value
        end
    end

    return sanitized
end

local function sanitizeSniffCache(sniffCache)
    if type(sniffCache) ~= "table" then
        return nil
    end

    return {
        host = type(sniffCache.host) == "string" and sniffCache.host or nil,
        ip = type(sniffCache.ip) == "string" and sniffCache.ip or nil,
        server = type(sniffCache.server) == "string" and sniffCache.server or nil,
        attackerIP = type(sniffCache.attackerIP) == "string" and sniffCache.attackerIP or nil,
    }
end

local function sanitizeClientState(clientState)
    if type(clientState) ~= "table" then
        return nil
    end

    local browserState = type(clientState.browserState) == "table" and clientState.browserState or {}
    local terminalState = type(clientState.terminalState) == "table" and clientState.terminalState or {}
    local packetCapture = type(clientState.packetCapture) == "table" and clientState.packetCapture or {}
    local blockedIPs = {}

    if type(browserState.blockedIPs) == "table" then
        for _, value in ipairs(browserState.blockedIPs) do
            if type(value) == "string" and value ~= "" then
                blockedIPs[#blockedIPs + 1] = value
            end
        end
    end

    return {
        browserState = {
            adminLoggedIn = browserState.adminLoggedIn == true,
            currentUrl = type(browserState.currentUrl) == "string" and browserState.currentUrl or "about:blank",
            stickyNoteInspected = browserState.stickyNoteInspected == true,
            adminTab = browserState.adminTab == "logs" and "logs" or "database",
            blockedIPs = blockedIPs,
        },
        terminalState = {
            currentHost = type(terminalState.currentHost) == "string" and terminalState.currentHost or "local",
            currentDir = type(terminalState.currentDir) == "string" and terminalState.currentDir or "/",
            connectedHost = type(terminalState.connectedHost) == "string" and terminalState.connectedHost or nil,
            sshSession = terminalState.sshSession == true,
            scanCache = type(terminalState.scanCache) == "string" and terminalState.scanCache or nil,
            sniffCache = sanitizeSniffCache(terminalState.sniffCache),
            lastAttackerIP = type(terminalState.lastAttackerIP) == "string" and terminalState.lastAttackerIP or "203.44.18.77",
        },
        packetCapture = {
            targetIP = type(packetCapture.targetIP) == "string" and packetCapture.targetIP or "",
            targetLabel = type(packetCapture.targetLabel) == "string" and packetCapture.targetLabel or "",
        },
        openFiles = sanitizeOpenFiles(clientState.openFiles),
    }
end

local function readSavedProgress(player)
    local key = buildSaveKey(player)
    local ok, payload = pcall(function()
        return PROGRESS_STORE:GetAsync(key)
    end)

    if ok and type(payload) == "table" then
        fallbackProgressCache[player.UserId] = payload
        return payload, true
    end

    local fallback = fallbackProgressCache[player.UserId]
    if type(fallback) == "table" then
        return fallback, false
    end

    return nil, ok
end

local function writeSavedProgress(player, payload)
    fallbackProgressCache[player.UserId] = payload

    local ok, err = pcall(function()
        PROGRESS_STORE:SetAsync(buildSaveKey(player), payload)
    end)

    return ok, err
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

    for attributeName, value in pairs(RUNTIME_RESET_ATTRIBUTES) do
        player:SetAttribute(attributeName, value)
    end

    CyberScenarioManager.ResetProgress(player)
end

LoadScenarioRemote.OnServerInvoke = function(player, scenarioId)
    local result, err = CyberScenarioManager.LoadScenario(player, scenarioId)
    local chapterNumber = extractChapterNumber(scenarioId)
    if chapterNumber then
        player:SetAttribute("CurrentChapter", chapterNumber)
    end
    return result, err
end

CheckSolutionRemote.OnServerInvoke = function(player, input)
    local result = CyberScenarioManager.CheckSolution(player, input)

    if type(result) == "table" and result.popupTitle and result.popupMessage then
        SuspicionManager.Add(MISTAKE_SUSPICION, player)
        LessonManager.TriggerCustomPopup(player, result.popupTitle, result.popupMessage, {
            throttleKey = result.popupThrottleKey,
            throttleWindow = result.popupThrottleWindow,
        })
    end

    return result
end

GetHintRemote.OnServerInvoke = function(player)
    return CyberScenarioManager.GetHint(player)
end

GetSessionInfoRemote.OnServerInvoke = function(player)
    return CyberScenarioManager.GetSessionInfo(player)
end

SaveProgressRemote.OnServerInvoke = function(player, clientState)
    local payload = {
        version = 1,
        savedAt = os.time(),
        attributes = capturePlayerAttributes(player),
        scenarioProgress = CyberScenarioManager.ExportProgress(player),
        position = capturePlayerPosition(player),
        clientState = sanitizeClientState(clientState),
    }

    local persistent, err = writeSavedProgress(player, payload)
    local message = persistent and "Progress saved." or "Progress saved for this session only."

    return {
        success = true,
        persistent = persistent,
        message = message,
        warning = persistent and nil or tostring(err),
    }
end

LoadSavedProgressRemote.OnServerInvoke = function(player)
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

    return {
        success = true,
        message = "Saved progress loaded.",
        clientState = sanitizeClientState(payload.clientState),
        sessionInfo = sessionInfo,
        savedAt = payload.savedAt,
    }
end

GetSavedProgressStatusRemote.OnServerInvoke = function(player)
    local payload = readSavedProgress(player)
    local hasSave = type(payload) == "table"

    return {
        success = true,
        hasSave = hasSave,
        message = hasSave and "Saved progress available." or "No saved progress found.",
    }
end

ClearSavedProgressRemote.OnServerInvoke = function(player)
    local persistent, err = clearSavedProgress(player)

    return {
        success = true,
        persistent = persistent,
        message = persistent and "Saved progress cleared." or "Saved progress cleared for this session only.",
        warning = persistent and nil or tostring(err),
    }
end

StartOverProgressRemote.OnServerInvoke = function(player)
    local persistent, err = clearSavedProgress(player)
    resetRuntimeState(player)

    return {
        success = true,
        persistent = persistent,
        message = persistent and "Progress reset. Starting over." or "Progress reset for this session. Starting over.",
        warning = persistent and nil or tostring(err),
    }
end

CleanupRemote.OnServerEvent:Connect(function(player)
    CyberScenarioManager.Cleanup(player)
end)

Players.PlayerRemoving:Connect(function(player)
    CyberScenarioManager.Cleanup(player)
end)
