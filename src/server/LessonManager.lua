local LessonManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Find the exact same mailbox we built in Ticket 111
local popupEvent = ReplicatedStorage:FindFirstChild("ShowEducationalPopup")
if not popupEvent then
	popupEvent = Instance.new("RemoteEvent")
	popupEvent.Name = "ShowEducationalPopup"
	popupEvent.Parent = ReplicatedStorage
end

-- 2. The Mapping System (The Library of Mistakes)
local lessonDatabase = {
	["ClickedPhish"] = {
		title = "PHISHING DETECTED",
		message = "Always check the sender's email domain before clicking links. Hackers use urgent language to trick you into acting quickly."
	},
	["StickyNotePassword"] = {
		title = "CREDENTIAL EXPOSURE",
		message = "Never write passwords on sticky notes attached to your monitor. Physical security is just as important as digital security!"
	},
	["PublicWifiOpsec"] = {
		title = "OPSEC WARNING",
		message = "Handling sensitive corporate tools in a public coffee shop exposes you to shoulder surfing and unsecured network snooping."
	},
    ["CameraDetected"] = {
        title = "SPOTTED BY CAMERA",
        message = "Cameras leave a permanent digital audit trail. As a cybersecurity professional, you must minimize your digital footprint."
    }
}

-- 3. The Logic Script that "listens" and triggers the UI
function LessonManager.TriggerMistake(player, mistakeId)
	local lesson = lessonDatabase[mistakeId]
	
	if lesson then
		-- Send the specific Title and Message to the player's UI
		popupEvent:FireClient(player, lesson.title, lesson.message)
		print("Sent lesson '" .. mistakeId .. "' to " .. player.Name)
	else
		warn("ERROR: Could not find an educational lesson for mistake: " .. tostring(mistakeId))
	end
end

return LessonManager