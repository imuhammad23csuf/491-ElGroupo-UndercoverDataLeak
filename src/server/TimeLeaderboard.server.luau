-- TimeLeaderboard.server.luau
-- Populates a SurfaceGui leaderboard Part in the Workspace with the top
-- mission completion times. Updates whenever MissionTimer broadcasts new data.
--
-- SETUP: In Studio, create a Part named "TimerLeaderboard" in Workspace.
--        This script will attach a SurfaceGui to it automatically.
--        You can move/resize the Part to fit your map layout.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- ─── Wait for the leaderboard Part ───────────────────────────────────────────
local boardPart = workspace:WaitForChild("TimerLeaderboard", 30)
if not boardPart then
	warn("[TimeLeaderboard] 'TimerLeaderboard' Part not found in Workspace. " ..
		"Create a Part with that name to display the leaderboard.")
	return
end

-- ─── Wait for Remotes ────────────────────────────────────────────────────────
local Remotes       = ReplicatedStorage:WaitForChild("MissionTimerRemotes", 15)
local EvLeaderboard = Remotes:WaitForChild("LeaderboardUpdate")

-- ─── Build SurfaceGui ────────────────────────────────────────────────────────
local existing = boardPart:FindFirstChild("LeaderboardSurface")
if existing then existing:Destroy() end

local surfGui = Instance.new("SurfaceGui")
surfGui.Name          = "LeaderboardSurface"
surfGui.Face          = Enum.NormalId.Front
surfGui.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfGui.PixelsPerStud = 50
surfGui.AlwaysOnTop   = false
surfGui.Parent        = boardPart

-- Background
local bg = Instance.new("Frame")
bg.Size                   = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3       = Color3.fromRGB(6, 8, 18)
bg.BorderSizePixel        = 0
bg.Parent                 = surfGui

local bgCorner = Instance.new("UICorner", bg)
bgCorner.CornerRadius = UDim.new(0, 14)

-- Header bar
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = Color3.fromRGB(20, 100, 200)
header.BorderSizePixel  = 0
header.Parent           = bg

local headerCorner = Instance.new("UICorner", header)
headerCorner.CornerRadius = UDim.new(0, 14)
-- cover bottom corners of header
local headerFix = Instance.new("Frame")
headerFix.Size            = UDim2.new(1, 0, 0.5, 0)
headerFix.Position        = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(20, 100, 200)
headerFix.BorderSizePixel = 0
headerFix.Parent          = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                 = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font                 = Enum.Font.GothamBlack
titleLabel.TextSize             = 26
titleLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
titleLabel.Text                 = "🏆  FASTEST TIMES"
titleLabel.Parent               = header

-- Row container (scrolling list)
local listFrame = Instance.new("ScrollingFrame")
listFrame.Name                  = "RowList"
listFrame.Size                  = UDim2.new(1, -16, 1, -72)
listFrame.Position              = UDim2.new(0, 8, 0, 66)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel       = 0
listFrame.ScrollBarThickness    = 0
listFrame.CanvasSize            = UDim2.new(0, 0, 0, 0) -- updated dynamically
listFrame.AutomaticCanvasSize   = Enum.AutomaticSize.Y
listFrame.Parent                = bg

local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.SortOrder    = Enum.SortOrder.LayoutOrder
listLayout.Padding      = UDim.new(0, 4)

-- ─── Row builder ─────────────────────────────────────────────────────────────
local MEDAL = {"🥇", "🥈", "🥉"}
local ROW_HEIGHT = 44

local function makeRow(rank: number, name: string, timeStr: string)
	local row = Instance.new("Frame")
	row.Name              = "Row_" .. rank
	row.Size              = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3  = rank % 2 == 0
		and Color3.fromRGB(14, 18, 36)
		or  Color3.fromRGB(18, 24, 48)
	row.BorderSizePixel   = 0
	row.LayoutOrder       = rank

	local rowCorner = Instance.new("UICorner", row)
	rowCorner.CornerRadius = UDim.new(0, 8)

	-- Rank / medal
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Size                  = UDim2.new(0, 48, 1, 0)
	rankLabel.Position              = UDim2.new(0, 4, 0, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Font                  = Enum.Font.GothamBold
	rankLabel.TextSize              = 18
	rankLabel.TextColor3            = rank <= 3
		and Color3.fromRGB(255, 215, 0)
		or  Color3.fromRGB(140, 160, 200)
	rankLabel.Text = MEDAL[rank] or ("#" .. rank)
	rankLabel.Parent = row

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                  = UDim2.new(0.55, -60, 1, 0)
	nameLabel.Position              = UDim2.new(0, 56, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                  = Enum.Font.GothamMedium
	nameLabel.TextSize              = 16
	nameLabel.TextColor3            = Color3.fromRGB(220, 230, 255)
	nameLabel.TextXAlignment        = Enum.TextXAlignment.Left
	nameLabel.Text                  = name
	nameLabel.TextTruncate          = Enum.TextTruncate.AtEnd
	nameLabel.Parent                = row

	-- Time value (right-aligned)
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size                  = UDim2.new(0, 110, 1, 0)
	timeLabel.Position              = UDim2.new(1, -114, 0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Font                  = Enum.Font.GothamBold
	timeLabel.TextSize              = 17
	timeLabel.TextColor3            = Color3.fromRGB(80, 210, 255)
	timeLabel.TextXAlignment        = Enum.TextXAlignment.Right
	timeLabel.Text                  = timeStr
	timeLabel.Parent                = row

	return row
end

local function formatTime(seconds: number): string
	local mins  = math.floor(seconds / 60)
	local secs  = math.floor(seconds % 60)
	local cents = math.floor((seconds % 1) * 100)
	return ("%02d:%02d.%02d"):format(mins, secs, cents)
end

-- "No records yet" placeholder
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name                 = "EmptyLabel"
emptyLabel.Size                 = UDim2.new(1, 0, 0, 60)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font                 = Enum.Font.GothamMedium
emptyLabel.TextSize             = 16
emptyLabel.TextColor3           = Color3.fromRGB(100, 120, 160)
emptyLabel.Text                 = "No records yet — be the first!"
emptyLabel.Visible              = true
emptyLabel.Parent               = listFrame

-- ─── Populate function ───────────────────────────────────────────────────────
local function populateBoard(data: {{name: string, time: number}})
	-- Remove old rows (keep emptyLabel)
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	if #data == 0 then
		emptyLabel.Visible = true
		return
	end

	emptyLabel.Visible = false
	for i, entry in ipairs(data) do
		local row = makeRow(i, entry.name, formatTime(entry.time))
		row.Parent = listFrame
	end
end

-- ─── Event wiring ────────────────────────────────────────────────────────────
-- The leaderboard RemoteEvent fires from server to ALL clients,
-- but we handle the board population HERE on the server using a server-side
-- SurfaceGui (not inside a LocalScript) so it shows to everyone.
--
-- Because SurfaceGui is parented to a Workspace Part (not PlayerGui),
-- we use a BindableEvent to receive data from MissionTimer on the same server.

local BindableUpdate = Instance.new("BindableEvent")
BindableUpdate.Name = "LeaderboardDataReady"
BindableUpdate.Parent = script

-- MissionTimer calls this BindableEvent instead of (or in addition to)
-- the RemoteEvent. Wire it up by connecting here:
BindableUpdate.Event:Connect(function(data)
	populateBoard(data)
end)

-- Expose so MissionTimer.server.luau can fire it:
_G.LeaderboardBindable = BindableUpdate

-- Also refresh when any player joins (so the board is correct on spawn)
Players.PlayerAdded:Connect(function(_player)
	task.wait(3) -- let DataStore settle
	-- MissionTimer will broadcast; nothing extra needed here unless
	-- you want an immediate refresh. For that, call _G.MissionTimer from here.
end)

-- Initial empty state
populateBoard({})

print("[TimeLeaderboard] Leaderboard surface built on Part 'TimerLeaderboard'.")