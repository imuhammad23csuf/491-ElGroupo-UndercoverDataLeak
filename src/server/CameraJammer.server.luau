-- CameraJammer server handler
-- Handles the JamCamera RemoteFunction invoked by the tablet's cam-jammer tool.
-- Sets a timed attribute on ReplicatedStorage that clients read to show the
-- "SIGNAL JAMMED" overlay on the camera monitor UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

local JAM_DURATION = 60
local JAM_STATE_ATTRIBUTE = "CameraNetworkJamUntil"
local COOLDOWN = 10
local HACK_TABLET_NAME = "HackTablet"

-- Per-player cooldown tracked with os.clock() (server-only timing, no network dependency)
local playerCooldowns = {}

Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
end)

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

local function hasEquippedTablet(player)
    if player:GetAttribute("HackTabletEquipped") == true then
        return true
    end

    local char = player.Character
    local equippedTool = char and char:FindFirstChildOfClass("Tool")
    return equippedTool ~= nil and equippedTool.Name == HACK_TABLET_NAME
end

JamRemote.OnServerInvoke = function(player, _target)
    -- Validate player is alive and in game
    if not player or not player.Parent then
        return { success = false, message = "Invalid request." }
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return { success = false, message = "Camera jammer unavailable." }
    end

    if not hasEquippedTablet(player) then
        return { success = false, message = "Equip the HackTablet before using Camera Jammer." }
    end

    if not CyberScenarioManager.hasActiveScenario(player) then
        return { success = false, message = "Camera jammer is only available during an active mission." }
    end

    -- Workspace:GetServerTimeNow() is used here because the client reads this
    -- attribute and compares it against its own Workspace:GetServerTimeNow() call,
    -- so both sides must use the same synchronized clock.
    local serverNow = Workspace:GetServerTimeNow()

    local currentJamUntil = ReplicatedStorage:GetAttribute(JAM_STATE_ATTRIBUTE)
    if typeof(currentJamUntil) == "number" and currentJamUntil > serverNow then
        local remaining = math.ceil(currentJamUntil - serverNow)
        return {
            success = false,
            message = string.format("Camera network already jammed. Clears in %d second%s.", remaining, remaining == 1 and "" or "s"),
        }
    end

    -- Per-player cooldown uses os.clock() (immediate, no network dependency)
    local clockNow = os.clock()
    local lastUsed = playerCooldowns[player.UserId] or -math.huge
    if clockNow - lastUsed < COOLDOWN then
        local wait = math.ceil(COOLDOWN - (clockNow - lastUsed))
        return {
            success = false,
            message = string.format("Camera jammer on cooldown. Ready in %d second%s.", wait, wait == 1 and "" or "s"),
        }
    end

    playerCooldowns[player.UserId] = clockNow
    ReplicatedStorage:SetAttribute(JAM_STATE_ATTRIBUTE, serverNow + JAM_DURATION)

    return {
        success = true,
        message = string.format("Camera network jammed for %d seconds.", JAM_DURATION),
    }
end
