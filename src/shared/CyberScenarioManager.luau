local ObjectiveManager = require(script.Parent.ObjectiveManager)
local SuspicionManager = require(script.Parent.SuspicionManager)
local ScenarioData = require(script.Parent.ScenarioData)

local CyberScenarioManager = {}

local activeSessions = {}

-- Load a scenario into the tablet for a player
function CyberScenarioManager.LoadScenario(player, scenarioId)
    local scenario = ScenarioData[scenarioId]

    -- TODO: store session in activeSessions[player.UserId]
    -- TODO: return scenario data (prompt, type, hint) to client
end

-- Check if the player's answer is correct
function CyberScenarioManager.CheckSolution(player, input)
    -- TODO: get activeSessions[player.UserId]
    -- TODO: compare input against ScenarioData correct answer
    -- TODO: call ObjectiveManager to report pass/fail
    -- TODO: return { success = bool, feedback = string }
end

-- Close the tablet app and return player to stealth gameplay
function CyberScenarioManager.Cleanup(player)
    -- TODO: clear activeSessions[player.UserId]
    -- TODO: fire RemoteEvent to client to close tablet UI
end

function CyberScenarioManager.hasActiveScenario(player)
    return activeSessions[player.UserId] ~= nil
end

return CyberScenarioManager
