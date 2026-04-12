-- CyberScenarioManager.server.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

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

LoadScenarioRemote.OnServerInvoke = function(player, scenarioId)
	return CyberScenarioManager.LoadScenario(player, scenarioId)
end

CheckSolutionRemote.OnServerInvoke = function(player, input)
	return CyberScenarioManager.CheckSolution(player, input)
end

GetHintRemote.OnServerInvoke = function(player)
	return CyberScenarioManager.GetHint(player)
end

GetSessionInfoRemote.OnServerInvoke = function(player)
	return CyberScenarioManager.GetSessionInfo(player)
end

CleanupRemote.OnServerEvent:Connect(function(player)
	CyberScenarioManager.Cleanup(player)
end)

Players.PlayerRemoving:Connect(function(player)
	CyberScenarioManager.Cleanup(player)
end)