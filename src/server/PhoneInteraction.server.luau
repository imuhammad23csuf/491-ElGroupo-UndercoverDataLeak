local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PHONE_NAME = "Phone"
local CLICK_DETECTOR_NAME = "PhoneClickDetector"
local REMOTE_NAME = "PhoneCallRequested"
local MAX_ACTIVATION_DISTANCE = 24
local PHONE_SEARCH_INTERVAL = 1

local phoneCallRequested = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not phoneCallRequested then
	phoneCallRequested = Instance.new("RemoteEvent")
	phoneCallRequested.Name = REMOTE_NAME
	phoneCallRequested.Parent = ReplicatedStorage
end

local connectedDetectors = {}
local detectorPhones = {}
local watchedPhones = {}

local function isPhoneInstance(instance)
	return instance
		and instance.Name == PHONE_NAME
		and (instance:IsA("Model") or instance:IsA("BasePart"))
end

local function findPhones()
	local phones = {}

	local direct = Workspace:FindFirstChild(PHONE_NAME)
	if isPhoneInstance(direct) then
		table.insert(phones, direct)
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isPhoneInstance(descendant) and descendant ~= direct then
			table.insert(phones, descendant)
		end
	end

	return phones
end

local function isInPhone(instance, phone)
	return phone
		and phone.Parent
		and instance
		and (instance == phone or instance:IsDescendantOf(phone))
end

local function canReachDetector(player, detector)
	if not player or player.Parent ~= Players then
		return false
	end

	local part = detector.Parent
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not part or not part:IsA("BasePart") or not root then
		return false
	end

	return (root.Position - part.Position).Magnitude <= MAX_ACTIVATION_DISTANCE + 3
end

local function connectDetector(detector, phone)
	if connectedDetectors[detector] then
		detectorPhones[detector] = phone or detectorPhones[detector]
		return
	end

	connectedDetectors[detector] = true
	detectorPhones[detector] = phone
	detector.MaxActivationDistance = MAX_ACTIVATION_DISTANCE

	detector.MouseClick:Connect(function(player)
		local owningPhone = detectorPhones[detector]
		if not isInPhone(detector, owningPhone) or not canReachDetector(player, detector) then
			return
		end

		phoneCallRequested:FireClient(player)
	end)
end

local function attachClickDetector(part, phone)
	if not part:IsA("BasePart") then
		return
	end

	local hasClickDetector = false
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ClickDetector") then
			hasClickDetector = true
			connectDetector(child, phone)
		end
	end

	if not hasClickDetector then
		local detector = Instance.new("ClickDetector")
		detector.Name = CLICK_DETECTOR_NAME
		detector.MaxActivationDistance = MAX_ACTIVATION_DISTANCE
		detector.Parent = part
		connectDetector(detector, phone)
	end
end

local function ensurePhoneDetectors(phone)
	if phone:IsA("BasePart") then
		attachClickDetector(phone, phone)
		return
	end

	for _, descendant in ipairs(phone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			attachClickDetector(descendant, phone)
		elseif descendant:IsA("ClickDetector") then
			connectDetector(descendant, phone)
		end
	end
end

local function attachPhone(phone)
	ensurePhoneDetectors(phone)

	if watchedPhones[phone] then
		return
	end

	watchedPhones[phone] = true
	phone.DescendantAdded:Connect(function(descendant)
		if not isInPhone(descendant, phone) then
			return
		end

		if descendant:IsA("BasePart") then
			attachClickDetector(descendant, phone)
		elseif descendant:IsA("ClickDetector") then
			connectDetector(descendant, phone)
		end
	end)
end

for _, phone in ipairs(findPhones()) do
	attachPhone(phone)
end

Workspace.DescendantAdded:Connect(function(descendant)
	if isPhoneInstance(descendant) then
		attachPhone(descendant)
		return
	end

	for phone in pairs(watchedPhones) do
		if isInPhone(descendant, phone) then
			if descendant:IsA("BasePart") then
				attachClickDetector(descendant, phone)
			elseif descendant:IsA("ClickDetector") then
				connectDetector(descendant, phone)
			end
			return
		end
	end
end)

task.spawn(function()
	while true do
		for phone in pairs(watchedPhones) do
			if not phone.Parent then
				watchedPhones[phone] = nil
			end
		end

		for _, phone in ipairs(findPhones()) do
			attachPhone(phone)
		end

		task.wait(PHONE_SEARCH_INTERVAL)
	end
end)
