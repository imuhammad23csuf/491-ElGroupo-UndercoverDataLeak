-- CameraJammer server handler
-- Handles the JamCamera RemoteFunction invoked by the tablet's cam-jammer tool.
-- Sets a timed attribute on ReplicatedStorage that clients read to show the
-- "SIGNAL JAMMED" overlay on the camera monitor UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local JAM_DURATION = 60
local JAM_STATE_ATTRIBUTE = "CameraNetworkJamUntil"
local COOLDOWN = 10

local lastJamTime = -math.huge

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local JamRemote = remotesFolder:FindFirstChild("JamCamera")
if not JamRemote then
    JamRemote = Instance.new("RemoteFunction")
    JamRemote.Name = "JamCamera"
    JamRemote.Parent = remotesFolder
end

JamRemote.OnServerInvoke = function(_player, _target)
    local now = Workspace:GetServerTimeNow()

    local currentJamUntil = ReplicatedStorage:GetAttribute(JAM_STATE_ATTRIBUTE)
    if typeof(currentJamUntil) == "number" and currentJamUntil > now then
        local remaining = math.ceil(currentJamUntil - now)
        return {
            success = false,
            message = string.format("Camera network already jammed. Clears in %d second%s.", remaining, remaining == 1 and "" or "s"),
        }
    end

    if now - lastJamTime < COOLDOWN then
        local wait = math.ceil(COOLDOWN - (now - lastJamTime))
        return {
            success = false,
            message = string.format("Camera jammer on cooldown. Ready in %d second%s.", wait, wait == 1 and "" or "s"),
        }
    end

    lastJamTime = now
    ReplicatedStorage:SetAttribute(JAM_STATE_ATTRIBUTE, now + JAM_DURATION)

    return {
        success = true,
        message = string.format("Camera network jammed for %d seconds.", JAM_DURATION),
    }
end
