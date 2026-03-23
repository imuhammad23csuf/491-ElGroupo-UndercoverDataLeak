local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("NarrativeRemotes")
local startDialogueEvent = remotesFolder:WaitForChild("StartDialogue")
local chooseOptionEvent = remotesFolder:WaitForChild("ChooseOption")
local dialogueUpdateEvent = remotesFolder:WaitForChild("DialogueUpdate")

local function displayNode(nodeData)
	if nodeData.error then
		warn("Narrative error:", nodeData.error)
		return
	end

	print("----- DIALOGUE UPDATE -----")
	print("Node:", nodeData.nodeId or "none")
	print("Text:", nodeData.text or "none")
	print("Integrity:", nodeData.integrity or 0)

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

-- Example starter call for testing
task.wait(3)
startDialogueEvent:FireServer("Intro")

-- For temporary testing in output:
-- After the dialogue starts, you can manually uncomment one of these.
-- task.wait(5)
-- chooseOptionEvent:FireServer(1)

-- task.wait(8)
-- chooseOptionEvent:FireServer(2)