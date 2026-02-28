--In Guard Script similar behavior but smarter

-- Guard Script
-- Implement a range for the AI to judge the distance between it and the player
-- Implement a way to tell guard the best time to chase the player
-- Implement a system telling the AI to chase for a certain interval of time up to 4 seconds
-- Roblox uses studs as a unit of measurement 1 stud = 1 foot
-- Implement the A* Algorithm using PathfindingService

PATROL_RETURNTIME = 4 -- Since we don't want the player to run far we set it to 4 seconds

CHASE_RANGE = 4 -- If player steps within 4 feet of NPC's patrol zone it can chase the player

MODEL = "GuardInside" -- The Model is called Guard Outside

FOV_TOTAL_DEGREES = 90

PATROL_SPEED = 16

CHASE_SPEED = 4.5

LOS_RANGE = 100


local PathfindingService = game:GetService("PathfindingService") -- Intialize Pathfinding Service

-- Added: path agent settings to reduce jitter/snaps by spacing waypoints out a bit
local PATH_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	WaypointSpacing = 6,
}

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

			humanoid.WalkSpeed = PATROL_SPEED

			-- Added: reduce physics correction snaps (ownership + limb collisions)
			local rootPart = rig:FindFirstChild("HumanoidRootPart", true) or rig.PrimaryPart
			if rootPart then
				rootPart:SetNetworkOwner(nil)
			end

			for _, part in ipairs(rig:GetDescendants()) do
				if part:IsA("BasePart") and part ~= rootPart then
					part.CanCollide = false
				end
			end

			-- Simple animation + animator setup (put your animation id below)
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end

			local walkAnim = Instance.new("Animation")
			walkAnim.AnimationId = "rbxassetid://913402848"

			local walkTrack = animator:LoadAnimation(walkAnim)
			walkTrack.Priority = Enum.AnimationPriority.Movement
			walkTrack.Looped = true
			-- Play/stop walk animation based on movement speed and adjust speed dynamically
			humanoid.Running:Connect(function(speed)
				if speed > 0.5 then
					if not walkTrack.IsPlaying then
						walkTrack:Play()
					end
					-- Adjust animation speed to match humanoid movement speed
					walkTrack:AdjustSpeed(speed / PATROL_SPEED)
				else
					if walkTrack.IsPlaying then
						walkTrack:Stop()
					end
				end
			end)

			local p1 = waypoints:FindFirstChild("P1", true)
			local p3 = waypoints:FindFirstChild("P3", true)
			local p2 = waypoints:FindFirstChild("P2", true)

			if not p1 then
				error("Waypoint 'P1' not found inside Waypoints folder.")
			end
			if not p3 then
				error("Waypoint 'P3' not found inside Waypoints folder.")
			end
			if not p2 then
				error ("No P2 found")
			end

			-- Utility: compute path and move along it; returns true if completed path, false if aborted/stuck
			local function moveToWithPath(targetPart)
				if not rootPart then
					rootPart = rig:FindFirstChild("HumanoidRootPart", true) or rig.PrimaryPart
					if not rootPart then
						return false
					end
				end

				if not walkTrack.IsPlaying then
					walkTrack:Play()
				end

				-- Always compute path for consistency (avoid long MoveTo stalls)
				local path = PathfindingService:CreatePath(PATH_PARAMS)
				path:ComputeAsync(rootPart.Position, targetPart.Position)
				if path.Status ~= Enum.PathStatus.Success then
					-- try a fallback MoveTo (short, non-blocking)
					humanoid:MoveTo(targetPart.Position)
					-- short wait and early return to avoid being stuck
					task.wait(1)
					return false
				end

				local waypoints = path:GetWaypoints()
				-- if no waypoints, fallback
				if #waypoints == 0 then
					humanoid:MoveTo(targetPart.Position)
					task.wait(1)
					return false
				end

				-- Iterate waypoints with a local stuck-timeout and distance-check (avoids MoveToFinished:Wait() pitfalls)
				for i, wp in ipairs(waypoints) do
					if not walkTrack.IsPlaying then
						walkTrack:Play()
					end

					-- Handle jump action
					if wp.Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end

					-- Start moving toward the waypoint
					humanoid:MoveTo(wp.Position)

					-- Wait until either we reach within a threshold OR timeout occurs
					local reached = false
					local startTime = tick()
					local timeout = 5 -- seconds per waypoint before we abort and recompute path
					local reachThreshold = 4 -- studs distance considered "reached"; generous to accommodate network
					while tick() - startTime < timeout do
						-- If rootPart becomes unavailable, abort
						if not rootPart or not rootPart.Parent then
							break
						end

						local dist = (rootPart.Position - wp.Position).Magnitude
						if dist <= reachThreshold then
							reached = true
							break
						end

						-- Small sleep to avoid tight loop
						task.wait(0.08)
					end

					if not reached then
						-- abort current path attempt so caller can decide (we'll return false -> outer loop can recalc)
						return false
					end
				end

				-- Successfully reached final waypoint
				return true
			end

			-- Patrol loop using robust path movement above
			while true do
				   -- Use the improved moveToWithPath (always computes path and times out gracefully)
				   moveToWithPath(p1)
				   task.wait(1)

				   moveToWithPath(p2)
				   task.wait(1.5)

				   moveToWithPath(p3)
				   task.wait(1)

				   moveToWithPath(p2)
				   task.wait(1.5)
			end

		end)
	end
end
-- Guard AI Summary:
-- NPC patrols between waypoints using MoveTo and A* pathfinding.
-- Animation starts instantly to avoid sliding.
-- Server network ownership and disabled limb collisions reduce jitter,
-- snapping, and micro-teleports during movement.
