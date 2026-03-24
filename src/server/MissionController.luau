local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectiveManager = require(ReplicatedStorage:WaitForChild("ObjectiveManager"))

-- This is our master list of tasks for Sprint 1
local defaultMission = {
	{ id = "task1", text = "Infiltrate the outer perimeter.", status = "In Progress" },
	{ id = "task2", text = "Copy the Guard's Key Code.", status = "Not Started" },
	{ id = "task3", text = "Unlock the sliding door.", status = "Not Started" }
}

-- Give the player the mission when they join
Players.PlayerAdded:Connect(function(player)
	-- Wait a brief moment for their UI to load
	task.wait(2)
	ObjectiveManager.SetPlayerObjectives(player, defaultMission)
end)

-- Example: How you will mark a task as complete later!
-- You can call a function like this from your Ghost Key script when the time comes.
local function completeTaskTwo(player)
	defaultMission[2].status = "Completed"
	defaultMission[3].status = "In Progress"
	ObjectiveManager.SetPlayerObjectives(player, defaultMission)
end
