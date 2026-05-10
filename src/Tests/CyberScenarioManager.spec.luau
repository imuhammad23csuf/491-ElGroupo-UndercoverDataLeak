local ObjectiveManager = require(game.ReplicatedStorage.Shared.ObjectiveManager)
ObjectiveManager.SetPlayerObjectives = function() end

local CyberScenarioManager = require(game.ReplicatedStorage.Shared.CyberScenarioManager)

local function makeFakePlayer(userId)
	local attributes = {}

	return {
		UserId = userId,
		Name = "TestPlayer" .. tostring(userId),
		GetAttribute = function(_, name)
			return attributes[name]
		end,
		SetAttribute = function(_, name, value)
			attributes[name] = value
		end,
	}
end

return function()
	describe("CyberScenarioManager progress persistence", function()
		it("exports the advanced step before cleanup and imports it without resetting", function()
			local player = makeFakePlayer(9101)
			CyberScenarioManager.ResetProgress(player)

			local loaded = CyberScenarioManager.LoadScenario(player, "Chapter1_Recon")
			expect(loaded).never.to.equal(nil)

			local result = CyberScenarioManager.CheckSolution(player, "help")
			expect(result.success).to.equal(true)
			expect(result.stepComplete).to.equal(true)

			local saved = CyberScenarioManager.ExportProgress(player)
			expect(CyberScenarioManager.HasProgressSnapshot(saved)).to.equal(true)
			expect(saved.activeSession.scenarioId).to.equal("Chapter1_Recon")
			expect(saved.activeSession.currentStep).to.equal(2)

			CyberScenarioManager.Cleanup(player)
			expect(CyberScenarioManager.GetSessionInfo(player)).to.equal(nil)

			local restored = CyberScenarioManager.ImportProgress(player, saved)
			expect(restored).never.to.equal(nil)
			expect(restored.scenarioId).to.equal("Chapter1_Recon")
			expect(restored.currentStep).to.equal(2)
		end)

		it("resolves completed chapter saves to the next chapter instead of defaulting to tutorial", function()
			local completedChapterOne = {
				activeSession = nil,
				completedScenarios = {
					Chapter1_Recon = true,
				},
			}

			expect(CyberScenarioManager.HasProgressSnapshot(completedChapterOne)).to.equal(true)
			expect(CyberScenarioManager.ResolveNextScenarioAfterCompletedProgress(completedChapterOne)).to.equal("Chapter2_SSH")
			expect(CyberScenarioManager.ResolveNextScenarioAfterCompletedProgress({
				activeSession = nil,
				completedScenarios = {},
			})).to.equal(nil)
		end)
	end)
end
