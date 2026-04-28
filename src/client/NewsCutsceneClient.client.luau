-- StarterPlayerScripts/NewsCutsceneClient (LocalScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local StartEvent = ReplicatedStorage:WaitForChild("StartNewsCutscene")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ok, Cutscene = pcall(function()
	return require(Shared:WaitForChild("NewsCutscene"))
end)

if not ok or type(Cutscene) ~= "table" or type(Cutscene.Play) ~= "function" then
	warn("[NewsCutsceneClient] NewsCutscene module missing/invalid.")
	return
end

local playing = false

StartEvent.OnClientEvent:Connect(function(payload)
	if playing then return end
	if not payload or not payload.headlines then
		warn("[NewsCutsceneClient] Missing payload/headlines.")
		return
	end

	playing = true
	Cutscene.Play(player, payload)
	playing = false
end)