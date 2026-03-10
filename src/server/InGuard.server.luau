-- InsideGuardScript
-- Tutorial-style AI with chase + smarter search + suspicion system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Get SuspicionManager
local SuspicionManager = require(ReplicatedStorage.Shared.SuspicionManager)

-- Guard setup
local guard = script.Parent

-- CHANGED: search recursively (everywhere under guard), and PatrolPoints anywhere in Workspace
local humanoid = guard:WaitForChild("Humanoid", math.huge) or guard:FindFirstChildWhichIsA("Humanoid", true) or workspace:FindFirstChildWhichIsA("Humanoid", true)
local hrp = guard:FindFirstChild("HumanoidRootPart", true) or workspace:FindFirstChild("HumanoidRootPart", true)
local patrolPoints = workspace:FindFirstChild("PatrolPoints", true) or guard:FindFirstChild("PatrolPoints", true)

-- State machine
local currentState = "Patrol" -- Patrol, Chase, Search, Return

-- Patrol setup
local patrolIndex = 1
local patrolTable = {}

if patrolPoints then
	for _, point in patrolPoints:GetChildren() do
		if point:IsA("BasePart") then
			table.insert(patrolTable, point)
		end
	end
end

-- Search setup
local lastKnownPosition = Vector3.new(0, 0, 0)
local searchTimer = 0
local searchDuration = 8
local searchPoints = {}
local searchIndex = 1

-- Vision setup
local visionRange = 30
local chaseSpeed = 16
local patrolSpeed = 9
local searchSpeed = 12

-- Suspicion rates
local chaseRate = 15 -- suspicion per second while chasing
local searchDecayRate = 5 -- suspicion decay per second while searching
local patrolDecayRate = 2 -- suspicion decay per second while patrolling

-- Current target player
local targetPlayer = nil

-- TODO: match exact tutorial function name
local function CanSeePlayer(player)
	local character = player.Character
	if not character then return false end
	
	local playerHrp = character:FindFirstChild("HumanoidRootPart")
	if not playerHrp then return false end
	
	local distance = (hrp.Position - playerHrp.Position).Magnitude
	if distance > visionRange then return false end
	
	-- TODO: match exact tutorial line of sight check
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {guard, character}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local direction = playerHrp.Position - hrp.Position
	local result = workspace:Raycast(hrp.Position, direction, rayParams)
	
	return result == nil
end

-- TODO: match exact tutorial function name
local function FindNearestPlayer()
	local nearestPlayer = nil
	local nearestDistance = visionRange
	
	for _, player in Players:GetPlayers() do
		if CanSeePlayer(player) then
			local character = player.Character
			if character then
				local playerHrp = character:FindFirstChild("HumanoidRootPart")
				if playerHrp then
					local distance = (hrp.Position - playerHrp.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestPlayer = player
					end
				end
			end
		end
	end
	
	return nearestPlayer
end

-- TODO: match exact tutorial function name
local function MoveToPosition(position, speed)
	humanoid.WalkSpeed = speed
	humanoid:MoveTo(position)
end

-- TODO: match exact tutorial function name
local function PatrolState(dt)
	if #patrolTable == 0 then return end
	
	local targetPoint = patrolTable[patrolIndex]
	MoveToPosition(targetPoint.Position, patrolSpeed)
	
	-- Decay suspicion while patrolling
	if targetPlayer then
		local suspicion = SuspicionManager.Get(targetPlayer)
		if suspicion > 0 then
			SuspicionManager.Reduce(patrolDecayRate * dt, targetPlayer)
		end
	end
	
	-- Check if reached patrol point
	local distance = (hrp.Position - targetPoint.Position).Magnitude
	if distance < 3 then
		patrolIndex = patrolIndex % #patrolTable + 1
	end
	
	-- Check for player detection
	local detectedPlayer = FindNearestPlayer()
	if detectedPlayer then
		targetPlayer = detectedPlayer
		currentState = "Chase"
	end
end

-- TODO: match exact tutorial function name
local function ChaseState(dt)
	if not targetPlayer then
		currentState = "Patrol"
		return
	end
	
	local character = targetPlayer.Character
	if not character then
		currentState = "Search"
		return
	end
	
	local playerHrp = character:FindFirstChild("HumanoidRootPart")
	if not playerHrp then
		currentState = "Search"
		return
	end
	
	-- Increase suspicion while chasing
	SuspicionManager.Add(chaseRate * dt, targetPlayer)
	
	-- Check if can still see player
	if CanSeePlayer(targetPlayer) then
		lastKnownPosition = playerHrp.Position
		MoveToPosition(playerHrp.Position, chaseSpeed)
	else
		-- Player lost, switch to search
		currentState = "Search"
		searchTimer = 0
		
		-- Generate search points around last known position
		searchPoints = {}
		for i = 1, 4 do
			local offset = Vector3.new(
				math.random(-10, 10),
				0,
				math.random(-10, 10)
			)
			table.insert(searchPoints, lastKnownPosition + offset)
		end
		searchIndex = 1
	end
end

-- TODO: match exact tutorial function name
local function SearchState(dt)
	-- Decay suspicion while searching
	if targetPlayer then
		local suspicion = SuspicionManager.Get(targetPlayer)
		if suspicion > 0 then
			SuspicionManager.Reduce(searchDecayRate * dt, targetPlayer)
		end
	end
	
	-- Check if player is rediscovered
	local detectedPlayer = FindNearestPlayer()
	if detectedPlayer then
		targetPlayer = detectedPlayer
		currentState = "Chase"
		return
	end
	
	-- Move to search points
	if #searchPoints > 0 then
		local searchPoint = searchPoints[searchIndex]
		MoveToPosition(searchPoint, searchSpeed)
		
		local distance = (hrp.Position - searchPoint).Magnitude
		if distance < 3 then
			searchIndex = searchIndex % #searchPoints + 1
		end
	else
		-- No search points, just look around
		MoveToPosition(lastKnownPosition, searchSpeed)
	end
	
	-- Update search timer
	searchTimer = searchTimer + dt
	if searchTimer >= searchDuration then
		currentState = "Patrol"
		targetPlayer = nil
	end
end

-- TODO: match exact tutorial function name
local function ReturnState(dt)
	-- Return to patrol
	if #patrolTable > 0 then
		local targetPoint = patrolTable[patrolIndex]
		MoveToPosition(targetPoint.Position, patrolSpeed)
		
		local distance = (hrp.Position - targetPoint.Position).Magnitude
		if distance < 3 then
			currentState = "Patrol"
		end
	else
		currentState = "Patrol"
	end
	
	-- Decay suspicion while returning
	if targetPlayer then
		local suspicion = SuspicionManager.Get(targetPlayer)
		if suspicion > 0 then
			SuspicionManager.Reduce(patrolDecayRate * dt, targetPlayer)
		end
	end
end

-- Main update loop
local lastTime = tick()

while true do
	local currentTime = tick()
	local dt = currentTime - lastTime
	lastTime = currentTime
	
	if currentState == "Patrol" then
		PatrolState(dt)
	elseif currentState == "Chase" then
		ChaseState(dt)
	elseif currentState == "Search" then
		SearchState(dt)
	elseif currentState == "Return" then
		ReturnState(dt)
	end
	
	task.wait(0.1)
end