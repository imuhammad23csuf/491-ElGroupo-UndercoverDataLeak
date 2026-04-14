local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(Shared:WaitForChild("SuspicionManager"))

local remotesFolder = ReplicatedStorage:FindFirstChild("CaughtRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "CaughtRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local showCaughtEvent = remotesFolder:FindFirstChild("ShowCaught")
if not showCaughtEvent then
	showCaughtEvent = Instance.new("RemoteEvent")
	showCaughtEvent.Name = "ShowCaught"
	showCaughtEvent.Parent = remotesFolder
end

local handlingCaughtByUserId = {}

local function resetGuards()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local startPart = obj:FindFirstChild("StartPoint", true)
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			if startPart and startPart:IsA("BasePart") and humanoid then
				obj:PivotTo(startPart.CFrame)
			end
		end
	end
end

local function getSpawnCandidates(player)
	local candidates = {}
	local currentChapter = tonumber(player:GetAttribute("CurrentChapter")) or 1
	local exactNames = {
		("Chapter%dSpawn"):format(currentChapter),
		("Chapter%dCheckpoint"):format(currentChapter),
		"Checkpoint",
	}

	for _, targetName in ipairs(exactNames) do
		local found = Workspace:FindFirstChild(targetName, true)
		if found and found:IsA("BasePart") then
			table.insert(candidates, found)
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			table.insert(candidates, obj)
		elseif obj:IsA("BasePart") then
			local lowerName = obj.Name:lower()
			if lowerName:find("spawn", 1, true) or lowerName:find("checkpoint", 1, true) then
				table.insert(candidates, obj)
			end
		end
	end

	return candidates
end

local function teleportPlayerToCheckpoint(player)
	local character = player.Character
	if not character then
		return false
	end

	for _, spawnPart in ipairs(getSpawnCandidates(player)) do
		if spawnPart and spawnPart.Parent then
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
			return true
		end
	end

	return false
end

local function freezePlayer(player, shouldFreeze)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if shouldFreeze then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
	end
end

local function resetSuspicion(player)
	SuspicionManager.Set(0, player)
end

local function handleCaught(player)
	if not player or not player.Parent then
		return
	end

	if handlingCaughtByUserId[player.UserId] then
		return
	end

	handlingCaughtByUserId[player.UserId] = true

	showCaughtEvent:FireClient(player, true)
	freezePlayer(player, true)

	task.wait(2)

	resetGuards()
	if not teleportPlayerToCheckpoint(player) then
		pcall(function()
			player:LoadCharacter()
		end)
	end
	resetSuspicion(player)

	task.wait(0.2)
	freezePlayer(player, false)
	showCaughtEvent:FireClient(player, false)

	handlingCaughtByUserId[player.UserId] = nil
end

SuspicionManager.Changed:Connect(function(newValue, player)
	if player and newValue >= 100 then
		handleCaught(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	handlingCaughtByUserId[player.UserId] = nil
end)
