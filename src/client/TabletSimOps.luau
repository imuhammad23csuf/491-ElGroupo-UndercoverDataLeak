local TabletSimOps = {}

function TabletSimOps.install(ctx)
local browserState = ctx.browserState
local terminalState = ctx.terminalState
local ActivePacketCapture = ctx.ActivePacketCapture
local OpenFiles = ctx.OpenFiles
local Player = ctx.Player
local addLine = ctx.addLine
local getRemote = ctx.getRemote
local CAMERA_JAM_REMOTE_NAME = ctx.CAMERA_JAM_REMOTE_NAME
local WANNAWAIL_ATTR_SOURCE_BLOCKED = ctx.WANNAWAIL_ATTR_SOURCE_BLOCKED
local WANNAWAIL_ATTR_FIREWALL_BLOCKED = ctx.WANNAWAIL_ATTR_FIREWALL_BLOCKED
local WANNAWAIL_ATTR_PROCESS_KILLED = ctx.WANNAWAIL_ATTR_PROCESS_KILLED
local WANNAWAIL_ATTR_LOADER_REMOVED = ctx.WANNAWAIL_ATTR_LOADER_REMOVED
local WANNAWAIL_ATTR_CONTAINED = ctx.WANNAWAIL_ATTR_CONTAINED
local WANNAWAIL_ATTACKER_IP = ctx.WANNAWAIL_ATTACKER_IP
local SimFSByHost = ctx.SimFSByHost
local SimFileContentsByHost = ctx.SimFileContentsByHost
local SimMetadataByHost = ctx.SimMetadataByHost
local SimProcessesByHost = ctx.SimProcessesByHost
local getAllHostsList = ctx.getAllHostsList
local getHostByIP = ctx.getHostByIP
local startPacketCaptureForIP = ctx.startPacketCaptureForIP
local setBrowserStatus = ctx.setBrowserStatus

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
addLine("Capture complete: targeted lab packets generated (sim)")
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
addLine("Browser view: visit RBXPacketAnalyzer.com")
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
local function fakeJamCam(rawInput)
local target = tostring(rawInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
if target == "" then
addLine("Try: jamcam 192.168.32.31 (jams all cameras for 60 seconds)")
return
end
local jamRemote = getRemote(CAMERA_JAM_REMOTE_NAME)
if not jamRemote or not jamRemote:IsA("RemoteFunction") then
addLine("jamcam: camera service unavailable.")
return
end
local ok, result = pcall(function()
return jamRemote:InvokeServer(target)
end)
if not ok or type(result) ~= "table" then
addLine("jamcam: request failed.")
return
end
addLine(tostring(result.message or "Camera jam request sent."))
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
local selectedMail = browserState._resolveSelectedMail and browserState._resolveSelectedMail() or nil
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
addLine("HackOS authorized lab commands:")
addLine("help - show this list")
addLine("hint - show a clue for the current objective")
addLine("apps - list apps")
addLine("open <terminal|browser|notes> - switch screens")
addLine("visit <url|home|tips|apps|mail|rbxpacketanalyzer> - open a browser page")
addLine("scan [nearby|ip] - scan nearby devices/host (sim)")
addLine("sniff [ip] - capture simulated lab packet traffic")
addLine("packets [ip] - packet analyzer terminal summary (browser: RBXPacketAnalyzer)")
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
addLine("psrep / ps aux - list simulated processes")
addLine("malwarescan - simulate malware scan")
addLine("firewall add deny <ip> - add a deny rule on the vault")
addLine("firewall deny <ip> - shorthand deny rule")
addLine("kill <pid> - terminate simulated process")
addLine("echo <text> - print text")
addLine("passwd <text> - password set/check (sim)")
addLine("baitcheck <text> - detect phishing clues (sim)")
addLine("Admin portal: open the Security Logs tab during Chapter 3")
addLine("decoymail <text> - inspect suspicious email tone (sim)")
addLine("crack-ng <target> - password policy audit (sim)")
addLine("admin <on|off> - toggle admin mode (sim)")
addLine("save - save progress manually")
addLine("clear - clear terminal")
addLine("time - show time")
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
simOps.fakeJamCam = fakeJamCam
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

return TabletSimOps
