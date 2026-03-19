local KeycardCopier = require(game.ServerScriptService.server.KeycardCopier)

local function makeFakePlayer(userId)
	return {
		UserId = userId,
	}
end

local function makeOwnedTool(ownerUserId)
	local tool = Instance.new("Tool")
	tool.Name = "Keycard"

	local ownerValue = Instance.new("IntValue")
	ownerValue.Name = "OwnerUserId"
	ownerValue.Value = ownerUserId
	ownerValue.Parent = tool

	return tool
end

return function()
	describe("KeycardCopier", function()
		it("allows unlock when the player owns the keycard", function()
			local player = makeFakePlayer(12345)
			local tool = makeOwnedTool(12345)

			local unlocked = false

			local result = KeycardCopier.tryUnlock(player, tool, function()
				unlocked = true
			end)

			expect(result).to.equal(true)
			expect(unlocked).to.equal(true)
		end)

		it("rejects unlock when the keycard belongs to someone else", function()
			local player = makeFakePlayer(12345)
			local tool = makeOwnedTool(99999)

			local unlocked = false

			local result = KeycardCopier.tryUnlock(player, tool, function()
				unlocked = true
			end)

			expect(result).to.equal(false)
			expect(unlocked).to.equal(false)
		end)

		it("rejects unlock when the keycard is missing", function()
			local player = makeFakePlayer(12345)

			local unlocked = false

			local result = KeycardCopier.tryUnlock(player, nil, function()
				unlocked = true
			end)

			expect(result).to.equal(false)
			expect(unlocked).to.equal(false)
		end)

		it("does not throw when given invalid input", function()
			local success, result = pcall(function()
				return KeycardCopier.tryUnlock(nil, nil, nil)
			end)

			expect(success).to.equal(true)
			expect(result).to.equal(false)
		end)
	end)
end