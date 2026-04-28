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
}

local TOOL_NAMES = {
	"HackTablet",
	"GhostKey",
}

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

local function enforceNoToolsBeforeVisit(player)
	if not player or player:GetAttribute("HasSpokenToAgentRay") == true then
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
	markAgentRayVisited(player)

	for _, toolName in ipairs(TOOL_NAMES) do
		grantTool(player, toolName)
	end

	LessonManager.TriggerMistake(player, "PublicWifiOpsec", {
		throttleKey = "agent_ray_cafe_tools",
		throttleWindow = 60,
	})
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

	local token = os.clock()
	pendingGrantTokensByUserId[player.UserId] = token

	task.spawn(function()
		waitForAgentDialogueToFinish(player, prompt, token)

		if pendingGrantTokensByUserId[player.UserId] ~= token then
			return
		end

		handleAgentVisit(player)
	end)
end

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
