local Players = game:GetService("Players")

local KeycardCopier = {}

local playerAccessState = {}

local function ensureAccessState(player)
	if player == nil or player.UserId == nil then
		return nil
	end

	local state = playerAccessState[player.UserId]
	if not state then
		state = {
			hasKeycardData = false,
			slidingDoorUnlocked = false,
		}
		playerAccessState[player.UserId] = state
	end

	return state
end

local function setServerMirror(player, attributeName, value)
	if player and player.Parent then
		player:SetAttribute(attributeName, value)
	end
end

local function hasOwnedKeycard(player, tool)
	if player == nil or tool == nil then
		return false
	end

	if tool:IsA("Tool") ~= true then
		return false
	end

	local ownerValue = tool:FindFirstChild("OwnerUserId")
	if ownerValue and ownerValue:IsA("IntValue") then
		return ownerValue.Value == player.UserId
	end

	-- Legacy fallback: some placed GhostKey tools predate the owner tag.
	-- Accept the canonical tool only while it is equipped by this player's character.
	return tool.Name == "GhostKey" and tool.Parent == player.Character
end

function KeycardCopier.canUnlock(player, tool)
	return hasOwnedKeycard(player, tool)
end

function KeycardCopier.tryUnlock(player, tool, unlockCallback)
	if KeycardCopier.canUnlock(player, tool) then
		if typeof(unlockCallback) == "function" then
			unlockCallback()
		end
		return true
	end

	return false
end

-- Compatibility bridge: older server scripts may still award this attribute directly.
-- Access checks read this module so gameplay no longer depends on raw attribute reads.
function KeycardCopier.syncLegacyKeycardData(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	if player:GetAttribute("HasKeycardData") == true then
		state.hasKeycardData = true
		return true
	end

	return false
end

function KeycardCopier.hasKeycardData(player)
	local state = ensureAccessState(player)
	return state ~= nil and state.hasKeycardData == true
end

function KeycardCopier.grantKeycardData(player)
    local state = ensureAccessState(player)
    if not state then
        return false
    end

    state.hasKeycardData = true
    setServerMirror(player, "HasKeycardData", true)
    
    require(game.ServerScriptService.Server.DecisionTracker).LogDecision(player, "ClonedKeycard", true)
 
    
    return true
end

function KeycardCopier.clearKeycardData(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	state.hasKeycardData = false
	setServerMirror(player, "HasKeycardData", nil)
	return true
end

function KeycardCopier.syncLegacySlidingDoorAccess(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	if player:GetAttribute("UnlockedSlidingDoor") == true then
		state.slidingDoorUnlocked = true
		return true
	end

	return false
end

function KeycardCopier.hasSlidingDoorAccess(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	if state.slidingDoorUnlocked == true then
		return true
	end

	-- Compatibility bridge: some existing live scanner scripts still set the
	-- server-side UnlockedSlidingDoor attribute directly after granting access.
	return KeycardCopier.syncLegacySlidingDoorAccess(player)
end

function KeycardCopier.grantSlidingDoorAccess(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	state.slidingDoorUnlocked = true
	setServerMirror(player, "UnlockedSlidingDoor", true)
	return true
end

function KeycardCopier.clearSlidingDoorAccess(player)
	local state = ensureAccessState(player)
	if not state then
		return false
	end

	state.slidingDoorUnlocked = false
	setServerMirror(player, "UnlockedSlidingDoor", nil)
	return true
end

function KeycardCopier.resetAccess(player)
	local state = ensureAccessState(player)
	if not state then
		return
	end

	state.hasKeycardData = false
	state.slidingDoorUnlocked = false
	setServerMirror(player, "HasKeycardData", nil)
	setServerMirror(player, "UnlockedSlidingDoor", nil)
end

Players.PlayerRemoving:Connect(function(player)
	playerAccessState[player.UserId] = nil
end)

return KeycardCopier
