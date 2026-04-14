local DecisionTracker = {}

-- The global table storing decisions for every player in the server
-- Format: [UserId] = { ["ReportedPhish"] = true, ["RudeToCoworker"] = false }
local playerDecisions = {}

-- Auto-builder to ensure the table doesn't crash if checked too early
local function ensureLogExists(player)
	if not playerDecisions[player.UserId] then
		playerDecisions[player.UserId] = {}
	end
end

-- ==========================================
-- 1. SAVE A DECISION (Called during dialogue)
-- ==========================================
function DecisionTracker.LogDecision(player, decisionKey, value)
	ensureLogExists(player)
	
	-- Save the key/value pair
	playerDecisions[player.UserId][decisionKey] = value
	
	print(string.format("[DECISION LOG] %s logged choice: %s = %s", player.Name, decisionKey, tostring(value)))
end

-- ==========================================
-- 2. QUERY A DECISION (Called for future NPC reactions)
-- ==========================================
function DecisionTracker.GetDecision(player, decisionKey)
	ensureLogExists(player)
	
	-- Returns the value (true/false/string), or nil if they haven't made it yet
	return playerDecisions[player.UserId][decisionKey]
end

-- ==========================================
-- 3. GET ETHICS SUMMARY (Called at the end of the game)
-- ==========================================
function DecisionTracker.GetAllDecisions(player)
	ensureLogExists(player)
	return playerDecisions[player.UserId]
end

return DecisionTracker