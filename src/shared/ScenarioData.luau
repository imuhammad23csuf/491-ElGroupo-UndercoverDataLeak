--[[
    ScenarioData.luau
    ─────────────────────────────────────────────────────────────────
    All chapter definitions for the CyberGame HackTablet.
    Each chapter is a keyed table with:
      • type            "terminal"
      • title / objective / welcomeMessage
      • steps[]         ordered list of tasks the player must complete

    Each step:
      • id              unique string identifier
      • instruction     shown in the tablet HUD above the terminal
      • hint            shown on request or on wrong command
      • validCommands   list of accepted input strings (lowercase-compared)
      • matchPrefix     if true, input only needs to START with one of validCommands
      • output          text the terminal prints when the command is correct
      • isLastStep      true on the final step of a chapter
--]]

local ScenarioData = {}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 1 — Bloxplay_ITWifi Recon
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter1_Recon = {
    type      = "terminal",
    title     = "Chapter 1: Recon Bloxplay_ITWifi",
    objective = "Scan and identify vulnerable WiFi networks at Bloxplay HQ.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║        HACKTABLET v2.4  —  RECON MODE           ║
║   Objective: Scan networks & capture packets     ║
╚══════════════════════════════════════════════════╝
You are outside Bloxplay HQ. Several WiFi networks are visible.
Type  help  to see available commands.
]],
    steps = {
        {
            id = "help",
            instruction = "Type: help to see available commands.",
            hint = "Type: help",
            validCommands = { "help" },
            output = [[
Available Commands:
  help
  scan
  sniff <SSID>
  connect <SSID> --creds <user:pass>
  clear
]],
        },
        {
            id = "scan",
            instruction = "Scan for WiFi networks. Type: scan",
            hint = "Type: scan",
            validCommands = { "scan" },
            output = [[
[*] Scanning for WiFi networks...
[*] 2 networks discovered:
  SSID                BSSID               ENC     SIGNAL
  Bloxplay_ITWifi     A4:2B:11:9C:7D:10   WPA2    ████░░
  Bloxplay_AdminWifi  B8:77:21:4E:91:02   WPA2    █████░
[*] Try sniff Bloxplay_ITWifi
]],
        },
        {
            id = "sniff",
            instruction = "Capture packets from Bloxplay_ITWifi. Type: sniff Bloxplay_ITWifi",
            hint = "Type: sniff Bloxplay_ITWifi",
            validCommands = { "sniff bloxplay_itwifi" },
            output = [[
[*] Capturing packets on Bloxplay_ITWifi...
[*] Found device: Laptop (192.168.32.12)
[*] Credentials found: user=rbxplayer, pass=simulatedpass
[*] Now connect Bloxplay_ITWifi --creds rbxplayer:simulatedpass
]],
        },
        {
            id = "connect",
            instruction = "Connect to Bloxplay_ITWifi. Type: connect Bloxplay_ITWifi --creds rbxplayer:simulatedpass",
            hint = "Type: connect Bloxplay_ITWifi --creds rbxplayer:simulatedpass",
            validCommands = { "connect bloxplay_itwifi" },
            matchPrefix = true,
            output = [[
[*] Connected to Bloxplay_ITWifi. DHCP lease: 192.168.32.77
[*] You are now inside the Bloxplay network.
]],
            isLastStep = true,
        },
    },
}

-- CHAPTER 2 — SSH to PlayerData_Vault
ScenarioData.Chapter2_SSH = {
    type      = "terminal",
    title     = "Chapter 2: SSH to PlayerData_Vault",
    objective = "Access PlayerData_Vault and review logs for suspicious activity.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║        HACKTABLET v2.4  —  FORENSICS MODE        ║
║   Objective: Investigate PlayerData_Vault        ║
╚══════════════════════════════════════════════════╝
Type: ssh bloxplay-admin@192.168.43.20
]],
    steps = {
        {
            id = "ssh_connect",
            instruction = "SSH into PlayerData_Vault. Type: ssh bloxplay-admin@192.168.43.20",
            hint = "Type: ssh bloxplay-admin@192.168.43.20",
            validCommands = { "ssh bloxplay-admin@192.168.43.20" },
            output = [[
[*] Connected to PlayerData_Vault (192.168.43.20)
[*] Last login: suspicious IP 203.44.18.77
]],
        },
        {
            id = "ls_logs",
            instruction = "List logs. Type: ls /var",
            hint = "Type: ls /var",
            validCommands = { "ls /var" },
            output = [[
/var: www backups tmp
]],
        },
        {
            id = "cat_authlog",
            instruction = "Read auth.log. Type: cat /etc/auth.log",
            hint = "Type: cat /etc/auth.log",
            validCommands = { "cat /etc/auth.log" },
            output = [[
2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:04:08 sshd[1322]: Accepted password for bloxplay-admin from 192.168.32.12
]],
            isLastStep = true,
        },
    },
}

-- CHAPTER 3 — Admin Portal Investigation (Browser Required)
ScenarioData.Chapter3_AdminPortal = {
    type      = "browser",
    title     = "Chapter 3: Investigate Admin Portal",
    objective = "Access the admin portal and attempt login using discovered credentials.",
    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║        HACKTABLET v2.4  —  BROWSER MODE         ║
║   Objective: Investigate the admin portal        ║
╚══════════════════════════════════════════════════╝
Use the browser to visit bloxplay.com/admin and try to log in as admin.
]],
    steps = {
        {
            id = "visit_admin",
            instruction = "Open the browser and go to bloxplay.com/admin.",
            hint = "Use the browser, not the terminal.",
            validCommands = {}, -- No terminal command
            output = [[
[Browser] Navigated to bloxplay.com/admin. Login page loaded.
]],
        },
        {
            id = "try_login",
            instruction = "Try logging in as admin using credentials you have found.",
            hint = "Try the username and password you discovered earlier.",
            validCommands = {}, -- No terminal command
            output = [[
[Browser] Login attempt made. Access denied. Try different credentials or check for clues in logs or captured packets.
]],
            isLastStep = true,
        },
    },
}

-- Ensure all scenario steps reference the same IPs, hostnames, and actions as the HackTablet simulation.
-- Example for Chapter 1 and 2 shown above. Repeat for all chapters, matching SimHosts and simulated files.

return ScenarioData
