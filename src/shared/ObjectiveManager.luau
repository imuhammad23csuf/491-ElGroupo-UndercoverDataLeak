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

-- === CLIENT SIDE ===
-- The UI listens for updates from the server
if RunService:IsClient() then
	updateRemote = ReplicatedStorage:WaitForChild("ObjectiveUpdate")
	updateRemote.OnClientEvent:Connect(function(objectivesList)
		currentObjectives = objectivesList
		bindable:Fire(currentObjectives)
	end)
end

-- === SERVER SIDE ===
-- The Server uses this to send new tasks to a specific player
function ObjectiveManager.SetPlayerObjectives(player, objectivesList)
	if RunService:IsServer() and player then
		updateRemote:FireClient(player, objectivesList)
	end
end

-- The Server uses this to update tasks for everyone in the game
function ObjectiveManager.SetGlobalObjectives(objectivesList)
	if RunService:IsServer() then
		updateRemote:FireAllClients(objectivesList)
	end
end

function ObjectiveManager.Get()
	return currentObjectives
end

return ObjectiveManager
