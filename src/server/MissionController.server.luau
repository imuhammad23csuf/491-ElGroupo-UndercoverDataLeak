local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

local STATUS_COMPLETED = "Completed"
local STATUS_IN_PROGRESS = "In Progress"
local STATUS_NOT_STARTED = "Not Started"

local TASK_AGENT_RAY = 1
local TASK_INFILTRATE = 2
local TASK_KEY_CODE = 3
local TASK_SLIDING_DOOR = 4
local TASK_STICKY_NOTE = 5

local INFILTRATION_CHECK_INTERVAL = 0.5
local INFILTRATION_DISTANCE = 35
local INFILTRATION_TARGET_NAMES = {
	"OuterPerimeterCheckpoint",
	"PerimeterCheckpoint",
	"InfiltrationCheckpoint",
	"OuterPerimeter",
	"Panel",
	"S.S.R. Teknikk Door",
}

local defaultMission = {
	{ id = "task1", text = "Meet Agent Ray at the Cafe to receive your tools.", status = STATUS_IN_PROGRESS },
	{ id = "task2", text = "Infiltrate the outer perimeter.", status = STATUS_NOT_STARTED },
	{ id = "task3", text = "Copy the Guard's Key Code.", status = STATUS_NOT_STARTED },
	{ id = "task4", text = "Unlock the sliding door.", status = STATUS_NOT_STARTED },
	{ id = "task5", text = "Find the Chapter 2 sticky note.", status = STATUS_NOT_STARTED },
}

local playerMissions = {}
local playerConnectionsByUserId = {}

local function cloneMission()
	local missionCopy = table.create(#defaultMission)
	for index, taskInfo in ipairs(defaultMission) do
		missionCopy[index] = {
			id = taskInfo.id,
			text = taskInfo.text,
			status = taskInfo.status,
		}
	end
	return missionCopy
end

local function getMission(player)
	if not player or player.Parent ~= Players then
		return nil
	end

	local mission = playerMissions[player]
	if not mission then
		mission = cloneMission()
		playerMissions[player] = mission
	end

	return mission
end

local function syncPlayerObjectives(player, mission)
	if not player or player.Parent ~= Players then
		return
	end

	mission = mission or getMission(player)
	if not mission then
		return
	end

	ObjectiveManager.SetPlayerObjectives(player, mission)
	CyberScenarioManager.SyncObjectives(player)
end

local function missionStage(mission)
	if mission[TASK_STICKY_NOTE].status == STATUS_COMPLETED then
		return 6
	end
	if mission[TASK_SLIDING_DOOR].status == STATUS_COMPLETED then
		return 5
	end
	if mission[TASK_KEY_CODE].status == STATUS_COMPLETED then
		return 4
	end
	if mission[TASK_INFILTRATE].status == STATUS_COMPLETED then
		return 3
	end
	if mission[TASK_AGENT_RAY].status == STATUS_COMPLETED then
		return 2
	end
	return 1
end

local function setMissionStage(player, stage)
	local mission = getMission(player)
	if not mission then
		return
	end

	local nextStage = math.max(missionStage(mission), stage)
	local before = table.concat({
		mission[TASK_AGENT_RAY].status,
		mission[TASK_INFILTRATE].status,
		mission[TASK_KEY_CODE].status,
		mission[TASK_SLIDING_DOOR].status,
		mission[TASK_STICKY_NOTE].status,
	}, "|")

	mission[TASK_AGENT_RAY].status = nextStage >= 2 and STATUS_COMPLETED or STATUS_IN_PROGRESS
	mission[TASK_INFILTRATE].status = nextStage >= 3 and STATUS_COMPLETED
		or (nextStage >= 2 and STATUS_IN_PROGRESS or STATUS_NOT_STARTED)
	mission[TASK_KEY_CODE].status = nextStage >= 4 and STATUS_COMPLETED
		or (nextStage >= 3 and STATUS_IN_PROGRESS or STATUS_NOT_STARTED)
	mission[TASK_SLIDING_DOOR].status = nextStage >= 5 and STATUS_COMPLETED
		or (nextStage >= 4 and STATUS_IN_PROGRESS or STATUS_NOT_STARTED)
	mission[TASK_STICKY_NOTE].status = nextStage >= 6 and STATUS_COMPLETED
		or (nextStage >= 5 and STATUS_IN_PROGRESS or STATUS_NOT_STARTED)

	local after = table.concat({
		mission[TASK_AGENT_RAY].status,
		mission[TASK_INFILTRATE].status,
		mission[TASK_KEY_CODE].status,
		mission[TASK_SLIDING_DOOR].status,
		mission[TASK_STICKY_NOTE].status,
	}, "|")

	if after ~= before then
		syncPlayerObjectives(player, mission)
	end
end

local function refreshMissionFromState(player)
	if not player or player.Parent ~= Players then
		return
	end

	if player:GetAttribute("RecoveredAdminCredentials") == true then
		setMissionStage(player, 6)
	elseif player:GetAttribute("UnlockedSlidingDoor") == true then
		setMissionStage(player, 5)
	elseif player:GetAttribute("HasKeycardData") == true then
		setMissionStage(player, 4)
	elseif player:GetAttribute("HasSpokenToAgentRay") == true then
		setMissionStage(player, 2)
	else
		syncPlayerObjectives(player)
	end
end

local function resetMission(player)
	if not player or player.Parent ~= Players then
		return
	end

	playerMissions[player] = cloneMission()
	syncPlayerObjectives(player, playerMissions[player])
end

local function getWorldPosition(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end

	return nil
end

local function getInfiltrationTargetPosition()
	for _, targetName in ipairs(INFILTRATION_TARGET_NAMES) do
		local target = Workspace:FindFirstChild(targetName, true)
		local position = getWorldPosition(target)
		if position then
			return position
		end
	end

	return nil
end

local function isNearInfiltrationTarget(player, targetPosition)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	return (root.Position - targetPosition).Magnitude <= INFILTRATION_DISTANCE
end

local function connectPlayer(player)
	playerMissions[player] = cloneMission()

	local connections = {}
	playerConnectionsByUserId[player.UserId] = connections

	table.insert(connections, player:GetAttributeChangedSignal("HasKeycardData"):Connect(function()
		refreshMissionFromState(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("HasSpokenToAgentRay"):Connect(function()
		refreshMissionFromState(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("UnlockedSlidingDoor"):Connect(function()
		refreshMissionFromState(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("RecoveredAdminCredentials"):Connect(function()
		refreshMissionFromState(player)
	end))

	task.delay(2, function()
		refreshMissionFromState(player)
	end)
end

local function disconnectPlayer(player)
	local connections = playerConnectionsByUserId[player.UserId]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	playerConnectionsByUserId[player.UserId] = nil
	playerMissions[player] = nil
end

local MissionController = {
	ResetMission = resetMission,
	MarkAgentRayVisited = function(player)
		setMissionStage(player, 2)
	end,
	MarkInfiltratedOuterPerimeter = function(player)
		setMissionStage(player, 3)
	end,
	MarkKeyCodeCopied = function(player)
		setMissionStage(player, 4)
	end,
	MarkSlidingDoorUnlocked = function(player)
		setMissionStage(player, 5)
	end,
	MarkStickyNoteFound = function(player)
		setMissionStage(player, 6)
	end,
	RefreshMission = refreshMissionFromState,
}

_G.MissionController = MissionController

local StartNewsCutscene = ReplicatedStorage:WaitForChild("StartNewsCutscene", 10)
if StartNewsCutscene then
	StartNewsCutscene.OnServerEvent:Connect(function(player)
		-- Eligibility check: player must exist, have a mission, and not already be in one
		if not player or not player.Parent then return end
		if not playerMissions[player] then return end
		if not CyberScenarioManager.hasActiveScenario(player) then return end
		if _G.MissionTimer then
			_G.MissionTimer.startMission(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	connectPlayer(player)
	refreshMissionFromState(player)
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(disconnectPlayer)

task.spawn(function()
	while task.wait(INFILTRATION_CHECK_INTERVAL) do
		local targetPosition = getInfiltrationTargetPosition()
		if targetPosition then
			for _, player in ipairs(Players:GetPlayers()) do
				local mission = getMission(player)
				if mission and missionStage(mission) == 2 and isNearInfiltrationTarget(player, targetPosition) then
					setMissionStage(player, 3)
				end
			end
		end
	end
end)
