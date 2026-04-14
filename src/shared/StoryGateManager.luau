local IntegrityService = require(script.Parent.IntegrityService)

local StoryGateManager = {}

local storyGates = {
	WhistleblowerPath = {
		type = "minIntegrity",
		value = 70,
	},

	CorporateSpyPath = {
		type = "maxIntegrity",
		value = 49,
	},

	Level3A = {
		type = "minIntegrity",
		value = 50,
	},

	Level3B = {
		type = "maxIntegrity",
		value = 49,
	},
}

function StoryGateManager.isUnlocked(player, gateId)
	local gate = storyGates[gateId]
	if not gate then
		return false, "Gate not found"
	end

	local integrity = IntegrityService.getIntegrity(player)

	if gate.type == "minIntegrity" then
		return integrity >= gate.value, integrity
	elseif gate.type == "maxIntegrity" then
		return integrity <= gate.value, integrity
	end

	return false, integrity
end

function StoryGateManager.getAvailablePaths(player)
	local results = {}

	for gateId, _ in pairs(storyGates) do
		local unlocked, integrity = StoryGateManager.isUnlocked(player, gateId)
		results[gateId] = {
			unlocked = unlocked,
			integrity = integrity,
		}
	end

	return results
end

return StoryGateManager