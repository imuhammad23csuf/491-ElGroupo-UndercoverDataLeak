local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NarrativeManager = require(Shared:WaitForChild("NarrativeManager"))
local IntegrityService = require(Shared:WaitForChild("IntegrityService"))

local remotesFolder = ReplicatedStorage:FindFirstChild("NarrativeRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "NarrativeRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local startDialogueEvent = remotesFolder:FindFirstChild("StartDialogue")
if not startDialogueEvent then
	startDialogueEvent = Instance.new("RemoteEvent")
	startDialogueEvent.Name = "StartDialogue"
	startDialogueEvent.Parent = remotesFolder
end

local chooseOptionEvent = remotesFolder:FindFirstChild("ChooseOption")
if not chooseOptionEvent then
	chooseOptionEvent = Instance.new("RemoteEvent")
	chooseOptionEvent.Name = "ChooseOption"
	chooseOptionEvent.Parent = remotesFolder
end

local dialogueUpdateEvent = remotesFolder:FindFirstChild("DialogueUpdate")
if not dialogueUpdateEvent then
	dialogueUpdateEvent = Instance.new("RemoteEvent")
	dialogueUpdateEvent.Name = "DialogueUpdate"
	dialogueUpdateEvent.Parent = remotesFolder
end

local function sendError(player, message)
	dialogueUpdateEvent:FireClient(player, {
		error = message,
	})
end

startDialogueEvent.OnServerEvent:Connect(function(player, dialogueId)
	local nodeData, err = NarrativeManager.startDialogue(player, dialogueId)
	if not nodeData then
		sendError(player, err or "Failed to start dialogue")
		return
	end

	dialogueUpdateEvent:FireClient(player, nodeData)
end)

chooseOptionEvent.OnServerEvent:Connect(function(player, choiceIndex)
	local nodeData, err = NarrativeManager.chooseOption(player, choiceIndex)
	if not nodeData then
		sendError(player, err or "Failed to process choice")
		return
	end

	dialogueUpdateEvent:FireClient(player, nodeData)
end)

Players.PlayerRemoving:Connect(function(player)
	NarrativeManager.endDialogue(player)
	IntegrityService.resetIntegrity(player)
end)