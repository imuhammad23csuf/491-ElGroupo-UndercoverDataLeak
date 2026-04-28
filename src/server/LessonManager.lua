local LessonManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local popupCooldowns = {}

local function ensureRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local popupEvent = ensureRemote("ShowEducationalPopup")
local notificationEvent = ensureRemote("ShowEducationalNotification")

local lessonDatabase = {
    ClickedPhish = {
        title = "PHISHING DETECTED",
        message = "Always check the sender's email domain before clicking links. Hackers use urgent language to trick you into acting quickly.",
    },
    FoundStickyNotePassword = {
        title = "CREDENTIAL EXPOSURE",
        message = "Never write passwords on sticky notes attached to your monitor. Physical security is just as important as digital security!",
    },
    PublicWifiOpsec = {
        title = "OPSEC WARNING",
        message = "Handling sensitive corporate tools in a public coffee shop exposes you to shoulder surfing and unsecured network snooping.",
    },
    CaughtByCamera = {
        title = "SPOTTED BY CAMERA",
        message = "Cameras leave a permanent digital audit trail. As a cybersecurity professional, you must minimize your digital footprint.",
    },
    DetectedBySecurity = {
        title = "SECURITY TRIGGERED",
        message = "You were spotted! Physical security personnel are your biggest threat during an on-site infiltration.",
    },
    ClonedKeycard = {
        title = "RFID CLONED",
        message = "You successfully cloned a badge. In the real world, unprotected RFID cards can be copied just by standing near someone.",
    }
}

local function shouldThrottlePopup(player, throttleKey, throttleWindow)
	if not player or type(throttleKey) ~= "string" or throttleKey == "" then
		return false
	end

	local window = tonumber(throttleWindow) or 0
	if window <= 0 then
		return false
	end

	local userId = player.UserId
	local now = os.clock()
	local playerCooldowns = popupCooldowns[userId]

	if not playerCooldowns then
		playerCooldowns = {}
		popupCooldowns[userId] = playerCooldowns
	end

	local lastSentAt = playerCooldowns[throttleKey]
	if lastSentAt and now - lastSentAt < window then
		return true
	end

	playerCooldowns[throttleKey] = now
	return false
end

local function sendPopup(player, title, message, options)
	if not player then
		return false
	end

	options = options or {}
	if shouldThrottlePopup(player, options.throttleKey, options.throttleWindow) then
		return false
	end

	popupEvent:FireClient(
		player,
		tostring(title or "SECURITY ALERT"),
		tostring(message or "No lesson available.")
	)

	return true
end

local function sendNotification(player, title, message, options)
	if not player then
		return false
	end

	options = options or {}
	if shouldThrottlePopup(player, options.throttleKey, options.throttleWindow) then
		return false
	end

	notificationEvent:FireClient(
		player,
		tostring(title or "SECURITY ALERT"),
		tostring(message or "No lesson available."),
		tonumber(options.duration) or 4
	)

	return true
end

function LessonManager.TriggerMistake(player, mistakeId, options)
	local lesson = lessonDatabase[mistakeId]
	if not lesson then
		warn("ERROR: Could not find an educational lesson for mistake: " .. tostring(mistakeId))
		return false
	end

	return sendPopup(player, lesson.title, lesson.message, options)
end

function LessonManager.TriggerCustomPopup(player, title, message, options)
	return sendPopup(player, title, message, options)
end

function LessonManager.TriggerNotification(player, title, message, options)
	return sendNotification(player, title, message, options)
end

Players.PlayerRemoving:Connect(function(player)
	popupCooldowns[player.UserId] = nil
end)

return LessonManager
