local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueData = require(ReplicatedStorage.Shared.DialogueData)
local IntegrityService = require(ReplicatedStorage.Shared.IntegrityService)

local NarrativeManager = {}

local activeSessions = {}

local function getDialogue(dialogueId)
	return DialogueData[dialogueId]
end

local function getSession(player)
	if not player or not player.UserId then
		return nil
	end

	return activeSessions[player.UserId]
end

local function setSession(player, sessionData)
	if not player or not player.UserId then
		return
	end

	activeSessions[player.UserId] = sessionData
end

local function clearSession(player)
	if not player or not player.UserId then
		return
	end

	activeSessions[player.UserId] = nil
end

function NarrativeManager.startDialogue(player, dialogueId)
	local dialogue = getDialogue(dialogueId)
	if not dialogue then
		return nil, "Dialogue not found"
	end

	local startNodeId = dialogue.start
	local startNode = dialogue.nodes[startNodeId]

	if not startNode then
		return nil, "Start node not found"
	end

	setSession(player, {
		dialogueId = dialogueId,
		currentNodeId = startNodeId,
	})

	return {
		dialogueId = dialogueId,
		nodeId = startNodeId,
		text = startNode.text,
		choices = startNode.choices,
		isEnd = startNode.isEnd or false,
		integrity = IntegrityService.getIntegrity(player),
	}
end

function NarrativeManager.getCurrentNode(player)
	local session = getSession(player)
	if not session then
		return nil, "No active dialogue"
	end

	local dialogue = getDialogue(session.dialogueId)
	if not dialogue then
		return nil, "Dialogue data missing"
	end

	local node = dialogue.nodes[session.currentNodeId]
	if not node then
		return nil, "Current node missing"
	end

	return {
		dialogueId = session.dialogueId,
		nodeId = session.currentNodeId,
		text = node.text,
		choices = node.choices,
		isEnd = node.isEnd or false,
		integrity = IntegrityService.getIntegrity(player),
	}
end

function NarrativeManager.chooseOption(player, choiceIndex)
	local session = getSession(player)
	if not session then
		return nil, "No active dialogue"
	end

	local dialogue = getDialogue(session.dialogueId)
	if not dialogue then
		return nil, "Dialogue data missing"
	end

	local currentNode = dialogue.nodes[session.currentNodeId]
	if not currentNode then
		return nil, "Current node missing"
	end

	local choices = currentNode.choices or {}
	local choice = choices[choiceIndex]

	if not choice then
		return nil, "Invalid choice"
	end

	if choice.integrity then
		IntegrityService.addIntegrity(player, choice.integrity)
	end

	if not choice.next then
		clearSession(player)
		return {
			dialogueId = session.dialogueId,
			nodeId = nil,
			text = nil,
			choices = {},
			isEnd = true,
			integrity = IntegrityService.getIntegrity(player),
		}
	end

	local nextNode = dialogue.nodes[choice.next]
	if not nextNode then
		clearSession(player)
		return nil, "Next node missing"
	end

	session.currentNodeId = choice.next
	setSession(player, session)

	local response = {
		dialogueId = session.dialogueId,
		nodeId = choice.next,
		text = nextNode.text,
		choices = nextNode.choices,
		isEnd = nextNode.isEnd or false,
		integrity = IntegrityService.getIntegrity(player),
	}

	if nextNode.isEnd then
		clearSession(player)
	end

	return response
end

function NarrativeManager.endDialogue(player)
	clearSession(player)
end

function NarrativeManager.hasActiveDialogue(player)
	return getSession(player) ~= nil
end

return NarrativeManager
