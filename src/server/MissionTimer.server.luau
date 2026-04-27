-- MissionTimer.server.luau
-- Tracks mission completion times, saves best times to DataStore,
-- and exposes RemoteEvents for client HUD and leaderboard updates.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ─── DataStore ───────────────────────────────────────────────────────────────
local BestTimesStore = DataStoreService:GetDataStore("MissionBestTimes_v1")

-- ─── RemoteEvents (create folder if needed) ──────────────────────────────────
local Remotes = ReplicatedStorage:FindFirstChild("MissionTimerRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "MissionTimerRemotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrMakeRemote(class, name)
	local existing = Remotes:FindFirstChild(name)
	if existing then return existing end
	local obj = Instance.new(class)
	obj.Name = name
	obj.Parent = Remotes
	return obj
end

-- Server → Client
local EvStartTimer   = getOrMakeRemote("RemoteEvent",    "StartTimer")   -- fires when mission begins
local EvStopTimer    = getOrMakeRemote("RemoteEvent",    "StopTimer")    -- fires with elapsed seconds
local EvNewBestTime  = getOrMakeRemote("RemoteEvent",    "NewBestTime")  -- fires when player sets new best
-- Client → Server (optional manual trigger fallback)
local EvMissionStart = getOrMakeRemote("RemoteEvent",    "MissionStart")
local EvMissionEnd   = getOrMakeRemote("RemoteEvent",    "MissionEnd")
-- Server → All clients (leaderboard refresh)
local EvLeaderboard  = getOrMakeRemote("RemoteEvent",    "LeaderboardUpdate")
-- Server → Client (send personal best on join)
local FnGetBestTime  = getOrMakeRemote("RemoteFunction", "GetMyBestTime")
local FnGetTimerState = getOrMakeRemote("RemoteFunction", "GetTimerState")

EvStartTimer.Name   = "StartTimer"
EvStopTimer.Name    = "StopTimer"
EvNewBestTime.Name  = "NewBestTime"
EvMissionStart.Name = "MissionStart"
EvMissionEnd.Name   = "MissionEnd"
EvLeaderboard.Name  = "LeaderboardUpdate"
FnGetBestTime.Name  = "GetMyBestTime"
FnGetTimerState.Name = "GetTimerState"

-- ─── State ───────────────────────────────────────────────────────────────────
-- activeMissions[player] = { startTick: number }
local activeMissions = {}
local bestTimeCache = {}
local bestTimeLoaded = {}
local requestWarnings = {}
local MAX_BEST_TIME = 60 * 60 * 24

local function sanitizeElapsedTime(value)
	local n = tonumber(value)
	if not n or n ~= n or n == math.huge or n == -math.huge or n < 0 or n > MAX_BEST_TIME then
		return nil
	end

	return math.floor(n * 100 + 0.5) / 100
end

local function warnRejectedClientRemote(player, remoteName)
	local userId = player.UserId
	requestWarnings[userId] = requestWarnings[userId] or {}

	local now = os.clock()
	local last = requestWarnings[userId][remoteName] or 0
	if now - last < 1 then
		return
	end

	requestWarnings[userId][remoteName] = now
	warn(("[MissionTimer] Ignored client-authored %s request from %s"):format(remoteName, player.Name))
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function datastoreKey(player)
	return "player_" .. player.UserId
end

local function loadBestTime(player)
	if bestTimeLoaded[player] then
		return bestTimeCache[player]
	end

	local ok, result = pcall(function()
		return BestTimesStore:GetAsync(datastoreKey(player))
	end)
	if ok then
		local sanitized = sanitizeElapsedTime(result)
		bestTimeCache[player] = sanitized
		bestTimeLoaded[player] = true
		return sanitized
	end

	warn("[MissionTimer] Failed to load best time for", player.Name, result)
	return nil
end

local function saveBestTime(player, elapsed)
	local sanitizedElapsed = sanitizeElapsedTime(elapsed)
	if not sanitizedElapsed then
		return bestTimeCache[player]
	end

	local ok, result = pcall(function()
		return BestTimesStore:UpdateAsync(datastoreKey(player), function(oldValue)
			local currentBest = sanitizeElapsedTime(oldValue)
			if currentBest and currentBest <= sanitizedElapsed then
				return currentBest
			end
			return sanitizedElapsed
		end)
	end)
	if not ok then
		warn("[MissionTimer] Failed to save best time for", player.Name, result)
		return bestTimeCache[player]
	end

	local saved = sanitizeElapsedTime(result) or sanitizedElapsed
	bestTimeCache[player] = saved
	bestTimeLoaded[player] = true
	return saved
end

-- Returns top-N best times as { {name, time} } sorted ascending
local TOP_N = 10
local function buildLeaderboardData()
	-- We read from a sorted DataStore for efficiency in production;
	-- here we use an OrderedDataStore pattern via a second store.
	-- For simplicity this version collects from connected players only
	-- and is easily swappable with an OrderedDataStore.
	local rows = {}
	for _, player in Players:GetPlayers() do
		local best = bestTimeCache[player]
		if best then
			table.insert(rows, { name = player.Name, time = best })
		end
	end
	table.sort(rows, function(a, b) return a.time < b.time end)
	local trimmed = {}
	for i = 1, math.min(TOP_N, #rows) do
		table.insert(trimmed, rows[i])
	end
	return trimmed
end

local function broadcastLeaderboard()
	local data = buildLeaderboardData()
	EvLeaderboard:FireAllClients(data)
end

-- ─── Core API ────────────────────────────────────────────────────────────────

local function getMissionElapsed(player)
	local mission = activeMissions[player]
	if not mission then
		return 0
	end

	return sanitizeElapsedTime(tick() - mission.startTick) or 0
end

--- Call this from MissionController (or any server script) when a mission begins.
local function startMission(player, initialElapsed)
	if activeMissions[player] then
		EvStartTimer:FireClient(player, getMissionElapsed(player))
		return
	end

	local elapsed = sanitizeElapsedTime(initialElapsed) or 0
	activeMissions[player] = { startTick = tick() - elapsed }
	EvStartTimer:FireClient(player, elapsed)
	print(("[MissionTimer] Mission started for %s at %.2fs"):format(player.Name, elapsed))
end

--- Call this when the mission ends (caught OR escaped).
--- outcome: "escaped" | "caught" | "completed" | "reset"
--- Returns elapsed seconds.
local function endMission(player, outcome)
	local mission = activeMissions[player]
	if not mission then
		warn("[MissionTimer] No active mission for", player.Name)
		return nil
	end

	if outcome ~= "escaped" and outcome ~= "caught" and outcome ~= "completed" and outcome ~= "reset" then
		outcome = "caught"
	end

	local elapsed = getMissionElapsed(player)
	activeMissions[player] = nil

	-- Always send elapsed to client regardless of outcome
	EvStopTimer:FireClient(player, elapsed, outcome)

	-- Only save/compare best time on successful mission completion.
	if outcome == "escaped" or outcome == "completed" then
		local previous = loadBestTime(player)
		local newBest = saveBestTime(player, elapsed)
		if newBest and (previous == nil or newBest < previous) then
			EvNewBestTime:FireClient(player, newBest, previous)
			print(("[MissionTimer] NEW BEST for %s: %.2fs (was %s)"):format(
				player.Name, newBest, previous and ("%.2fs"):format(previous) or "none"))
		end
		broadcastLeaderboard()
	end

	print(("[MissionTimer] Mission ended for %s | outcome=%s | time=%.2fs"):format(
		player.Name, outcome, elapsed))
	return elapsed
end

-- ─── Expose functions via _G for other server scripts ────────────────────────
-- Usage from MissionController:
--   _G.MissionTimer.startMission(player)
--   _G.MissionTimer.endMission(player, "escaped")
_G.MissionTimer = {
	startMission = startMission,
	endMission   = endMission,
	getElapsed = getMissionElapsed,
	isMissionActive = function(player)
		return activeMissions[player] ~= nil
	end,
	completeMission = function(player)
		return endMission(player, "completed")
	end,
	resetMission = function(player)
		return endMission(player, "reset")
	end,
}

-- ─── Optional: listen to RemoteEvents from client (fallback / debug) ─────────
EvMissionStart.OnServerEvent:Connect(function(player)
	warnRejectedClientRemote(player, "MissionStart")
end)

EvMissionEnd.OnServerEvent:Connect(function(player)
	warnRejectedClientRemote(player, "MissionEnd")
end)

-- ─── Serve personal best on request ─────────────────────────────────────────
FnGetBestTime.OnServerInvoke = function(player)
	return loadBestTime(player)
end

FnGetTimerState.OnServerInvoke = function(player)
	local mission = activeMissions[player]
	if not mission then
		return {
			running = false,
			elapsed = 0,
		}
	end

	return {
		running = true,
		elapsed = getMissionElapsed(player),
	}
end

-- ─── Cleanup on leave ────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	if activeMissions[player] then
		-- Mission abandoned — don't save time
		activeMissions[player] = nil
		print("[MissionTimer] Cleaned up abandoned mission for", player.Name)
	end
	bestTimeCache[player] = nil
	bestTimeLoaded[player] = nil
	requestWarnings[player.UserId] = nil
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		loadBestTime(player)
		broadcastLeaderboard()
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		loadBestTime(player)
	end)
end

-- ─── Refresh leaderboard every 60s for late-joining players ──────────────────
task.spawn(function()
	while true do
		task.wait(60)
		broadcastLeaderboard()
	end
end)

print("[MissionTimer] Server module loaded.")
