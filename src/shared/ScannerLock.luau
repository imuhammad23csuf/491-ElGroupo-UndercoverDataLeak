local prompt = script.Parent

prompt.Triggered:Connect(function(player)
	-- 1. Check if the player is physically holding the GhostKey
	local character = player.Character
	local holdingGhostKey = character and character:FindFirstChild("GhostKey")

	if holdingGhostKey then
		-- 2. They have the key in hand! Now check if they stole the code.
		if player:GetAttribute("HasKeycardData") == true then
			print("ACCESS GRANTED: Unlocking doors for " .. player.Name)

			-- Unlock the door
			player:SetAttribute("UnlockedSlidingDoor", true)

			-- Change UI and turn off the scanner
			prompt.ActionText = "ACCESS GRANTED"
			task.wait(1)
			prompt.Enabled = false 
		else
			-- They hold the key, but haven't hacked the guard yet
			print("ACCESS DENIED: Ghost Key is empty")
			prompt.ActionText = "KEY EMPTY"
			task.wait(1)
			prompt.ActionText = "OpenDoor"
		end
	else
		-- 3. They pressed 'E' with empty hands
		print("ACCESS DENIED: You must equip the Ghost Key!")
		prompt.ActionText = "USE GHOST KEY"
		task.wait(1)
		prompt.ActionText = "OpenDoor"
	end
end)