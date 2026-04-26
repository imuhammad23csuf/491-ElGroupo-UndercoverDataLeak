local TabletIncidentLogs = {}

function TabletIncidentLogs.getWannaWailIncidentLogs(player, config, adminLogFeed)
    local currentChapter = tonumber(player:GetAttribute("CurrentChapter")) or 0
    if currentChapter < 3 then
        return {}
    end

    local infectedCount = math.max(tonumber(player:GetAttribute(config.WANNAWAIL_ATTR_COUNT)) or 0, 0)
    local active = player:GetAttribute(config.WANNAWAIL_ATTR_ACTIVE) == true or infectedCount > 0
    local lastMachine = tostring(player:GetAttribute(config.WANNAWAIL_ATTR_LAST_MACHINE) or "Office Terminal 01")
    local sourceBlocked = player:GetAttribute(config.WANNAWAIL_ATTR_SOURCE_BLOCKED) == true
    local firewallBlocked = player:GetAttribute(config.WANNAWAIL_ATTR_FIREWALL_BLOCKED) == true
    local processKilled = player:GetAttribute(config.WANNAWAIL_ATTR_PROCESS_KILLED) == true
    local loaderRemoved = player:GetAttribute(config.WANNAWAIL_ATTR_LOADER_REMOVED) == true
    local contained = player:GetAttribute(config.WANNAWAIL_ATTR_CONTAINED) == true
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
        push(adminLogFeed.live[1], ("Latest endpoint alert from %s shows outbound callback activity tied to %s."):format(lastMachine, config.WANNAWAIL_ATTACKER_IP))
    end
    if infectedCount >= 2 then
        push(adminLogFeed.live[2], ("%d office endpoints now report rapid rename activity consistent with live ransomware spread."):format(infectedCount))
        logs[#logs + 1] = {
            severity = "CRITICAL",
            title = "Lateral movement detected",
            detail = ("WannaWail is pivoting between internal endpoints. %d machines now show coordinated spread behavior."):format(infectedCount),
            stamp = "08:15",
        }
    end
    if infectedCount >= 3 then
        push(adminLogFeed.live[3], ("%d user-facing screens now show WannaWail banners. Latest hit: %s."):format(infectedCount, lastMachine))
        logs[#logs + 1] = {
            severity = "CRITICAL",
            title = "Cross-host propagation accelerating",
            detail = ("Lateral movement reached additional user systems. Latest compromised endpoint: %s."):format(lastMachine),
            stamp = "08:16",
        }
    end
    if active and not processKilled then
        push(adminLogFeed.live[4], "The sync_jobs.sh process is still alive on PlayerData_Vault and continues coordinating the outbreak.")
    end
    if infectedCount >= 4 and not sourceBlocked then
        push(adminLogFeed.live[5], ("Player export traffic is still trying to stage outbound transfer through %s while the outbreak remains active."):format(config.WANNAWAIL_ATTACKER_IP))
    end
    if sourceBlocked then
        logs[#logs + 1] = {
            severity = "HIGH",
            title = "Emergency browser block applied",
            detail = ("RBXIPBlocker denied the hostile source %s at the browser response layer."):format(config.WANNAWAIL_ATTACKER_IP),
            stamp = "08:19",
        }
    end
    if firewallBlocked then
        logs[#logs + 1] = {
            severity = "MEDIUM",
            title = "Vault firewall deny rule added",
            detail = ("PlayerData_Vault now mirrors the deny rule for %s locally."):format(config.WANNAWAIL_ATTACKER_IP),
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

return TabletIncidentLogs
