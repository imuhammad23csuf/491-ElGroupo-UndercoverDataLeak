-- Simple Guard Script (Patrol + Chase + Walk Animation + Touch Kill)
-- Patrol loops: P1 -> P2 -> P3 -> P1 -> ...
-- Chase behavior: CHASE exactly CHASE_MAX_TIME seconds, then RETURN TO PATROL and IGNORE chasing for CHASE_COOLDOWN seconds.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local GUARD: Model = script.Parent
local HUMANOID: Humanoid = GUARD:FindFirstChildOfClass("Humanoid")
local HRP: BasePart? = GUARD:FindFirstChild("HumanoidRootPart")


-- === SETTINGS ===
local PATROL_SPEED = 10
local CHASE_SPEED = 16

local VISION_RANGE = 45
local FOV_TOTAL_DEGREES = 120
local VISION_DOT = math.cos(math.rad(FOV_TOTAL_DEGREES / 2)) -- dot threshold

local CHASE_MAX_TIME = 5.0   -- EXACT chase duration (seconds) — always stop after this
local CHASE_UPDATE = 0.12     -- how often we refresh MoveTo during chase
local CHASE_COOLDOWN = 3.0    -- after a chase finishes, ignore starting a new chase for this many seconds

-- Path tuning (used when target is lost but we still have a last-known position)
local REPATH_INTERVAL = 0.75
local REPATH_DIST = 6

-- Patrol mode: Loop (P1 -> P2 -> P3 -> P1 -> ...)
local PATROL_MODE = "Loop" -- locked to loop as requested

-- === WALK ANIMATION ===
local WALK_ANIM_ID = "rbxassetid://913402848" -- replace if needed
local Animator = HUMANOID:FindFirstChildOfClass("Animator") or Instance.new("Animator", HUMANOID)

local WalkTrack do
	local anim = Instance.new("Animation")
	anim.AnimationId = WALK_ANIM_ID
	WalkTrack = Animator:LoadAnimation(anim)
end

local function playWalk()
	if WalkTrack and not WalkTrack.IsPlaying then
		WalkTrack:Play(0.15)
	end
end

local function stopWalk()
	if WalkTrack and WalkTrack.IsPlaying then
		WalkTrack:Stop(0.15)
	end
end

-- === PATROL POINTS ===
local PatrolFolder = GUARD:FindFirstChild("PatrolPoints")
local PatrolPoints = {}

-- FIX: Only accept points named like P1, P2, P3 (prevents random parts in the folder)
if PatrolFolder then
	local parts = {}

	for _, obj in ipairs(PatrolFolder:GetChildren()) do
		local n = tonumber(obj.Name:match("^P(%d+)$"))
		if n then
			table.insert(parts, obj)
		end
	end

	table.sort(parts, function(a, b)
		local na = tonumber(a.Name:match("%d+")) or 0
		local nb = tonumber(b.Name:match("%d+")) or 0
		return na < nb
	end)

	-- FIX: Cache world positions once (if folder is inside guard, points won't "move")
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			table.insert(PatrolPoints, p.Position)
		elseif p:IsA("Attachment") then
			table.insert(PatrolPoints, p.WorldPosition)
		end
	end
end

local patrolIndex = 1

-- === HELPERS ===
local function safeAlive(h: Humanoid?)
	return h and h.Parent and h.Health > 0
end

local function losClear(targetPart: BasePart)
	if not HRP then return false end

	local origin = HRP.Position
	local diff = targetPart.Position - origin

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {GUARD}
	params.IgnoreWater = true

	local hit = Workspace:Raycast(origin, diff, params)
	if not hit then
		return true
	end

	return hit.Instance:IsDescendantOf(targetPart.Parent)
end

local function inFOV(targetPos: Vector3)
	if not HRP then return false end

	local diff = targetPos - HRP.Position
	local dist = diff.Magnitude
	if dist > VISION_RANGE then return false end
	if dist < 0.1 then return true end

	local dir = diff.Unit
	return HRP.CFrame.LookVector:Dot(dir) >= VISION_DOT
end

local function canSeeCharacter(char: Model)
	local targetHRP = char:FindFirstChild("HumanoidRootPart")
	if not targetHRP or not targetHRP:IsA("BasePart") then
		return false, nil
	end

	if not inFOV(targetHRP.Position) then
		return false, nil
	end

	if not losClear(targetHRP) then
		return false, nil
	end

	return true, targetHRP
end

-- Find best visible target (nearest visible)
local function findVisibleTarget()
	if not HRP then return nil, nil end

	local bestPlayer = nil
	local bestHRP = nil
	local bestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if not safeAlive(hum) then continue end

		local seen, phrp = canSeeCharacter(char)
		if seen and phrp then
			local d = (phrp.Position - HRP.Position).Magnitude
			if d < bestDist then
				bestDist = d
				bestPlayer = player
				bestHRP = phrp
			end
		end
	end

	return bestPlayer, bestHRP
end

-- === PATHFINDING (patrol + last-known chase) ===
local function computePath(toPos: Vector3)
	if not HRP then return nil end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	path:ComputeAsync(HRP.Position, toPos)
	if path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path:GetWaypoints()
end

local function followPathTo(toPos: Vector3)
	local wps = computePath(toPos)
	if not wps or #wps == 0 then
		-- fallback direct attempt (short wait so it doesn't block long)
		HUMANOID:MoveTo(toPos)
		HUMANOID.MoveToFinished:Wait(2)
		return
	end

	for _, wp in ipairs(wps) do
		if wp.Action == Enum.PathWaypointAction.Jump then
			HUMANOID.Jump = true
		end
		HUMANOID:MoveTo(wp.Position)
		local ok = HUMANOID.MoveToFinished:Wait(2.5)
		if not ok then
			break
		end
	end
end

-- === KILL ON CONTACT ===
local KILL_COOLDOWN = 0.5
local lastKillTick = 0

local function killIfPlayer(part: BasePart)
	if os.clock() - lastKillTick < KILL_COOLDOWN then return end
	local model = part and part:FindFirstAncestorOfClass("Model")
	if not model or model == GUARD then return end

	local hum: Humanoid? = model:FindFirstChildOfClass("Humanoid")
	if not safeAlive(hum) then return end

	local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
	if not isPlayer then return end

	hum.Health = 0
	lastKillTick = os.clock()
end

-- === STATE: chase cooldown tracker ===
local lastChaseEnd = -math.huge

-- === MAIN BEHAVIOR ===
local function doPatrolStep()
	if #PatrolPoints == 0 then
		task.wait(0.25)
		return
	end

	HUMANOID.WalkSpeed = PATROL_SPEED
	playWalk()

	local goal = PatrolPoints[patrolIndex]
	followPathTo(goal)

	stopWalk()

	-- Loop: P1 -> P2 -> P3 -> P1 -> ...
	patrolIndex = (patrolIndex % #PatrolPoints) + 1
	task.wait(0.5)
end

-- Chase exactly CHASE_MAX_TIME seconds, then return to patrol.
-- After chase finishes we set lastChaseEnd so the guard will not start chasing again
-- for CHASE_COOLDOWN seconds (even if player remains visible).
local function doChaseExactWithCooldown(targetPlayer: Player, targetHRP: BasePart)
	HUMANOID.WalkSpeed = CHASE_SPEED
	playWalk()

	local chaseStart = os.clock()
	local lastKnown = targetHRP.Position

	-- last-known path throttle
	local lastPathTime = 0
	local lastPathGoal: Vector3? = nil
	-- === KEYCARD HELPERS ===
	-- Simple, server-safe, no drops, no parts

	local function HasKeycard(guard: Instance): boolean
		if not guard then return false end
		return guard:GetAttribute("HasKeycard") == true
	end

	local function GetKeycardCode(guard: Instance): string?
		if not guard then return nil end
		if guard:GetAttribute("HasKeycard") ~= true then
			return nil
		end
		return guard:GetAttribute("KeycardCode")
	end


	while true do
		-- Hard cap: stop chasing after exact duration
		if os.clock() - chaseStart >= CHASE_MAX_TIME then
			break
		end

		-- validate target still exists (if they died/logged out, stop early)
		local char = targetPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or (hum and hum.Health <= 0) then
			break
		end

		-- try to update last-known if we can still see them
		local seen, phrp = canSeeCharacter(char)
		if seen and phrp then
			lastKnown = phrp.Position
		end

		-- always refresh MoveTo to the lastKnown (smooth following)
		HUMANOID:MoveTo(lastKnown)
		task.wait(CHASE_UPDATE)
	end

	-- Immediately stop movement and return to patrol:
	-- MoveTo to current position so we don't keep moving toward lastKnown
	if HRP then
		HUMANOID:MoveTo(HRP.Position)
	end

	stopWalk()
	HUMANOID.WalkSpeed = PATROL_SPEED

	-- record chase end time so we won't immediately re-chase
	lastChaseEnd = os.clock()
end

local function brain()
	while task.wait(0.2) do
		if not HRP or not HUMANOID then
			break
		end

		-- Respect chase cooldown: if we recently finished a chase, don't start another yet
		if os.clock() - lastChaseEnd < CHASE_COOLDOWN then
			-- continue patrolling during cooldown
			doPatrolStep()
			continue
		end

		-- Look for a visible target (only start chasing when seen)
		local plr, phrp = findVisibleTarget()

		if plr and phrp then
			doChaseExactWithCooldown(plr, phrp)
		else
			doPatrolStep()
		end
	end
end

-- Hook up kill-on-touch
if HRP then
	HRP.Touched:Connect(killIfPlayer)
end

task.spawn(brain)
