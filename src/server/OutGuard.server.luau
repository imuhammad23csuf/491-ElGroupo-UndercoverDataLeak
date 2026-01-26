-- Guard Script
-- Implement a range for the AI to judge the distance between it and the player
-- Implement a system telling the AI to chase for a certain interval of time up to 4 seconds
-- Roblox uses studs as a unit of measurement 1 stud = 1 foot
-- Implement the A* Algorithm using PathfindingService

PATROL_RETURNTIME = 4 -- Since we don't want the player to run far we set it to 4 seconds

CHASE_RANGE = 4 -- If player steps within 4 feet of NPC's patrol zone it can chase the player

MODEL = "GuardOutside" -- The Model is called Outside Guard 

FOV_TOTAL_DEGREES = 90 

LOS_RANGE = 100

local PathfindingService = game:GetService("PathfindingService") -- Intialize Pathfinding Service

-- FIX: get ALL guards, not just one
for _, rig in ipairs(game.Workspace:GetChildren()) do
	if rig:IsA("Model") and rig.Name == MODEL then

		task.spawn(function()

			local waypoints = rig:FindFirstChild("Waypoints", true)
			if not waypoints then
				error("Waypoints folder not found in the rig. Please create a folder named 'Waypoints' inside the rig Model and add Part objects for patrol points.")
			end

			local humanoid = rig:FindFirstChild("Humanoid", true)
			if not humanoid then
				error("Humanoid not found in the rig. Ensure the rig contains a Humanoid.")
			end

			local p1 = waypoints:FindFirstChild("P1", true)
			local p3 = waypoints:FindFirstChild("P3", true)

			if not p1 then
				error("Waypoint 'P1' not found inside Waypoints folder.")
			end
			if not p3 then
				error("Waypoint 'P3' not found inside Waypoints folder.")
			end

			while true do
				humanoid:MoveTo(p1.Position)
				humanoid.MoveToFinished:Wait()

				humanoid:MoveTo(p3.Position)
				humanoid.MoveToFinished:Wait()
			end

		end)
	end
end
