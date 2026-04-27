-- HackTablet OS (StarterPlayerScripts) - FULL CODE - MODIFIED
-- Simulation-only cybersecurity tablet for a fictional game streaming company
-- Missions tab logic/UI/objective system left intact
-- MODIFICATIONS: Close on unequip only, reset menu on re-equip, loading bar boot screen
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Http = game:GetService("HttpService")
local Tween = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))
local ScenarioData = require(Shared:WaitForChild("ScenarioData"))
local CameraMetadata = require(Shared:WaitForChild("CameraMetadata"))
local TabletData = require(script.Parent:WaitForChild("TabletData"))
local TabletIncidentLogs = require(script.Parent:WaitForChild("TabletIncidentLogs"))
local TabletSimOps = require(script.Parent:WaitForChild("TabletSimOps"))
local TabletMainUI = require(script.Parent:WaitForChild("TabletMainUI"))
local TabletMissionUI = require(script.Parent:WaitForChild("TabletMissionUI"))
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local TOOL_NAME = "HackTablet"
local Tool = nil
local PROMPT = "rbxplayer@hackos:~$ "
local AUDIO_TAG = "HackTablet_Audio"
local E_BIND = "HackTablet_E_Block"
local BLUR_NAME = "HackStartBlur"
local RESTORE_STATE_ATTRIBUTE = "HackTabletRestoreBlob"
local SAVE_REMOTE_NAME = "SaveProgress"
local START_OVER_REMOTE_NAME = "StartOverProgress"
local CAMERA_JAM_REMOTE_NAME = "JamCamera"
local DISTRACT_GUARD_REMOTE_NAME = "DistractOutGuard"
local WANNAWAIL_ATTR_ACTIVE = "WannaWailActive"
local WANNAWAIL_ATTR_COUNT = "WannaWailInfectedCount"
local WANNAWAIL_ATTR_LAST_MACHINE = "WannaWailLastMachine"
local WANNAWAIL_ATTR_SOURCE_BLOCKED = "WannaWailSourceBlocked"
local WANNAWAIL_ATTR_FIREWALL_BLOCKED = "WannaWailFirewallRuleAdded"
local WANNAWAIL_ATTR_PROCESS_KILLED = "WannaWailProcessKilled"
local WANNAWAIL_ATTR_LOADER_REMOVED = "WannaWailLoaderRemoved"
local WANNAWAIL_ATTR_CONTAINED = "WannaWailContained"
local WANNAWAIL_ATTACKER_IP = "203.44.18.77"
local AUTO_SAVE_DELAY = 1.5
local DEFAULT_CHAPTER3_MAILBOX = TabletData.DEFAULT_CHAPTER3_MAILBOX
local CHAPTER3_MAILBOX = TabletData.resolveChapter3Mailbox(ScenarioData)
local FakePlayerRows = TabletData.FakePlayerRows
local SimHosts = TabletData.SimHosts
local SimFSByHost = TabletData.SimFSByHost
local SimFileContentsByHost = TabletData.SimFileContentsByHost
local SimMetadataByHost = TabletData.SimMetadataByHost
local OpenFiles = {}
local SimProcessesByHost = TabletData.SimProcessesByHost
local FakeAdminRecords = TabletData.FakeAdminRecords
local AdminLogFeed = TabletData.AdminLogFeed
local PAGES = TabletData.PAGES

local isEquipped = false
local started = false
local lastEquipped = false

local MainGUI, HintGUI, ReplayPromptGUI
local TermFrame, BrowserFrame, TermOut, TermInput, UrlBox, PageLabel, ClockLabel, MissionsFrame, MissionsList, ObjectivesList
local BrowserStatusLabel, BrowserContent, LinkBar
local AdminLoginPage, AdminDashboardPage, AdminUserBox, AdminPassBox, AdminLoginStatus, AdminSearchBox, AdminResultsFrame
local PacketPage, PacketToolbar, PacketListFrame, PacketIPBox, PacketDNSBox, PacketApplyBtn, PacketClearBtn, PacketFollowBtn


local browserState = {
    adminLoggedIn = false,
    currentUrl = "about:blank",
    stickyNoteInspected = false,
    adminTab = "database",
    blockedIPs = {},
    selectedMailId = type(CHAPTER3_MAILBOX[1]) == "table" and tostring(CHAPTER3_MAILBOX[1].id or "") or "",
    logStreamStartedAt = 0,
    logsLastRender = 0,
    lastInteractionAt = os.clock(),
    idleAutoSaveNotified = false,
    visiblePanel = "terminal",
}
local terminalState = {
    currentHost = "local",
    currentDir = "/",
    connectedHost = nil,
    sshSession = false,
    scanCache = nil,
    sniffCache = nil,
    lastAttackerIP = WANNAWAIL_ATTACKER_IP,
}
local commandHistory = {}
local historyIndex = nil
local currentDraft = ""
local autoSaveQueuedAt = 0
local autoSaveLastRunAt = 0
local autoSaveInFlight = false
local autoSaveSuppressed = false
local replayPromptShown = false
local replayPromptClearDone = false
local chapterExpanded = {}

local ActivePacketCapture = {
    targetIP = "",
    targetLabel = "",
    rows = {},
}

local addLine, historyUp, historyDown
local captureProgressState, applyProgressState, applyPendingRestoreState, submitScenarioAction
local installSimOps

local function getWannaWailIncidentLogs()
return TabletIncidentLogs.getWannaWailIncidentLogs(Player, {
WANNAWAIL_ATTR_COUNT = WANNAWAIL_ATTR_COUNT,
WANNAWAIL_ATTR_ACTIVE = WANNAWAIL_ATTR_ACTIVE,
WANNAWAIL_ATTR_LAST_MACHINE = WANNAWAIL_ATTR_LAST_MACHINE,
WANNAWAIL_ATTR_SOURCE_BLOCKED = WANNAWAIL_ATTR_SOURCE_BLOCKED,
WANNAWAIL_ATTR_FIREWALL_BLOCKED = WANNAWAIL_ATTR_FIREWALL_BLOCKED,
WANNAWAIL_ATTR_PROCESS_KILLED = WANNAWAIL_ATTR_PROCESS_KILLED,
WANNAWAIL_ATTR_LOADER_REMOVED = WANNAWAIL_ATTR_LOADER_REMOVED,
WANNAWAIL_ATTR_CONTAINED = WANNAWAIL_ATTR_CONTAINED,
WANNAWAIL_ATTACKER_IP = WANNAWAIL_ATTACKER_IP,
}, AdminLogFeed)
end

local function notify(t)
pcall(function()
StarterGui:SetCore("SendNotification", t)
end)
end

browserState._markInteraction = function()
	browserState.lastInteractionAt = os.clock()
	browserState.idleAutoSaveNotified = false
end
local function mk(t, p)
local i = Instance.new(t)
for k, v in pairs(p or {}) do
i[k] = v
end
return i
end
local function round(o, r)
mk("UICorner", { Parent = o, CornerRadius = UDim.new(0, r or 10) })
end
local function fadeVol(s, v, d)
if not s then return end
pcall(function()
Tween:Create(s, TweenInfo.new(d or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
Volume = math.clamp(v, 0, 10),
}):Play()
end)
end
notify({ Title = "SIMULATION WARNING", Text = "Simulated interface. Do not replicate in real life.", Duration = 5 })
local function getSound()
local s = SoundService:FindFirstChild(AUDIO_TAG)
if s and s:IsA("Sound") then
return s
end
s = mk("Sound", {
Name = AUDIO_TAG,
SoundId = "rbxassetid://74606780873749",
Volume = 0,
Looped = false,
Parent = SoundService,
})
task.spawn(function()
pcall(function()
ContentProvider:PreloadAsync({ s })
end)
end)
return s
end
local function playAudio()
local s = getSound()
if not s.IsPlaying then
s.TimePosition = 0
s:Play()
end
fadeVol(s, 0.95, 0.4)
end
local function stopAudio()
local s = SoundService:FindFirstChild(AUDIO_TAG)
if not s then return end
fadeVol(s, 0, 0.25)
task.delay(0.3, function()
if s and s.IsPlaying then
s:Stop()
end
end)
end
local function isToolEquipped()
	local c = Player.Character
	return Tool and c and Tool.Parent == c or false
end
local function setEquipped(on)
isEquipped = on
Player:SetAttribute("HackTabletEquipped", on)
end
local function getRemote(name)
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
return nil
end
return remotes:FindFirstChild(name)
end
local function getVisibleCameraLabels()
local labels = {}
local seen = {}
for _, obj in ipairs(Workspace:GetDescendants()) do
if obj:IsA("Model") and obj.Name == "Camera" then
local label = tostring(CameraMetadata.GetLocationLabel(obj) or "Unknown Location")
if label ~= "" and not seen[label] then
seen[label] = true
labels[#labels + 1] = label
end
end
end
table.sort(labels)
return labels
end
local function requestCameraJamFromTablet(options)
options = options or {}
browserState._markInteraction()

if BrowserStatusLabel then
BrowserStatusLabel.Text = "Sending camera jammer request..."
end
if options.echoTerminal and TermOut and TermOut.Parent then
addLine("Camera jammer request sent...")
end

local labels = getVisibleCameraLabels()
if #labels == 0 then
local message = "No camera models detected by the tablet jammer."
if BrowserStatusLabel then
BrowserStatusLabel.Text = message
end
notify({ Title = "HackTablet", Text = message, Duration = 3 })
if options.echoTerminal and TermOut and TermOut.Parent then
addLine(message)
end
return false
end
local jamRemote = getRemote(CAMERA_JAM_REMOTE_NAME)
if not jamRemote or not jamRemote:IsA("RemoteFunction") then
local message = "Camera jammer service unavailable."
if BrowserStatusLabel then
BrowserStatusLabel.Text = message
end
notify({ Title = "HackTablet", Text = message, Duration = 3 })
if options.echoTerminal and TermOut and TermOut.Parent then
addLine(message)
end
return false
end
local ok, result = pcall(function()
return jamRemote:InvokeServer("camera_network")
end)
local message = nil
if ok and type(result) == "table" then
message = tostring(result.message or "Camera jam request sent.")
else
message = "Camera jammer request failed."
end
if BrowserStatusLabel then
BrowserStatusLabel.Text = message
end
notify({ Title = "HackTablet", Text = message, Duration = 4 })
if options.echoTerminal and TermOut and TermOut.Parent then
addLine(message)
end
return ok and type(result) == "table" and result.success == true
end

local function requestGuardDistractFromTablet(options)
	options = options or {}
	browserState._markInteraction()

	local distractRemote = getRemote(DISTRACT_GUARD_REMOTE_NAME)
	if not distractRemote or not distractRemote:IsA("RemoteFunction") then
		local message = "Guard distraction service unavailable."
		if BrowserStatusLabel then
			BrowserStatusLabel.Text = message
		end
		notify({ Title = "HackTablet", Text = message, Duration = 3 })
		if options.echoTerminal and TermOut and TermOut.Parent then
			addLine(message)
		end
		return false
	end

	local ok, result = pcall(function()
		return distractRemote:InvokeServer()
	end)

	local success = ok and type(result) == "table" and result.success == true
	local message = "Guard distraction request failed."
	if ok and type(result) == "table" and type(result.message) == "string" and result.message ~= "" then
		message = result.message
	end

	if BrowserStatusLabel then
		BrowserStatusLabel.Text = message
	end

	notify({ Title = "HackTablet", Text = message, Duration = 4 })

	if options.echoTerminal and TermOut and TermOut.Parent then
		addLine(message)
	end

	return success
end
local function saveNow(options)
options = options or {}
if autoSaveSuppressed then
if not options.silent then
notify({ Title = "HackTablet", Text = "Saving is disabled after mission completion.", Duration = 3 })
end
autoSaveQueuedAt = 0
return false
end
if autoSaveInFlight then
if options.force then
autoSaveQueuedAt = os.clock()
end
return false
end
local saveRemote = getRemote(SAVE_REMOTE_NAME)
if not saveRemote then
if not options.silent then
notify({ Title = "HackTablet", Text = "Save service unavailable.", Duration = 3 })
end
return false
end
autoSaveInFlight = true
local ok, result = pcall(function()
return saveRemote:InvokeServer(captureProgressState and captureProgressState() or nil)
end)
autoSaveInFlight = false
if not ok or type(result) ~= "table" or not result.success then
if not options.silent then
notify({ Title = "HackTablet", Text = "Could not save progress.", Duration = 3 })
end
return false
end
autoSaveQueuedAt = 0
autoSaveLastRunAt = os.clock()
if not options.silent then
notify({ Title = "HackTablet", Text = tostring(result.message or "Progress saved."), Duration = 2 })
end
return true
end

local function queueAutoSave(_force)
if autoSaveSuppressed then
autoSaveQueuedAt = 0
return false
end
autoSaveQueuedAt = os.clock()
return true
end

local function teardownStart()
local blur = Lighting:FindFirstChild(BLUR_NAME)
if blur then blur:Destroy() end
local boot = PlayerGui:FindFirstChild("HackStart")
if boot then boot:Destroy() end
end
local function sanitizeTerminalText(txt)
local value = tostring(txt or "")
local maxRun = 28
value = value:gsub("([^%s%-_/%.,:;%(%)%[%]%{%}%+=]+)", function(token)
if #token <= maxRun then
return token
end
local chunks = {}
for i = 1, #token, maxRun do
chunks[#chunks + 1] = token:sub(i, i + maxRun - 1)
end
return table.concat(chunks, "\n")
end)
return value
end

local function ensureTerminalList()
if not TermOut then
return nil
end
local layout = TermOut:FindFirstChild("UIListLayout")
if layout and layout:IsA("UIListLayout") then
return layout
end
TermOut:ClearAllChildren()
layout = mk("UIListLayout", {
Parent = TermOut,
Name = "UIListLayout",
Padding = UDim.new(0, 4),
SortOrder = Enum.SortOrder.LayoutOrder,
HorizontalAlignment = Enum.HorizontalAlignment.Left,
})
return layout
end

local function refreshTerminalCanvas()
local layout = ensureTerminalList()
if not (TermOut and layout) then
return
end
local function update()
if not (TermOut and layout and layout.Parent == TermOut) then
return
end
local contentHeight = layout.AbsoluteContentSize.Y
local viewportHeight = TermOut.AbsoluteWindowSize.Y > 0 and TermOut.AbsoluteWindowSize.Y or TermOut.AbsoluteSize.Y
TermOut.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 12)
TermOut.CanvasPosition = Vector2.new(0, math.max(0, (contentHeight + 12) - viewportHeight))
end
task.defer(update)
task.delay(0.03, update)
end

local function resetTerminalOutput(initialText)
if not TermOut then
return
end
TermOut:ClearAllChildren()
ensureTerminalList()
TermOut.CanvasSize = UDim2.new(0, 0, 0, 0)
TermOut.CanvasPosition = Vector2.new(0, 0)
if type(initialText) == "string" and initialText ~= "" then
addLine(initialText)
else
refreshTerminalCanvas()
end
end

addLine = function(txt, color)
if not TermOut then
return
end
ensureTerminalList()
mk("TextLabel", {
Parent = TermOut,
BackgroundTransparency = 1,
Font = Enum.Font.Code,
TextSize = 15,
TextColor3 = color or Color3.fromRGB(172, 255, 198),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
TextTruncate = Enum.TextTruncate.None,
AutomaticSize = Enum.AutomaticSize.Y,
Size = UDim2.new(1, -12, 0, 0),
ClipsDescendants = true,
RichText = false,
Text = sanitizeTerminalText(txt),
})
refreshTerminalCanvas()
end

local function normalizeUrl(url)
local u = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
if u == "" then return "about:blank" end
local low = u:lower()
if low == "home" then return "hackos://home" end
if low == "tips" then return "hackos://tips" end
if low == "apps" then return "hackos://apps" end
if low == "mail" or low == "bloxmail" then return "mail.bloxplay.com" end
if low == "packetanalyzer" or low == "rbxpacketanalyzer" or low == "rbxpacketnet" then return "rbxpacketanalyzer.com" end
if low == "ipblocker" or low == "rbxipblocker" then return "rbxipblocker.com" end
if low:sub(1, 8) == "hackos://" then
return low
end
low = low:gsub("^https?://", ""):gsub("/+$", "")
return low
end
local function setBrowserStatus(text)
if BrowserStatusLabel then
BrowserStatusLabel.Text = text or ""
end
end
local function hideAllBrowserPages()
if AdminLoginPage then AdminLoginPage.Visible = false end
if AdminDashboardPage then AdminDashboardPage.Visible = false end
if PacketPage then PacketPage.Visible = false end
local mailPage = BrowserContent and BrowserContent:FindFirstChild("MailPage")
if mailPage then mailPage.Visible = false end
local ipBlockerPage = BrowserContent and BrowserContent:FindFirstChild("IPBlockerPage")
if ipBlockerPage then ipBlockerPage.Visible = false end
if PageLabel then PageLabel.Visible = false end
end
local function randomChoice(t)
return t[math.random(1, #t)]
end
local function getAllHostsList()
local out = {}
for _, host in pairs(SimHosts) do
table.insert(out, host)
end
table.sort(out, function(a, b)
return a.label < b.label
end)
return out
end
local function getHostByIP(ip)
ip = tostring(ip or "")
for _, host in pairs(SimHosts) do
if host.ip == ip then
return host
end
end
return nil
end
local function startPacketCaptureForIP(ip)
local host = getHostByIP(ip)
if not host then
ActivePacketCapture.targetIP = ""
ActivePacketCapture.targetLabel = ""
ActivePacketCapture.rows = {}
return false
end
local rows = {}
if host.label == "Laptop" then
rows = {
{
ip = host.ip,
protocol = "DNS",
dns = "admin.bloxplay.local",
port = "53",
server = "NameMesh",
src = "192.168.32.12",
dst = "192.168.32.10",
tag = "Exposure",
tone = "warning",
summary = "Workstation resolves an internal admin zone from the same user-facing network path.",
},
{
ip = host.ip,
protocol = "HTTPS",
dns = "bloxplay.com/admin",
port = "443",
server = "CorePanel",
src = "192.168.32.12",
dst = "192.168.43.2",
tag = "Vulnerability",
tone = "danger",
summary = "Admin portal is reachable from a mixed-trust workstation segment.",
},
{
ip = host.ip,
protocol = "HTTPS",
dns = "auth.bloxplay.local",
port = "443",
server = "CorePanel",
src = "192.168.32.12",
dst = "192.168.43.2",
tag = "Credential Path",
tone = "danger",
summary = "Authentication traffic shares the same route as user workstation activity.",
},
{
ip = host.ip,
protocol = "HTTPS",
dns = "playerdata.bloxplay.local",
port = "443",
server = "VaultLeaf",
src = "192.168.32.12",
dst = "192.168.43.20",
tag = "Sensitive",
tone = "warning",
summary = "The workstation can talk directly to player-data services across the exposed path.",
},
{
ip = host.ip,
protocol = "HTTP",
dns = "sync-edge.bloxcdn.net",
port = "80",
server = "VaultLeaf",
src = "192.168.43.20",
dst = "203.44.18.77",
tag = "Suspicious",
tone = "danger",
summary = "Unexpected cleartext callback leaves the protected zone during the capture window.",
},
{
ip = host.ip,
protocol = "DNS",
dns = "cdn.bloxplay.net",
port = "53",
server = "NameMesh",
src = "192.168.32.12",
dst = "192.168.32.10",
tag = "Normal",
tone = "normal",
summary = "Routine content delivery lookup from the workstation.",
},
}
elseif host.label == "PlayerData_Vault" then
rows = {
{
ip = host.ip,
protocol = "HTTPS",
dns = "playerdata.bloxplay.local",
port = "443",
server = "VaultLeaf",
src = "192.168.43.20",
dst = "192.168.43.2",
tag = "Internal",
tone = "normal",
summary = "Expected vault-to-gateway management traffic.",
},
{
ip = host.ip,
protocol = "HTTP",
dns = "sync-edge.bloxcdn.net",
port = "80",
server = "VaultLeaf",
src = "192.168.43.20",
dst = "203.44.18.77",
tag = "Suspicious",
tone = "danger",
summary = "External callback from the vault appears outside approved maintenance flow.",
},
{
ip = host.ip,
protocol = "HTTPS",
dns = "bloxplay.com/admin",
port = "443",
server = "CorePanel",
src = "192.168.43.2",
dst = "192.168.43.20",
tag = "Control",
tone = "warning",
summary = "Management traffic is transiting the same trust path as the incident activity.",
},
}
else
rows = {
{
ip = host.ip,
protocol = "DNS",
dns = "cdn.bloxplay.net",
port = "53",
server = "NameMesh",
src = host.ip,
dst = "192.168.32.10",
tag = "Normal",
tone = "normal",
summary = "Routine service discovery from the selected host.",
},
{
ip = host.ip,
protocol = "HTTPS",
dns = "bloxplay.com",
port = "443",
server = host.server,
src = host.ip,
dst = "192.168.32.10",
tag = "Observed",
tone = "warning",
summary = "General application traffic from the selected system.",
},
}
end
ActivePacketCapture.targetIP = host.ip
ActivePacketCapture.targetLabel = host.label
ActivePacketCapture.rows = rows
return true
end
local function renderAdminResults(query)
if not AdminResultsFrame then return end
query = tostring(query or ""):lower()
for _, child in ipairs(AdminResultsFrame:GetChildren()) do
if child:IsA("Frame") then
child:Destroy()
end
end
local layout = AdminResultsFrame:FindFirstChild("UIListLayout")
if not layout then
layout = mk("UIListLayout", {
Parent = AdminResultsFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
end
local count = 0
for _, row in ipairs(FakeAdminRecords) do
local hay = (row.username .. " " .. row.role .. " " .. row.dept .. " " .. row.note):lower()
if query == "" or hay:find(query, 1, true) then
count = count + 1
local card = mk("Frame", {
Parent = AdminResultsFrame,
BackgroundColor3 = Color3.fromRGB(246, 248, 252),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 92),
})
round(card, 8)
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "USER: " .. row.username,
Font = Enum.Font.GothamBold,
TextSize = 14,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 18),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "ROLE: " .. row.role .. " DEPT: " .. row.dept,
Font = Enum.Font.Code,
TextSize = 13,
TextColor3 = Color3.fromRGB(45, 52, 64),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 30),
Size = UDim2.new(1, -20, 0, 16),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = "NOTE: " .. row.note,
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(65, 74, 88),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 50),
Size = UDim2.new(1, -20, 0, 34),
})
end
end
for _, row in ipairs(FakePlayerRows) do
local hay = ("player " .. row.username .. " " .. row.display .. " " .. row.region .. " " .. row.plan .. " " .. row.status):lower()
if query ~= "" and hay:find(query, 1, true) then
count = count + 1
local card = mk("Frame", {
Parent = AdminResultsFrame,
BackgroundColor3 = Color3.fromRGB(240, 247, 255),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 92),
})
round(card, 8)
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "PLAYER: " .. row.username .. " (" .. row.display .. ")",
Font = Enum.Font.GothamBold,
TextSize = 14,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 18),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "REGION: " .. row.region .. " PLAN: " .. row.plan,
Font = Enum.Font.Code,
TextSize = 13,
TextColor3 = Color3.fromRGB(45, 52, 64),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 30),
Size = UDim2.new(1, -20, 0, 16),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "STATUS: " .. row.status,
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(65, 74, 88),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 52),
Size = UDim2.new(1, -20, 0, 20),
})
end
end
if count == 0 then
local empty = mk("Frame", {
Parent = AdminResultsFrame,
BackgroundColor3 = Color3.fromRGB(246, 248, 252),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 48),
})
round(empty, 8)
mk("TextLabel", {
Parent = empty,
BackgroundTransparency = 1,
Text = "No database results found (sim).",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(65, 74, 88),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 12),
Size = UDim2.new(1, -20, 0, 20),
})
end
task.defer(function()
AdminResultsFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)
end
local function showTextPage(text, status)
hideAllBrowserPages()
if PageLabel then
PageLabel.Visible = true
PageLabel.Text = text or ""
end
setBrowserStatus(status or "Static page loaded (sim)")
end
local function showAdminLoginPage(url)
hideAllBrowserPages()
if AdminLoginPage then
AdminLoginPage.Visible = true
end
if AdminLoginStatus then
AdminLoginStatus.Text = "Administrator credentials required."
end
setBrowserStatus(("Loaded %s (credentials required)"):format(url))
end
local function renderAdminLogs()
if not AdminDashboardPage then return end
local logsFrame = AdminDashboardPage:FindFirstChild("AdminLogsFrame")
if not logsFrame or not logsFrame:IsA("ScrollingFrame") then return end
for _, child in ipairs(logsFrame:GetChildren()) do
if child:IsA("Frame") then
child:Destroy()
end
end
local layout = logsFrame:FindFirstChild("UIListLayout")
if not layout then
layout = mk("UIListLayout", {
Parent = logsFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
end
local logs = {}
for _, entry in ipairs(AdminLogFeed.base) do
logs[#logs + 1] = entry
end
for _, entry in ipairs(getWannaWailIncidentLogs()) do
logs[#logs + 1] = entry
end
for _, entry in ipairs(logs) do
local chipColor = Color3.fromRGB(78, 125, 255)
local cardColor = Color3.fromRGB(243, 247, 255)
if entry.severity == "MEDIUM" then
chipColor = Color3.fromRGB(208, 143, 38)
cardColor = Color3.fromRGB(255, 249, 235)
elseif entry.severity == "HIGH" then
chipColor = Color3.fromRGB(212, 92, 49)
cardColor = Color3.fromRGB(255, 243, 239)
elseif entry.severity == "CRITICAL" then
chipColor = Color3.fromRGB(184, 43, 43)
cardColor = Color3.fromRGB(255, 236, 236)
end
local card = mk("Frame", {
Parent = logsFrame,
BackgroundColor3 = cardColor,
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 88),
})
round(card, 8)
local chip = mk("TextLabel", {
Parent = card,
BackgroundColor3 = chipColor,
BorderSizePixel = 0,
Text = tostring(entry.severity),
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(0, 76, 0, 20),
})
round(chip, 6)
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = tostring(entry.stamp),
Font = Enum.Font.Code,
TextSize = 12,
TextColor3 = Color3.fromRGB(70, 78, 92),
TextXAlignment = Enum.TextXAlignment.Right,
Position = UDim2.new(1, -88, 0, 12),
Size = UDim2.new(0, 78, 0, 18),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = tostring(entry.title),
Font = Enum.Font.GothamBold,
TextSize = 14,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 36),
Size = UDim2.new(1, -20, 0, 18),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = tostring(entry.detail),
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(70, 78, 92),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 56),
Size = UDim2.new(1, -20, 0, 24),
})
end
task.defer(function()
logsFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)
end
local function renderIPBlockerHistory()
local ipBlockerPage = BrowserContent and BrowserContent:FindFirstChild("IPBlockerPage")
local historyFrame = ipBlockerPage and ipBlockerPage:FindFirstChild("IPBlockerHistoryFrame")
if not historyFrame or not historyFrame:IsA("ScrollingFrame") then return end
for _, child in ipairs(historyFrame:GetChildren()) do
if child:IsA("Frame") then
child:Destroy()
end
end
local layout = historyFrame:FindFirstChild("UIListLayout")
if not layout then
layout = mk("UIListLayout", {
Parent = historyFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
end
local blockedIPs = browserState.blockedIPs or {}
if #blockedIPs == 0 then
local empty = mk("Frame", {
Parent = historyFrame,
BackgroundColor3 = Color3.fromRGB(240, 243, 249),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 48),
})
round(empty, 8)
mk("TextLabel", {
Parent = empty,
BackgroundTransparency = 1,
Text = "No blocked sources recorded yet.",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(70, 78, 92),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 14),
Size = UDim2.new(1, -20, 0, 18),
})
else
for _, ip in ipairs(blockedIPs) do
local row = mk("Frame", {
Parent = historyFrame,
BackgroundColor3 = Color3.fromRGB(236, 245, 238),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 54),
})
round(row, 8)
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = ip,
Font = Enum.Font.Code,
TextSize = 13,
TextColor3 = Color3.fromRGB(22, 86, 46),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 0, 16),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = "Browser response rule active",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(49, 101, 68),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 28),
Size = UDim2.new(1, -20, 0, 14),
})
end
end
task.defer(function()
historyFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)
end
local function showAdminDashboard(url)
hideAllBrowserPages()
if AdminDashboardPage then
AdminDashboardPage.Visible = true
end
local databaseTabBtn = AdminDashboardPage and AdminDashboardPage:FindFirstChild("AdminDatabaseTabBtn")
local logsTabBtn = AdminDashboardPage and AdminDashboardPage:FindFirstChild("AdminLogsTabBtn")
local logsFrame = AdminDashboardPage and AdminDashboardPage:FindFirstChild("AdminLogsFrame")
local showLogs = browserState.adminTab == "logs"
if AdminSearchBox then
AdminSearchBox.Visible = not showLogs
end
if AdminResultsFrame then
AdminResultsFrame.Visible = not showLogs
end
if logsFrame then
logsFrame.Visible = showLogs
end
if databaseTabBtn and databaseTabBtn:IsA("TextButton") then
databaseTabBtn.BackgroundColor3 = showLogs and Color3.fromRGB(100, 110, 132) or Color3.fromRGB(76, 123, 255)
end
if logsTabBtn and logsTabBtn:IsA("TextButton") then
logsTabBtn.BackgroundColor3 = showLogs and Color3.fromRGB(76, 123, 255) or Color3.fromRGB(100, 110, 132)
end
if showLogs then
renderAdminLogs()
setBrowserStatus(("Authenticated to %s - security logs live"):format(url))
else
renderAdminResults(AdminSearchBox and AdminSearchBox.Text or "")
setBrowserStatus(("Authenticated to %s (database view)"):format(url))
end
end
local function showIPBlockerPage(url)
hideAllBrowserPages()
local ipBlockerPage = BrowserContent and BrowserContent:FindFirstChild("IPBlockerPage")
if ipBlockerPage then
ipBlockerPage.Visible = true
end
local inputBox = ipBlockerPage and ipBlockerPage:FindFirstChild("IPBlockerInputBox")
if inputBox and inputBox:IsA("TextBox") then
inputBox.Text = ""
end
local statusLabel = ipBlockerPage and ipBlockerPage:FindFirstChild("IPBlockerStatus")
if statusLabel and statusLabel:IsA("TextLabel") then
statusLabel.Text = "Enter a hostile source from the investigation feed."
end
renderIPBlockerHistory()
setBrowserStatus(("Loaded %s response console (sim)"):format(url))
end
local function showMailPage(url)
hideAllBrowserPages()
local mailPage = BrowserContent and BrowserContent:FindFirstChild("MailPage")
if mailPage then
mailPage.Visible = true
end
if (browserState.selectedMailId == nil or browserState.selectedMailId == "") and type(CHAPTER3_MAILBOX[1]) == "table" then
browserState.selectedMailId = tostring(CHAPTER3_MAILBOX[1].id or "")
end
if browserState._renderMailPage then
browserState._renderMailPage()
end
setBrowserStatus(("Loaded %s staff inbox (sim)"):format(url))
end

local function packetMatchesFilter(pkt, dnsFilter)
dnsFilter = tostring(dnsFilter or ""):lower()
if dnsFilter == "" then
return true
end
local blob = (pkt.dns .. " " .. pkt.server .. " " .. pkt.protocol .. " " .. pkt.src .. " " .. pkt.dst):lower()
return blob:find(dnsFilter, 1, true) ~= nil
end
local function populatePacketRows()
if not PacketListFrame then return end
for _, child in ipairs(PacketListFrame:GetChildren()) do
if child:IsA("Frame") then
child:Destroy()
end
end
local layout = PacketListFrame:FindFirstChild("UIListLayout")
if not layout then
layout = mk("UIListLayout", {
Parent = PacketListFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
end
local ipFilter = PacketIPBox and PacketIPBox.Text or ""
local dnsFilter = PacketDNSBox and PacketDNSBox.Text or ""
local host = getHostByIP(ipFilter)
local rows = {}
if host then
if ActivePacketCapture.targetIP ~= host.ip then
startPacketCaptureForIP(host.ip)
end
for _, row in ipairs(ActivePacketCapture.rows) do
if packetMatchesFilter(row, dnsFilter) then
table.insert(rows, row)
end
end
end
if not host then
local row = mk("Frame", {
Parent = PacketListFrame,
BackgroundColor3 = Color3.fromRGB(244, 247, 252),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 54),
})
round(row, 8)
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = "Enter a valid target IP to begin capture (sim).",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(55, 66, 82),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 16),
Size = UDim2.new(1, -20, 0, 20),
})
elseif #rows == 0 then
local row = mk("Frame", {
Parent = PacketListFrame,
BackgroundColor3 = Color3.fromRGB(244, 247, 252),
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 54),
})
round(row, 8)
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = "No packets match the current DNS filter (sim).",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(55, 66, 82),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 16),
Size = UDim2.new(1, -20, 0, 20),
})
end
for _, pkt in ipairs(rows) do
local rowColor = Color3.fromRGB(241, 246, 252)
local accentColor = Color3.fromRGB(76, 123, 255)
local chipText = Color3.new(1, 1, 1)
if pkt.tone == "warning" then
rowColor = Color3.fromRGB(255, 248, 234)
accentColor = Color3.fromRGB(210, 143, 38)
elseif pkt.tone == "danger" then
rowColor = Color3.fromRGB(255, 238, 238)
accentColor = Color3.fromRGB(186, 61, 61)
end
local row = mk("Frame", {
Parent = PacketListFrame,
BackgroundColor3 = rowColor,
BorderSizePixel = 0,
Size = UDim2.new(1, -10, 0, 114),
})
round(row, 8)
mk("Frame", {
Parent = row,
BackgroundColor3 = accentColor,
BorderSizePixel = 0,
Position = UDim2.new(0, 0, 0, 0),
Size = UDim2.new(0, 6, 1, 0),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = pkt.protocol .. "  " .. pkt.src .. "  ->  " .. pkt.dst,
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.fromRGB(20, 20, 28),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 14, 0, 8),
Size = UDim2.new(1, -124, 0, 18),
})
local chip = mk("TextLabel", {
Parent = row,
BackgroundColor3 = accentColor,
BorderSizePixel = 0,
Text = pkt.tag,
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = chipText,
Position = UDim2.new(1, -100, 0, 8),
Size = UDim2.new(0, 88, 0, 20),
})
round(chip, 6)
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = "DNS: " .. pkt.dns .. "    PORT: " .. pkt.port .. "    SERVER: " .. pkt.server,
Font = Enum.Font.Code,
TextSize = 12,
TextColor3 = Color3.fromRGB(35, 45, 60),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 14, 0, 32),
Size = UDim2.new(1, -28, 0, 16),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = pkt.summary,
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(58, 67, 80),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 14, 0, 56),
Size = UDim2.new(1, -28, 0, 42),
})
end
task.defer(function()
PacketListFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)
end
local function showPacketPage(url)
hideAllBrowserPages()
if PacketPage then
PacketPage.Visible = true
end
populatePacketRows()
setBrowserStatus(("Loaded %s packet analyzer (authorized sim)"):format(url))
end
local function navigateTo(url)
local uNorm = normalizeUrl(url)
browserState.currentUrl = uNorm
if UrlBox then
UrlBox.Text = uNorm == "about:blank" and "" or uNorm
end
if uNorm == "about:blank" then
showTextPage("", "")
return
end
if uNorm == "bloxplay.com/admin" or uNorm == "www.bloxplay.com/admin" then
local result = submitScenarioAction and submitScenarioAction("browser_visit bloxplay.com/admin", { "ch2_admin_portal" })
if browserState.adminLoggedIn then
showAdminDashboard(uNorm)
else
showAdminLoginPage(uNorm)
end
if result and result.success then
setBrowserStatus("Admin portal reached. Mission step complete.")
end
return
end
if uNorm == "mail.bloxplay.com" or uNorm == "www.mail.bloxplay.com" then
local result = submitScenarioAction and submitScenarioAction("browser_visit mail.bloxplay.com", { "ch3_mail_site" })
showMailPage(uNorm)
queueAutoSave(false)
if result and result.success then
setBrowserStatus("BloxMail opened. Mission step complete.")
end
return
end
if uNorm == "rbxpacketanalyzer.com" or uNorm == "www.rbxpacketanalyzer.com" or uNorm == "rbxpacketnet.com" or uNorm == "www.rbxpacketnet.com" then
local result = submitScenarioAction and submitScenarioAction("browser_visit rbxpacketanalyzer.com", { "ch1_packets" })
showPacketPage(uNorm)
queueAutoSave(false)
if result and result.success then
setBrowserStatus("RBXPacketAnalyzer opened. Mission step complete.")
end
return
end
if uNorm == "rbxipblocker.com" or uNorm == "www.rbxipblocker.com" then
local result = submitScenarioAction and submitScenarioAction("browser_visit rbxipblocker.com", { "ch4_visit_blocker" })
showIPBlockerPage(uNorm)
queueAutoSave(false)
if result and result.success then
setBrowserStatus("RBXIPBlocker opened. Mission step complete.")
end
return
end
showTextPage(PAGES[uNorm] or ('No renderer for "%s" (sim).'):format(url), "Page loaded (sim)")
queueAutoSave(false)
end
local function copyStringArray(values)
local copy = {}
if type(values) ~= "table" then
return copy
end
for _, value in ipairs(values) do
if type(value) == "string" and value ~= "" then
copy[#copy + 1] = value
end
end
return copy
end
local function getVisiblePanel()
if browserState.visiblePanel == "browser" or browserState.visiblePanel == "missions" or browserState.visiblePanel == "terminal" then
return browserState.visiblePanel
end
if BrowserFrame and BrowserFrame.Visible then
return "browser"
end
if MissionsFrame and MissionsFrame.Visible then
return "missions"
end
return "terminal"
end
local function applyVisiblePanelLayout(panel)
if not (TermFrame and BrowserFrame and MissionsFrame) then
return
end
local inset = 6
if panel == "terminal" then
TermFrame.Position = UDim2.new(0, inset, 0, inset)
TermFrame.Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2))
BrowserFrame.Position = UDim2.new(0, inset, 0, inset)
BrowserFrame.Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2))
elseif panel == "browser" then
BrowserFrame.Position = UDim2.new(0, inset, 0, inset)
BrowserFrame.Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2))
TermFrame.Position = UDim2.new(0, inset, 0, inset)
TermFrame.Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2))
else
MissionsFrame.Position = UDim2.new(0, inset, 0, inset)
MissionsFrame.Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2))
end
end

local function setVisiblePanel(panel, options)
options = options or {}
panel = panel == "browser" and "browser" or panel == "missions" and "missions" or "terminal"
browserState.visiblePanel = panel
if not (TermFrame and BrowserFrame and MissionsFrame) then
return panel
end
applyVisiblePanelLayout(panel)
TermFrame.Visible = panel == "terminal"
BrowserFrame.Visible = panel == "browser"
MissionsFrame.Visible = panel == "missions"
if panel == "terminal" then
if options.captureFocus ~= false and TermInput and TermInput.Parent then
task.defer(function()
if TermInput and TermInput.Parent and TermFrame and TermFrame.Visible and MainGUI and MainGUI.Enabled then
TermInput:CaptureFocus()
end
end)
end
return panel
end
if panel == "browser" then
local urlToOpen = options.url
if urlToOpen == nil then
if UrlBox and UrlBox.Text ~= "" then
urlToOpen = UrlBox.Text
else
local savedUrl = tostring(browserState.currentUrl or "about:blank")
urlToOpen = savedUrl ~= "about:blank" and savedUrl or "home"
if UrlBox then
UrlBox.Text = urlToOpen
end
end
elseif UrlBox then
UrlBox.Text = urlToOpen == "about:blank" and "" or urlToOpen
end
if options.navigate ~= false then
navigateTo(urlToOpen)
end
if options.captureFocus ~= false and UrlBox then
task.defer(function()
if UrlBox and UrlBox.Parent and BrowserFrame and BrowserFrame.Visible and MainGUI and MainGUI.Enabled then
pcall(function() UrlBox:CaptureFocus() end)
end
end)
end
end
return panel
end
local function captureSessionRestoreState()
return {
progress = captureProgressState and captureProgressState() or nil,
started = started == true,
commandHistory = copyStringArray(commandHistory),
currentDraft = tostring(currentDraft or ""),
}
end
local function applySessionRestoreState(state)
if type(state) ~= "table" then
return false
end
local restored = false
if type(state.progress) == "table" and applyProgressState then
restored = applyProgressState(state.progress)
end
commandHistory = copyStringArray(state.commandHistory)
historyIndex = nil
currentDraft = type(state.currentDraft) == "string" and state.currentDraft or ""
if TermInput and TermInput.Parent then
TermInput.Text = currentDraft
end
if state.started == true then
started = true
end
return restored or state.started == true or #commandHistory > 0 or currentDraft ~= ""
end
captureProgressState = function()
local openFiles = {}
for pathName, isOpen in pairs(OpenFiles) do
if isOpen then
openFiles[#openFiles + 1] = tostring(pathName)
end
end
table.sort(openFiles)
local sniffCache = nil
if type(terminalState.sniffCache) == "table" then
sniffCache = {
host = terminalState.sniffCache.host,
ip = terminalState.sniffCache.ip,
server = terminalState.sniffCache.server,
attackerIP = terminalState.sniffCache.attackerIP,
}
end
local blockedIPs = {}
for _, ip in ipairs(browserState.blockedIPs or {}) do
blockedIPs[#blockedIPs + 1] = tostring(ip)
end
table.sort(blockedIPs)
return {
browserState = {
adminLoggedIn = browserState.adminLoggedIn == true,
currentUrl = tostring(browserState.currentUrl or "about:blank"),
stickyNoteInspected = browserState.stickyNoteInspected == true,
adminTab = browserState.adminTab == "logs" and "logs" or "database",
blockedIPs = blockedIPs,
selectedMailId = tostring(browserState.selectedMailId or ""),
visiblePanel = getVisiblePanel(),
},
terminalState = {
currentHost = tostring(terminalState.currentHost or "local"),
currentDir = tostring(terminalState.currentDir or "/"),
connectedHost = terminalState.connectedHost,
sshSession = terminalState.sshSession == true,
scanCache = terminalState.scanCache,
sniffCache = sniffCache,
lastAttackerIP = tostring(terminalState.lastAttackerIP or "203.44.18.77"),
},
packetCapture = {
targetIP = tostring(ActivePacketCapture.targetIP or ""),
targetLabel = tostring(ActivePacketCapture.targetLabel or ""),
},
openFiles = openFiles,
}
end
applyProgressState = function(state)
if type(state) ~= "table" then
return false
end
local previousBrowserState = browserState
local browser = type(state.browserState) == "table" and state.browserState or {}
local terminal = type(state.terminalState) == "table" and state.terminalState or {}
local packetCapture = type(state.packetCapture) == "table" and state.packetCapture or {}
local sniffCache = nil
if type(terminal.sniffCache) == "table" then
sniffCache = {
host = terminal.sniffCache.host,
ip = terminal.sniffCache.ip,
server = terminal.sniffCache.server,
attackerIP = terminal.sniffCache.attackerIP,
}
end
local blockedIPs = {}
if type(browser.blockedIPs) == "table" then
for _, ip in ipairs(browser.blockedIPs) do
if type(ip) == "string" and ip ~= "" then
blockedIPs[#blockedIPs + 1] = ip
end
end
end
browserState = {
adminLoggedIn = browser.adminLoggedIn == true,
currentUrl = type(browser.currentUrl) == "string" and browser.currentUrl or "about:blank",
stickyNoteInspected = browser.stickyNoteInspected == true,
adminTab = browser.adminTab == "logs" and "logs" or "database",
blockedIPs = blockedIPs,
selectedMailId = type(browser.selectedMailId) == "string" and browser.selectedMailId or (type(CHAPTER3_MAILBOX[1]) == "table" and tostring(CHAPTER3_MAILBOX[1].id or "") or ""),
logStreamStartedAt = 0,
logsLastRender = 0,
lastInteractionAt = os.clock(),
idleAutoSaveNotified = false,
visiblePanel = browser.visiblePanel == "browser" and "browser" or browser.visiblePanel == "missions" and "missions" or "terminal",
}
for key, value in pairs(previousBrowserState or {}) do
if type(key) == "string" and key:sub(1, 1) == "_" then
browserState[key] = value
end
end
terminalState = {
currentHost = type(terminal.currentHost) == "string" and terminal.currentHost or "local",
currentDir = type(terminal.currentDir) == "string" and terminal.currentDir or "/",
connectedHost = type(terminal.connectedHost) == "string" and terminal.connectedHost or nil,
sshSession = terminal.sshSession == true,
scanCache = type(terminal.scanCache) == "string" and terminal.scanCache or nil,
sniffCache = sniffCache,
lastAttackerIP = type(terminal.lastAttackerIP) == "string" and terminal.lastAttackerIP or "203.44.18.77",
}
ActivePacketCapture = {
targetIP = type(packetCapture.targetIP) == "string" and packetCapture.targetIP or "",
targetLabel = type(packetCapture.targetLabel) == "string" and packetCapture.targetLabel or "",
rows = {},
}
if ActivePacketCapture.targetIP ~= "" then
startPacketCaptureForIP(ActivePacketCapture.targetIP)
end
OpenFiles = {}
if type(state.openFiles) == "table" then
for _, pathName in ipairs(state.openFiles) do
if type(pathName) == "string" and pathName ~= "" then
OpenFiles[pathName] = true
end
end
end
if UrlBox then
UrlBox.Text = browserState.currentUrl == "about:blank" and "" or browserState.currentUrl
end
if PacketIPBox then
PacketIPBox.Text = ActivePacketCapture.targetIP
end
if PacketDNSBox then
PacketDNSBox.Text = ""
end
if PacketPage and PacketPage.Visible then
populatePacketRows()
end
setVisiblePanel(browserState.visiblePanel, {
url = browserState.visiblePanel == "browser" and browserState.currentUrl or nil,
navigate = browserState.visiblePanel == "browser",
captureFocus = false,
})
started = true
installSimOps()
return true
end
applyPendingRestoreState = function()
local raw = Player:GetAttribute(RESTORE_STATE_ATTRIBUTE)
if type(raw) ~= "string" or raw == "" then
return false
end
Player:SetAttribute(RESTORE_STATE_ATTRIBUTE, nil)
local ok, state = pcall(function()
return Http:JSONDecode(raw)
end)
if not ok or type(state) ~= "table" then
return false
end
return applyProgressState(state)
end
local function resetUI()
local previousBrowserState = browserState
if TermOut then
resetTerminalOutput(PROMPT)
end
if TermInput then TermInput.Text = "" end
browserState = { adminLoggedIn = false, currentUrl = "about:blank", stickyNoteInspected = false, adminTab = "database", blockedIPs = {}, selectedMailId = type(CHAPTER3_MAILBOX[1]) == "table" and tostring(CHAPTER3_MAILBOX[1].id or "") or "", logStreamStartedAt = 0, logsLastRender = 0, lastInteractionAt = os.clock(), idleAutoSaveNotified = false, visiblePanel = "terminal" }
for key, value in pairs(previousBrowserState or {}) do
if type(key) == "string" and key:sub(1, 1) == "_" then
browserState[key] = value
end
end
terminalState = {
currentHost = "local",
currentDir = "/",
connectedHost = nil,
sshSession = false,
scanCache = nil,
sniffCache = nil,
lastAttackerIP = "203.44.18.77",
}
ActivePacketCapture = { targetIP = "", targetLabel = "", rows = {} }
OpenFiles = {}
commandHistory = {}
historyIndex = nil
currentDraft = ""
if UrlBox then UrlBox.Text = "" end
if BrowserFrame then navigateTo("about:blank") end
setVisiblePanel("terminal", { navigate = false, captureFocus = false })
installSimOps()
applyPendingRestoreState()
end

local function getScenarioRemote(name)
return getRemote(name)
end
local function buildReplayPromptGUI()
if ReplayPromptGUI then
return ReplayPromptGUI
end
local gui = mk("ScreenGui", {
Parent = PlayerGui,
Name = "HackTabletReplayPrompt",
IgnoreGuiInset = true,
ResetOnSpawn = false,
DisplayOrder = 250,
Enabled = false,
})
local shade = mk("TextButton", {
Parent = gui,
AutoButtonColor = false,
Modal = true,
Text = "",
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = Color3.fromRGB(4, 7, 12),
BackgroundTransparency = 0.18,
})
local panel = mk("Frame", {
Parent = shade,
BackgroundColor3 = Color3.fromRGB(15, 20, 32),
Size = UDim2.fromOffset(460, 250),
Position = UDim2.fromScale(0.5, 0.5),
AnchorPoint = Vector2.new(0.5, 0.5),
})
round(panel, 18)
mk("TextLabel", {
Parent = panel,
BackgroundTransparency = 1,
Font = Enum.Font.GothamBlack,
TextSize = 26,
TextColor3 = Color3.fromRGB(235, 242, 255),
Text = "MISSION COMPLETE",
Size = UDim2.new(1, -40, 0, 34),
Position = UDim2.new(0, 20, 0, 22),
})
mk("TextLabel", {
Parent = panel,
BackgroundTransparency = 1,
Font = Enum.Font.Gotham,
TextSize = 16,
TextColor3 = Color3.fromRGB(186, 201, 228),
TextWrapped = true,
Text = "You finished Chapter 4. Do you want to play the operation again from the beginning?",
Size = UDim2.new(1, -40, 0, 58),
Position = UDim2.new(0, 20, 0, 68),
})
mk("TextLabel", {
Parent = panel,
BackgroundTransparency = 1,
Font = Enum.Font.GothamSemibold,
TextSize = 13,
TextColor3 = Color3.fromRGB(255, 194, 102),
TextWrapped = true,
Text = "Your saved progress has been removed, so Continue will show No Save Found.",
Size = UDim2.new(1, -40, 0, 40),
Position = UDim2.new(0, 20, 0, 132),
})
local playAgainBtn = mk("TextButton", {
Parent = panel,
Name = "PlayAgainButton",
AutoButtonColor = true,
Text = "PLAY AGAIN",
Font = Enum.Font.GothamBold,
TextSize = 15,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(79, 131, 255),
BorderSizePixel = 0,
Size = UDim2.new(0, 170, 0, 42),
Position = UDim2.new(0.5, -182, 1, -62),
})
round(playAgainBtn, 12)
local doneBtn = mk("TextButton", {
Parent = panel,
Name = "DoneButton",
AutoButtonColor = true,
Text = "NOT NOW",
Font = Enum.Font.GothamBold,
TextSize = 15,
TextColor3 = Color3.fromRGB(220, 231, 248),
BackgroundColor3 = Color3.fromRGB(46, 57, 79),
BorderSizePixel = 0,
Size = UDim2.new(0, 170, 0, 42),
Position = UDim2.new(0.5, 12, 1, -62),
})
round(doneBtn, 12)
ReplayPromptGUI = gui
return gui
end
local function setReplayPromptVisible(visible)
if not ReplayPromptGUI then
buildReplayPromptGUI()
end
if ReplayPromptGUI then
ReplayPromptGUI.Enabled = visible == true
end
end
local function clearEndingAutosave()
if replayPromptClearDone then
return
end
autoSaveSuppressed = true
autoSaveQueuedAt = 0
replayPromptClearDone = true
local clearRemote = getScenarioRemote("ClearSavedProgress")
if not clearRemote then
return
end
local ok, result = pcall(function()
return clearRemote:InvokeServer()
end)
if ok and type(result) == "table" and type(result.warning) == "string" and result.warning ~= "" then
warn("[HackTablet] ClearSavedProgress warning:", result.warning)
elseif not ok then
warn("[HackTablet] ClearSavedProgress invoke failed")
end
end
local function startReplayRun()
local startOverRemote = getScenarioRemote(START_OVER_REMOTE_NAME)
if not startOverRemote then
notify({ Title = "HackTablet", Text = "Start Over is unavailable right now.", Duration = 3 })
return
end
local promptGui = buildReplayPromptGUI()
local playAgainBtn = promptGui:FindFirstChild("PlayAgainButton", true)
local doneBtn = promptGui:FindFirstChild("DoneButton", true)
if playAgainBtn and playAgainBtn:IsA("TextButton") then
playAgainBtn.Text = "STARTING..."
playAgainBtn.Active = false
playAgainBtn.Selectable = false
end
if doneBtn and doneBtn:IsA("TextButton") then
doneBtn.Active = false
doneBtn.Selectable = false
end
local okReset, resetResult = pcall(function()
return startOverRemote:InvokeServer()
end)
if playAgainBtn and playAgainBtn:IsA("TextButton") then
playAgainBtn.Text = "PLAY AGAIN"
playAgainBtn.Active = true
playAgainBtn.Selectable = true
end
if doneBtn and doneBtn:IsA("TextButton") then
doneBtn.Active = true
doneBtn.Selectable = true
end
if not okReset or type(resetResult) ~= "table" or not resetResult.success then
notify({ Title = "HackTablet", Text = type(resetResult) == "table" and tostring(resetResult.message or "Could not start over.") or "Could not start over.", Duration = 3 })
return
end
autoSaveSuppressed = false
autoSaveQueuedAt = 0
autoSaveLastRunAt = os.clock()
replayPromptShown = false
replayPromptClearDone = false
Player:SetAttribute(RESTORE_STATE_ATTRIBUTE, nil)
resetUI()
local loadScenarioRemote = getScenarioRemote("LoadScenario")
if not loadScenarioRemote then
notify({ Title = "HackTablet", Text = "Could not load Chapter 1.", Duration = 3 })
return
end
local okLoad, loadResult = pcall(function()
return loadScenarioRemote:InvokeServer("Chapter1_Recon")
end)
if not okLoad or type(loadResult) ~= "table" then
notify({ Title = "HackTablet", Text = "Could not load Chapter 1.", Duration = 3 })
return
end
setReplayPromptVisible(false)
if HintGUI then
HintGUI.Enabled = false
end
if MainGUI then
MainGUI.Enabled = true
end
started = true
if browserState._ensureClockLoop then
browserState._ensureClockLoop()
end
if browserState._updateClockLabel then
browserState._updateClockLabel()
end
playAudio()
setVisiblePanel("missions", { navigate = false, captureFocus = false })
if browserState._refreshMissionPanels then
browserState._refreshMissionPanels()
end
if browserState._markInteraction then
browserState._markInteraction()
end
notify({ Title = "HackTablet", Text = "Fresh run loaded. Check your tablet instructions.", Duration = 4 })
end
local function showReplayPrompt()
if replayPromptShown then
return
end
replayPromptShown = true
clearEndingAutosave()
autoSaveSuppressed = true
autoSaveQueuedAt = 0
stopAudio()
if TermInput then
pcall(function()
TermInput:ReleaseFocus()
end)
end
local promptGui = buildReplayPromptGUI()
local playAgainBtn = promptGui:FindFirstChild("PlayAgainButton", true)
local doneBtn = promptGui:FindFirstChild("DoneButton", true)
if playAgainBtn and playAgainBtn:IsA("TextButton") then
playAgainBtn.MouseButton1Click:Once(function()
startReplayRun()
end)
end
if doneBtn and doneBtn:IsA("TextButton") then
doneBtn.MouseButton1Click:Once(function()
setReplayPromptVisible(false)
if isToolEquipped() and started then
playAudio()
end
notify({ Title = "HackTablet", Text = "Saved progress removed. Continue will show No Save Found.", Duration = 4 })
end)
end
setReplayPromptVisible(true)
end
local function syncScenarioProgress(raw, options)
options = options or {}
local checkSolutionRemote = getScenarioRemote("CheckSolution")
if not checkSolutionRemote then
return nil
end
local ok, result = pcall(function()
return checkSolutionRemote:InvokeServer(raw)
end)
if not ok or type(result) ~= "table" then
return nil
end
local completedScenarioId = tostring(result.completedScenarioId or "")
local finalChapterComplete = result.success and result.chapterComplete and completedScenarioId == "Chapter4_IncidentResponse"
if result.success and not finalChapterComplete then
queueAutoSave(result.stepComplete or result.chapterComplete)
end
if result.success and result.autoStartedNextChapter and type(result.nextTitle) == "string" and result.nextTitle ~= "" then
	notify({
		Title = "HackTablet",
		Text = ("%s started. Check your tablet for the next instructions."):format(result.nextTitle),
		Duration = 4,
	})
	if not options.silent then
		addLine(("[*] %s started."):format(result.nextTitle))
		if type(result.nextInstruction) == "string" and result.nextInstruction ~= "" then
			addLine(("[*] %s"):format(result.nextInstruction))
		end
	end
	task.defer(function()
		if browserState._ensureChapter3MailVisible then
			browserState._ensureChapter3MailVisible()
		end
	end)
end
if not options.silent and result.success and (result.stepComplete or result.chapterComplete) and type(result.feedback) == "string" and result.feedback ~= "" then
addLine(result.feedback)
end
if finalChapterComplete then
task.defer(showReplayPrompt)
end
return result
end
local function getScenarioSessionInfo()
local getSessionInfoRemote = getScenarioRemote("GetSessionInfo")
if not getSessionInfoRemote then
return nil
end
local ok, sessionInfo = pcall(function()
return getSessionInfoRemote:InvokeServer()
end)
if ok and type(sessionInfo) == "table" then
return sessionInfo
end
return nil
end

browserState._getMailEntryById = function(emailId)
if type(emailId) == "string" and emailId ~= "" then
for _, entry in ipairs(CHAPTER3_MAILBOX) do
if type(entry) == "table" and tostring(entry.id or "") == emailId then
return entry
end
end
end
return nil
end
browserState._resolveSelectedMail = function()
local selectedMail = browserState._getMailEntryById and browserState._getMailEntryById(browserState.selectedMailId) or nil
if selectedMail then
browserState.selectedMailId = tostring(selectedMail.id or "")
return selectedMail
end
local fallbackMail = type(CHAPTER3_MAILBOX[1]) == "table" and CHAPTER3_MAILBOX[1] or nil
browserState.selectedMailId = fallbackMail and tostring(fallbackMail.id or "") or ""
return fallbackMail
end
browserState._getMailTriageState = function()
local sessionInfo = getScenarioSessionInfo()
if type(sessionInfo) ~= "table" or sessionInfo.scenarioId ~= "Chapter3_Malware" then
return {
currentStepId = nil,
resolved = {},
actions = {},
resolvedCount = 0,
total = #CHAPTER3_MAILBOX,
}
end
local stepState = type(sessionInfo.stepState) == "table" and type(sessionInfo.stepState.ch3_inbox_triage) == "table" and sessionInfo.stepState.ch3_inbox_triage or {}
local resolved = type(stepState.resolved) == "table" and stepState.resolved or {}
local actions = type(stepState.actions) == "table" and stepState.actions or {}
local resolvedCount = 0
for _, entry in ipairs(CHAPTER3_MAILBOX) do
if type(entry) == "table" and resolved[tostring(entry.id or "")] == true then
resolvedCount = resolvedCount + 1
end
end
return {
sessionInfo = sessionInfo,
currentStepId = sessionInfo.stepId,
resolved = resolved,
actions = actions,
resolvedCount = resolvedCount,
total = #CHAPTER3_MAILBOX,
}
end
browserState._ensureChapter3MailVisible = function()
if not MainGUI or not MainGUI.Enabled or not BrowserFrame or not TermFrame then
return
end
local sessionInfo = getScenarioSessionInfo()
if type(sessionInfo) ~= "table" or sessionInfo.scenarioId ~= "Chapter3_Malware" then
browserState.mailAutoOpenStepId = nil
return
end
local stepId = tostring(sessionInfo.stepId or "")
if stepId ~= "ch3_mail_site" and stepId ~= "ch3_inbox_triage" then
browserState.mailAutoOpenStepId = nil
return
end
if browserState.mailAutoOpenStepId == stepId then
return
end
browserState.mailAutoOpenStepId = stepId
setVisiblePanel("browser", { navigate = false, captureFocus = false })
if stepId == "ch3_mail_site" then
navigateTo("mail.bloxplay.com")
else
browserState.currentUrl = "mail.bloxplay.com"
if UrlBox then
UrlBox.Text = "mail.bloxplay.com"
end
showMailPage("mail.bloxplay.com")
setBrowserStatus("BloxMail reopened for the Chapter 3 inbox triage step.")
end
end
browserState._renderMailPage = function()
local mailPage = BrowserContent and BrowserContent:FindFirstChild("MailPage")
if not mailPage then return end
local inboxList = mailPage:FindFirstChild("MailInboxList")
local detailCard = mailPage:FindFirstChild("MailDetailCard")
if not inboxList or not detailCard then return end
local triageState = browserState._getMailTriageState and browserState._getMailTriageState() or { resolved = {}, actions = {}, resolvedCount = 0, total = #CHAPTER3_MAILBOX }
local summaryLabel = mailPage:FindFirstChild("MailInboxSummary")
if (browserState.selectedMailId == nil or browserState.selectedMailId == "") and type(CHAPTER3_MAILBOX[1]) == "table" then
browserState.selectedMailId = tostring(CHAPTER3_MAILBOX[1].id or "")
end
local selectedMail = browserState._resolveSelectedMail and browserState._resolveSelectedMail() or nil
if selectedMail then
browserState.selectedMailId = tostring(selectedMail.id or "")
end
for _, child in ipairs(inboxList:GetChildren()) do
if child:IsA("GuiButton") or child:IsA("Frame") then
child:Destroy()
end
end
if summaryLabel and summaryLabel:IsA("TextLabel") then
local pendingCount = math.max(0, triageState.total - triageState.resolvedCount)
if #CHAPTER3_MAILBOX == 0 then
summaryLabel.Text = "Inbox queue unavailable. Reloading fallback mail data."
elseif triageState.currentStepId == "ch3_inbox_triage" then
summaryLabel.Text = ("%d total emails. %d resolved, %d still waiting in the left inbox queue."):format(triageState.total, triageState.resolvedCount, pendingCount)
elseif triageState.resolvedCount >= triageState.total and triageState.total > 0 then
summaryLabel.Text = "Inbox triage is complete. Move to the live incident logs next."
else
summaryLabel.Text = "Use the left inbox queue to inspect each message, then choose Report or Pass Through."
end
end
if #CHAPTER3_MAILBOX == 0 then
local emptyRow = mk("Frame", {
Parent = inboxList,
BackgroundColor3 = Color3.fromRGB(243, 246, 251),
BorderSizePixel = 0,
Size = UDim2.new(1, -8, 0, 58),
})
round(emptyRow, 8)
mk("TextLabel", {
Parent = emptyRow,
BackgroundTransparency = 1,
Text = "Inbox unavailable (sim).",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(75, 84, 98),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 12, 0, 18),
Size = UDim2.new(1, -24, 0, 20),
})
else
for index, entry in ipairs(CHAPTER3_MAILBOX) do
local emailId = tostring(entry.id or ("mail_" .. index))
local isSelected = browserState.selectedMailId == emailId
local resolvedAction = triageState.actions[emailId]
local statusText = "Pending"
local chipColor = Color3.fromRGB(152, 163, 179)
local rowColor = isSelected and Color3.fromRGB(228, 236, 248) or Color3.fromRGB(244, 247, 252)
if resolvedAction == "report" then
statusText = "FLAGGED"
chipColor = Color3.fromRGB(191, 71, 58)
rowColor = isSelected and Color3.fromRGB(250, 234, 231) or Color3.fromRGB(252, 242, 239)
elseif resolvedAction == "pass" then
statusText = "AUTHORIZED"
chipColor = Color3.fromRGB(61, 136, 92)
rowColor = isSelected and Color3.fromRGB(229, 244, 234) or Color3.fromRGB(240, 249, 242)
end
local row = mk("TextButton", {
Parent = inboxList,
BackgroundColor3 = rowColor,
BorderSizePixel = 0,
ClipsDescendants = true,
AutoButtonColor = false,
Text = "",
Size = UDim2.new(1, -8, 0, 52),
})
round(row, 8)
row.MouseButton1Click:Connect(function()
browserState.selectedMailId = emailId
queueAutoSave(false)
if browserState._renderMailPage then
browserState._renderMailPage()
end
end)
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = tostring(entry.subject or "Untitled message"),
TextTruncate = Enum.TextTruncate.AtEnd,
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 12, 0, 8),
Size = UDim2.new(1, -118, 0, 18),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = tostring(entry.sender or "Unknown sender"),
TextTruncate = Enum.TextTruncate.AtEnd,
Font = Enum.Font.Code,
TextSize = 11,
TextColor3 = Color3.fromRGB(76, 86, 102),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 12, 0, 28),
Size = UDim2.new(1, -118, 0, 14),
})
local chip = mk("TextLabel", {
Parent = row,
BackgroundColor3 = chipColor,
BorderSizePixel = 0,
Text = statusText,
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(1, -100, 0, 16),
Size = UDim2.new(0, 88, 0, 20),
})
round(chip, 6)
end
end
task.defer(function()
local layout = inboxList:FindFirstChild("UIListLayout")
inboxList.CanvasSize = UDim2.new(0, 0, 0, ((layout and layout.AbsoluteContentSize.Y) or 0) + 10)
end)
selectedMail = browserState._resolveSelectedMail and browserState._resolveSelectedMail() or nil
local senderLabel = detailCard:FindFirstChild("MailDetailSender")
local subjectLabel = detailCard:FindFirstChild("MailDetailSubject")
local bodyFrame = detailCard:FindFirstChild("MailDetailBodyFrame")
local bodyLabel = bodyFrame and bodyFrame:FindFirstChild("MailDetailBody")
local statusLabel = detailCard:FindFirstChild("MailStatusLabel")
local actionHintLabel = detailCard:FindFirstChild("MailActionHintLabel")
local reportButton = detailCard:FindFirstChild("MailReportButton", true)
local passButton = detailCard:FindFirstChild("MailPassButton", true)
if senderLabel and senderLabel:IsA("TextLabel") then
senderLabel.Text = "FROM: " .. tostring(selectedMail and selectedMail.sender or "No sender selected")
end
if subjectLabel and subjectLabel:IsA("TextLabel") then
subjectLabel.Text = "SUBJECT: " .. tostring(selectedMail and selectedMail.subject or "No message selected")
end
if bodyLabel and bodyLabel:IsA("TextLabel") then
bodyLabel.Text = tostring(selectedMail and selectedMail.body or "Select a message from the inbox to inspect it.")
end
if detailCard and detailCard:IsA("ScrollingFrame") then
detailCard.CanvasPosition = Vector2.new(0, 0)
end
local selectedAction = selectedMail and triageState.actions[tostring(selectedMail.id or "")] or nil
local isMailStepActive = triageState.currentStepId == "ch3_mail_site" or triageState.currentStepId == "ch3_inbox_triage"
local canClassify = selectedMail ~= nil and triageState.total > 0 and selectedAction == nil
if statusLabel and statusLabel:IsA("TextLabel") then
if triageState.total == 0 then
statusLabel.Text = "Inbox unavailable."
elseif selectedAction == "report" then
statusLabel.Text = "This message has been FLAGGED as phishing."
elseif selectedAction == "pass" then
statusLabel.Text = "This message has been AUTHORIZED to pass through."
elseif triageState.resolvedCount >= triageState.total and triageState.total > 0 then
statusLabel.Text = "Inbox triage complete. Move to the admin Security Logs tab."
elseif isMailStepActive then
statusLabel.Text = ("%d/%d messages reviewed. Keep sorting the queue before the incident escalates."):format(triageState.resolvedCount, triageState.total)
else
statusLabel.Text = "Review the selected message before deciding whether it should be reported."
end
end
if actionHintLabel and actionHintLabel:IsA("TextLabel") then
if selectedAction == "report" then
actionHintLabel.Text = "FLAGGED messages stay blocked from the staff inbox."
elseif selectedAction == "pass" then
actionHintLabel.Text = "AUTHORIZED messages are safe to let through the staff inbox."
elseif canClassify and isMailStepActive then
actionHintLabel.Text = "Report phishing mail. Pass Through legitimate internal mail."
elseif canClassify then
actionHintLabel.Text = "Choose an action and the server will validate it against the active Chapter 3 review step."
elseif triageState.resolvedCount >= triageState.total and triageState.total > 0 then
actionHintLabel.Text = "Inbox review is complete. Move to the live incident response tools."
else
actionHintLabel.Text = "This message is waiting for the active Chapter 3 mail review step."
end
end
if reportButton and reportButton:IsA("TextButton") then
reportButton.Active = canClassify
reportButton.AutoButtonColor = canClassify
reportButton.BackgroundColor3 = canClassify and Color3.fromRGB(184, 61, 61) or Color3.fromRGB(154, 161, 170)
reportButton.TextTransparency = canClassify and 0 or 0.18
end
if passButton and passButton:IsA("TextButton") then
passButton.Active = canClassify
passButton.AutoButtonColor = canClassify
passButton.BackgroundColor3 = canClassify and Color3.fromRGB(63, 142, 96) or Color3.fromRGB(154, 161, 170)
passButton.TextTransparency = canClassify and 0 or 0.18
end
end
browserState._classifySelectedMail = function(action)
local selectedMail = browserState._resolveSelectedMail and browserState._resolveSelectedMail() or nil
if not selectedMail then
setBrowserStatus("No inbox message selected.")
return
end
local triageState = browserState._getMailTriageState and browserState._getMailTriageState() or { currentStepId = nil, resolvedCount = 0, total = #CHAPTER3_MAILBOX }
if triageState.total > 0 and triageState.resolvedCount >= triageState.total then
setBrowserStatus("Inbox triage already complete.")
if browserState._renderMailPage then
browserState._renderMailPage()
end
return
end
local result = syncScenarioProgress(("browser_mail %s %s"):format(tostring(selectedMail.id or ""), tostring(action or "report")), { silent = true })
local actionLabel = tostring(action or "") == "pass" and "authorized" or "flagged"
if result and result.stepComplete then
setBrowserStatus(("Message %s. Inbox triage complete. WannaWail activity is now hitting office systems."):format(actionLabel))
elseif result and result.success then
local progressText = type(result.feedback) == "string" and result.feedback or ""
if progressText ~= "" then
setBrowserStatus(("Message %s. %s"):format(actionLabel, progressText))
else
setBrowserStatus(("Message %s."):format(actionLabel))
end
elseif result and type(result.output) == "string" and result.output ~= "" then
local compactOutput = result.output:gsub('%s+', ' ')
setBrowserStatus(compactOutput)
else
setBrowserStatus("Could not reach the mail classification service. Try again.")
end
if browserState._renderMailPage then
browserState._renderMailPage()
end
end
local function scenarioStepMatches(stepIds)
if type(stepIds) ~= "table" or #stepIds == 0 then
return true
end
local sessionInfo = getScenarioSessionInfo()
local currentStepId = sessionInfo and sessionInfo.stepId
if type(currentStepId) ~= "string" or currentStepId == "" then
return false
end
for _, stepId in ipairs(stepIds) do
if currentStepId == stepId then
return true
end
end
return false
end
submitScenarioAction = function(raw, stepIds)
if not scenarioStepMatches(stepIds) then
return nil
end
return syncScenarioProgress(raw, { silent = true })
end
local function showScenarioHint()
local getHintRemote = getScenarioRemote("GetHint")
if not getHintRemote then
addLine("No hint available right now.")
return
end
local ok, hintText = pcall(function()
return getHintRemote:InvokeServer()
end)
if ok and type(hintText) == "string" and hintText ~= "" then
addLine(hintText)
else
addLine("No hint available right now.")
end
end
local function handle(cmdLine)
local raw = tostring(cmdLine or ""):gsub("^%s+", ""):gsub("%s+$", "")
addLine(PROMPT .. raw)
local args = {}
for w in raw:gmatch("%S+") do
args[#args + 1] = w
end
local cmd = (args[1] or ""):lower()
local simOps = browserState._simOps or {}
if cmd == "" then
addLine(PROMPT)
return
end
local function rest(from)
local t = {}
for i = from, #args do
t[#t + 1] = args[i]
end
return table.concat(t, " ")
end
local function parseQuotedAndFile(input)
local pat, file = input:match('^%s*"(.-)"%s+(.+)$')
if pat and file then return pat, file end
local tokens = {}
for token in tostring(input or ""):gmatch("%S+") do
 tokens[#tokens + 1] = token
end
if #tokens < 2 then
 return nil, nil
end
local lastToken = tokens[#tokens]
tokens[#tokens] = nil
return table.concat(tokens, " "), lastToken
end
if cmd == "help" then
simOps.showHelp()
elseif cmd == "hint" then
showScenarioHint()
elseif cmd == "apps" then
addLine("Apps (SIM): terminal, browser, BloxMail, RBXPacketAnalyzer, admin portal, RBXIPBlocker")
addLine("Tip: open browser")
elseif cmd == "open" then
local which = (args[2] or ""):lower()
if which == "terminal" then
setVisiblePanel("terminal")
addLine("Switched to Terminal.")
elseif which == "browser" then
setVisiblePanel("browser")
addLine("Switched to Browser.")
elseif which == "notes" then
addLine("Notes app (sim) coming soon")
else
addLine("Try: open terminal OR open browser")
end
elseif cmd == "visit" then
local target = rest(2)
addLine("Opening " .. (target ~= "" and target or "about:blank") .. " ... (sim)")
if UrlBox then UrlBox.Text = target end
navigateTo(target)
elseif cmd == "scan" then
simOps.showScan(rest(2))
elseif cmd == "sniff" then
simOps.showSniff(rest(2))
elseif cmd == "packets" then
simOps.showPackets(rest(2))
elseif cmd == "devices" then
simOps.showDevices()
elseif cmd == "mac" then
simOps.showMac(args[2] or "")
elseif cmd == "connect" then
simOps.fakeConnect(rest(2))
elseif cmd == "ssh" then
simOps.fakeSSH(rest(2))
elseif cmd == "exit" then
simOps.fakeExit()
elseif cmd == "netstat" then
simOps.fakeNetstat()
elseif cmd == "pwd" then
simOps.showWorkingDirectory()
elseif cmd == "cd" then
simOps.changeDirectory(rest(2))
elseif cmd == "psrep" or (cmd == "ps" and (args[2] or "") == "aux") then
simOps.fakePsrep()
elseif cmd == "grep" then
local pattern, file = parseQuotedAndFile(rest(2))
simOps.fakeGrep(pattern, file)
elseif cmd == "malwarescan" then
simOps.fakeMalwareScan()
elseif cmd == "firewall" then
simOps.fakeFirewall(rest(2))
elseif cmd == "jamcam" or cmd == "jamcamera" then
simOps.fakeJamCam(rest(2))
elseif cmd == "kill" then
simOps.fakeKill(args[2] or "")
elseif cmd == "ls" then
simOps.listPath(rest(2))
elseif cmd == "stat" then
simOps.showStat(rest(2))
elseif cmd == "find" then
simOps.findEntries(rest(2))
elseif cmd == "cat" then
simOps.catFile(rest(2))
elseif cmd == "openfile" then
simOps.openFile(rest(2))
elseif cmd == "closefile" then
simOps.closeFile(rest(2))
elseif cmd == "echo" then
addLine(rest(2))
elseif cmd == "rm" then
simOps.removeFile(rest(2))
elseif cmd == "passwd" then
simOps.fakePasswd(rest(2))
elseif cmd == "baitcheck" then
simOps.phishCheck(rest(2))
elseif cmd == "decoymail" then
simOps.decoyMail(rest(2))
elseif cmd == "crack-ng" then
simOps.fakeCrackNG(rest(2))
elseif cmd == "admin" then
local on = (args[2] or ""):lower() == "on"
browserState.adminLoggedIn = on
addLine("Admin mode (sim) = " .. tostring(on))
elseif cmd == "save" then
if saveNow({ force = true }) then
addLine("Save completed.")
end
elseif cmd == "load" or cmd == "continue" then
addLine("Use Continue on the start screen.")
elseif cmd == "time" then
addLine(os.date("%Y-%m-%d %H:%M:%S"))
elseif cmd == "clear" or cmd == "reset" then
resetTerminalOutput(PROMPT)
return
else
addLine("I do not know that command. Type: help")
end
if cmd ~= "hint" and cmd ~= "jamcam" and cmd ~= "jamcamera" and cmd ~= "visit" and cmd ~= "packets" then
syncScenarioProgress(raw)
end
addLine(PROMPT)
end
local function pushHistory(cmd)
cmd = tostring(cmd or ""):gsub("^%s+", ""):gsub("%s+$", "")
if cmd == "" then return end
if commandHistory[#commandHistory] ~= cmd then
table.insert(commandHistory, cmd)
end
historyIndex = nil
currentDraft = ""
end
historyUp = function()
if #commandHistory == 0 or not TermInput then return end
if historyIndex == nil then
currentDraft = TermInput.Text
historyIndex = #commandHistory
else
historyIndex = math.max(1, historyIndex - 1)
end
TermInput.Text = commandHistory[historyIndex] or ""
TermInput.CursorPosition = #TermInput.Text + 1
end
historyDown = function()
if #commandHistory == 0 or not TermInput then return end
if historyIndex == nil then
return
end
historyIndex = historyIndex + 1
if historyIndex > #commandHistory then
historyIndex = nil
TermInput.Text = currentDraft or ""
else
TermInput.Text = commandHistory[historyIndex] or ""
end
TermInput.CursorPosition = #TermInput.Text + 1
end
local function buildMainUI()
local ui = TabletMainUI.build({
PlayerGui = PlayerGui,
UIS = UIS,
mk = mk,
round = round,
PROMPT = PROMPT,
addLine = addLine,
navigateTo = navigateTo,
pushHistory = pushHistory,
handle = handle,
setVisiblePanel = setVisiblePanel,
requestCameraJamFromTablet = requestCameraJamFromTablet,
requestGuardDistractFromTablet = requestGuardDistractFromTablet,
saveNow = saveNow,
startPacketCaptureForIP = startPacketCaptureForIP,
populatePacketRows = populatePacketRows,
renderAdminResults = renderAdminResults,
renderIPBlockerHistory = renderIPBlockerHistory,
showAdminDashboard = showAdminDashboard,
setBrowserStatus = setBrowserStatus,
submitScenarioAction = submitScenarioAction,
isToolEquipped = isToolEquipped,
getBrowserState = function()
return browserState
end,
isStarted = function()
return started == true
end,
getHostByIP = getHostByIP,
ActivePacketCapture = ActivePacketCapture,
WANNAWAIL_ATTR_SOURCE_BLOCKED = WANNAWAIL_ATTR_SOURCE_BLOCKED,
WANNAWAIL_ATTACKER_IP = WANNAWAIL_ATTACKER_IP,
historyUp = historyUp,
historyDown = historyDown,
onTerminalTextChanged = function(text)
if historyIndex == nil then
currentDraft = text
end
end,
})
MainGUI = ui.MainGUI
TermFrame = ui.TermFrame
BrowserFrame = ui.BrowserFrame
TermOut = ui.TermOut
TermInput = ui.TermInput
UrlBox = ui.UrlBox
PageLabel = ui.PageLabel
ClockLabel = ui.ClockLabel
MissionsFrame = ui.MissionsFrame
MissionsList = ui.MissionsList
ObjectivesList = ui.ObjectivesList
BrowserStatusLabel = ui.BrowserStatusLabel
BrowserContent = ui.BrowserContent
LinkBar = ui.LinkBar
AdminLoginPage = ui.AdminLoginPage
AdminDashboardPage = ui.AdminDashboardPage
AdminUserBox = ui.AdminUserBox
AdminPassBox = ui.AdminPassBox
AdminLoginStatus = ui.AdminLoginStatus
AdminSearchBox = ui.AdminSearchBox
AdminResultsFrame = ui.AdminResultsFrame
PacketPage = ui.PacketPage
PacketToolbar = ui.PacketToolbar
PacketListFrame = ui.PacketListFrame
PacketIPBox = ui.PacketIPBox
PacketDNSBox = ui.PacketDNSBox
PacketApplyBtn = ui.PacketApplyBtn
PacketClearBtn = ui.PacketClearBtn
PacketFollowBtn = ui.PacketFollowBtn
if TermOut then
resetTerminalOutput(PROMPT)
end
return MainGUI
end

installSimOps = function()
TabletSimOps.install({
browserState = browserState,
terminalState = terminalState,
ActivePacketCapture = ActivePacketCapture,
OpenFiles = OpenFiles,
Player = Player,
addLine = addLine,
getRemote = getRemote,
CAMERA_JAM_REMOTE_NAME = CAMERA_JAM_REMOTE_NAME,
WANNAWAIL_ATTR_SOURCE_BLOCKED = WANNAWAIL_ATTR_SOURCE_BLOCKED,
WANNAWAIL_ATTR_FIREWALL_BLOCKED = WANNAWAIL_ATTR_FIREWALL_BLOCKED,
WANNAWAIL_ATTR_PROCESS_KILLED = WANNAWAIL_ATTR_PROCESS_KILLED,
WANNAWAIL_ATTR_LOADER_REMOVED = WANNAWAIL_ATTR_LOADER_REMOVED,
WANNAWAIL_ATTR_CONTAINED = WANNAWAIL_ATTR_CONTAINED,
WANNAWAIL_ATTACKER_IP = WANNAWAIL_ATTACKER_IP,
SimFSByHost = SimFSByHost,
SimFileContentsByHost = SimFileContentsByHost,
SimMetadataByHost = SimMetadataByHost,
SimProcessesByHost = SimProcessesByHost,
getAllHostsList = getAllHostsList,
getHostByIP = getHostByIP,
startPacketCaptureForIP = startPacketCaptureForIP,
setBrowserStatus = setBrowserStatus,
})
end

installSimOps()

-- Boot splash with a real loading bar
local function playStart(onDone)
teardownStart()
local blur = mk("BlurEffect", { Parent = Lighting, Name = BLUR_NAME, Size = 12 })
local gui = mk("ScreenGui", { Parent = PlayerGui, Name = "HackStart", IgnoreGuiInset = true, ResetOnSpawn = false })
local bg = mk("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 14) })
mk("UIGradient", {
Parent = bg,
Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 20, 40)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 14)),
}),
Rotation = 45,
})
local card = mk("Frame", {
Parent = bg,
Size = UDim2.fromOffset(420, 280),
Position = UDim2.fromScale(0.5, 0.5),
AnchorPoint = Vector2.new(0.5, 0.5),
BackgroundColor3 = Color3.fromRGB(16, 22, 35),
})
round(card, 18)
mk("UIStroke", {
Parent = card,
Color = Color3.fromRGB(100, 150, 255),
Thickness = 2,
Transparency = 0.3,
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "HACKTABLET OS",
Font = Enum.Font.GothamBlack,
TextSize = 32,
TextColor3 = Color3.fromRGB(220, 235, 255),
Size = UDim2.new(1, 0, 0, 50),
Position = UDim2.new(0, 0, 0, 20),
})
mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "Initializing security system...",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(150, 170, 200),
Size = UDim2.new(1, 0, 0, 20),
Position = UDim2.new(0, 0, 0, 80),
})
local percentLabel = mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "000%",
Font = Enum.Font.Code,
TextSize = 20,
TextColor3 = Color3.fromRGB(198, 219, 255),
Size = UDim2.new(1, -56, 0, 28),
Position = UDim2.new(0, 28, 0, 122),
TextXAlignment = Enum.TextXAlignment.Right,
})
local barTrack = mk("Frame", {
Parent = card,
BackgroundColor3 = Color3.fromRGB(29, 39, 60),
BorderSizePixel = 0,
Size = UDim2.new(1, -56, 0, 22),
Position = UDim2.new(0, 28, 0, 158),
})
round(barTrack, 11)
local trackStroke = mk("UIStroke", {
Parent = barTrack,
Color = Color3.fromRGB(77, 108, 171),
Transparency = 0.4,
Thickness = 1,
})
local barFill = mk("Frame", {
Parent = barTrack,
BackgroundColor3 = Color3.fromRGB(95, 154, 255),
BorderSizePixel = 0,
Size = UDim2.new(0, 0, 1, 0),
})
round(barFill, 11)
local fillGradient = mk("UIGradient", {
Parent = barFill,
Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(66, 120, 238)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(143, 197, 255)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(66, 120, 238)),
}),
Rotation = 0,
})
local statusLabel = mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "Loading secure modules...",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(156, 181, 221),
Size = UDim2.new(1, -56, 0, 22),
Position = UDim2.new(0, 28, 0, 191),
TextXAlignment = Enum.TextXAlignment.Left,
})
local footer = mk("TextLabel", {
Parent = card,
BackgroundTransparency = 1,
Text = "SIMULATED DEVICE BOOT",
Font = Enum.Font.Code,
TextSize = 12,
TextColor3 = Color3.fromRGB(111, 132, 170),
Size = UDim2.new(1, -56, 0, 18),
Position = UDim2.new(0, 28, 1, -34),
TextXAlignment = Enum.TextXAlignment.Left,
})
local duration = 1.8
local steps = {
{ at = 0.0, text = "Loading secure modules..." },
{ at = 0.3, text = "Authenticating user profile..." },
{ at = 0.62, text = "Syncing terminal workspace..." },
{ at = 0.85, text = "Establishing secure link..." },
}
local cancelled = false
gui.Destroying:Connect(function()
cancelled = true
end)
local fillTween = Tween:Create(barFill, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
Size = UDim2.new(1, 0, 1, 0),
})
fillTween:Play()
local shimmerTween = Tween:Create(fillGradient, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {
Offset = Vector2.new(0.35, 0),
})
shimmerTween:Play()
local startTime = tick()
task.spawn(function()
while not cancelled and gui.Parent and card.Parent do
local alpha = math.clamp((tick() - startTime) / duration, 0, 1)
local percent = math.floor(alpha * 100 + 0.5)
percentLabel.Text = string.format("%03d%%", percent)
for i = #steps, 1, -1 do
if alpha >= steps[i].at then
statusLabel.Text = steps[i].text
break
end
end
if alpha >= 1 then
break
end
task.wait(0.03)
end
end)
task.delay(duration, function()
if cancelled or not gui.Parent then
return
end
percentLabel.Text = "100%"
statusLabel.Text = "Secure link established."
shimmerTween:Cancel()
trackStroke.Transparency = 0.7
fillGradient.Offset = Vector2.new(0, 0)
Tween:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
BackgroundTransparency = 1,
}):Play()
Tween:Create(barTrack, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
BackgroundTransparency = 1,
}):Play()
Tween:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
BackgroundTransparency = 1,
}):Play()
Tween:Create(percentLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
TextTransparency = 1,
}):Play()
Tween:Create(statusLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
TextTransparency = 1,
}):Play()
Tween:Create(footer, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
TextTransparency = 1,
}):Play()
Tween:Create(blur, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
Size = 0,
}):Play()
task.delay(0.35, function()
if gui.Parent then
gui:Destroy()
end
if blur.Parent then
blur:Destroy()
end
if not cancelled and onDone then
onDone()
end
end)
end)
end
local function buildHint()
local gui = mk("ScreenGui", {
Parent = PlayerGui,
Name = "TabletHint",
IgnoreGuiInset = true,
ResetOnSpawn = false,
Enabled = false,
})
local shade = mk("Frame", {
Parent = gui,
Size = UDim2.fromScale(1, 1),
BackgroundColor3 = Color3.fromRGB(5, 8, 12),
BackgroundTransparency = 0.3,
})
local panel = mk("Frame", {
Parent = shade,
BackgroundColor3 = Color3.fromRGB(15, 20, 32),
Size = UDim2.fromOffset(430, 190),
Position = UDim2.fromScale(0.5, 0.62),
AnchorPoint = Vector2.new(0.5, 0.5),
})
round(panel, 16)
mk("TextLabel", {
Parent = panel,
BackgroundTransparency = 1,
Font = Enum.Font.GothamBlack,
TextSize = 28,
TextColor3 = Color3.fromRGB(225, 235, 255),
Text = "HackOS Tablet",
Size = UDim2.new(1, 0, 0, 36),
Position = UDim2.new(0, 0, 0, 16),
})
mk("TextLabel", {
Parent = panel,
BackgroundTransparency = 1,
Font = Enum.Font.Gotham,
TextSize = 16,
TextColor3 = Color3.fromRGB(180, 200, 230),
TextWrapped = true,
Text = UIS.TouchEnabled and "Tap START to boot." or "Click START to boot.",
Size = UDim2.new(1, -40, 0, 42),
Position = UDim2.new(0, 20, 0, 60),
})
local startBtn = mk("TextButton", {
Parent = panel,
Text = "START",
Font = Enum.Font.GothamSemibold,
TextSize = 18,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(79, 131, 255),
Size = UDim2.fromOffset(210, 42),
Position = UDim2.new(0.5, -105, 1, -58),
})
round(startBtn, 12)
startBtn.MouseButton1Click:Connect(function()
	browserState._markInteraction()
if not isToolEquipped() then
gui.Enabled = false
return
end
gui.Enabled = false
playStart(function()
if isToolEquipped() and MainGUI then
resetUI()
MainGUI.Enabled = true
started = true
playAudio()
if browserState._ensureChapter3MailVisible then
browserState._ensureChapter3MailVisible()
end
if TermInput and not (BrowserFrame and BrowserFrame.Visible) then TermInput:CaptureFocus() end
else
stopAudio()
end
end)
end)
return gui
end
local function allowE()
return isToolEquipped() and started and MainGUI and MainGUI.Enabled
end
function bindEGuard()
CAS:UnbindAction(E_BIND)
CAS:BindActionAtPriority(E_BIND, function(_, state)
if state ~= Enum.UserInputState.Begin then
return Enum.ContextActionResult.Pass
end
return allowE() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E)
end
local function renderMissionCards(objectivesList)
TabletMissionUI.renderMissionCards(MissionsList, objectivesList, mk, round)
end

function renderObjectiveCards(objectivesList)
TabletMissionUI.renderObjectiveCards(ObjectivesList, objectivesList, chapterExpanded, mk, round, function(chapter)
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local loadScenario = remotes:FindFirstChild("LoadScenario")
if loadScenario then
loadScenario:InvokeServer(chapter.id)
end
end, function(chapter)
chapterExpanded[chapter.id] = not chapterExpanded[chapter.id]
renderObjectiveCards(objectivesList)
end)
end

do
browserState._clockLoopStarted = false
browserState._objectiveUpdatesBound = false

browserState._updateClockLabel = function()
	if ClockLabel and ClockLabel.Parent then
		ClockLabel.Text = os.date("%H:%M")
	end
end

browserState._refreshMissionPanels = function()
	renderMissionCards(ObjectiveManager.Get())
	renderObjectiveCards(ObjectiveManager.Get("ChapterObjectives"))
end

browserState._bindObjectiveUpdates = function()
	if browserState._objectiveUpdatesBound then
		return
	end

	browserState._objectiveUpdatesBound = true
	ObjectiveManager.Changed:Connect(function(objectivesList, category)
		if category == "ChapterObjectives" then
			renderObjectiveCards(objectivesList)
			return
		end

		if category == nil or category == "" then
			renderMissionCards(objectivesList)
		end
	end)
end

browserState._ensureClockLoop = function()
	browserState._updateClockLabel()
	if browserState._clockLoopStarted then
		return
	end

	browserState._clockLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(1)
			if not ClockLabel or not ClockLabel.Parent then
				browserState._clockLoopStarted = false
				break
			end
			browserState._updateClockLabel()
		end
	end)
end

browserState._onEquipped = function()
	if not isToolEquipped() then
		setEquipped(false)
		lastEquipped = false
		return
	end
	setEquipped(true)
	lastEquipped = true
	browserState._markInteraction()
	local pendingRestore = Player:GetAttribute(RESTORE_STATE_ATTRIBUTE)
	local hasPendingRestore = type(pendingRestore) == "string" and pendingRestore ~= ""
	if HintGUI and HintGUI.Parent ~= PlayerGui then
		HintGUI = nil
	end
	if MainGUI and MainGUI.Parent ~= PlayerGui then
		MainGUI = nil
	end
	if ReplayPromptGUI and ReplayPromptGUI.Parent ~= PlayerGui then
		ReplayPromptGUI = nil
	end
	local existingHint = PlayerGui:FindFirstChild("TabletHint")
	if existingHint and existingHint ~= HintGUI then
		existingHint:Destroy()
	end
	local existingMain = PlayerGui:FindFirstChild("TabletGUI")
	if existingMain and existingMain ~= MainGUI then
		existingMain:Destroy()
	end
	if ReplayPromptGUI then
		ReplayPromptGUI.Enabled = false
	end
	local builtMain = false
	if not HintGUI then
		HintGUI = buildHint()
	end
	if not MainGUI then
		MainGUI = buildMainUI()
		builtMain = true
	end
	local restored = false
	if hasPendingRestore then
		restored = applyPendingRestoreState()
	elseif builtMain and started then
		restored = applySessionRestoreState(captureSessionRestoreState())
	end
	browserState._bindObjectiveUpdates()
	browserState._ensureClockLoop()
	browserState._refreshMissionPanels()
	if started then
		HintGUI.Enabled = false
		MainGUI.Enabled = true
		if builtMain or restored then
			setVisiblePanel(browserState.visiblePanel, {
				url = browserState.visiblePanel == "browser" and browserState.currentUrl or nil,
				navigate = browserState.visiblePanel == "browser",
				captureFocus = false,
			})
		end
		playAudio()
		if browserState._ensureChapter3MailVisible then
			browserState._ensureChapter3MailVisible()
		end
	else
		HintGUI.Enabled = true
		MainGUI.Enabled = false
	end
	bindEGuard()
end

browserState._onUnequipped = function()
	if not isEquipped and not HintGUI and not MainGUI and not ReplayPromptGUI then
		lastEquipped = false
		return
	end
	setEquipped(false)
	lastEquipped = false
	if started then
		saveNow({ force = true, silent = true })
	end
	local permanentRemoval = not Tool or Tool.Parent == nil
	if ReplayPromptGUI then
		ReplayPromptGUI.Enabled = false
		if permanentRemoval then
			ReplayPromptGUI:Destroy()
			ReplayPromptGUI = nil
		end
	end
	if HintGUI then 
		HintGUI.Enabled = false
		if permanentRemoval then
			HintGUI:Destroy()
			HintGUI = nil
		end
	end
	if MainGUI then 
		MainGUI.Enabled = false
		if permanentRemoval then
			MainGUI:Destroy()
			MainGUI = nil
		end
	end
	if permanentRemoval then
		started = false
	end
	stopAudio()
	teardownStart()
	bindEGuard()
end

browserState._hookTool = function(t)
	if Tool == t then return end
	Tool = t
	t.AncestryChanged:Connect(function(_, parent)
		if not parent and Tool == t then
			browserState._onUnequipped()
			Tool = nil
		end
	end)
	t:GetPropertyChangedSignal("Parent"):Connect(function()
		if Tool ~= t then
			return
		end
		local char = Player.Character
		if char and t.Parent == char then
			browserState._onEquipped()
		elseif isEquipped or HintGUI or MainGUI or ReplayPromptGUI then
			browserState._onUnequipped()
		end
	end)
	t.Equipped:Connect(browserState._onEquipped)
	t.Unequipped:Connect(browserState._onUnequipped)
	local char = Player.Character
	if char and t.Parent == char then
		browserState._onEquipped()
	end
end

browserState._findTool = function()
	local char = Player.Character
	local backpack = Player:FindFirstChildOfClass("Backpack")
	if char then
		local t = char:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	if backpack then
		local t = backpack:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	return nil
end

browserState._watchContainer = function(container)
	if not container then
		return
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			browserState._hookTool(child)
		end
	end)
	local toolInContainer = container:FindFirstChild(TOOL_NAME)
	if toolInContainer and toolInContainer:IsA("Tool") then
		browserState._hookTool(toolInContainer)
	end
end

browserState._watchContainer(Player:WaitForChild("Backpack"))
browserState._watchContainer(Player.Character or Player.CharacterAdded:Wait())
Tool = Tool or browserState._findTool()
if Tool then
	browserState._hookTool(Tool)
end
lastEquipped = isToolEquipped()
Player.CharacterAdded:Connect(function(char)
	started = false
	stopAudio()
	teardownStart()
	bindEGuard()
	browserState._watchContainer(char)
	task.defer(function()
		Tool = nil
		lastEquipped = false
		task.wait(0.1)
		Tool = browserState._findTool()
		if Tool then
			browserState._hookTool(Tool)
			if isToolEquipped() then
				browserState._onEquipped()
			end
		end
	end)
end)
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if not Tool then
		Tool = browserState._findTool() or Tool
		if Tool then
			browserState._hookTool(Tool)
		end
		return
	end
	if browserState._ensureChapter3MailVisible then
		browserState._ensureChapter3MailVisible()
	end
	if browserState.adminTab == "logs" and BrowserFrame and BrowserFrame.Visible and AdminDashboardPage and AdminDashboardPage.Visible then
		if now - (browserState.logsLastRender or 0) >= 1 then
			browserState.logsLastRender = now
			renderAdminLogs()
		end
	end
	if autoSaveQueuedAt > 0 and not autoSaveInFlight and now - autoSaveQueuedAt >= AUTO_SAVE_DELAY then
		saveNow({ silent = true })
	end
	local equippedNow = isToolEquipped()
	if equippedNow ~= lastEquipped then
		lastEquipped = equippedNow
		if equippedNow then
			browserState._onEquipped()
		else
			browserState._onUnequipped()
		end
	end
end)
end

if MainGUI then
MainGUI:GetPropertyChangedSignal("Enabled"):Connect(bindEGuard)
end
Player:GetAttributeChangedSignal(RESTORE_STATE_ATTRIBUTE):Connect(function()
applyPendingRestoreState()
end)
task.defer(function()
applyPendingRestoreState()
end)
