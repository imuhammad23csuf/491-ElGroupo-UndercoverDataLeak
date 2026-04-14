-- Suspicion Manager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SuspicionManager = {}

local MAX_VAL = 100
local DEBUG_ENABLED = true

local bindable = Instance.new("BindableEvent")
SuspicionManager.Changed = bindable.Event

local function debugLog(message)
	if DEBUG_ENABLED then
		warn(("[SuspicionManager] %s"):format(message))
	end
end

local function clampNumber(value)
	return math.clamp(tonumber(value) or 0, 0, MAX_VAL)
end

local function getSharedRoot()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared and RunService:IsClient() then
		shared = ReplicatedStorage:WaitForChild("Shared", 10)
	end
	if shared then
		return shared
	end
	return ReplicatedStorage
end

local updateRemote
local actionRemote

if RunService:IsServer() then
	local root = getSharedRoot()

	updateRemote = root:FindFirstChild("SuspicionUpdate")
	if not updateRemote then
		updateRemote = Instance.new("RemoteEvent")
		updateRemote.Name = "SuspicionUpdate"
		updateRemote.Parent = root
	end

	actionRemote = root:FindFirstChild("SuspicionAction")
	if not actionRemote then
		actionRemote = Instance.new("RemoteEvent")
		actionRemote.Name = "SuspicionAction"
		actionRemote.Parent = root
	end
else
	local root = getSharedRoot()
	updateRemote = root:WaitForChild("SuspicionUpdate")
	actionRemote = root:WaitForChild("SuspicionAction")
end

local localSuspicion = 0
local serverSuspicionByUserId = {}

local function getServerSuspicion(player)
	if not player then
		return 0
	end
	return serverSuspicionByUserId[player.UserId] or 0
end

local function pushToClient(player, newValue)
	if player and player.Parent then
		updateRemote:FireClient(player, newValue)
	end
end

local function syncPlayerAttribute(player, newValue)
	if player and player.Parent then
		player:SetAttribute("Suspicion", clampNumber(newValue))
	end
end

local function setServerSuspicion(player, newValue)
	if not player then
		return
	end

	local clamped = clampNumber(newValue)
	serverSuspicionByUserId[player.UserId] = clamped
	syncPlayerAttribute(player, clamped)
	pushToClient(player, clamped)
	bindable:Fire(clamped, player)
end

local function applyServerDelta(player, delta)
	if not player then
		return
	end
	local currentValue = getServerSuspicion(player)
	local newValue = clampNumber(currentValue + delta)
	serverSuspicionByUserId[player.UserId] = newValue
	syncPlayerAttribute(player, newValue)
	debugLog(("%s %+d -> %d"):format(player.Name, delta, newValue))
	pushToClient(player, newValue)
	bindable:Fire(newValue, player)
end

function SuspicionManager.Add(amount, player)
	local delta = math.max(0, tonumber(amount) or 0)
	if delta <= 0 then
		return
	end

	if RunService:IsServer() then
		if player then
			applyServerDelta(player, delta)
		else
			for _, candidate in ipairs(Players:GetPlayers()) do
				applyServerDelta(candidate, delta)
			end
		end
	else
		actionRemote:FireServer("Add", delta)
	end
end

function SuspicionManager.Reduce(amount, player)
	local delta = math.max(0, tonumber(amount) or 0)
	if delta <= 0 then
		return
	end

	if RunService:IsServer() then
		if player then
			applyServerDelta(player, -delta)
		else
			for _, candidate in ipairs(Players:GetPlayers()) do
				applyServerDelta(candidate, -delta)
			end
		end
	else
		actionRemote:FireServer("Reduce", delta)
	end
end

function SuspicionManager.Get(player)
	if RunService:IsServer() then
		if player then
			return getServerSuspicion(player)
		end
		return 0
	end

	return localSuspicion
end

function SuspicionManager.Set(value, player)
	local clamped = clampNumber(value)
	if RunService:IsServer() then
		if player then
			setServerSuspicion(player, clamped)
		else
			for _, candidate in ipairs(Players:GetPlayers()) do
				setServerSuspicion(candidate, clamped)
			end
		end
	else
		local current = SuspicionManager.Get()
		if clamped > current then
			SuspicionManager.Add(clamped - current)
		elseif clamped < current then
			SuspicionManager.Reduce(current - clamped)
		end
	end
end

function SuspicionManager.GetSuspicion(player)
	return SuspicionManager.Get(player)
end

local function applySignedSuspicion(amount, player)
	local value = tonumber(amount) or 0
	if value > 0 then
		SuspicionManager.Add(value, player)
	elseif value < 0 then
		SuspicionManager.Reduce(-value, player)
	end
end

function SuspicionManager.AddSuspicion(player, amount)
	applySignedSuspicion(amount, player)
end

function SuspicionManager.addSuspicion(player, amount)
	applySignedSuspicion(amount, player)
end

function SuspicionManager.ReduceSuspicion(player, amount)
	local value = tonumber(amount) or 0
	if value > 0 then
		SuspicionManager.Reduce(value, player)
	elseif value < 0 then
		SuspicionManager.Add(-value, player)
	end
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player)
		setServerSuspicion(player, 0)
		debugLog(("PlayerAdded sync -> %s = 0"):format(player.Name))
	end)

	Players.PlayerRemoving:Connect(function(player)
		serverSuspicionByUserId[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		setServerSuspicion(player, 0)
	end

	actionRemote.OnServerEvent:Connect(function(player, action, amount)
		if action == "Reduce" then
			SuspicionManager.Reduce(amount, player)
		elseif action == "Add" then
			SuspicionManager.Add(amount, player)
		elseif action == "Get" then
			pushToClient(player, getServerSuspicion(player))
		end
	end)
else
	updateRemote.OnClientEvent:Connect(function(newValue)
		localSuspicion = clampNumber(newValue)
		debugLog(("Client sync -> %d"):format(localSuspicion))
		bindable:Fire(localSuspicion)
	end)

	task.defer(function()
		actionRemote:FireServer("Get", 0)
	end)
end

return SuspicionManager
