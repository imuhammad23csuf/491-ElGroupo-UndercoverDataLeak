local NarrativeManager = require(game.ReplicatedStorage.Shared.NarrativeManager)
local IntegrityService = require(game.ReplicatedStorage.Shared.IntegrityService)

local function makeFakePlayer(userId)
	return {
		UserId = userId,
	}
end

return function()
	describe("NarrativeManager", function()
		-- IntegrityService and dialogue sessions persist at module scope; reset between examples so
		-- integrity deltas match DialogueData (e.g. Intro choice 1 is +10 once), not accumulated reruns.
		beforeEach(function()
			for _, userId in ipairs({ 101, 102, 103, 104 }) do
				local p = makeFakePlayer(userId)
				IntegrityService.resetIntegrity(p)
				NarrativeManager.endDialogue(p)
			end
		end)

		it("starts a dialogue successfully", function()
			local player = makeFakePlayer(101)

			local nodeData, err = NarrativeManager.startDialogue(player, "Intro")

			expect(err).to.equal(nil)
			expect(nodeData).never.to.equal(nil)
			expect(nodeData.nodeId).to.equal("node1")
		end)

		it("applies integrity changes when a choice is made", function()
			local player = makeFakePlayer(102)

			NarrativeManager.startDialogue(player, "Intro")
			local nextNode = NarrativeManager.chooseOption(player, 1)

			expect(nextNode).never.to.equal(nil)
			expect(IntegrityService.getIntegrity(player)).to.equal(10)
		end)

		it("branches correctly to another node", function()
			local player = makeFakePlayer(103)

			NarrativeManager.startDialogue(player, "Intro")
			local nextNode = NarrativeManager.chooseOption(player, 2)

			expect(nextNode).never.to.equal(nil)
			expect(nextNode.nodeId).to.equal("node3")
		end)

		it("returns an error for invalid choices", function()
			local player = makeFakePlayer(104)

			NarrativeManager.startDialogue(player, "Intro")
			local result, err = NarrativeManager.chooseOption(player, 99)

			expect(result).to.equal(nil)
			expect(err).to.equal("Invalid choice")
		end)
	end)
end