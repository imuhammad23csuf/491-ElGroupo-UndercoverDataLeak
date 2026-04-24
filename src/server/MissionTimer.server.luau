-- MissionTimer.server.luau
-- Tracks mission completion times, saves best times to DataStore,
-- and exposes RemoteEvents for client HUD and leaderboard updates.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

EvStartTimer.Name   = "StartTimer"
EvStopTimer.Name    = "StopTimer"
EvNewBestTime.Name  = "NewBestTime"
EvMissionStart.Name = "MissionStart"
EvMissionEnd.Name   = "MissionEnd"
EvLeaderboard.Name  = "LeaderboardUpdate"
FnGetBestTime.Name  = "GetMyBestTime"

-- ─── State ───────────────────────────────────────────────────────────────────
-- activeMissions[player] = { startTick: number }
local activeMissions = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function datastoreKey(player: Player): string
	return "player_" .. player.UserId
end

local function loadBestTime(player: Player): number?
	local ok, result = pcall(function()
		return BestTimesStore:GetAsync(datastoreKey(player))
	end)
	if ok then return result end
	warn("[MissionTimer] Failed to load best time for", player.Name, result)
	return nil
end

local function saveBestTime(player: Player, time: number)
	local ok, err = pcall(function()
		BestTimesStore:SetAsync(datastoreKey(player), time)
	end)
	if not ok then
		warn("[MissionTimer] Failed to save best time for", player.Name, err)
	end
end

-- Returns top-N best times as { {name, time} } sorted ascending
local TOP_N = 10
local function buildLeaderboardData(): {{name: string, time: number}}
	-- We read from a sorted DataStore for efficiency in production;
	-- here we use an OrderedDataStore pattern via a second store.
	-- For simplicity this version collects from connected players only
	-- and is easily swappable with an OrderedDataStore.
	local rows = {}
	for _, player in Players:GetPlayers() do
		local best = loadBestTime(player)
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

--- Call this from MissionController (or any server script) when a mission begins.
local function startMission(player: Player)
	if activeMissions[player] then
		warn("[MissionTimer] Mission already active for", player.Name)
		return
	end
	activeMissions[player] = { startTick = tick() }
	EvStartTimer:FireClient(player)
	print("[MissionTimer] Mission started for", player.Name)
end

--- Call this when the mission ends (caught OR escaped).
--- outcome: "escaped" | "caught"
--- Returns elapsed seconds.
local function endMission(player: Player, outcome: string): number?
	local mission = activeMissions[player]
	if not mission then
		warn("[MissionTimer] No active mission for", player.Name)
		return nil
	end

	local elapsed = math.floor((tick() - mission.startTick) * 100 + 0.5) / 100 -- 2 dp
	activeMissions[player] = nil

	-- Always send elapsed to client regardless of outcome
	EvStopTimer:FireClient(player, elapsed, outcome)

	-- Only save/compare best time on successful escape
	if outcome == "escaped" then
		local previous = loadBestTime(player)
		if previous == nil or elapsed < previous then
			saveBestTime(player, elapsed)
			EvNewBestTime:FireClient(player, elapsed, previous)
			print(("[MissionTimer] NEW BEST for %s: %.2fs (was %s)"):format(
				player.Name, elapsed, previous and ("%.2fs"):format(previous) or "none"))
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
}

-- ─── Optional: listen to RemoteEvents from client (fallback / debug) ─────────
EvMissionStart.OnServerEvent:Connect(function(player)
	-- Only allow if no active mission (guard against exploits spamming)
	if not activeMissions[player] then
		startMission(player)
	end
end)

EvMissionEnd.OnServerEvent:Connect(function(player, outcome)
	-- Validate outcome string
	if outcome ~= "escaped" and outcome ~= "caught" then outcome = "caught" end
	endMission(player, outcome)
end)

-- ─── Serve personal best on request ─────────────────────────────────────────
FnGetBestTime.OnServerInvoke = function(player)
	return loadBestTime(player)
end

-- ─── Cleanup on leave ────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	if activeMissions[player] then
		-- Mission abandoned — don't save time
		activeMissions[player] = nil
		print("[MissionTimer] Cleaned up abandoned mission for", player.Name)
	end
end)

-- ─── Refresh leaderboard every 60s for late-joining players ──────────────────
task.spawn(function()
	while true do
		task.wait(60)
		broadcastLeaderboard()
	end
end)

print("[MissionTimer] Server module loaded.")
