local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCdata = require(Shared:WaitForChild("NPCdata"))
local LessonManager = require(script.Parent:WaitForChild("LessonManager"))

local AGENT_NAME_NORMALIZED = "agentray"
local PROMPT_NAME = "AgentRayPrompt"
local ACTION_TEXT = "Talk"
local OBJECT_TEXT = "Agent Ray"
local MAX_DISTANCE = 10
local HOLD_DURATION = 0.2
local LINE_DURATION = 3.2

local activeConversations = {}
local hookedModels = {}

local function normalizeName(name)
	return tostring(name or ""):gsub("[%s_%-]", ""):lower()
end

local function isAgentRayModel(instance)
	return instance:IsA("Model") and normalizeName(instance.Name) == AGENT_NAME_NORMALIZED
end

local function getDialogueLines()
	return NPCdata["Agent Ray"] or {
		"So you're the operative they sent?",
		"I have your tools ready.",
		"Use them carefully, and stay out of sight.",
	}
end

local function getPromptParent(model)
	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("Head", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function ensurePrompt(model)
	local prompt = model:FindFirstChild(PROMPT_NAME, true)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	local promptParent = getPromptParent(model)
	if not promptParent then
		warn("[AgentRay] No BasePart found for prompt on", model:GetFullName())
		return nil
	end

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = OBJECT_TEXT
	prompt.MaxActivationDistance = MAX_DISTANCE
	prompt.HoldDuration = HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptParent

	return prompt
end

local function playDialogue(player)
	for _, line in ipairs(getDialogueLines()) do
		LessonManager.TriggerNotification(player, "AGENT RAY", line, {
			duration = 3,
		})
		task.wait(LINE_DURATION)
	end
end

local function onPromptTriggered(player)
	if not player or not player.Parent then
		return
	end

	if activeConversations[player.UserId] then
		return
	end

	if player:GetAttribute("HasSpokenToAgentRay") == true then
		LessonManager.TriggerNotification(player, "AGENT RAY", "You already talked to me. Stay sharp.", {
			throttleKey = "agent_ray_repeat",
			throttleWindow = 5,
			duration = 3,
		})
		return
	end

	activeConversations[player.UserId] = true

	task.spawn(function()
		playDialogue(player)
		player:SetAttribute("HasSpokenToAgentRay", true)
		activeConversations[player.UserId] = nil
	end)
end

local function hookAgentRayModel(model)
	if hookedModels[model] then
		return
	end

	local prompt = ensurePrompt(model)
	if not prompt then
		return
	end

	hookedModels[model] = true
	prompt.Triggered:Connect(onPromptTriggered)
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	if isAgentRayModel(obj) then
		hookAgentRayModel(obj)
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if isAgentRayModel(obj) then
		hookAgentRayModel(obj)
	end
end)
