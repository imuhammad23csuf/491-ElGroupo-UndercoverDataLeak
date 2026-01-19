-- =========================================================
-- KEYCARD COPIER TOOL — SERVER (TODOs)
-- =========================================================

-- TODO: Receive copy request from client (no target data)
-- TODO: Validate the requesting player and character
-- TODO: Find the player's HumanoidRootPart (for position & direction)

-- TODO: Scan workspace DESCENDANTS for guard models
-- TODO: Filter only models with IsGuard == true
-- TODO: Reject player characters
-- TODO: Ensure guard has a valid Humanoid
-- TODO: Ensure guard is alive (Health > 0)

-- TODO: Determine a usable root part for the guard (R6-safe)
--       - Prefer Humanoid.RootPart
--       - Fallback to HumanoidRootPart
--       - Fallback to Torso
--       - Last resort: any BasePart descendant

-- TODO: Check distance between player and guard (range limit)
-- TODO: Optional: check if guard is in front of player (dot product)
-- TODO: Choose the BEST guard if multiple are valid
--       - Prefer closer
--       - Prefer more in front (optional)

-- TODO: Validate keycard data
--       - HasKeycard == true (Boolean)
--       - KeycardCode exists (String)

-- TODO: On success:
--       - Copy KeycardCode to PLAYER attributes
--       - Set success status attribute
--       - Print debug info (during development only)

-- TODO: On failure:
--       - Set appropriate failure status
--       - Do NOT modify guard data
--       - Do NOT error or crash

-- TODO: Ensure attributes are read from the LIVE guard instance
-- TODO: Ensure attributes are written to the Player, not the Tool

-- TODO: Keep logic server-authoritative
-- TODO: Remove debug prints before shipping


