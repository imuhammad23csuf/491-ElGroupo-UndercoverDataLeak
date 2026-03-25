local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "Guard" then
			local startPart = obj:FindFirstChild("StartPoint")
			if startPart and startPart:IsA("BasePart") then
				obj:PivotTo(startPart.CFrame)
			end
		end
	end
end

local function teleportPlayerToChapterStart(player)
	local character = player.Character
	if not character then
		return
	end

	local currentChapter = player:GetAttribute("CurrentChapter") or 1
	local spawnName = "Chapter" .. tostring(currentChapter) .. "Spawn"
	local spawnPart = workspace:FindFirstChild(spawnName)

	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	else
		warn("No chapter spawn found for", spawnName)
	end
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
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

local function resetSuspicion(player)
	local current = SuspicionManager.Get(player)
	if current > 0 then
		SuspicionManager.Reduce(current, player)
	end
end

local function teleportPlayerToCheckpoint(player)
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
	teleportPlayerToCheckpoint(player)
	resetSuspicion(player)

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