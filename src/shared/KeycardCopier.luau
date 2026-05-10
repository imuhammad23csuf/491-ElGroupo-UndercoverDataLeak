-- Shared fallback for KeycardCopier so tests can run in client or server
local ok, serverMod = pcall(function()
    return require(game.ServerScriptService.Server.KeycardCopier)
end)

if ok and type(serverMod) == "table" then
    return serverMod
end

local KeycardCopier = {}

local function hasOwnedKeycard(player, tool)
    if player == nil or tool == nil then
        return false
    end

    if tool.ClassName ~= "Tool" then
        return false
    end

    local ownerValue = tool:FindFirstChild("OwnerUserId")
    if ownerValue and ownerValue.ClassName == "IntValue" then
        return ownerValue.Value == player.UserId
    end

    return tool.Name == "GhostKey" and tool.Parent == (player.Character)
end

function KeycardCopier.canUnlock(player, tool)
    return hasOwnedKeycard(player, tool)
end

function KeycardCopier.tryUnlock(player, tool, unlockCallback)
    if KeycardCopier.canUnlock(player, tool) then
        if type(unlockCallback) == "function" then
            unlockCallback()
        end
        return true
    end
    return false
end

return KeycardCopier
