-- StarterPlayerScripts/NewsCutsceneClient (LocalScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local StartEvent = ReplicatedStorage:WaitForChild("StartNewsCutscene")
local CompleteEvent = ReplicatedStorage:WaitForChild("NewsCutsceneFinished", 10)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ok, Cutscene = pcall(function()
	return require(Shared:WaitForChild("NewsCutscene"))
end)

if not ok or type(Cutscene) ~= "table" or type(Cutscene.Play) ~= "function" then
	warn("[NewsCutsceneClient] NewsCutscene module missing/invalid.")
	return
end

local playing = false
local STARTED_ATTRIBUTE = "NewsCutsceneStarted"
local COMPLETED_ATTRIBUTE = "NewsCutsceneCompleted"

StartEvent.OnClientEvent:Connect(function(payload)
	if playing then return end
	if player:GetAttribute(COMPLETED_ATTRIBUTE) == true then return end
	if not payload or not payload.headlines then
		warn("[NewsCutsceneClient] Missing payload/headlines.")
		return
	end

	playing = true
	player:SetAttribute(STARTED_ATTRIBUTE, true)
	local okPlay, playErr = pcall(function()
		Cutscene.Play(player, payload)
	end)
	if not okPlay then
		warn("[NewsCutsceneClient] News cutscene failed: " .. tostring(playErr))
	end
	player:SetAttribute(COMPLETED_ATTRIBUTE, true)
	if CompleteEvent and CompleteEvent:IsA("RemoteEvent") then
		CompleteEvent:FireServer()
	end
	playing = false
end)
