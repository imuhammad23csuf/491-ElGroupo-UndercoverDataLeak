local PathfindingService = game:GetService("PathfindingService")
-- Guard Script
-- Implement a range for the AI to judge the distance between it and the player
-- Implement a system telling the AI to chase for a certain interval of time up to 4 seconds
-- Roblox uses studs as a unit of measurement 1 stud = 1 foot 
-- Implement the A* Algorithm using PathfindingService

PATROL_RETURNTIME = 4 -- Since we don't want the player to run far we set it to 4 seconds

CHASE_RANGE = 4 -- If player steps within 4 feet of NPC's patrol zone it can chase the player

MODEL = "OutsideGuard" -- The Model is called Outside Guard 

local PathfindingService = game:GetService(PathfindingService) -- Intialize Pathfinding Service




