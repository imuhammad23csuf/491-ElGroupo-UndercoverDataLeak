-- SuspicionController (client)
-- Thin client wrapper around the shared SuspicionManager.
-- The shared module handles all network sync (OnClientEvent / RequestSync)
-- when it is required, so no duplicate setup is needed here.
-- Exposes init() for init.client.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SuspicionManager = require(Shared:WaitForChild("SuspicionManager"))

local SuspicionController = {}

-- Re-export the read-only API so callers can use SuspicionController directly.
SuspicionController.Changed = SuspicionManager.Changed
SuspicionController.Get = SuspicionManager.Get
SuspicionController.GetSuspicion = SuspicionManager.GetSuspicion

-- Called by init.client.luau. The shared SuspicionManager already registers
-- the update listener and requests a sync when required, so no extra work
-- is needed here.
function SuspicionController.init()
-- Intentionally empty: SuspicionManager self-initialises on require.
end

return SuspicionController
