local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local REMOTES_FOLDER_NAME = "Remotes"
local TITLE_SCREEN_REMOTE_NAME = "SetTitleScreenVisible"
local TOOL_VAULT_NAME = "HiddenStarterTools"

local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = REMOTES_FOLDER_NAME
	remotesFolder.Parent = ReplicatedStorage
end

local titleScreenRemote = remotesFolder:FindFirstChild(TITLE_SCREEN_REMOTE_NAME)
if not titleScreenRemote then
	titleScreenRemote = Instance.new("RemoteEvent")
	titleScreenRemote.Name = TITLE_SCREEN_REMOTE_NAME
	titleScreenRemote.Parent = remotesFolder
end

local toolVault = ServerStorage:FindFirstChild(TOOL_VAULT_NAME)
if not toolVault then
	toolVault = Instance.new("Folder")
	toolVault.Name = TOOL_VAULT_NAME
	toolVault.Parent = ServerStorage
end

local managedToolNames = {}
local monitoredPlayers = {}

local function isManagedTool(tool)
	return tool and tool:IsA("Tool") and managedToolNames[tool.Name] == true
end

local function registerToolTemplate(tool)
	if not tool or not tool:IsA("Tool") then
		return
	end

	managedToolNames[tool.Name] = true

	local existing = toolVault:FindFirstChild(tool.Name)
	if existing and existing ~= tool then
		existing:Destroy()
	end

	tool.Parent = toolVault
end

local function hideStarterPackTools()
	for _, child in ipairs(StarterPack:GetChildren()) do
		registerToolTemplate(child)
	end
end

local function shouldShowTools(player)
	return player:GetAttribute("HasSpokenToAgentRay") == true
		and player:GetAttribute("TitleScreenVisible") ~= true
end

local function removeManagedTools(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if isManagedTool(child) then
			child:Destroy()
		end
	end
end

local function ensureTool(container, template)
	if not container or not template or not template:IsA("Tool") then
		return
	end

	local existing = container:FindFirstChild(template.Name)
	if existing and existing:IsA("Tool") then
		return
	end

	template:Clone().Parent = container
end

local function syncPlayerTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	local character = player.Character

	if shouldShowTools(player) then
		for _, template in ipairs(toolVault:GetChildren()) do
			if template:IsA("Tool") then
				ensureTool(backpack, template)
				ensureTool(starterGear, template)
			end
		end
	else
		removeManagedTools(backpack)
		removeManagedTools(starterGear)
		removeManagedTools(character)
	end
end

local function monitorContainer(player, container)
	if not container then
		return
	end

	container.ChildAdded:Connect(function(child)
		if isManagedTool(child) and not shouldShowTools(player) then
			task.defer(function()
				if child.Parent == container and not shouldShowTools(player) then
					child:Destroy()
				end
			end)
		end
	end)
end

local function setupPlayer(player)
	if monitoredPlayers[player] then
		return
	end

	monitoredPlayers[player] = true

	if player:GetAttribute("TitleScreenVisible") == nil then
		player:SetAttribute("TitleScreenVisible", true)
	end

	if player:GetAttribute("HasSpokenToAgentRay") == nil then
		player:SetAttribute("HasSpokenToAgentRay", false)
	end

	player:GetAttributeChangedSignal("TitleScreenVisible"):Connect(function()
		syncPlayerTools(player)
	end)

	player:GetAttributeChangedSignal("HasSpokenToAgentRay"):Connect(function()
		syncPlayerTools(player)
	end)

	player.CharacterAdded:Connect(function(character)
		monitorContainer(player, character)
		task.defer(function()
			syncPlayerTools(player)
		end)
	end)

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	monitorContainer(player, backpack)
	monitorContainer(player, player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear"))

	task.defer(function()
		syncPlayerTools(player)
	end)
end

hideStarterPackTools()

StarterPack.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		task.defer(function()
			if child.Parent == StarterPack then
				registerToolTemplate(child)
			end
		end)
	end
end)

titleScreenRemote.OnServerEvent:Connect(function(player, isVisible)
	if not player or not player.Parent then
		return
	end

	player:SetAttribute("TitleScreenVisible", isVisible == true)
	syncPlayerTools(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	monitoredPlayers[player] = nil
end)
