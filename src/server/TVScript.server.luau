local tv = script.Parent
local clickDetector = tv:WaitForChild("ClickDetector")

local replicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local openEvent = replicatedStorage:WaitForChild("OpenCameraMonitor")

local JAM_STATE_ATTRIBUTE = "CameraNetworkJamUntil"

-- Reuse the existing educational-notification remote so the client
-- displays the standard in-game toast (see EducationalNotification.client.luau).
local function getNotifyRemote()
	local remote = replicatedStorage:FindFirstChild("ShowEducationalNotification")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ShowEducationalNotification"
		remote.Parent = replicatedStorage
	end
	return remote
end

local function isJamActive()
	local jamUntil = replicatedStorage:GetAttribute(JAM_STATE_ATTRIBUTE)
	return typeof(jamUntil) == "number" and jamUntil > Workspace:GetServerTimeNow()
end

local function notifyAll(title, message)
	local remote = getNotifyRemote()
	for _, player in ipairs(Players:GetPlayers()) do
		remote:FireClient(player, title, message, 6)
	end
end

clickDetector.MouseClick:Connect(function(player)
	openEvent:FireClient(player)

	-- Warn the player opening the monitor if cameras are currently jammed.
	if isJamActive() then
		local remote = getNotifyRemote()
		remote:FireClient(player, "CAMERA NETWORK JAMMED", "All camera feeds are disrupted. Security cannot monitor the area.", 6)
	end
end)

-- Broadcast a game-wide message whenever the jam state toggles so every
-- player knows whether cameras are active or blinded.
replicatedStorage:GetAttributeChangedSignal(JAM_STATE_ATTRIBUTE):Connect(function()
	if isJamActive() then
		notifyAll("CAMERA NETWORK JAMMED", "All security cameras have been disrupted. Camera feeds are offline.")
	else
		notifyAll("Camera Network Restored", "Security cameras are back online.")
	end
end)