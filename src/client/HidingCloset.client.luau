prompt = script.Parent
model = prompt.Parent.Parent.Door
interacts = {
	"Hide",
	"Exit",
}
prompt.Triggered:Connect(function(player)
	if script.Parent.Parent.Parent.userInside.Value == "" or script.Parent.Parent.Parent.userInside.Value == player.Name then
		rotateCount = 0
		prompt.Enabled = false
		model.DoorOpen:Play()
		while rotateCount < 20 do
			pivot = model:GetPivot()
			model:PivotTo(pivot * CFrame.fromEulerAngles(0,-0.1,0))
			rotateCount = rotateCount + 1
			task.wait(0.01)
		end
		if prompt.ActionText == interacts[1] then
			char = player.Character
			char:FindFirstChild("HumanoidRootPart").Anchored = true
			char:MoveTo(prompt.Parent.Parent.Frame.Base.HidingPosition.WorldPosition)
			local clone = script.Parent.Parent.Parent.HidingUI:Clone()
			clone.Parent = player.PlayerGui
			script.Parent.Parent.Parent.somebodyHiding.Value = true
			script.Parent.Parent.Parent.userInside.Value = player.Name
		elseif prompt.ActionText == interacts[2] then
			char = player.Character
			char:FindFirstChild("HumanoidRootPart").Anchored = false
			char:MoveTo(prompt.Parent.Parent.Frame.Base.ExitPosition.WorldPosition)
			script.Parent.Parent.Parent.somebodyHiding.Value = false
			script.Parent.Parent.Parent.userInside.Value = ""
		end
		rotateCount = 0
		while rotateCount < 20 do
			pivot = model:GetPivot()
			model:PivotTo(pivot * CFrame.fromEulerAngles(0,0.1,0))
			rotateCount = rotateCount + 1
			task.wait(0.01)
		end
		model.DoorClose:Play()
		local ui = player.PlayerGui:FindFirstChild("HidingUI")
		if prompt.ActionText == interacts[1] then
			while ui.ImageLabel.ImageTransparency > 0.5 do -- FIX HERE
				ui.ImageLabel.ImageTransparency = ui.ImageLabel.ImageTransparency - 0.1
				task.wait(0.025)
			end
			prompt.ActionText = interacts[2]
		elseif prompt.ActionText == interacts[2] then
			local cloned = player.PlayerGui:FindFirstChild("HidingUI")
			if cloned then
				while cloned.ImageLabel.ImageTransparency < 1 do
					cloned.ImageLabel.ImageTransparency = cloned.ImageLabel.ImageTransparency + 0.1
					task.wait(0.025)
				end
				cloned:Remove()
			end
			prompt.ActionText = interacts[1]
		end
		prompt.Enabled = true
	end
end)