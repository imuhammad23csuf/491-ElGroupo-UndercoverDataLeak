local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CyberScenarioManager = require(script.Parent.CyberScenarioManager)

-- TODO: create CyberScenarioRemotes folder + RemoteEvents
-- (LoadScenario, SubmitSolution, CloseScenario)
-- following the same pattern as NarrativeRemotes

-- TODO: wire OnServerEvent for each remote to the three
-- CyberScenarioManager functions above