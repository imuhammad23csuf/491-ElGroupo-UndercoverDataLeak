local ObjectiveManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Auto-create the RemoteEvent if it doesn't exist
local updateRemote = ReplicatedStorage:FindFirstChild("ObjectiveUpdate")
if not updateRemote and RunService:IsServer() then
	updateRemote = Instance.new("RemoteEvent")
	updateRemote.Name = "ObjectiveUpdate"
	updateRemote.Parent = ReplicatedStorage
end

local bindable = Instance.new("BindableEvent")
ObjectiveManager.Changed = bindable.Event

local currentObjectives = {}
local currentObjectiveGroups = {}

-- === CLIENT SIDE ===
-- The UI listens for updates from the server
if RunService:IsClient() then
	updateRemote = ReplicatedStorage:WaitForChild("ObjectiveUpdate")
	updateRemote.OnClientEvent:Connect(function(objectivesList, category)
		if type(objectivesList) ~= "table" then
			return
		end

		if type(category) == "string" and category ~= "" then
			currentObjectiveGroups[category] = objectivesList
		else
			currentObjectives = objectivesList
		end

		bindable:Fire(objectivesList, category)
	end)
end

-- === SERVER SIDE ===
-- The Server uses this to send new tasks to a specific player.
-- The optional category argument allows separate objective groups.
function ObjectiveManager.SetPlayerObjectives(player, objectivesList, category)
	if RunService:IsServer() and player then
		updateRemote:FireClient(player, objectivesList, category)
	end
end

-- The Server uses this to update tasks for everyone in the game.
-- The optional category argument allows separate objective groups.
function ObjectiveManager.SetGlobalObjectives(objectivesList, category)
	if RunService:IsServer() then
		updateRemote:FireAllClients(objectivesList, category)
	end
end

function ObjectiveManager.Get(category)
	if type(category) == "string" and category ~= "" then
		return currentObjectiveGroups[category] or {}
	end

	return currentObjectives
end

return ObjectiveManager
