-- Server loader for RepTrack module
-- Other server scripts can require this module via ReplicatedStorage.Shared.RepTrack or by using _G.RepTrack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	warn("RepTrack.server.luau should run on server only")
	return
end

local sharedRoot = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
local repTrackModule = sharedRoot:FindFirstChild("RepTrack")
if not repTrackModule then
	warn("RepTrack module not found in ReplicatedStorage.Shared or ReplicatedStorage")
	return
end

local RepTrack = require(repTrackModule)

-- Expose globally to server scripts for quick access.
_G.RepTrack = RepTrack

--  Provide a RemoteFunction/RemoteEvent interface
local networkRoot = sharedRoot
if not networkRoot then
	networkRoot = ReplicatedStorage
end

local remoteName = "RepTrackUpdate"
local remoteEvent = networkRoot:FindFirstChild(remoteName)
if not remoteEvent then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = remoteName
	remoteEvent.Parent = networkRoot
end

remoteEvent.OnServerEvent:Connect(function(player, command, value)
	if type(command) ~= "string" then
		return
	end

	if command == "AddRGood" then
		RepTrack.AddRGood(value)
	elseif command == "AddRbad" then
		RepTrack.AddRbad(value)
	elseif command == "SetRGood" then
		RepTrack.SetRGood(value)
	elseif command == "SetRbad" then
		RepTrack.SetRbad(value)
	end
end)

print("RepTrack server initialized: RGood=" .. RepTrack.GetRGood() .. ", Rbad=" .. RepTrack.GetRbad())
