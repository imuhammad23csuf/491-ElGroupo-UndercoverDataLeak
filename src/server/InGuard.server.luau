-- Simple Guard Script (Patrol + Chase + Walk Animation)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SuspicionManager = require(ReplicatedStorage:WaitForChild("SuspicionManager"))

local GUARD = Workspace:WaitForChild("GuardInside")
local RIG = GUARD:WaitForChild("Rig")
local HUMANOID = RIG:WaitForChild("Humanoid")
local HRP = RIG:WaitForChild("HumanoidRootPart")

-- === SETTINGS ===
local PATROL_SPEED = 10
local CHASE_SPEED = 16
local VISION_RANGE = 80
local VISION_ANGLE = math.cos(math.rad(60)) -- 120° total FOV
local CHASE_TIMEOUT = 10 -- seconds before giving up

-- === WALK ANIMATION ===
local WALK_ANIM_ID = "http://www.roblox.com/asset/?id=913402848" -- replace if needed
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

-- === PATROL POINTS (Original uses PatrolPoints1) ===
local PatrolFolder = (RIG:FindFirstChild("PatrolPoints1") or GUARD:FindFirstChild("PatrolPoints1"))
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
	local diff = playerHRP.Position - HRP.Position
	local dist = diff.Magnitude
	if dist > VISION_RANGE then return false end
	local dir = diff.Unit
	if HRP.CFrame.LookVector:Dot(dir) < VISION_ANGLE then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {GUARD}
	local ray = Workspace:Raycast(HRP.Position, dir * dist, params)
	if not ray then return true end
	local hitModel = ray.Instance:FindFirstAncestorOfClass("Model")
	return hitModel and hitModel == playerHRP.Parent
end

local function moveTo(pos)
	if HUMANOID then
		HUMANOID:MoveTo(pos)
		HUMANOID.MoveToFinished:Wait()
	end
end

-- === MAIN BEHAVIOR ===
local function patrol()
	while task.wait(0.2) do
		-- Look for players
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

		-- Chase logic (advanced chase + search)
		if nearestPlayer and nearestHRP then
			SuspicionManager.Add(12, nearestPlayer)

			HUMANOID.WalkSpeed = CHASE_SPEED
			playWalk()
			local startTime = os.clock()
			local lastSeenPos = nearestHRP.Position
			local lastTick = 0

			while os.clock() - startTime < CHASE_TIMEOUT do
				local char = nearestPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not char or not safeAlive(hum) then break end

				if os.clock() - lastTick >= 1 then
					SuspicionManager.Add(3, nearestPlayer)
					lastTick = os.clock()
				end

				if canSeePlayer(nearestHRP) then
					lastSeenPos = nearestHRP.Position
					HUMANOID:MoveTo(nearestHRP.Position)
				else
					SuspicionManager.Add(1, nearestPlayer)

					HUMANOID:MoveTo(lastSeenPos)
					task.wait(0.4)

					local searchStart = os.clock()
					while os.clock() - searchStart < 2.5 do
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

				task.wait(0.2)
			end

			stopWalk()
			HUMANOID.WalkSpeed = PATROL_SPEED
		end

		-- Patrol between points
		if #Waypoints > 0 then
			local point = Waypoints[currentPoint]
			if point then
				HUMANOID.WalkSpeed = PATROL_SPEED
				playWalk()
				moveTo(point.Position)
				stopWalk()
				currentPoint = (currentPoint % #Waypoints) + 1
				task.wait(1)
			end
		else
			task.wait(0.5)
		end
	end
end

-- === CLONE (Uses PatrolPoints2 and walks 3->2->1) ===
local GUARD2 = GUARD:Clone()
GUARD2.Name = "GuardInside_Clone"
GUARD2.Parent = Workspace

local RIG2 = GUARD2:WaitForChild("Rig")
local HUMANOID2 = RIG2:WaitForChild("Humanoid")
local HRP2 = RIG2:WaitForChild("HumanoidRootPart")

-- === SAFE SPAWN OFFSET ===
local SPAWN_OFFSET = 10
if HRP and HRP2 then
	local rightVector = HRP.CFrame.RightVector
	local offsetPosition = HRP.Position + (rightVector * SPAWN_OFFSET)
	HRP2.CFrame = CFrame.new(offsetPosition, offsetPosition + HRP.CFrame.LookVector)
end

local Animator2 = HUMANOID2:FindFirstChildOfClass("Animator") or Instance.new("Animator", HUMANOID2)
local WalkTrack2 do
	local anim = Instance.new("Animation")
	anim.AnimationId = WALK_ANIM_ID
	WalkTrack2 = Animator2:LoadAnimation(anim)
end

local function playWalk2()
	if WalkTrack2 and not WalkTrack2.IsPlaying then WalkTrack2:Play() end
end
local function stopWalk2()
	if WalkTrack2 and WalkTrack2.IsPlaying then WalkTrack2:Stop() end
end

-- Clone patrol points folder
local PatrolFolder2 = (RIG2:FindFirstChild("PatrolPoints2") or GUARD2:FindFirstChild("PatrolPoints2"))
local Waypoints2 = {}
if PatrolFolder2 then
	for _, part in ipairs(PatrolFolder2:GetChildren()) do
		if part:IsA("BasePart") then table.insert(Waypoints2, part) end
	end
	table.sort(Waypoints2, function(a,b)
		local na = tonumber(a.Name:match("%d+")) or math.huge
		local nb = tonumber(b.Name:match("%d+")) or math.huge
		return na < nb
	end)
end

local currentPoint2 = #Waypoints2 > 0 and #Waypoints2 or 1

local function canSeePlayer2(playerHRP)
	if not HRP2 or not playerHRP then return false end
	local diff = playerHRP.Position - HRP2.Position
	local dist = diff.Magnitude
	if dist > VISION_RANGE then return false end
	local dir = diff.Unit
	if HRP2.CFrame.LookVector:Dot(dir) < VISION_ANGLE then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {GUARD2}
	local ray = Workspace:Raycast(HRP2.Position, dir * dist, params)
	if not ray then return true end
	local hitModel = ray.Instance:FindFirstAncestorOfClass("Model")
	return hitModel and hitModel == playerHRP.Parent
end

local function moveTo2(pos)
	if HUMANOID2 then
		HUMANOID2:MoveTo(pos)
		HUMANOID2.MoveToFinished:Wait()
	end
end

local function patrol2()
	while task.wait(0.2) do
		-- Look for players
		local nearestPlayer, nearestHRP, minDist = nil, nil, VISION_RANGE + 1
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and safeAlive(hum) then
				local dist = (hrp.Position - HRP2.Position).Magnitude
				if dist < minDist and canSeePlayer2(hrp) then
					minDist = dist
					nearestPlayer = player
					nearestHRP = hrp
				end
			end
		end

		-- Chase logic (advanced chase + search)
		if nearestPlayer and nearestHRP then
			SuspicionManager.Add(12, nearestPlayer)

			HUMANOID2.WalkSpeed = CHASE_SPEED
			playWalk2()
			local startTime = os.clock()
			local lastSeenPos = nearestHRP.Position
			local lastTick = 0

			while os.clock() - startTime < CHASE_TIMEOUT do
				local char = nearestPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not char or not safeAlive(hum) then break end

				if os.clock() - lastTick >= 1 then
					SuspicionManager.Add(3, nearestPlayer)
					lastTick = os.clock()
				end

				if canSeePlayer2(nearestHRP) then
					lastSeenPos = nearestHRP.Position
					HUMANOID2:MoveTo(nearestHRP.Position)
				else
					SuspicionManager.Add(1, nearestPlayer)

					HUMANOID2:MoveTo(lastSeenPos)
					task.wait(0.4)

					local searchStart = os.clock()
					while os.clock() - searchStart < 2.5 do
						if HRP2 then
							HRP2.CFrame = HRP2.CFrame * CFrame.Angles(0, math.rad(35), 0)
						end
						if canSeePlayer2(nearestHRP) then
							lastSeenPos = nearestHRP.Position
							break
						end
						task.wait(0.15)
					end

					if not canSeePlayer2(nearestHRP) then
						break
					end
				end

				task.wait(0.2)
			end

			stopWalk2()
			HUMANOID2.WalkSpeed = PATROL_SPEED
		end

		-- Patrol between points (reverse: 3 -> 2 -> 1)
		if #Waypoints2 > 0 then
			local point = Waypoints2[currentPoint2]
			if point then
				HUMANOID2.WalkSpeed = PATROL_SPEED
				playWalk2()
				moveTo2(point.Position)
				stopWalk2()
				currentPoint2 = ((currentPoint2 - 2) % #Waypoints2) + 1
				task.wait(1)
			end
		else
			task.wait(0.5)
		end
	end
end

task.spawn(patrol)
task.spawn(patrol2)