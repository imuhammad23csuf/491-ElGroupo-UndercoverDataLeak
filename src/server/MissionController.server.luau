local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

local defaultMission = {
	{ id = "task1", text = "Infiltrate the outer perimeter.", status = "In Progress" },
	{ id = "task2", text = "Copy the Guard's Key Code.", status = "Not Started" },
	{ id = "task3", text = "Unlock the sliding door.", status = "Not Started" },
}

local playerMissions = {}

local function cloneMission()
	local missionCopy = table.create(#defaultMission)
	for index, taskInfo in ipairs(defaultMission) do
		missionCopy[index] = {
			id = taskInfo.id,
			text = taskInfo.text,
			status = taskInfo.status,
		}
	end
	return missionCopy
end

local function syncPlayerObjectives(player)
	if not player or player.Parent ~= Players then
		return
	end

	local mission = playerMissions[player]
	if not mission then
		mission = cloneMission()
		playerMissions[player] = mission
	end

	ObjectiveManager.SetPlayerObjectives(player, mission)
	CyberScenarioManager.SyncObjectives(player)
end

Players.PlayerAdded:Connect(function(player)
	playerMissions[player] = cloneMission()

	task.delay(2, function()
		syncPlayerObjectives(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	playerMissions[player] = cloneMission()
	syncPlayerObjectives(player)
end

Players.PlayerRemoving:Connect(function(player)
	playerMissions[player] = nil
end)

local function completeTaskTwo(player)
	local mission = playerMissions[player]
	if not mission then
		return
	end

	mission[2].status = "Completed"
	mission[3].status = "In Progress"
	ObjectiveManager.SetPlayerObjectives(player, mission)
end
