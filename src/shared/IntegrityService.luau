local IntegrityService = {}

local integrityScores = {}

function IntegrityService.getIntegrity(player)
	if not player or not player.UserId then
		return 0
	end

	return integrityScores[player.UserId] or 0
end

function IntegrityService.setIntegrity(player, value)
	if not player or not player.UserId then
		return 0
	end

	integrityScores[player.UserId] = value
	return value
end

function IntegrityService.addIntegrity(player, amount)
	if not player or not player.UserId then
		return 0
	end

	local current = IntegrityService.getIntegrity(player)
	local updated = current + amount
	integrityScores[player.UserId] = updated

	return updated
end

function IntegrityService.resetIntegrity(player)
	if not player or not player.UserId then
		return
	end

	integrityScores[player.UserId] = 0
end

return IntegrityService