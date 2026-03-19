local tv = script.Parent
local clickDetector = tv:WaitForChild("ClickDetector")

local replicatedStorage = game:GetService("ReplicatedStorage")
local openEvent = replicatedStorage:WaitForChild("OpenCameraMonitor")

clickDetector.MouseClick:Connect(function(player)
	openEvent:FireClient(player)
end)