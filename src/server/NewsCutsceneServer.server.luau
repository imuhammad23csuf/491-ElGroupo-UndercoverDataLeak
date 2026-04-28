-- ServerScriptService/NewsCutsceneServer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Ensure RemoteEvent exists
local StartEvent = ReplicatedStorage:FindFirstChild("StartNewsCutscene")
if not StartEvent then
	StartEvent = Instance.new("RemoteEvent")
	StartEvent.Name = "StartNewsCutscene"
	StartEvent.Parent = ReplicatedStorage
end

local CompleteEvent = ReplicatedStorage:FindFirstChild("NewsCutsceneFinished")
if not CompleteEvent then
	CompleteEvent = Instance.new("RemoteEvent")
	CompleteEvent.Name = "NewsCutsceneFinished"
	CompleteEvent.Parent = ReplicatedStorage
end

-- Headlines (~60 seconds)
local HEADLINES = {
	{ text = "Good evening. We're coming to you with disturbing reports about the popular gaming platform Bloxplay.", duration = 4 },
	{ text = "Investigations reveal that Bloxplay has been sharing children's personal data with unauthorized third parties.", duration = 5 },
	{ text = "Security experts confirm that sensitive information including ages, locations, and gaming habits were compromised.", duration = 5 },
	{ text = "Parents express outrage as bad actors may have gained access to their children's private information.", duration = 4 },
	{ text = "Bloxplay officials have yet to comment on these serious allegations.", duration = 3 },
	{ text = "We'll continue to follow this developing story and bring you updates as they become available.", duration = 4 },
}

local NEWS_MUSIC_ID = "rbxassetid://137057705955446"
local STARTED_ATTRIBUTE = "NewsCutsceneStarted"
local COMPLETED_ATTRIBUTE = "NewsCutsceneCompleted"

-- Helper to get position from part/model
local function getPos(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart.Position
		end
		return inst:GetPivot().Position
	end
	return nil
end

-- Face NewsAgent toward camera
local function faceRigTowardCamera()
	local rig = workspace:FindFirstChild("NewsAgent")
	if not rig then return end

	local folder = rig:FindFirstChild("CameraPath")
	if not folder then return end

	local node = folder:FindFirstChild("CamFront") or folder:FindFirstChild("Cam1")
	if not node then return end

	local root = rig:FindFirstChild("HumanoidRootPart", true)
	if not root then
		root = rig.PrimaryPart or rig:FindFirstChildWhichIsA("BasePart", true)
	end
	if not root then return end

	local rootPos = root.Position
	local camPos = getPos(node)
	if not camPos then return end

	local target = Vector3.new(camPos.X, rootPos.Y, camPos.Z)
	root.CFrame = CFrame.new(rootPos, target)
end

-- 🔥 START CUTSCENE AUTOMATICALLY
local function startCutscene(player)
	if player:GetAttribute(STARTED_ATTRIBUTE) == true or player:GetAttribute(COMPLETED_ATTRIBUTE) == true then
		return
	end

	player:SetAttribute(STARTED_ATTRIBUTE, true)
	player:SetAttribute(COMPLETED_ATTRIBUTE, false)

	StartEvent:FireClient(player, {
		headlines         = HEADLINES,
		totalTime         = 60,
		musicId           = NEWS_MUSIC_ID,
		useRigName        = "NewsAgent",
		showBroadcastHUD  = true,
		showCenterCard    = false,
		clockStart        = "15:26",
	})
end

StartEvent.OnServerEvent:Connect(function(player)
	if not player or player.Parent ~= Players then
		return
	end

	task.defer(faceRigTowardCamera)
	startCutscene(player)
end)

CompleteEvent.OnServerEvent:Connect(function(player)
	if not player or player.Parent ~= Players then
		return
	end
	if player:GetAttribute(STARTED_ATTRIBUTE) ~= true then
		return
	end

	player:SetAttribute(COMPLETED_ATTRIBUTE, true)
end)

Players.PlayerAdded:Connect(function()
	task.defer(faceRigTowardCamera)
end)
