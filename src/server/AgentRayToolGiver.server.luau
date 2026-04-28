local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCdata = require(Shared:WaitForChild("NPCdata"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))

local AGENT_NAMES = {
	["Agent Ray"] = true,
	AgentRay = true,
	["Special Agent Ray"] = true,
	SpecialAgentRay = true,
}

local TOOL_NAMES = {
	"HackTablet",
	"GhostKey",
}

local DIALOGUE_REMOTE_NAME = "AgentRayDialogueEvent"
local TOOL_NAME_SET = {}
for _, toolName in ipairs(TOOL_NAMES) do
	TOOL_NAME_SET[toolName] = true
end

local TEMPLATE_FOLDER_NAME = "AgentRayToolTemplates"
local PROMPT_NAME = "AgentRayToolPrompt"
local FALLBACK_DIALOGUE_SECONDS_PER_LINE = 3.1
local FALLBACK_DIALOGUE_MIN_SECONDS = 10
local FALLBACK_DIALOGUE_MAX_SECONDS = 28
local DIALOGUE_FINISH_POLL_INTERVAL = 0.15
local PENDING_DIALOGUE_TOOL_CHECK_DELAY = 1.25
local GRANT_HANDOFF_GRACE_SECONDS = 6
local OPSEC_POPUP_DELAY_SECONDS = 0.35

local DIALOGUE_COMPLETE_ATTRIBUTES = {
	"AgentRayDialogueComplete",
	"AgentRayDialogueCompleted",
}

local DIALOGUE_ACTIVE_ATTRIBUTES = {
	"AgentRayDialogueActive",
	"DialogueActive",
	"InDialogue",
	"IsTalkingToNPC",
}

local templateFolder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
if not templateFolder then
	templateFolder = Instance.new("Folder")
	templateFolder.Name = TEMPLATE_FOLDER_NAME
	templateFolder.Parent = ServerStorage
end

local playerConnections = {}
local attachedAgents = {}
local connectedPrompts = {}
local pendingGrantTokensByUserId = {}
<<<<<<< Updated upstream
local pendingGrantPromptsByUserId = {}

local dialogueRemote = ReplicatedStorage:FindFirstChild(DIALOGUE_REMOTE_NAME)
if not dialogueRemote then
	dialogueRemote = Instance.new("RemoteEvent")
	dialogueRemote.Name = DIALOGUE_REMOTE_NAME
	dialogueRemote.Parent = ReplicatedStorage
end
=======
local delayedPendingToolChecksByUserId = {}
local grantHandoffUntilByUserId = {}
>>>>>>> Stashed changes

local function isToolName(name)
	return TOOL_NAME_SET[tostring(name or "")] == true
end

local function cacheToolTemplate(tool)
	if not tool or not tool:IsA("Tool") or not isToolName(tool.Name) then
		return
	end

	if templateFolder:FindFirstChild(tool.Name) then
		return
	end

	local clone = tool:Clone()
	clone.Parent = templateFolder
end

local function findToolTemplate(toolName)
	local cached = templateFolder:FindFirstChild(toolName)
	if cached and cached:IsA("Tool") then
		return cached
	end

	for _, container in ipairs({ ServerStorage, ReplicatedStorage, StarterPack, Workspace }) do
		local found = container:FindFirstChild(toolName, true)
		if found and found:IsA("Tool") then
			cacheToolTemplate(found)
			return templateFolder:FindFirstChild(toolName) or found
		end
	end

	return nil
end

local function hasToolIn(container, toolName)
	return container and container:FindFirstChild(toolName) ~= nil
end

local function dedupeToolsIn(container, toolName, keptTool)
	if not container then
		return keptTool
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child.Name == toolName then
			if not keptTool then
				keptTool = child
			else
				cacheToolTemplate(child)
				child:Destroy()
			end
		end
	end

	return keptTool
end

local function dedupePlayerTool(player, toolName)
	if not player then
		return
	end

	local activeTool = nil
	activeTool = dedupeToolsIn(player.Character, toolName, activeTool)
	activeTool = dedupeToolsIn(player:FindFirstChildOfClass("Backpack"), toolName, activeTool)
	dedupeToolsIn(player:FindFirstChild("StarterGear"), toolName, nil)
end

local function removeToolsFrom(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and isToolName(child.Name) then
			cacheToolTemplate(child)
			child:Destroy()
		end
	end
end

local function removeAgentTools(player)
	if not player then
		return
	end

	removeToolsFrom(player.Character)
	removeToolsFrom(player:FindFirstChildOfClass("Backpack"))
	removeToolsFrom(player:FindFirstChild("StarterGear"))
end

local function isAgentRayToolAllowed(player)
	if not player then
		return false
	end

	if player:GetAttribute("HasSpokenToAgentRay") == true then
		return true
	end

	local handoffUntil = grantHandoffUntilByUserId[player.UserId]
	return handoffUntil ~= nil and os.clock() <= handoffUntil
end

local function openGrantHandoffWindow(player, seconds)
	if not player then
		return
	end

	grantHandoffUntilByUserId[player.UserId] = math.max(
		grantHandoffUntilByUserId[player.UserId] or 0,
		os.clock() + (seconds or GRANT_HANDOFF_GRACE_SECONDS)
	)
end

local function schedulePendingToolCheck(player)
	if not player then
		return
	end

	local userId = player.UserId
	if delayedPendingToolChecksByUserId[userId] then
		return
	end

	delayedPendingToolChecksByUserId[userId] = true
	task.delay(PENDING_DIALOGUE_TOOL_CHECK_DELAY, function()
		delayedPendingToolChecksByUserId[userId] = nil

		if player.Parent ~= Players or isAgentRayToolAllowed(player) then
			return
		end

		removeAgentTools(player)
	end)
end

local function enforceNoToolsBeforeVisit(player)
	if not player or isAgentRayToolAllowed(player) then
		return
	end

	if pendingGrantTokensByUserId[player.UserId] then
		schedulePendingToolCheck(player)
		return
	end

	removeAgentTools(player)
end

local function grantTool(player, toolName)
	local template = findToolTemplate(toolName)
	if not template then
		warn(("[AgentRayToolGiver] Missing tool template: %s"):format(toolName))
		return false
	end

	dedupePlayerTool(player, toolName)

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	local character = player.Character
	if backpack and not hasToolIn(character, toolName) and not hasToolIn(backpack, toolName) then
		local tool = template:Clone()
		tool.Parent = backpack
	end

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear and not hasToolIn(starterGear, toolName) then
		local persistentTool = template:Clone()
		persistentTool.Parent = starterGear
	end

	dedupePlayerTool(player, toolName)
	return true
end

local function markAgentRayVisited(player)
	player:SetAttribute("HasSpokenToAgentRay", true)

	local missionController = _G.MissionController
	if missionController and typeof(missionController.MarkAgentRayVisited) == "function" then
		missionController.MarkAgentRayVisited(player)
	end
end

local function handleAgentVisit(player)
	if not player or player.Parent ~= Players then
		return
	end

	pendingGrantTokensByUserId[player.UserId] = nil
<<<<<<< Updated upstream
	pendingGrantPromptsByUserId[player.UserId] = nil
	player:SetAttribute("AgentRayDialogueActive", false)
	player:SetAttribute("AgentRayDialogueComplete", true)
=======
	delayedPendingToolChecksByUserId[player.UserId] = nil
	openGrantHandoffWindow(player)
>>>>>>> Stashed changes
	markAgentRayVisited(player)

	for _, toolName in ipairs(TOOL_NAMES) do
		grantTool(player, toolName)
	end

	task.delay(OPSEC_POPUP_DELAY_SECONDS, function()
		if player.Parent ~= Players or player:GetAttribute("HasSpokenToAgentRay") ~= true then
			return
		end

		LessonManager.TriggerMistake(player, "PublicWifiOpsec", {
			throttleKey = "agent_ray_cafe_tools",
			throttleWindow = 60,
		})
	end)
end

_G.AgentRayToolGiver = {
	GrantTools = handleAgentVisit,
	GiveTools = handleAgentVisit,
}

local function getAgentDialogueDelay()
	local lines = NPCdata["Agent Ray"] or NPCdata.AgentRay
	local lineCount = 4
	if type(lines) == "table" then
		lineCount = #lines
	end

	return math.clamp(lineCount * FALLBACK_DIALOGUE_SECONDS_PER_LINE, FALLBACK_DIALOGUE_MIN_SECONDS, FALLBACK_DIALOGUE_MAX_SECONDS)
end

local function getAgentDialogueLines()
	local lines = NPCdata["Agent Ray"] or NPCdata.AgentRay
	if type(lines) ~= "table" or #lines == 0 then
		return {
			"I am Special Agent Ray. I have your tools ready.",
			"Use them carefully. The operation depends on discretion.",
		}
	end

	local copy = table.create(#lines)
	for index, line in ipairs(lines) do
		copy[index] = tostring(line)
	end

	return copy
end

local function hasDialogueCompleteAttribute(player)
	for _, attributeName in ipairs(DIALOGUE_COMPLETE_ATTRIBUTES) do
		if player:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

local function isDialogueMarkedActive(player)
	for _, attributeName in ipairs(DIALOGUE_ACTIVE_ATTRIBUTES) do
		if player:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

local function waitForAgentDialogueToFinish(player, prompt, token)
	local fallbackDelay = getAgentDialogueDelay()
	local startedAt = os.clock()
	local sawPromptDisabled = prompt and prompt.Enabled == false
	local sawDialogueActive = isDialogueMarkedActive(player)

	while player.Parent == Players and pendingGrantTokensByUserId[player.UserId] == token do
		if hasDialogueCompleteAttribute(player) then
			return
		end

		if prompt and prompt.Parent then
			if prompt.Enabled == false then
				sawPromptDisabled = true
			elseif sawPromptDisabled and os.clock() - startedAt >= 0.5 then
				return
			end
		end

		if isDialogueMarkedActive(player) then
			sawDialogueActive = true
		elseif sawDialogueActive and os.clock() - startedAt >= 0.5 then
			return
		end

		if os.clock() - startedAt >= fallbackDelay then
			return
		end

		task.wait(DIALOGUE_FINISH_POLL_INTERVAL)
	end
end

local function getPromptPart(prompt)
	local parent = prompt and prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end
	if parent and parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
		return parent.Parent
	end

	return nil
end

local function isPlayerNearPrompt(player, prompt)
	local part = getPromptPart(prompt)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not part or not root then
		return false
	end

	local maxDistance = tonumber(prompt.MaxActivationDistance) or 12
	return (root.Position - part.Position).Magnitude <= maxDistance + 6
end

local function completeAgentDialogue(player, token)
	if not player or player.Parent ~= Players then
		return
	end

	local userId = player.UserId
	if pendingGrantTokensByUserId[userId] ~= token then
		return
	end

	local prompt = pendingGrantPromptsByUserId[userId]
	if prompt and prompt.Parent and not isPlayerNearPrompt(player, prompt) then
		player:SetAttribute("AgentRayDialogueActive", false)
		pendingGrantTokensByUserId[userId] = nil
		pendingGrantPromptsByUserId[userId] = nil
		return
	end

	handleAgentVisit(player)
end

local function scheduleAgentVisitAfterDialogue(player, prompt)
	if not player or player.Parent ~= Players then
		return
	end

	if player:GetAttribute("HasSpokenToAgentRay") == true then
		handleAgentVisit(player)
		return
	end

	if pendingGrantTokensByUserId[player.UserId] then
		return
	end

	local token = ("%d:%.3f"):format(player.UserId, os.clock())
	pendingGrantTokensByUserId[player.UserId] = token
	pendingGrantPromptsByUserId[player.UserId] = prompt
	player:SetAttribute("AgentRayDialogueComplete", false)
	player:SetAttribute("AgentRayDialogueActive", true)

	dialogueRemote:FireClient(player, "Start", token, getAgentDialogueLines())

	task.delay(getAgentDialogueDelay() + 8, function()
		if pendingGrantTokensByUserId[player.UserId] == token then
			player:SetAttribute("AgentRayDialogueActive", false)
			pendingGrantTokensByUserId[player.UserId] = nil
			pendingGrantPromptsByUserId[player.UserId] = nil
		end
	end)

	-- Compatibility with any pre-existing Agent Ray dialogue script that marks
	-- the same player attributes on the server.
	task.spawn(function()
		waitForAgentDialogueToFinish(player, prompt, token)

		if pendingGrantTokensByUserId[player.UserId] ~= token then
			return
		end

		if hasDialogueCompleteAttribute(player) then
			handleAgentVisit(player)
		end
	end)
end

dialogueRemote.OnServerEvent:Connect(function(player, action, token)
	if action == "Complete" then
		completeAgentDialogue(player, token)
	elseif action == "Cancel" and pendingGrantTokensByUserId[player.UserId] == token then
		pendingGrantTokensByUserId[player.UserId] = nil
		pendingGrantPromptsByUserId[player.UserId] = nil
		player:SetAttribute("AgentRayDialogueActive", false)
	end
end)

local function getAttachPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function attachToAgent(instance)
	if attachedAgents[instance] or not AGENT_NAMES[instance.Name] then
		return
	end

	local part = getAttachPart(instance)
	if not part then
		return
	end

	attachedAgents[instance] = true

	local function connectPrompt(prompt)
		if connectedPrompts[prompt] then
			return
		end

		connectedPrompts[prompt] = true
		prompt.Triggered:Connect(function(player)
			scheduleAgentVisitAfterDialogue(player, prompt)
		end)
	end

	local foundDialoguePrompt = false
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			foundDialoguePrompt = true
			connectPrompt(descendant)
		end
	end

	local prompt = part:FindFirstChild(PROMPT_NAME)
	if not foundDialoguePrompt and not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Agent Ray"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	if prompt then
		connectPrompt(prompt)
	end

	instance.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			connectPrompt(descendant)
		end
	end)
end

local function watchPlayerContainer(player, container)
	if not container then
		return
	end

	table.insert(playerConnections[player.UserId], container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and isToolName(child.Name) then
			task.defer(enforceNoToolsBeforeVisit, player)
		end
	end))
end

local function connectPlayer(player)
	playerConnections[player.UserId] = {}

	table.insert(playerConnections[player.UserId], player:GetAttributeChangedSignal("HasSpokenToAgentRay"):Connect(function()
		if player:GetAttribute("HasSpokenToAgentRay") ~= true then
			pendingGrantTokensByUserId[player.UserId] = nil
			delayedPendingToolChecksByUserId[player.UserId] = nil
			grantHandoffUntilByUserId[player.UserId] = nil
			removeAgentTools(player)
		end
	end))

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	watchPlayerContainer(player, backpack)
	watchPlayerContainer(player, player:FindFirstChild("StarterGear"))

	table.insert(playerConnections[player.UserId], player.CharacterAdded:Connect(function(character)
		watchPlayerContainer(player, character)
		task.defer(enforceNoToolsBeforeVisit, player)
	end))

	if player.Character then
		watchPlayerContainer(player, player.Character)
	end

	task.defer(enforceNoToolsBeforeVisit, player)
end

local function disconnectPlayer(player)
	local connections = playerConnections[player.UserId]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	playerConnections[player.UserId] = nil
	pendingGrantTokensByUserId[player.UserId] = nil
<<<<<<< Updated upstream
	pendingGrantPromptsByUserId[player.UserId] = nil
=======
	delayedPendingToolChecksByUserId[player.UserId] = nil
	grantHandoffUntilByUserId[player.UserId] = nil
>>>>>>> Stashed changes
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if AGENT_NAMES[descendant.Name] and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
		attachToAgent(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if AGENT_NAMES[descendant.Name] and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
		attachToAgent(descendant)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	connectPlayer(player)
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(disconnectPlayer)
