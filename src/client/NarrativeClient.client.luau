local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("NarrativeRemotes")
local chooseOptionEvent = remotesFolder:WaitForChild("ChooseOption")
local dialogueUpdateEvent = remotesFolder:WaitForChild("DialogueUpdate")

local function displayNode(nodeData)
	if type(nodeData) ~= "table" then
		return
	end

	if nodeData.error then
		warn("Narrative error:", nodeData.error)
		return
	end

	print("----- DIALOGUE UPDATE -----")
	print("Node:", nodeData.nodeId or "none")
	print("Text:", nodeData.text or "none")

	if nodeData.choices and #nodeData.choices > 0 then
		for index, choice in ipairs(nodeData.choices) do
			print(index .. ". " .. choice.text)
		end
	else
		print("No choices available.")
	end

	if nodeData.isEnd then
		print("Dialogue ended.")
	end
end

dialogueUpdateEvent.OnClientEvent:Connect(displayNode)

-- chooseOptionEvent is kept so dialogue UI can hook into it later.
local _unusedChooseOptionEvent = chooseOptionEvent
