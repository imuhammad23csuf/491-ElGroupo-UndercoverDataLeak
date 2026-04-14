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
local activeSessions = {}   -- [UserId] = { scenarioId, currentStep, startTime, completedSteps }
local completedScenarios = {} -- [UserId] = { [scenarioId] = true }

local scenarioOrder = {
    "Chapter1_Recon",
    "Chapter2_SSH",
    "Chapter3_Malware",
    "Chapter4_IncidentResponse",
}

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

    -- ── Correct command ─────────────────────────────────────────
    table.insert(session.completedSteps, step.id)

    local isLast = step.isLastStep == true

    if not isLast then
        -- Advance to next step
        session.currentStep = session.currentStep + 1
        local nextStep = scenario.steps[session.currentStep]
        syncObjectives(player)

        return {
            success          = true,
            output           = step.output,
            stepComplete     = true,
            chapterComplete  = false,
            nextInstruction  = nextStep and nextStep.instruction or nil,
            nextHint         = nextStep and nextStep.hint or nil,
            stepIndex        = session.currentStep,
            totalSteps       = #scenario.steps,
            feedback         = "Step complete!",
        }
    else
        -- Chapter finished
        local completed = completedScenarios[player.UserId]
        if not completed then
            completed = {}
            completedScenarios[player.UserId] = completed
        end
        completed[session.scenarioId] = true
        activeSessions[player.UserId] = nil
        syncObjectives(player)

        -- Chapter 1 involves unauthorized network access — add minor suspicion
        if session.scenarioId == "Chapter1_Recon" then
            pcall(function()
                SuspicionManager.AddSuspicion(player, 10)
            end)
        end

        return {
            success             = true,
            output              = step.output,
            stepComplete        = true,
            chapterComplete     = true,
            feedback            = "Chapter complete!",
            completedScenarioId = session.scenarioId,
            totalSteps          = #scenario.steps,
            stepIndex           = session.currentStep,
        }
    end
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

function CyberScenarioManager.SyncObjectives(player)
    syncObjectives(player)
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
    }
end

return CyberScenarioManager
