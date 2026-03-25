-- GuardInside (Patrol + Advanced Chase + Search + Batched Suspicion)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(sharedRoot:WaitForChild("SuspicionManager"))

local GUARD = Workspace:WaitForChild("GuardInside")
local RIG = GUARD:WaitForChild("Rig")
local HUMANOID = RIG:WaitForChild("Humanoid")
local HRP = RIG:WaitForChild("HumanoidRootPart")

-- === INDOOR SETTINGS ===
local PATROL_SPEED = 8
local CHASE_SPEED = 14
local VISION_RANGE = 35  -- Shorter range for indoors
local VISION_ANGLE = math.cos(math.rad(60)) -- 120° total FOV
local CHASE_TIMEOUT = 3

-- Suspicion tuning (Inside)
local SUSPICION_PER_TICK = 2     -- matches camera suspicion rate
local SUSPICION_TICK_RATE = 0.25 -- matches camera suspicion cadence

-- === SUSPICION THROTTLE/BATCH ===
local SUSPICION_PUSH_INTERVAL = 0.5 
local pendingSuspicion = {}         

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
		SuspicionManager.Add(delta, player) -- BUG FIXED: Added player argument
		pendingSuspicion[uid] = 0
	end
end

-- background flusher
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

	-- BUG FIXED: Lifted eyes up 1.5 studs
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
		-- Look for players
		local nearestPlayer, nearestHRP = findTarget()

		-- Chase logic (advanced chase + search)
		if nearestPlayer and nearestHRP then
			HUMANOID.WalkSpeed = CHASE_SPEED
			playWalk()
			local chaseStartTime = os.clock()
			local lastSeenPos = nearestHRP.Position

			while os.clock() - chaseStartTime < CHASE_TIMEOUT do
				local char = nearestPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not char or not safeAlive(hum) then break end

				if canSeePlayer(nearestHRP) then
					queueSuspicion(nearestPlayer, SUSPICION_PER_TICK)
					lastSeenPos = nearestHRP.Position
					HUMANOID:MoveTo(nearestHRP.Position)
				else
					-- Search: go to last seen position, then "look around"
					HUMANOID:MoveTo(lastSeenPos)
					task.wait(0.4)

					local searchStart = os.clock()
					while os.clock() - searchStart < 2.5 and os.clock() - chaseStartTime < CHASE_TIMEOUT do
						-- rotate/scan
						if HRP then
							HRP.CFrame = HRP.CFrame * CFrame.Angles(0, math.rad(35), 0)
						end
						if canSeePlayer(nearestHRP) then
							lastSeenPos = nearestHRP.Position
							break
						end
						task.wait(0.15)
					end

					if not canSeePlayer(nearestHRP) then
						break
					end
				end

				task.wait(SUSPICION_TICK_RATE)
			end

			-- flush any remaining suspicion for responsiveness
			flushSuspicion(nearestPlayer)

			stopWalk()
			HUMANOID.WalkSpeed = PATROL_SPEED
		end

		-- Patrol between points (BUG FIXED: Active vision while walking)
		if not nearestPlayer and #Waypoints > 0 then
			local point = Waypoints[currentPoint]
			if point then
				HUMANOID.WalkSpeed = PATROL_SPEED
				playWalk()
				HUMANOID:MoveTo(point.Position)

				local startMoveTime = os.clock()
				while (HRP.Position - point.Position).Magnitude > 4 do
					if os.clock() - startMoveTime > 8 then break end

					nearestPlayer, nearestHRP = findTarget()
					if nearestPlayer then break end
					task.wait(0.2)
				end

				if not nearestPlayer then
					stopWalk()
					currentPoint = (currentPoint % #Waypoints) + 1
					task.wait(1)
				end
			end
		end
	end
end

task.spawn(patrol)
