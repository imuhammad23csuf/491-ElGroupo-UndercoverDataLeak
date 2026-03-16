-- GuardOutside (Patrol + Basic Chase + Batched Suspicion)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SuspicionManager = require(ReplicatedStorage:WaitForChild("SuspicionManager"))

local GUARD = Workspace:WaitForChild("GuardOutside")
local RIG = GUARD:WaitForChild("Rig")
local HUMANOID = RIG:WaitForChild("Humanoid")
local HRP = RIG:WaitForChild("HumanoidRootPart")

-- === SETTINGS ===
local PATROL_SPEED = 8
local CHASE_SPEED = 13
local VISION_RANGE = 60
local VISION_ANGLE = math.cos(math.rad(60)) -- 120° total FOV
local CHASE_TIMEOUT = 5 -- seconds before giving up

-- Suspicion tuning (Outside)
local SUSPICION_TICK_SEEN = 1.5      -- add when actively seeing player (per tick)
local SUSPICION_TICK_RATE = 0.2    -- matches chase tick wait

-- === SUSPICION THROTTLE/BATCH ===
local SUSPICION_PUSH_INTERVAL = 0.5 -- send at most 2x/sec
local pendingSuspicion = {}         -- [userId] = accumulated delta

local function queueSuspicion(player, amount)
	if not player or not player.UserId then return end
	local uid = player.UserId
	pendingSuspicion[uid] = (pendingSuspicion[uid] or 0) + (amount or 0)
end

local function flushSuspicion(player)
	if not player or not player.UserId then return end
	local uid = player.UserId
	local delta = pendingSuspicion[uid] or 0
	if delta > 0 then
		SuspicionManager.Add(delta, player)
		pendingSuspicion[uid] = 0
	end
end

-- background flusher (flush all pending every interval)
task.spawn(function()
	while task.wait(SUSPICION_PUSH_INTERVAL) do
		for uid, delta in pairs(pendingSuspicion) do
			if delta and delta > 0 then
				local ply = Players:GetPlayerByUserId(uid)
				if ply then
					SuspicionManager.Add(delta, ply)
				end
				pendingSuspicion[uid] = 0
			end
		end
	end
end)

-- === WALK ANIMATION ===
local WALK_ANIM_ID = "http://www.roblox.com/asset/?id=913402848"
local Animator = HUMANOID:FindFirstChildOfClass("Animator") or Instance.new("Animator", HUMANOID)
local WalkTrack do
	local anim = Instance.new("Animation")
	anim.AnimationId = WALK_ANIM_ID
	WalkTrack = Animator:LoadAnimation(anim)
end

local function playWalk()
	if WalkTrack and not WalkTrack.IsPlaying then WalkTrack:Play() end
end
local function stopWalk()
	if WalkTrack and WalkTrack.IsPlaying then WalkTrack:Stop() end
end

-- === PATROL POINTS ===
local PatrolFolder = RIG:FindFirstChild("PatrolPoints") or GUARD:FindFirstChild("PatrolPoints")
local Waypoints = {}
if PatrolFolder then
	for _, part in ipairs(PatrolFolder:GetChildren()) do
		if part:IsA("BasePart") then table.insert(Waypoints, part) end
	end
	table.sort(Waypoints, function(a,b)
		local na = tonumber(a.Name:match("%d+")) or math.huge
		local nb = tonumber(b.Name:match("%d+")) or math.huge
		return na < nb
	end)
end
local currentPoint = 1

-- === HELPERS ===
local function safeAlive(h) return h and h.Health > 0 and h.Parent end

local function canSeePlayer(playerHRP)
	if not HRP or not playerHRP then return false end

	-- Lift the "eyes" up slightly so the ray doesn't scrape the floor/small bumps
	local eyePosition = HRP.Position + Vector3.new(0, 1.5, 0)
	local targetPosition = playerHRP.Position + Vector3.new(0, 1.5, 0)

	local diff = targetPosition - eyePosition
	local dist = diff.Magnitude
	if dist > VISION_RANGE then return false end

	local dir = diff.Unit
	if HRP.CFrame.LookVector:Dot(dir) < VISION_ANGLE then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {GUARD}
	local ray = Workspace:Raycast(eyePosition, dir * dist, params)

	if not ray then return true end
	local hitModel = ray.Instance and ray.Instance:FindFirstAncestorOfClass("Model")
	return hitModel and hitModel == playerHRP.Parent
end

local function findTarget()
	local nearestPlayer, nearestHRP, minDist = nil, nil, VISION_RANGE + 1
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and safeAlive(hum) then
			local dist = (hrp.Position - HRP.Position).Magnitude
			if dist < minDist and canSeePlayer(hrp) then
				minDist = dist
				nearestPlayer = player
				nearestHRP = hrp
			end
		end
	end
	return nearestPlayer, nearestHRP
end

-- === MAIN BEHAVIOR ===
local function patrol()
	while task.wait(0.2) do
		-- 1. Check for players
		local nearestPlayer, nearestHRP = findTarget()

		-- 2. If no player is seen, do patrol movement
		if not nearestPlayer and #Waypoints > 0 then
			local point = Waypoints[currentPoint]
			if point then
				HUMANOID.WalkSpeed = PATROL_SPEED
				playWalk()
				HUMANOID:MoveTo(point.Position)

				-- Look for players WHILE walking instead of waiting blindly
				local startMoveTime = os.clock()
				while (HRP.Position - point.Position).Magnitude > 4 do
					-- Safety timeout in case the guard gets stuck on a wall
					if os.clock() - startMoveTime > 8 then break end

					-- Check vision every 0.2 seconds while walking
					nearestPlayer, nearestHRP = findTarget()
					if nearestPlayer then 
						break -- Spotted someone! Break out of the walking loop!
					end
					task.wait(0.2)
				end

				-- Only wait at the waypoint if we didn't just spot someone
				if not nearestPlayer then
					stopWalk()
					currentPoint = (currentPoint % #Waypoints) + 1
					task.wait(1)
				end
			end
		end

		-- 3. Chase logic (With memory)
		if nearestPlayer and nearestHRP then
			HUMANOID.WalkSpeed = CHASE_SPEED
			playWalk()
			local startTime = os.clock()
			local lastSeenTime = os.clock() -- Gives the guard a "memory"

			while os.clock() - startTime < CHASE_TIMEOUT do
				local char = nearestPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not char or not safeAlive(hum) then break end

				-- Update memory if we can still see them
				if canSeePlayer(nearestHRP) then
					lastSeenTime = os.clock()
					queueSuspicion(nearestPlayer, SUSPICION_TICK_SEEN)
				end

				-- If we haven't seen them for 2.5 seconds, give up the chase
				if os.clock() - lastSeenTime > 2.5 then 
					break 
				end

				HUMANOID:MoveTo(nearestHRP.Position)
				task.wait(SUSPICION_TICK_RATE)
			end

			-- flush any remaining suspicion
			flushSuspicion(nearestPlayer)

			stopWalk()
			HUMANOID.WalkSpeed = PATROL_SPEED
		end
	end
end

task.spawn(patrol)