local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local notificationEvent = ReplicatedStorage:WaitForChild("ShowEducationalNotification")

local function showNotification(title, message, duration)
	task.spawn(function()
		for _ = 1, 6 do
			local ok = pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = tostring(title or "SECURITY ALERT"),
					Text = tostring(message or "No details available."),
					Duration = tonumber(duration) or 4,
				})
			end)

			if ok then
				return
			end

			task.wait(0.5)
		end
	end)
end

notificationEvent.OnClientEvent:Connect(showNotification)
