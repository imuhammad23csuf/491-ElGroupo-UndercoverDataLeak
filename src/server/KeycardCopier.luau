local KeycardCopier = {}

local function hasOwnedKeycard(player, tool)
	if player == nil or tool == nil then
		return false
	end

	if tool:IsA("Tool") ~= true then
		return false
	end

	local ownerValue = tool:FindFirstChild("OwnerUserId")
	if ownerValue == nil or ownerValue:IsA("IntValue") ~= true then
		return false
	end

	return ownerValue.Value == player.UserId
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

return KeycardCopier