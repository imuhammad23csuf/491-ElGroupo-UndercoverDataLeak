-- TimeLeaderboard.client.luau
-- Shows a top-right on-screen leaderboard of fastest mission times.
-- Press L to toggle open/closed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Wait for Remotes ────────────────────────────────────────────────────────
local Remotes       = ReplicatedStorage:WaitForChild("MissionTimerRemotes", 10)
local EvLeaderboard = Remotes:WaitForChild("LeaderboardUpdate")
local FnGetBestTime = Remotes:WaitForChild("GetMyBestTime")

-- ─── Constants ───────────────────────────────────────────────────────────────
local PANEL_WIDTH   = 260
local ROW_HEIGHT    = 36
local HEADER_HEIGHT = 48
local MAX_ROWS      = 10
local TOGGLE_KEY    = Enum.KeyCode.L

-- ─── Colors (matching suspicion meter dark style) ────────────────────────────
local COLOR_BG        = Color3.fromRGB(10, 10, 18)
local COLOR_HEADER    = Color3.fromRGB(20, 100, 200)
local COLOR_ROW_ODD   = Color3.fromRGB(14, 18, 36)
local COLOR_ROW_EVEN  = Color3.fromRGB(18, 24, 48)
local COLOR_TEXT      = Color3.fromRGB(220, 230, 255)
local COLOR_TIME      = Color3.fromRGB(80, 210, 255)
local COLOR_DIM       = Color3.fromRGB(100, 120, 160)
local COLOR_GOLD      = Color3.fromRGB(255, 210, 50)
local MEDAL           = {"🥇", "🥈", "🥉"}

-- ─── Build ScreenGui ─────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "TimeLeaderboardGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- Outer panel (slides in/out from the right)
local panel = Instance.new("Frame")
panel.Name              = "Panel"
panel.Size              = UDim2.new(0, PANEL_WIDTH, 0, HEADER_HEIGHT) -- grows with rows
panel.AnchorPoint       = Vector2.new(1, 0)
panel.Position          = UDim2.new(1, 16, 0, 80) -- 80px from top, starts off-screen (+16)
panel.BackgroundColor3  = COLOR_BG
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel   = 0
panel.ClipsDescendants  = true
panel.Parent            = screenGui

local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = COLOR_HEADER
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.4

-- Header
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = COLOR_HEADER
header.BorderSizePixel = 0
header.Parent          = panel

local headerCorner = Instance.new("UICorner", header)
headerCorner.CornerRadius = UDim.new(0, 12)

-- Fix header bottom corners
local headerFix = Instance.new("Frame")
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = COLOR_HEADER
headerFix.BorderSizePixel  = 0
headerFix.Parent           = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                 = UDim2.new(1, -12, 1, 0)
titleLabel.Position             = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font                 = Enum.Font.GothamBlack
titleLabel.TextSize             = 16
titleLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment       = Enum.TextXAlignment.Left
titleLabel.Text                 = "🏆  FASTEST TIMES"
titleLabel.Parent               = header

-- Toggle hint label (top-right of header)
local hintLabel = Instance.new("TextLabel")
hintLabel.Size                  = UDim2.new(0, 60, 1, 0)
hintLabel.Position              = UDim2.new(1, -64, 0, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font                  = Enum.Font.GothamMedium
hintLabel.TextSize              = 11
hintLabel.TextColor3            = Color3.fromRGB(200, 220, 255)
hintLabel.TextTransparency      = 0.3
hintLabel.Text                  = "[L]"
hintLabel.Parent                = header

-- Row container
local rowList = Instance.new("Frame")
rowList.Name                  = "RowList"
rowList.Size                  = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
rowList.Position              = UDim2.new(0, 0, 0, HEADER_HEIGHT)
rowList.BackgroundTransparency = 1
rowList.BorderSizePixel       = 0
rowList.Parent                = panel

local listLayout = Instance.new("UIListLayout", rowList)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 2)

local listPadding = Instance.new("UIPadding", rowList)
listPadding.PaddingLeft   = UDim.new(0, 6)
listPadding.PaddingRight  = UDim.new(0, 6)
listPadding.PaddingTop    = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)

-- Empty state label
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name                 = "EmptyLabel"
emptyLabel.Size                 = UDim2.new(1, 0, 0, ROW_HEIGHT)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font                 = Enum.Font.GothamMedium
emptyLabel.TextSize             = 13
emptyLabel.TextColor3           = COLOR_DIM
emptyLabel.Text                 = "No records yet — be the first!"
emptyLabel.LayoutOrder          = 999
emptyLabel.Parent               = rowList

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function formatTime(seconds: number): string
	local mins  = math.floor(seconds / 60)
	local secs  = math.floor(seconds % 60)
	local cents = math.floor((seconds % 1) * 100)
	return ("%02d:%02d.%02d"):format(mins, secs, cents)
end

local function updatePanelHeight(rowCount: number)
	local contentHeight = HEADER_HEIGHT
		+ 12 -- top+bottom padding
		+ math.max(1, rowCount) * ROW_HEIGHT
		+ math.max(0, rowCount - 1) * 2 -- gaps
	TweenService:Create(panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, PANEL_WIDTH, 0, contentHeight) }
	):Play()
end

local function makeRow(rank: number, name: string, timeStr: string, isMe: boolean)
	local row = Instance.new("Frame")
	row.Name             = "Row_" .. rank
	row.Size             = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = rank % 2 == 0 and COLOR_ROW_EVEN or COLOR_ROW_ODD
	row.BorderSizePixel  = 0
	row.LayoutOrder      = rank

	local rowCorner = Instance.new("UICorner", row)
	rowCorner.CornerRadius = UDim.new(0, 6)

	-- Highlight own row
	if isMe then
		local highlight = Instance.new("UIStroke", row)
		highlight.Color     = COLOR_TIME
		highlight.Thickness = 1
		highlight.Transparency = 0.4
	end

	-- Rank / medal
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Size                  = UDim2.new(0, 36, 1, 0)
	rankLabel.Position              = UDim2.new(0, 4, 0, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Font                  = Enum.Font.GothamBold
	rankLabel.TextSize              = 15
	rankLabel.TextColor3            = rank <= 3 and COLOR_GOLD or COLOR_DIM
	rankLabel.Text                  = MEDAL[rank] or ("#" .. rank)
	rankLabel.Parent                = row

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                  = UDim2.new(1, -120, 1, 0)
	nameLabel.Position              = UDim2.new(0, 42, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                  = isMe and Enum.Font.GothamBold or Enum.Font.GothamMedium
	nameLabel.TextSize              = 13
	nameLabel.TextColor3            = isMe and Color3.fromRGB(255, 255, 255) or COLOR_TEXT
	nameLabel.TextXAlignment        = Enum.TextXAlignment.Left
	nameLabel.TextTruncate          = Enum.TextTruncate.AtEnd
	nameLabel.Text                  = name .. (isMe and "  ◀" or "")
	nameLabel.Parent                = row

	-- Time
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size                  = UDim2.new(0, 74, 1, 0)
	timeLabel.Position              = UDim2.new(1, -76, 0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Font                  = Enum.Font.GothamBold
	timeLabel.TextSize              = 13
	timeLabel.TextColor3            = COLOR_TIME
	timeLabel.TextXAlignment        = Enum.TextXAlignment.Right
	timeLabel.Text                  = timeStr
	timeLabel.Parent                = row

	return row
end

-- ─── Populate ─────────────────────────────────────────────────────────────────
local function populateBoard(data: {{name: string, time: number}})
	-- Clear old rows
	for _, child in rowList:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	if #data == 0 then
		emptyLabel.Visible = true
		updatePanelHeight(0)
		return
	end

	emptyLabel.Visible = false
	for i, entry in ipairs(data) do
		local isMe = entry.name == player.Name
		local row  = makeRow(i, entry.name, formatTime(entry.time), isMe)
		row.Parent = rowList
	end
	updatePanelHeight(#data)
end

-- ─── Toggle logic ─────────────────────────────────────────────────────────────
local isOpen   = false
local OPEN_X   = UDim2.new(1, -10, 0, 80)  -- fully on screen
local CLOSED_X = UDim2.new(1, PANEL_WIDTH + 10, 0, 80) -- off-screen right

-- Start hidden (off-screen)
panel.Position = CLOSED_X

local function setOpen(open: boolean)
	isOpen = open
	TweenService:Create(panel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = open and OPEN_X or CLOSED_X }
	):Play()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		setOpen(not isOpen)
	end
end)

-- ─── Remote wiring ────────────────────────────────────────────────────────────
EvLeaderboard.OnClientEvent:Connect(function(data)
	populateBoard(data)
	-- If panel is open, data refreshes live
end)

-- Request initial data on join
task.spawn(function()
	-- Give server a moment to set up
	task.wait(2)
	-- Personal best fetch also triggers a leaderboard broadcast from the server
	FnGetBestTime:InvokeServer()
end)

-- ─── Tab hint (always visible, slides with panel) ────────────────────────────
-- Small collapsed tab sticking out even when panel is hidden
local tabHint = Instance.new("TextButton")
tabHint.Name              = "TabHint"
tabHint.Size              = UDim2.new(0, 28, 0, 72)
tabHint.AnchorPoint       = Vector2.new(1, 0)
tabHint.Position          = UDim2.new(1, 0, 0, 80)
tabHint.BackgroundColor3  = COLOR_HEADER
tabHint.BorderSizePixel   = 0
tabHint.Text              = ""
tabHint.Parent            = screenGui

local tabCorner = Instance.new("UICorner", tabHint)
tabCorner.CornerRadius = UDim.new(0, 6)

local tabIcon = Instance.new("TextLabel")
tabIcon.Size                 = UDim2.new(1, 0, 1, 0)
tabIcon.BackgroundTransparency = 1
tabIcon.Font                 = Enum.Font.GothamBlack
tabIcon.TextSize             = 12
tabIcon.TextColor3           = Color3.fromRGB(255, 255, 255)
tabIcon.Text                 = "🏆\nL"
tabIcon.Parent               = tabHint

tabHint.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

print("[TimeLeaderboard] Client leaderboard loaded. Press L to toggle.")
