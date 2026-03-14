-- lets layers interact with server to initate CyberScenario
-- currently just opens tablet due to scenarios not being implemented
-- Fires event to client when player interacts with server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OpenTabletEvent = ReplicatedStorage:WaitForChild("OpenTabletEvent")

-- Find the ProximityPrompt in the model
local model = Workspace:WaitForChild("servers"):WaitForChild("Interactable server")
local prompt = model:FindFirstChild("ProximityPrompt", true)

if prompt then
	prompt.Triggered:Connect(function(player)
		-- Fire event to the specific client
		OpenTabletEvent:FireClient(player)
		print("Fired OpenTabletEvent to", player.Name)
	end)
	print("Server terminal interaction script loaded")
else
	warn("ProximityPrompt not found in Interactable server")
end