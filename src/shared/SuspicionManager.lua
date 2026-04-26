local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SuspicionManager = {}

local MAX_VAL = 100
local DEBUG_ENABLED = true
local DECAY_INTERVAL_SECONDS = 1
local DECAY_AMOUNT = 1.5
local ADDITION_INTERVAL_SECONDS = 0.35
local ADDITION_AMOUNT_PER_TICK = 1.5
local AUTHORITATIVE_SYNC_INTERVAL_SECONDS = 0.5
local SYNC_REQUEST_COOLDOWN = 0.5

local bindable = Instance.new("BindableEvent")
SuspicionManager.Changed = bindable.Event

local function debugLog(message)
	if DEBUG_ENABLED then
		warn(("[SuspicionManager] %s"):format(message))
	end
end

local function isFiniteNumber(value)
	local n = tonumber(value)
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

local function clampNumber(value)
	local n = isFiniteNumber(value)
	if not n then
		return 0
	end
	return math.clamp(n, 0, MAX_VAL)
end

local function clampDelta(value)
	local n = isFiniteNumber(value)
	if not n then
		return 0
	end
	return math.max(0, n)
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
local pendingAdditionsByUserId = {}
local syncRequestByUserId = {}
local attributeConnectionsByUserId = {}
local attributeRepairLogByUserId = {}
local decayLoopStarted = false
local additionLoopStarted = false
local authoritativeSyncLoopStarted = false

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

local function restoreTrustedSuspicionAttribute(player)
	if not player or not player.Parent then
		return
	end

	local trusted = getServerSuspicion(player)
	if clampNumber(player:GetAttribute("Suspicion")) == trusted then
		return
	end

	local now = os.clock()
	local lastLoggedAt = attributeRepairLogByUserId[player.UserId] or 0
	if now - lastLoggedAt >= 1 then
		attributeRepairLogByUserId[player.UserId] = now
		debugLog(("Restored server-owned suspicion for %s -> %s"):format(player.Name, tostring(trusted)))
	end

	syncPlayerAttribute(player, trusted)
	pushToClient(player, trusted)
end

local function watchSuspicionAttribute(player)
	if not player then
		return
	end

	local existing = attributeConnectionsByUserId[player.UserId]
	if existing then
		existing:Disconnect()
	end

	attributeConnectionsByUserId[player.UserId] = player:GetAttributeChangedSignal("Suspicion"):Connect(function()
		restoreTrustedSuspicionAttribute(player)
	end)
	restoreTrustedSuspicionAttribute(player)
end

local function withinSyncCooldown(player)
	if not player then
		return false
	end

	local now = os.clock()
	local last = syncRequestByUserId[player.UserId] or 0
	if now - last < SYNC_REQUEST_COOLDOWN then
		return false
	end

	syncRequestByUserId[player.UserId] = now
	return true
end

local function setServerSuspicion(player, newValue)
	if not player then
		return
	end

	local clamped = clampNumber(newValue)
	pendingAdditionsByUserId[player.UserId] = nil
	serverSuspicionByUserId[player.UserId] = clamped
	syncPlayerAttribute(player, clamped)
	pushToClient(player, clamped)
	bindable:Fire(clamped, player)
end

local function applyServerDelta(player, delta, options)
	if not player then
		return
	end

	local signedDelta = isFiniteNumber(delta)
	if not signedDelta or signedDelta == 0 then
		return
	end

	local currentValue = getServerSuspicion(player)
	local newValue = clampNumber(currentValue + signedDelta)
	serverSuspicionByUserId[player.UserId] = newValue
	syncPlayerAttribute(player, newValue)
	if not (options and options.silent) then
		debugLog(("%s %+.1f -> %.1f"):format(player.Name, signedDelta, newValue))
	end
	pushToClient(player, newValue)
	bindable:Fire(newValue, player)
end

local function enqueueServerAddition(player, amount)
	if not player or not player.Parent then
		return
	end

	local delta = clampDelta(amount)
	if delta <= 0 then
		return
	end

	local currentValue = getServerSuspicion(player)
	local room = MAX_VAL - currentValue
	if room <= 0 then
		return
	end

	local userId = player.UserId
	local pending = pendingAdditionsByUserId[userId] or 0
	pendingAdditionsByUserId[userId] = math.min(pending + delta, room)
end

local function startServerAdditionLoop()
	if additionLoopStarted or not RunService:IsServer() then
		return
	end

	additionLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(ADDITION_INTERVAL_SECONDS)
			for userId, pending in pairs(pendingAdditionsByUserId) do
				if pending and pending > 0 then
					local player = Players:GetPlayerByUserId(userId)
					if player then
						local room = MAX_VAL - getServerSuspicion(player)
						if room > 0 then
							local step = math.min(pending, ADDITION_AMOUNT_PER_TICK, room)
							pendingAdditionsByUserId[userId] = pending - step
							if pendingAdditionsByUserId[userId] <= 0.001 then
								pendingAdditionsByUserId[userId] = nil
							end
							applyServerDelta(player, step)
						else
							pendingAdditionsByUserId[userId] = nil
						end
					else
						pendingAdditionsByUserId[userId] = nil
					end
				else
					pendingAdditionsByUserId[userId] = nil
				end
			end
		end
	end)
end

local function startServerDecayLoop()
	if decayLoopStarted or not RunService:IsServer() then
		return
	end

	decayLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(DECAY_INTERVAL_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				if getServerSuspicion(player) > 0 then
					-- Server-owned decay preserves the old gameplay pacing without trusting the client.
					applyServerDelta(player, -DECAY_AMOUNT, { silent = true })
				end
			end
		end
	end)
end

local function startAuthoritativeSyncLoop()
	if authoritativeSyncLoopStarted or not RunService:IsServer() then
		return
	end

	authoritativeSyncLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(AUTHORITATIVE_SYNC_INTERVAL_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				local trusted = getServerSuspicion(player)
				restoreTrustedSuspicionAttribute(player)
				pushToClient(player, trusted)
			end
		end
	end)
end

function SuspicionManager.Add(amount, player)
	local delta = clampDelta(amount)
	if delta <= 0 then
		return
	end

	if RunService:IsServer() then
		if player then
			enqueueServerAddition(player, delta)
		else
			for _, candidate in ipairs(Players:GetPlayers()) do
				enqueueServerAddition(candidate, delta)
			end
		end
	else
		debugLog("Rejected client attempt to add suspicion directly.")
	end
end

function SuspicionManager.Reduce(amount, player)
	local delta = clampDelta(amount)
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
		debugLog("Rejected client attempt to reduce suspicion directly.")
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
		debugLog("Rejected client attempt to set suspicion directly.")
	end
end

function SuspicionManager.GetSuspicion(player)
	return SuspicionManager.Get(player)
end

local function applySignedSuspicion(amount, player)
	local value = isFiniteNumber(amount) or 0
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
	local value = isFiniteNumber(amount) or 0
	if value > 0 then
		SuspicionManager.Reduce(value, player)
	elseif value < 0 then
		SuspicionManager.Add(-value, player)
	end
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player)
		setServerSuspicion(player, 0)
		watchSuspicionAttribute(player)
		debugLog(("PlayerAdded sync -> %s = 0"):format(player.Name))
	end)

	Players.PlayerRemoving:Connect(function(player)
		local connection = attributeConnectionsByUserId[player.UserId]
		if connection then
			connection:Disconnect()
		end
		attributeConnectionsByUserId[player.UserId] = nil
		attributeRepairLogByUserId[player.UserId] = nil
		serverSuspicionByUserId[player.UserId] = nil
		pendingAdditionsByUserId[player.UserId] = nil
		syncRequestByUserId[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		setServerSuspicion(player, 0)
		watchSuspicionAttribute(player)
	end

	startServerDecayLoop()
	startServerAdditionLoop()
	startAuthoritativeSyncLoop()

	actionRemote.OnServerEvent:Connect(function(player, action)
		if type(action) ~= "string" then
			return
		end

		if action ~= "Get" and action ~= "RequestSync" then
			-- Security fix: clients can request a fresh snapshot only; they can never mutate suspicion.
			debugLog(("Rejected insecure suspicion action '%s' from %s"):format(tostring(action), player.Name))
			return
		end

		if not withinSyncCooldown(player) then
			return
		end

		pushToClient(player, getServerSuspicion(player))
	end)
else
	updateRemote.OnClientEvent:Connect(function(newValue)
		localSuspicion = clampNumber(newValue)
		debugLog(("Client sync -> %.1f"):format(localSuspicion))
		bindable:Fire(localSuspicion)
	end)

	task.defer(function()
		actionRemote:FireServer("RequestSync")
	end)
end

return SuspicionManager
