--[[
    CyberScenarioManager.luau  (ModuleScript — server-side)
    ─────────────────────────────────────────────────────────────────
    Manages active HackTablet scenario sessions per player.

    Public API
    ──────────
    LoadScenario(player, scenarioId)  → data, err
        Starts a new session for the player and returns the chapter
        metadata (title, objective, welcomeMessage, first instruction).

    CheckSolution(player, input)  → result
        Parses a raw terminal command string against the player's
        current step.  Returns a result table:
          {
            success        : bool   — was the command correct?
            output         : string — terminal text to display
            stepComplete   : bool   — did this step finish?
            chapterComplete: bool   — was this the last step?
            nextInstruction: string — instruction for next step
            nextHint       : string — hint for next step
            stepIndex      : int    — new step index (1-based)
            totalSteps     : int
            feedback       : string — short status message
          }

    GetHint(player)  → string
        Returns the hint for the player's current step.

    Cleanup(player)
        Clears the player's session.

    hasActiveScenario(player)  → bool
    GetSessionInfo(player)     → table | nil
--]]

-- All siblings in ReplicatedStorage.Shared
local ObjectiveManager  = require(script.Parent.ObjectiveManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SuspicionManager  = require(script.Parent.SuspicionManager)
local ScenarioData      = require(script.Parent.ScenarioData)

local CyberScenarioManager = {}
local activeSessions = {}   -- [UserId] = { scenarioId, currentStep, startTime, completedSteps, stepState }
local completedScenarios = {} -- [UserId] = { [scenarioId] = true }

local scenarioOrder = {
    "Chapter1_Recon",
    "Chapter2_SSH",
    "Chapter3_Malware",
    "Chapter4_IncidentResponse",
}

local function getScenarioOrderIndex(scenarioId)
    for index, id in ipairs(scenarioOrder) do
        if id == scenarioId then
            return index
        end
    end
    return nil
end

local function buildMissionObjectives(player)
    local session = activeSessions[player.UserId]
    local completed = completedScenarios[player.UserId] or {}
    local objectivesList = {}

    for index, scenarioId in ipairs(scenarioOrder) do
        local scenario = ScenarioData[scenarioId]
        if scenario then
            local status = "Not Started"
            local text = scenario.title
            local unlocked = index == 1 or completed[scenarioOrder[index - 1]]
            if not unlocked then
                status = "Locked"
                text = scenario.title .. " (Locked)"
            elseif completed[scenarioId] then
                status = "Completed"
            elseif session and session.scenarioId == scenarioId then
                status = "In Progress"
                text = string.format("%s (Step %d/%d)", scenario.title, session.currentStep, #scenario.steps)
            end

            table.insert(objectivesList, {
                id = "cyber_" .. scenarioId,
                text = text,
                status = status,
            })
        end
    end

    return objectivesList
end

local function buildChapterObjectives(player)
    local session = activeSessions[player.UserId]
    local completed = completedScenarios[player.UserId] or {}
    local objectivesList = {}

    for index, scenarioId in ipairs(scenarioOrder) do
        local scenario = ScenarioData[scenarioId]
        if scenario then
            local unlocked = index == 1 or completed[scenarioOrder[index - 1]]
            local status = "Not Started"

            if not unlocked then
                status = "Locked"
            elseif completed[scenarioId] then
                status = "Completed"
            elseif session and session.scenarioId == scenarioId then
                status = "In Progress"
            end

            local steps = {}
            for stepIndex, step in ipairs(scenario.steps or {}) do
                local stepStatus = "Not Started"

                if not unlocked then
                    stepStatus = "Locked"
                elseif completed[scenarioId] then
                    stepStatus = "Completed"
                elseif session and session.scenarioId == scenarioId then
                    if stepIndex < session.currentStep then
                        stepStatus = "Completed"
                    elseif stepIndex == session.currentStep then
                        stepStatus = "In Progress"
                    else
                        stepStatus = "Not Started"
                    end
                end

                table.insert(steps, {
                    id = step.id or (scenarioId .. "_step" .. stepIndex),
                    text = step.instruction or ("Step " .. stepIndex),
                    status = stepStatus,
                })
            end

            table.insert(objectivesList, {
                id = scenarioId,
                title = scenario.title,
                text = scenario.title,
                status = status,
                unlocked = unlocked,
                steps = steps,
            })
        end
    end

    return objectivesList
end

local function syncObjectives(player)
    if player then
        ObjectiveManager.SetPlayerObjectives(player, buildChapterObjectives(player), "ChapterObjectives")
    end
end

-- ── Helpers ─────────────────────────────────────────────────────────

local function trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

-- Strip leading/trailing whitespace and lowercase the entire string.
local function normalize(s)
    return trim(s):lower()
end

local function isStrongPasswordCommand(rawInput)
    local input = trim(rawInput)
    local password = input:match("^passwd%s+(.+)$")

    if not password then
        return false
    end

    return #password >= 12
        and password:match("%d") ~= nil
        and password:match("%l") ~= nil
        and password:match("%u") ~= nil
        and password:match("[%p%W_]") ~= nil
end

local function isPhishingAnalysisCommand(rawInput)
    local input = normalize(rawInput)
    local tool, message = input:match("^(%S+)%s+(.+)$")

    if (tool ~= "baitcheck" and tool ~= "decoymail") or not message or message == "" then
        return false
    end

    for _, keyword in ipairs({
        "urgent",
        "verify",
        "reset",
        "password",
        "click",
        "link",
        "security",
        "account",
    }) do
        if message:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

--[[
    Check whether the player's input matches any of the step's
    validCommands.

    Matching rules:
      • Always case-insensitive.
      • If step.matchPrefix == true: input only needs to START WITH a
        valid command string (lets players include extra flags/args).
      • Otherwise: exact match required.
--]]
local function commandMatches(rawInput, step)
    if step.requiresStrongPassword then
        return isStrongPasswordCommand(rawInput)
    end

    if step.requiresPhishingAnalysis then
        return isPhishingAnalysisCommand(rawInput)
    end

    local input = normalize(rawInput)

    for _, valid in ipairs(step.validCommands) do
        local v = normalize(valid)

        if step.matchPrefix then
            -- Accept "connect novatech_guest --creds ..." when valid = "connect novatech_guest"
            if input == v or input:sub(1, #v) == v then
                return true
            end
        else
            if input == v then
                return true
            end
        end
    end

    return false
end

local function singleLine(text)
    return trim(tostring(text or "")):gsub("%s*\n%s*", " ")
end

local function getSuggestedCommand(step)
    local suggestedCommand = singleLine(step.suggestedCommand)
    if suggestedCommand ~= "" then
        return suggestedCommand
    end

    if step.requiresStrongPassword then
        return "passwd NewStrongPass123!"
    end

    if step.requiresPhishingAnalysis then
        return 'baitcheck "URGENT verify your account now"'
    end

    local validCommands = step.validCommands
    if type(validCommands) ~= "table" or #validCommands == 0 then
        return nil
    end

    local example = singleLine(validCommands[1])
    if example == "" then
        return nil
    end

    return example
end

local function buildMistakePopup(step)
    local lines = {
        "Current objective: " .. singleLine(step.instruction or "Follow the active mission step."),
    }

    local hint = singleLine(step.hint)
    if hint ~= "" then
        table.insert(lines, "Hint: " .. hint)
    end

    local suggestedCommand = getSuggestedCommand(step)
    if suggestedCommand then
        table.insert(lines, "Try: " .. suggestedCommand)
    end

    return {
        title = "HACKTABLET MISTAKE",
        message = table.concat(lines, "\n"),
        throttleKey = "tablet_step_" .. tostring(step.id or "unknown"),
        throttleWindow = 2,
    }
end

-- ── Public API ───────────────────────────────────────────────────────

local function cloneCompletedScenarios(source)
    local out = {}

    if type(source) ~= "table" then
        return out
    end

    for scenarioId, completed in pairs(source) do
        if completed then
            out[scenarioId] = true
        end
    end

    return out
end

local function buildCompletedStepsForScenario(scenario, currentStep)
    local completedSteps = {}
    local steps = scenario and scenario.steps or {}
    local clampedStep = math.clamp(tonumber(currentStep) or 1, 1, math.max(#steps, 1))

    for index = 1, clampedStep - 1 do
        local step = steps[index]
        if step and step.id then
            table.insert(completedSteps, step.id)
        end
    end

    return completedSteps
end


local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = deepCopy(nestedValue)
    end

    return copy
end

local function ensureStepState(session, stepId)
    session.stepState = session.stepState or {}

    if type(session.stepState[stepId]) ~= "table" then
        session.stepState[stepId] = {}
    end

    return session.stepState[stepId]
end

local function getMailEntryById(scenario, emailId)
    local mailInbox = scenario and scenario.mailInbox
    if type(mailInbox) ~= "table" then
        return nil
    end

    for _, entry in ipairs(mailInbox) do
        if type(entry) == "table" and tostring(entry.id) == tostring(emailId) then
            return entry
        end
    end

    return nil
end

local function countResolvedEntries(resolvedMap)
    local count = 0

    for _, resolved in pairs(resolvedMap or {}) do
        if resolved then
            count = count + 1
        end
    end

    return count
end

local function completeStep(player, session, scenario, step)
    table.insert(session.completedSteps, step.id)

    local isLast = step.isLastStep == true

    if not isLast then
        session.currentStep = session.currentStep + 1
        local nextStep = scenario.steps[session.currentStep]
        syncObjectives(player)

        return {
            success = true,
            output = step.output,
            stepComplete = true,
            chapterComplete = false,
            nextInstruction = nextStep and nextStep.instruction or nil,
            nextHint = nextStep and nextStep.hint or nil,
            stepIndex = session.currentStep,
            totalSteps = #scenario.steps,
            feedback = "Step complete!",
        }
    end

    local completed = completedScenarios[player.UserId]
    if not completed then
        completed = {}
        completedScenarios[player.UserId] = completed
    end
    completed[session.scenarioId] = true
    activeSessions[player.UserId] = nil
    syncObjectives(player)

    if session.scenarioId == "Chapter1_Recon" then
        pcall(function()
            SuspicionManager.AddSuspicion(player, 10)
        end)
    end

    return {
        success = true,
        output = step.output,
        stepComplete = true,
        chapterComplete = true,
        feedback = "Chapter complete!",
        completedScenarioId = session.scenarioId,
        totalSteps = #scenario.steps,
        stepIndex = session.currentStep,
    }
end

local function handleMailTriageStep(player, session, scenario, step, rawInput)
    local input = normalize(rawInput)
    local emailId, action = input:match("^browser_mail%s+([%w_%-]+)%s+(report|pass)$")

    if not emailId or not action then
        local mistakePopup = buildMistakePopup(step)
        return {
            success = false,
            output = table.concat({
                "[!] Use the Report or Pass Through buttons inside BloxMail to classify each message.",
                "[?] Hint: " .. (step.hint or "Review the active inbox queue."),
            }, string.char(10)),
            feedback = "Incorrect command - try again.",
            popupTitle = mistakePopup.title,
            popupMessage = mistakePopup.message,
            popupThrottleKey = mistakePopup.throttleKey,
            popupThrottleWindow = mistakePopup.throttleWindow,
        }
    end

    local emailEntry = getMailEntryById(scenario, emailId)
    if not emailEntry then
        return {
            success = false,
            output = "[!] That inbox message is not part of the active Chapter 3 queue.",
            feedback = "Unknown inbox message.",
        }
    end

    local stepState = ensureStepState(session, step.id)
    stepState.resolved = stepState.resolved or {}
    stepState.actions = stepState.actions or {}
    stepState.penalized = stepState.penalized or {}

    if stepState.resolved[emailId] == true then
        return {
            success = true,
            output = ('[*] "%s" is already classified.'):format(tostring(emailEntry.subject or emailId)),
            feedback = "Message already handled.",
            stepComplete = false,
            chapterComplete = false,
            stepIndex = session.currentStep,
            totalSteps = #scenario.steps,
        }
    end

    local expectedAction = normalize(emailEntry.expectedAction)
    if expectedAction ~= "report" and expectedAction ~= "pass" then
        expectedAction = "report"
    end

    if action == expectedAction then
        stepState.resolved[emailId] = true
        stepState.actions[emailId] = action

        local totalEmails = #((scenario and scenario.mailInbox) or {})
        local resolvedCount = countResolvedEntries(stepState.resolved)

        if totalEmails > 0 and resolvedCount >= totalEmails then
            return completeStep(player, session, scenario, step)
        end

        return {
            success = true,
            output = ('[*] "%s" classified as %s.'):format(
                tostring(emailEntry.subject or emailId),
                action == "report" and "REPORT" or "PASS THROUGH"
            ) .. string.char(10) .. ("[*] Inbox triage progress: %d/%d complete."):format(
                resolvedCount,
                totalEmails
            ),
            feedback = ("Inbox triage progress: %d/%d"):format(resolvedCount, totalEmails),
            stepComplete = false,
            chapterComplete = false,
            stepIndex = session.currentStep,
            totalSteps = #scenario.steps,
        }
    end

    local penaltyKey = ("%s:%s"):format(emailId, action)
    if not stepState.penalized[penaltyKey] then
        stepState.penalized[penaltyKey] = true
        local mistakePopup = buildMistakePopup(step)

        return {
            success = false,
            output = ('[!] "%s" should not be marked %s.'):format(
                tostring(emailEntry.subject or emailId),
                action == "report" and "REPORT" or "PASS THROUGH"
            ) .. string.char(10) .. "[?] Review the sender, urgency, and request before deciding again.",
            feedback = "Incorrect classification - review the message again.",
            popupTitle = mistakePopup.title,
            popupMessage = mistakePopup.message,
            popupThrottleKey = mistakePopup.throttleKey .. "_mail_" .. penaltyKey,
            popupThrottleWindow = mistakePopup.throttleWindow,
        }
    end

    return {
        success = false,
        output = ('[!] "%s" is still unresolved. Review it again before choosing.'):format(tostring(emailEntry.subject or emailId)),
        feedback = "Message still pending.",
        stepComplete = false,
        chapterComplete = false,
        stepIndex = session.currentStep,
        totalSteps = #scenario.steps,
    }
end

--[[
    CanLoadScenario
    Validates and sanitizes a scenarioId before loading.
    Called by the server script to reject bad inputs early.

    Returns  (safeScenarioId, nil)    when the request is valid
    Returns  (nil, errMsg)            when the request is invalid
--]]
function CyberScenarioManager.CanLoadScenario(player, scenarioId)
    if type(scenarioId) ~= "string" then
        return nil, "Invalid chapter ID."
    end

    local trimmed = scenarioId:match("^%s*(.-)%s*$")
    if trimmed == "" or #trimmed > 64 then
        return nil, "Invalid chapter ID."
    end

    if not ScenarioData[trimmed] then
        return nil, "Unknown chapter: " .. trimmed
    end

    local orderIndex = getScenarioOrderIndex(trimmed)
    if orderIndex and orderIndex > 1 then
        local completed = completedScenarios[player.UserId] or {}
        local prerequisiteScenarioId = scenarioOrder[orderIndex - 1]
        if completed[prerequisiteScenarioId] ~= true then
            return nil, "Chapter is locked until the previous chapter is completed."
        end
    end

    return trimmed, nil
end

--[[
    LoadScenario
    Begins a new chapter session for the player.

    Returns  (data, nil)    on success
    Returns  (nil,  errMsg) on failure
--]]
function CyberScenarioManager.LoadScenario(player, scenarioId)
    local scenario = ScenarioData[scenarioId]
    if not scenario then
        return nil, "Scenario not found: " .. tostring(scenarioId)
    end

    -- Overwrite any existing session (re-starting a chapter is fine)
    activeSessions[player.UserId] = {
        scenarioId      = scenarioId,
        currentStep     = 1,
        startTime       = os.time(),
        completedSteps  = {},
        stepState       = {},
    }

    completedScenarios[player.UserId] = completedScenarios[player.UserId] or {}
    local firstStep = scenario.steps[1]
    syncObjectives(player)

    return {
        scenarioId          = scenarioId,
        title               = scenario.title,
        objective           = scenario.objective,
        welcomeMessage      = scenario.welcomeMessage,
        currentInstruction  = firstStep.instruction,
        currentHint         = firstStep.hint,
        stepIndex           = 1,
        totalSteps          = #scenario.steps,
    }, nil
end


--[[
    CheckSolution
    Evaluates a raw terminal command string against the player's
    current step and advances the step on success.
--]]
function CyberScenarioManager.CheckSolution(player, input)
    -- ── Guard: no active session ────────────────────────────────
    local session = activeSessions[player.UserId]
    if not session then
        return {
            success         = false,
            output          = "[!] No active scenario loaded.\n    Open the HackTablet and select a chapter to begin.",
            feedback        = "No active session.",
            chapterComplete = false,
        }
    end

    local scenario = ScenarioData[session.scenarioId]
    if not scenario then
        return {
            success  = false,
            output   = "[!] Internal error: scenario data missing.",
            feedback = "Scenario data error.",
        }
    end

    local step = scenario.steps[session.currentStep]
    if not step then
        return {
            success         = false,
            output          = "[!] This chapter is already complete.",
            feedback        = "Already finished.",
            chapterComplete = true,
        }
    end

    -- ── Universal commands ──────────────────────────────────────
    local normInput = normalize(input)

    -- clear — works at any time, resets visual terminal (not progress)
    if normInput == "clear" then
        return {
            success       = true,
            output        = "",
            clearTerminal = true,
            feedback      = "Terminal cleared.",
        }
    end

    -- help typed during a non-help step — show current progress reminder
    if normInput == "help" and not commandMatches(input, step) then
        return {
            success  = false,
            output   = table.concat({
                "[*] Current Objective:",
                "    " .. step.instruction,
                "",
                "[?] Hint: " .. (step.hint or "Re-read the objective above."),
                "",
                "[*] Step " .. session.currentStep .. " of " .. #scenario.steps,
            }, "\n"),
            feedback = "Use 'hint' for a direct tip.",
        }
    end

    -- hint — explicit shortcut for the current step's hint
    if normInput == "hint" then
        return {
            success  = false,
            output   = "[?] HINT: " .. (step.hint or "No hint available for this step."),
            feedback = "Hint displayed.",
        }
    end

    if step.id == "ch3_inbox_triage" then
        return handleMailTriageStep(player, session, scenario, step, input)
    end

    if step.id == "ch2_admin_login" and player:GetAttribute("RecoveredAdminCredentials") ~= true then
        return {
            success = false,
            output = table.concat({
                "[!] Admin login verification is locked until you inspect the sticky note credential hint.",
                "[?] Hint: find and inspect the sticky note in the world first.",
            }, "\n"),
            feedback = "Inspect sticky note first.",
        }
    end

    -- ── Evaluate command ────────────────────────────────────────
    if not commandMatches(input, step) then
        local mistakePopup = buildMistakePopup(step)
        return {
            success             = false,
            output              = table.concat({
                "[!] Command not recognised or not the right command for this step.",
                "[?] Hint: " .. (step.hint or "Try a different approach."),
            }, "\n"),
            feedback            = "Incorrect command - try again.",
            popupTitle          = mistakePopup.title,
            popupMessage        = mistakePopup.message,
            popupThrottleKey    = mistakePopup.throttleKey,
            popupThrottleWindow = mistakePopup.throttleWindow,
        }
    end

    -- ?? Correct command ?????????????????????????????????????????
    return completeStep(player, session, scenario, step)
end


--[[
    GetHint
    Returns the hint string for the player's current step.
--]]
function CyberScenarioManager.GetHint(player)
    local session = activeSessions[player.UserId]
    if not session then
        return "[!] No active scenario. Load a chapter first."
    end

    local scenario = ScenarioData[session.scenarioId]
    local step = scenario and scenario.steps[session.currentStep]
    if not step then
        return "[!] No hint available — chapter is complete."
    end

    return "[?] HINT (" .. session.scenarioId .. " · Step " .. session.currentStep .. "): "
        .. (step.hint or "Re-read the objective carefully.")
end


--[[
    Cleanup
    Ends the player's active session and signals the client to close
    the tablet UI (the RemoteEvent fire happens in the server script).
--]]
function CyberScenarioManager.Cleanup(player)
    activeSessions[player.UserId] = nil
    syncObjectives(player)
end

function CyberScenarioManager.ResetProgress(player)
    if not player then
        return
    end

    activeSessions[player.UserId] = nil
    completedScenarios[player.UserId] = {}
    syncObjectives(player)
end

function CyberScenarioManager.SyncObjectives(player)
    syncObjectives(player)
end

function CyberScenarioManager.ExportProgress(player)
    if not player then
        return {
            activeSession = nil,
            completedScenarios = {},
        }
    end

    local session = activeSessions[player.UserId]

    return {
        activeSession = session and {
            scenarioId = session.scenarioId,
            currentStep = session.currentStep,
            startTime = session.startTime,
            stepState = deepCopy(session.stepState),
        } or nil,
        completedScenarios = cloneCompletedScenarios(completedScenarios[player.UserId]),
    }
end

function CyberScenarioManager.ImportProgress(player, progressData)
    if not player then
        return nil
    end

    progressData = type(progressData) == "table" and progressData or {}
    completedScenarios[player.UserId] = cloneCompletedScenarios(progressData.completedScenarios)
    activeSessions[player.UserId] = nil

    local savedSession = progressData.activeSession
    if type(savedSession) == "table" then
        local scenarioId = tostring(savedSession.scenarioId or "")
        local scenario = ScenarioData[scenarioId]

        if scenario and type(scenario.steps) == "table" and #scenario.steps > 0 then
            local currentStep = math.clamp(tonumber(savedSession.currentStep) or 1, 1, #scenario.steps)

            activeSessions[player.UserId] = {
                scenarioId = scenarioId,
                currentStep = currentStep,
                startTime = tonumber(savedSession.startTime) or os.time(),
                completedSteps = buildCompletedStepsForScenario(scenario, currentStep),
                stepState = deepCopy(savedSession.stepState),
            }
        end
    end

    syncObjectives(player)
    return CyberScenarioManager.GetSessionInfo(player)
end

--[[
    hasActiveScenario
    Quick boolean check used by the server and other systems.
--]]
function CyberScenarioManager.hasActiveScenario(player)
    return activeSessions[player.UserId] ~= nil
end


--[[
    GetSessionInfo
    Returns a lightweight summary of the player's current session,
    useful for UI widgets that need to show progress without
    triggering a full command evaluation.
--]]
function CyberScenarioManager.GetSessionInfo(player)
    local session = activeSessions[player.UserId]
    if not session then return nil end

    local scenario = ScenarioData[session.scenarioId]
    local step     = scenario and scenario.steps[session.currentStep]

    return {
        scenarioId   = session.scenarioId,
        title        = scenario and scenario.title or "Unknown",
        currentStep  = session.currentStep,
        stepId       = step and step.id or nil,
        totalSteps   = scenario and #scenario.steps or 0,
        instruction  = step and step.instruction or "Chapter complete.",
        hint         = step and step.hint or "",
        elapsedTime  = os.time() - session.startTime,
        stepState    = deepCopy(session.stepState),
    }
end

return CyberScenarioManager

