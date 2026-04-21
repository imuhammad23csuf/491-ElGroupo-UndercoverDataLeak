local TabletMainUI = {}

function TabletMainUI.build(ctx)
local PlayerGui = ctx.PlayerGui
local UIS = ctx.UIS
local mk = ctx.mk
local round = ctx.round
local PROMPT = ctx.PROMPT
local addLine = ctx.addLine
local navigateTo = ctx.navigateTo
local pushHistory = ctx.pushHistory
local handle = ctx.handle
local setVisiblePanel = ctx.setVisiblePanel
local requestCameraJamFromTablet = ctx.requestCameraJamFromTablet
local requestGuardDistractFromTablet = ctx.requestGuardDistractFromTablet
local saveNow = ctx.saveNow
local startPacketCaptureForIP = ctx.startPacketCaptureForIP
local populatePacketRows = ctx.populatePacketRows
local renderAdminResults = ctx.renderAdminResults
local renderIPBlockerHistory = ctx.renderIPBlockerHistory
local showAdminDashboard = ctx.showAdminDashboard
local setBrowserStatus = ctx.setBrowserStatus
local submitScenarioAction = ctx.submitScenarioAction
local isToolEquipped = ctx.isToolEquipped
local getBrowserState = ctx.getBrowserState
local getHostByIP = ctx.getHostByIP
local ActivePacketCapture = ctx.ActivePacketCapture
local WANNAWAIL_ATTR_SOURCE_BLOCKED = ctx.WANNAWAIL_ATTR_SOURCE_BLOCKED
local WANNAWAIL_ATTACKER_IP = ctx.WANNAWAIL_ATTACKER_IP
local historyUp = ctx.historyUp
local historyDown = ctx.historyDown
local onTerminalTextChanged = ctx.onTerminalTextChanged

local function buildQuickLink(parent, text, url, _posX)
local b = mk("TextButton", {
Parent = parent,
Text = text,
Font = Enum.Font.GothamSemibold,
TextSize = 10,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(70, 96, 160),
AutomaticSize = Enum.AutomaticSize.X,
Size = UDim2.new(0, 0, 1, 0),
TextWrapped = false,
TextTruncate = Enum.TextTruncate.AtEnd,
})
mk("UIPadding", {
Parent = b,
PaddingLeft = UDim.new(0, 6),
PaddingRight = UDim.new(0, 6),
})
round(b, 8)
b.MouseButton1Click:Connect(function()
navigateTo(url)
end)
return b
end
local function buildMainUI()
local TermFrame, BrowserFrame, TermOut, TermInput, UrlBox, PageLabel, ClockLabel, MissionsFrame, MissionsList, ObjectivesList
local BrowserStatusLabel, BrowserContent, LinkBar
local AdminLoginPage, AdminDashboardPage, AdminUserBox, AdminPassBox, AdminLoginStatus, AdminSearchBox, AdminResultsFrame
local PacketPage, PacketToolbar, PacketListFrame, PacketIPBox, PacketDNSBox, PacketApplyBtn, PacketClearBtn, PacketFollowBtn
local gui = mk("ScreenGui", {
Parent = PlayerGui,
Name = "TabletGUI",
IgnoreGuiInset = true,
ResetOnSpawn = false,
Enabled = false,
DisplayOrder = 50,
})
local MainGUI = gui

-- Tablet body (outer shell / bezel)
-- Do not rotate the actual content container. A rotated GUI clipping chain
-- is what was letting terminal text and objective cards look like they were
-- spilling past the tablet bezel.
local tabletSize = UDim2.fromScale(UIS.TouchEnabled and 0.64 or 0.44, UIS.TouchEnabled and 0.70 or 0.53)
local tabletPosition = UDim2.fromScale(0.5, UIS.TouchEnabled and 0.52 or 0.54)

local tabletHolder = mk("Frame", {
	Parent = gui,
	Size = tabletSize,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = tabletPosition,
	BackgroundTransparency = 1,
})
tabletHolder.Rotation = 0

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 4 / 3
aspect.Parent = tabletHolder

local desktop = mk("Frame", {
	Parent = tabletHolder,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(15, 15, 20),
	BorderSizePixel = 0,
	ClipsDescendants = true,
})

round(desktop, 18)

-- Inner screen (actual UI goes here)
local screen = mk("Frame", {
	Parent = desktop,
	Size = UDim2.fromScale(0.94, 0.92),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 14, 22),
	ClipsDescendants = true,
})

round(screen, 14)

mk("UIGradient", {
	Parent = screen,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 34, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 10, 16)),
	}),
	Rotation = 120,
})

local top = mk("Frame", {
Parent = screen,
Size = UDim2.new(1, 0, 0, 50),
BackgroundColor3 = Color3.fromRGB(17, 22, 32),
BackgroundTransparency = 0.08,
ClipsDescendants = true,
})
local brandLabel = mk("TextLabel", {
Parent = top,
BackgroundTransparency = 1,
Text = "HackOS v1.4",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.fromRGB(220, 236, 255),
Position = UDim2.new(0, 10, 0, 0),
Size = UDim2.new(0, 110, 1, 0),
TextXAlignment = Enum.TextXAlignment.Left,
})
ClockLabel = mk("TextLabel", {
Parent = top,
BackgroundTransparency = 1,
Text = "--:--",
Font = Enum.Font.Code,
TextSize = 12,
TextColor3 = Color3.fromRGB(190, 208, 240),
Position = UDim2.new(1, -80, 0, 0),
Size = UDim2.new(0, 72, 1, 0),
TextXAlignment = Enum.TextXAlignment.Right,
})
local btnRow = mk("Frame", {
Parent = top,
BackgroundTransparency = 1,
Position = UDim2.new(0, 118, 0, 10),
Size = UDim2.new(1, -208, 0, 30),
})
local btnLayout = mk("UIListLayout", {
Parent = btnRow,
FillDirection = Enum.FillDirection.Horizontal,
HorizontalAlignment = Enum.HorizontalAlignment.Left,
VerticalAlignment = Enum.VerticalAlignment.Center,
Padding = UDim.new(0, 5),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local function button(fullText, compactText)
local b = mk("TextButton", {
Parent = btnRow,
Text = fullText,
Font = Enum.Font.GothamSemibold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(45, 57, 84),
AutomaticSize = Enum.AutomaticSize.X,
Size = UDim2.new(0, 0, 1, 0),
TextWrapped = false,
TextTruncate = Enum.TextTruncate.AtEnd,
})
local padding = mk("UIPadding", {
Parent = b,
PaddingLeft = UDim.new(0, 7),
PaddingRight = UDim.new(0, 7),
})
round(b, 8)
return {
button = b,
padding = padding,
fullText = fullText,
compactText = compactText,
}
end
local bTermData = button("💻", "💻")
local bBrowserData = button("🌐", "🌐")
local bMissionsData = button("🎯", "🎯")
local bJamData = button("📷", "📷")
local bSaveData = button("💾", "💾")
local bDistractData = button("🎭", "🎭")
local bTerm = bTermData.button
local bBrowser = bBrowserData.button
local bMissions = bMissionsData.button
local bJam = bJamData.button
local bSave = bSaveData.button
local bDistract = bDistractData.button
local topButtons = {
bTermData,
bBrowserData,
bMissionsData,
bJamData,
bSaveData,
bDistractData,
}
local pad = mk("Frame", {
Parent = screen,
Position = UDim2.new(0, 14, 0, 60),
Size = UDim2.new(1, -28, 1, -74),
BackgroundColor3 = Color3.fromRGB(15, 19, 28),
BackgroundTransparency = 0.1,
ClipsDescendants = true,
})
round(pad, 14)
TermFrame = mk("Frame", {
Parent = pad,
BackgroundColor3 = Color3.fromRGB(11, 14, 18),
Size = UDim2.new(0.52, -6, 1, -12),
Position = UDim2.new(0, 6, 0, 6),
ClipsDescendants = true,
})
BrowserFrame = mk("Frame", {
Parent = pad,
BackgroundColor3 = Color3.fromRGB(236, 238, 243),
Size = UDim2.new(0.48, -6, 1, -12),
Position = UDim2.new(0.52, 0, 0, 6),
Visible = false,
ClipsDescendants = true,
})
round(TermFrame, 12)
round(BrowserFrame, 12)
MissionsFrame = mk("Frame", {
Parent = pad,
BackgroundColor3 = Color3.fromRGB(15, 19, 28),
Size = UDim2.new(1, -12, 1, -12),
Position = UDim2.new(0, 6, 0, 6),
Visible = false,
ClipsDescendants = true,
})
round(MissionsFrame, 12)
local missionsScroll = mk("ScrollingFrame", {
Parent = MissionsFrame,
BackgroundTransparency = 1,
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 1, -20),
ScrollBarThickness = 6,
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollingDirection = Enum.ScrollingDirection.Y,
ElasticBehavior = Enum.ElasticBehavior.Never,
ClipsDescendants = true,
})
local missionsScrollPadding = mk("UIPadding", {
Parent = missionsScroll,
PaddingTop = UDim.new(0, 2),
PaddingBottom = UDim.new(0, 10),
})
local missionsScrollLayout = mk("UIListLayout", {
Parent = missionsScroll,
Name = "MissionScrollLayout",
Padding = UDim.new(0, 10),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local missionsHeader = mk("TextLabel", {
Parent = missionsScroll,
BackgroundTransparency = 1,
Text = "MISSIONS",
Font = Enum.Font.GothamBlack,
TextSize = 14,
TextColor3 = Color3.fromRGB(220, 236, 255),
Size = UDim2.new(1, -2, 0, 22),
TextXAlignment = Enum.TextXAlignment.Left,
LayoutOrder = 1,
})
MissionsList = mk("Frame", {
Parent = missionsScroll,
BackgroundColor3 = Color3.fromRGB(8, 10, 13),
BorderSizePixel = 0,
Size = UDim2.new(1, -2, 0, 1),
AutomaticSize = Enum.AutomaticSize.Y,
ClipsDescendants = true,
LayoutOrder = 2,
})
round(MissionsList, 10)
mk("UIPadding", {
Parent = MissionsList,
PaddingTop = UDim.new(0, 8),
PaddingBottom = UDim.new(0, 8),
PaddingLeft = UDim.new(0, 8),
PaddingRight = UDim.new(0, 8),
})
mk("UIListLayout", {
Parent = MissionsList,
Name = "UIListLayout",
Padding = UDim.new(0, 8),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local objectivesHeader = mk("TextLabel", {
Parent = missionsScroll,
BackgroundTransparency = 1,
Text = "OBJECTIVES",
Font = Enum.Font.GothamBlack,
TextSize = 14,
TextColor3 = Color3.fromRGB(220, 236, 255),
Size = UDim2.new(1, -2, 0, 22),
TextXAlignment = Enum.TextXAlignment.Left,
LayoutOrder = 3,
})
ObjectivesList = mk("Frame", {
Parent = missionsScroll,
BackgroundColor3 = Color3.fromRGB(8, 10, 13),
BorderSizePixel = 0,
Size = UDim2.new(1, -2, 0, 1),
AutomaticSize = Enum.AutomaticSize.Y,
ClipsDescendants = true,
LayoutOrder = 4,
})
round(ObjectivesList, 10)
mk("UIPadding", {
Parent = ObjectivesList,
PaddingTop = UDim.new(0, 8),
PaddingBottom = UDim.new(0, 8),
PaddingLeft = UDim.new(0, 8),
PaddingRight = UDim.new(0, 8),
})
mk("UIListLayout", {
Parent = ObjectivesList,
Name = "UIListLayout",
Padding = UDim.new(0, 8),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local function getViewportWidth()
local camera = workspace.CurrentCamera
if camera then
return camera.ViewportSize.X
end
return 1280
end
local function isCompactTopBar()
return UIS.TouchEnabled or getViewportWidth() <= 1100
end
local function applyTopBarLayout()
local compact = isCompactTopBar()
local topHeight = compact and 40 or 50
local brandWidth = compact and 74 or 110
local clockWidth = compact and 48 or 72
top.Size = UDim2.new(1, 0, 0, topHeight)
brandLabel.Text = compact and "HackOS" or "HackOS v1.4"
brandLabel.TextSize = compact and 10 or 13
brandLabel.Size = UDim2.new(0, brandWidth, 1, 0)
ClockLabel.TextSize = compact and 11 or 12
ClockLabel.Position = UDim2.new(1, -(clockWidth + 8), 0, 0)
ClockLabel.Size = UDim2.new(0, clockWidth, 1, 0)
btnRow.Position = UDim2.new(0, brandWidth + 8, 0, compact and 6 or 10)
btnRow.Size = UDim2.new(1, -(brandWidth + clockWidth + 24), 0, compact and 28 or 30)
btnLayout.Padding = UDim.new(0, compact and 4 or 5)
for _, spec in ipairs(topButtons) do
spec.button.Text = compact and spec.compactText or spec.fullText
spec.button.Font = compact and Enum.Font.SourceSansBold or Enum.Font.GothamSemibold
spec.button.TextSize = compact and 18 or 12
spec.padding.PaddingLeft = UDim.new(0, compact and 8 or 10)
spec.padding.PaddingRight = UDim.new(0, compact and 8 or 10)
end
pad.Position = UDim2.new(0, 14, 0, topHeight + 10)
pad.Size = UDim2.new(1, -28, 1, -(topHeight + 24))
end
local function applyMissionSectionsLayout()
local scroller = MissionsFrame and MissionsFrame:FindFirstChildWhichIsA("ScrollingFrame")
if not scroller then
return
end
scroller.Position = UDim2.new(0, 10, 0, 10)
scroller.Size = UDim2.new(1, -20, 1, -20)
task.defer(function()
local layout = scroller:FindFirstChild("MissionScrollLayout")
local paddingTop = missionsScrollPadding and missionsScrollPadding.PaddingTop.Offset or 0
local paddingBottom = missionsScrollPadding and missionsScrollPadding.PaddingBottom.Offset or 0
local contentHeight = (layout and layout.AbsoluteContentSize.Y or 0) + paddingTop + paddingBottom
scroller.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end)
end
task.defer(function()
applyTopBarLayout()
applyMissionSectionsLayout()
end)
local currentCamera = workspace.CurrentCamera
if currentCamera then
currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
applyTopBarLayout()
task.defer(applyMissionSectionsLayout)
end)
end
MissionsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
task.defer(applyMissionSectionsLayout)
end)
MissionsList:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(applyMissionSectionsLayout)
end)
ObjectivesList:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(applyMissionSectionsLayout)
end)
local terminalViewport = mk("Frame", {
Parent = TermFrame,
BackgroundColor3 = Color3.fromRGB(8, 10, 13),
BorderSizePixel = 0,
Size = UDim2.new(1, -16, 1, -78),
Position = UDim2.new(0, 8, 0, 8),
ClipsDescendants = true,
})
round(terminalViewport, 10)
TermOut = mk("ScrollingFrame", {
Parent = terminalViewport,
BackgroundTransparency = 1,
BorderSizePixel = 0,
ScrollBarThickness = 6,
AutomaticCanvasSize = Enum.AutomaticSize.None,
CanvasSize = UDim2.new(0, 0, 0, 0),
ScrollingEnabled = true,
ScrollingDirection = Enum.ScrollingDirection.Y,
ElasticBehavior = Enum.ElasticBehavior.Never,
Size = UDim2.new(1, 0, 1, 0),
Position = UDim2.new(0, 0, 0, 0),
ClipsDescendants = true,
})
mk("UIPadding", {
Parent = TermOut,
PaddingTop = UDim.new(0, 6),
PaddingBottom = UDim.new(0, 6),
PaddingLeft = UDim.new(0, 6),
PaddingRight = UDim.new(0, 6),
})
mk("UIListLayout", {
Parent = TermOut,
Name = "UIListLayout",
Padding = UDim.new(0, 4),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local h = UIS.TouchEnabled and 40 or 32
TermInput = mk("TextBox", {
Parent = TermFrame,
Text = "",
ClearTextOnFocus = false,
PlaceholderText = "Type command... (Up/Down for history)",
Font = Enum.Font.Code,
TextSize = 13,
TextColor3 = Color3.fromRGB(172, 255, 198),
BackgroundColor3 = Color3.fromRGB(8, 10, 13),
BorderSizePixel = 0,
Size = UDim2.new(1, -(UIS.TouchEnabled and 112 or 16), 0, h),
Position = UDim2.new(0, 8, 1, -(8 + h)),
})
round(TermInput, 9)
if UIS.TouchEnabled then
local run = mk("TextButton", {
Parent = TermFrame,
Text = "Run",
Font = Enum.Font.GothamSemibold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(72, 126, 255),
Size = UDim2.fromOffset(90, h),
Position = UDim2.new(1, -98, 1, -(8 + h)),
})
round(run, 9)
run.MouseButton1Click:Connect(function()
local c = TermInput.Text
TermInput.Text = ""
pushHistory(c)
handle(c)
task.defer(function()
if TermInput and TermInput.Parent and TermFrame.Visible then
TermInput:CaptureFocus()
end
end)
end)
end
UrlBox = mk("TextBox", {
Parent = BrowserFrame,
Text = "",
PlaceholderText = "home (or type a URL)",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(223, 227, 236),
Size = UDim2.new(1, -88, 0, 32),
Position = UDim2.new(0, 8, 0, 8),
})
round(UrlBox, 8)
local goBtn = mk("TextButton", {
Parent = BrowserFrame,
Text = "GO",
Font = Enum.Font.GothamSemibold,
TextSize = 14,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(79, 131, 255),
Size = UDim2.fromOffset(64, 32),
Position = UDim2.new(1, -72, 0, 8),
})
round(goBtn, 8)
BrowserStatusLabel = mk("TextLabel", {
Parent = BrowserFrame,
BackgroundTransparency = 1,
Text = "",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(70, 82, 100),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 8, 0, 42),
Size = UDim2.new(1, -16, 0, 18),
})
LinkBar = mk("Frame", {
Parent = BrowserFrame,
BackgroundTransparency = 1,
Position = UDim2.new(0, 8, 0, 62),
Size = UDim2.new(1, -16, 0, 24),
})
mk("UIListLayout", {
Parent = LinkBar,
FillDirection = Enum.FillDirection.Horizontal,
HorizontalAlignment = Enum.HorizontalAlignment.Left,
VerticalAlignment = Enum.VerticalAlignment.Center,
Padding = UDim.new(0, 5),
SortOrder = Enum.SortOrder.LayoutOrder,
})
buildQuickLink(LinkBar, "🏠 Home", "hackos://home", 0)
buildQuickLink(LinkBar, "📡 PacketNet", "rbxpacketnet.com", 118)
buildQuickLink(LinkBar, "🔐 Admin", "bloxplay.com/admin", 236)
buildQuickLink(LinkBar, "🛡 Block", "rbxipblocker.com", 354)
BrowserContent = mk("Frame", {
Parent = BrowserFrame,
BackgroundColor3 = Color3.fromRGB(250, 251, 253),
BorderSizePixel = 0,
Position = UDim2.new(0, 8, 0, 92),
Size = UDim2.new(1, -16, 1, -100),
})
round(BrowserContent, 10)
PageLabel = mk("TextLabel", {
Parent = BrowserContent,
BackgroundTransparency = 1,
TextWrapped = true,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.new(0, 0, 0),
Text = "",
Size = UDim2.new(1, -16, 1, -16),
Position = UDim2.new(0, 8, 0, 8),
Visible = true,
})
AdminLoginPage = mk("Frame", {
Parent = BrowserContent,
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = AdminLoginPage,
BackgroundTransparency = 1,
Text = "BLOXPLAY ADMIN",
Font = Enum.Font.GothamBlack,
TextSize = 16,
TextColor3 = Color3.fromRGB(28, 36, 52),
Size = UDim2.new(1, 0, 0, 24),
Position = UDim2.new(0, 0, 0, 10),
})
mk("TextLabel", {
Parent = AdminLoginPage,
BackgroundTransparency = 1,
Text = "Authorized Personnel Login (SIM)",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(90, 100, 118),
Size = UDim2.new(1, 0, 0, 16),
Position = UDim2.new(0, 0, 0, 36),
})
AdminUserBox = mk("TextBox", {
Parent = AdminLoginPage,
Text = "",
PlaceholderText = "username",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Size = UDim2.new(0.8, 0, 0, 30),
Position = UDim2.new(0.1, 0, 0, 60),
})
round(AdminUserBox, 8)
AdminPassBox = mk("TextBox", {
Parent = AdminLoginPage,
Text = "",
PlaceholderText = "password",
Font = Enum.Font.Gotham,
TextSize = 13,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Size = UDim2.new(0.8, 0, 0, 30),
Position = UDim2.new(0.1, 0, 0, 98),
ClearTextOnFocus = false,
MultiLine = false,
TextEditable = true,
})
round(AdminPassBox, 8)
AdminPassBox:SetAttribute("RealPassword", "")
local adminPassMasking = false
AdminPassBox:GetPropertyChangedSignal("Text"):Connect(function()
if adminPassMasking then return end
local real = tostring(AdminPassBox:GetAttribute("RealPassword") or "")
local shown = tostring(AdminPassBox.Text or "")
if shown == real then
real = shown
elseif shown ~= string.rep("*", #real) then
if #shown > #real then
local added = shown:sub(#real + 1)
real = real .. added
elseif #shown < #real then
real = real:sub(1, #shown)
end
end
AdminPassBox:SetAttribute("RealPassword", real)
adminPassMasking = true
local masked = string.rep("*", #real)
if AdminPassBox.Text ~= masked then
AdminPassBox.Text = masked
end
AdminPassBox.CursorPosition = #masked + 1
adminPassMasking = false
end)
local adminLoginBtn = mk("TextButton", {
Parent = AdminLoginPage,
Text = "LOGIN",
Font = Enum.Font.GothamBold,
TextSize = 13,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(76, 123, 255),
Size = UDim2.new(0.4, 0, 0, 30),
Position = UDim2.new(0.3, 0, 0, 136),
})
round(adminLoginBtn, 8)
AdminLoginStatus = mk("TextLabel", {
Parent = AdminLoginPage,
BackgroundTransparency = 1,
Text = "",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(90, 100, 118),
Size = UDim2.new(1, -20, 0, 18),
Position = UDim2.new(0, 10, 0, 174),
})
mk("TextLabel", {
Parent = AdminLoginPage,
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Use the physical office note for credentials.",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(97, 108, 126),
Size = UDim2.new(1, -20, 0, 30),
Position = UDim2.new(0, 10, 0, 194),
})
AdminDashboardPage = mk("Frame", {
Parent = BrowserContent,
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = AdminDashboardPage,
BackgroundTransparency = 1,
Text = "BLOXPLAY ADMIN DATABASE",
Font = Enum.Font.GothamBlack,
TextSize = 14,
TextColor3 = Color3.fromRGB(28, 36, 52),
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 20),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = AdminDashboardPage,
BackgroundTransparency = 1,
Text = "Database records and live incident logging",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(90, 100, 118),
Position = UDim2.new(0, 10, 0, 28),
Size = UDim2.new(1, -20, 0, 14),
TextXAlignment = Enum.TextXAlignment.Left,
})
local adminDatabaseTabBtn = mk("TextButton", {
Parent = AdminDashboardPage,
Name = "AdminDatabaseTabBtn",
Text = "DB",
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(76, 123, 255),
Position = UDim2.new(0, 10, 0, 48),
Size = UDim2.new(0, 80, 0, 24),
})
round(adminDatabaseTabBtn, 8)
local adminLogsTabBtn = mk("TextButton", {
Parent = AdminDashboardPage,
Name = "AdminLogsTabBtn",
Text = "Logs",
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(100, 110, 132),
Position = UDim2.new(0, 96, 0, 48),
Size = UDim2.new(0, 96, 0, 24),
})
round(adminLogsTabBtn, 8)
AdminSearchBox = mk("TextBox", {
Parent = AdminDashboardPage,
Text = "",
PlaceholderText = "Search staff or player data...",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 78),
Size = UDim2.new(1, -20, 0, 28),
})
round(AdminSearchBox, 8)
AdminResultsFrame = mk("ScrollingFrame", {
Parent = AdminDashboardPage,
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 112),
Size = UDim2.new(1, -20, 1, -120),
})
round(AdminResultsFrame, 8)
mk("UIListLayout", {
Parent = AdminResultsFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local adminLogsFrame = mk("ScrollingFrame", {
Parent = AdminDashboardPage,
Name = "AdminLogsFrame",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 78),
Size = UDim2.new(1, -20, 1, -86),
Visible = false,
})
round(adminLogsFrame, 8)
mk("UIListLayout", {
Parent = adminLogsFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
PacketPage = mk("Frame", {
Parent = BrowserContent,
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = PacketPage,
BackgroundTransparency = 1,
Text = "RBXPacketNet",
Font = Enum.Font.GothamBlack,
TextSize = 16,
TextColor3 = Color3.fromRGB(30, 40, 58),
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 22),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = PacketPage,
BackgroundTransparency = 1,
Text = "Targeted Packet Capture (SIM)",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(88, 98, 114),
Position = UDim2.new(0, 10, 0, 30),
Size = UDim2.new(1, -20, 0, 16),
TextXAlignment = Enum.TextXAlignment.Left,
})
PacketToolbar = mk("Frame", {
Parent = PacketPage,
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 52),
Size = UDim2.new(1, -20, 0, 38),
})
round(PacketToolbar, 8)
PacketIPBox = mk("TextBox", {
Parent = PacketToolbar,
Text = "",
PlaceholderText = "Target IP",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
Position = UDim2.new(0, 6, 0, 5),
Size = UDim2.new(0.32, -4, 0, 28),
})
round(PacketIPBox, 8)
PacketDNSBox = mk("TextBox", {
Parent = PacketToolbar,
Text = "",
PlaceholderText = "DNS/Server filter",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
Position = UDim2.new(0.32, 4, 0, 5),
Size = UDim2.new(0.24, -4, 0, 28),
})
round(PacketDNSBox, 8)
PacketApplyBtn = mk("TextButton", {
Parent = PacketToolbar,
Text = "CAP",
Font = Enum.Font.GothamSemibold,
TextSize = 10,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(79, 131, 255),
Position = UDim2.new(0.56, 4, 0, 5),
Size = UDim2.new(0.16, -2, 0, 28),
})
round(PacketApplyBtn, 8)
PacketClearBtn = mk("TextButton", {
Parent = PacketToolbar,
Text = "CLR",
Font = Enum.Font.GothamSemibold,
TextSize = 10,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(110, 120, 145),
Position = UDim2.new(0.72, 4, 0, 5),
Size = UDim2.new(0.14, -2, 0, 28),
})
round(PacketClearBtn, 8)
PacketFollowBtn = mk("TextButton", {
Parent = PacketToolbar,
Text = "FOL",
Font = Enum.Font.GothamSemibold,
TextSize = 10,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(76, 168, 110),
Position = UDim2.new(0.86, 4, 0, 5),
Size = UDim2.new(0.14, -10, 0, 28),
})
round(PacketFollowBtn, 8)
PacketListFrame = mk("ScrollingFrame", {
Parent = PacketPage,
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 96),
Size = UDim2.new(1, -20, 1, -104),
})
round(PacketListFrame, 8)
mk("UIListLayout", {
Parent = PacketListFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
local mailPage = mk("Frame", {
Parent = BrowserContent,
Name = "MailPage",
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = mailPage,
BackgroundTransparency = 1,
Text = "BloxMail - Staff Inbox Queue",
Font = Enum.Font.GothamBold,
TextSize = 14,
TextColor3 = Color3.fromRGB(24, 30, 38),
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 18),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = mailPage,
Name = "MailInboxSummary",
BackgroundTransparency = 1,
TextWrapped = true,
Text = "Open messages from the left inbox queue, then classify each one before the incident escalates.",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(88, 98, 114),
Position = UDim2.new(0, 10, 0, 28),
Size = UDim2.new(1, -20, 0, 20),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
})
mk("ScrollingFrame", {
Parent = mailPage,
Name = "MailInboxList",
BackgroundColor3 = Color3.fromRGB(239, 243, 248),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 54),
Size = UDim2.new(0.44, -16, 1, -62),
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollBarThickness = 6,
ScrollBarImageColor3 = Color3.fromRGB(152, 160, 173),
})
round(mailPage:FindFirstChild("MailInboxList"), 10)
mk("UIListLayout", {
Parent = mailPage.MailInboxList,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
mk("ScrollingFrame", {
Parent = mailPage,
Name = "MailDetailCard",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ClipsDescendants = true,
Position = UDim2.new(0.44, -2, 0, 54),
Size = UDim2.new(0.56, -8, 1, -62),
CanvasSize = UDim2.new(0, 0, 0, 0),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollBarThickness = 5,
ScrollBarImageColor3 = Color3.fromRGB(152, 160, 173),
ScrollingDirection = Enum.ScrollingDirection.Y,
})
round(mailPage:FindFirstChild("MailDetailCard"), 10)
mk("UIPadding", {
Parent = mailPage.MailDetailCard,
PaddingBottom = UDim.new(0, 10),
PaddingLeft = UDim.new(0, 10),
PaddingRight = UDim.new(0, 10),
PaddingTop = UDim.new(0, 10),
})
mk("UIListLayout", {
Parent = mailPage.MailDetailCard,
Name = "UIListLayout",
Padding = UDim.new(0, 8),
SortOrder = Enum.SortOrder.LayoutOrder,
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailSender",
BackgroundTransparency = 1,
TextWrapped = true,
AutomaticSize = Enum.AutomaticSize.Y,
Text = "FROM:",
Font = Enum.Font.Code,
TextSize = 11,
TextColor3 = Color3.fromRGB(55, 64, 80),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, -6, 0, 0),
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailSubject",
BackgroundTransparency = 1,
TextWrapped = true,
AutomaticSize = Enum.AutomaticSize.Y,
Text = "SUBJECT:",
Font = Enum.Font.GothamBold,
TextSize = 12,
TextColor3 = Color3.fromRGB(25, 30, 38),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, -6, 0, 0),
})
mk("Frame", {
Parent = mailPage.MailDetailCard,
Name = "MailDetailBodyFrame",
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
AutomaticSize = Enum.AutomaticSize.Y,
ClipsDescendants = true,
Size = UDim2.new(1, -6, 0, 0),
})
round(mailPage.MailDetailCard.MailDetailBodyFrame, 8)
mk("UIPadding", {
Parent = mailPage.MailDetailCard.MailDetailBodyFrame,
PaddingBottom = UDim.new(0, 8),
PaddingLeft = UDim.new(0, 8),
PaddingRight = UDim.new(0, 8),
PaddingTop = UDim.new(0, 8),
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard.MailDetailBodyFrame,
Name = "MailDetailBody",
BackgroundTransparency = 1,
AutomaticSize = Enum.AutomaticSize.Y,
TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Text = "Select a message from the inbox to inspect it.",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.fromRGB(48, 56, 70),
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, 0, 0, 0),
})
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailStatusLabel",
BackgroundTransparency = 1,
TextWrapped = true,
AutomaticSize = Enum.AutomaticSize.Y,
Text = "Review the selected message before deciding whether it should be reported.",
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.fromRGB(176, 92, 42),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, -6, 0, 0),
})
mk("Frame", {
Parent = mailPage.MailDetailCard,
Name = "MailActionRow",
BackgroundTransparency = 1,
Size = UDim2.new(1, -6, 0, 26),
})
mk("TextButton", {
Parent = mailPage.MailDetailCard.MailActionRow,
Name = "MailReportButton",
BackgroundColor3 = Color3.fromRGB(184, 61, 61),
BorderSizePixel = 0,
Text = "Report",
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(0, 0, 0, 0),
Size = UDim2.new(0.42, -6, 1, 0),
AutoButtonColor = true,
})
round(mailPage.MailDetailCard.MailActionRow.MailReportButton, 8)
mk("TextButton", {
Parent = mailPage.MailDetailCard.MailActionRow,
Name = "MailPassButton",
BackgroundColor3 = Color3.fromRGB(63, 142, 96),
BorderSizePixel = 0,
Text = "Pass Through",
Font = Enum.Font.GothamBold,
TextSize = 11,
TextColor3 = Color3.new(1, 1, 1),
Position = UDim2.new(0.42, 6, 0, 0),
Size = UDim2.new(0.58, -6, 1, 0),
AutoButtonColor = true,
})
round(mailPage.MailDetailCard.MailActionRow.MailPassButton, 8)
mk("TextLabel", {
Parent = mailPage.MailDetailCard,
Name = "MailActionHintLabel",
BackgroundTransparency = 1,
TextWrapped = true,
AutomaticSize = Enum.AutomaticSize.Y,
Text = "Report phishing mail. Pass Through legitimate internal mail.",
Font = Enum.Font.Gotham,
TextSize = 10,
TextColor3 = Color3.fromRGB(92, 100, 114),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, -6, 0, 0),
})
local mailReportButton = mailPage.MailDetailCard:FindFirstChild("MailReportButton", true)
if mailReportButton then
mailReportButton.MouseButton1Click:Connect(function()
if getBrowserState()._classifySelectedMail then
getBrowserState()._classifySelectedMail("report")
end
end)
end
local mailPassButton = mailPage.MailDetailCard:FindFirstChild("MailPassButton", true)
if mailPassButton then
mailPassButton.MouseButton1Click:Connect(function()
if getBrowserState()._classifySelectedMail then
getBrowserState()._classifySelectedMail("pass")
end
end)
end
local ipBlockerPage = mk("Frame", {
Parent = BrowserContent,
Name = "IPBlockerPage",
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
})
mk("TextLabel", {
Parent = ipBlockerPage,
BackgroundTransparency = 1,
Text = "RBXIPBlocker",
Font = Enum.Font.GothamBlack,
TextSize = 16,
TextColor3 = Color3.fromRGB(30, 40, 58),
Position = UDim2.new(0, 10, 0, 8),
Size = UDim2.new(1, -20, 0, 22),
TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
Parent = ipBlockerPage,
BackgroundTransparency = 1,
Text = "Emergency hostile source blocking console (SIM)",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(88, 98, 114),
Position = UDim2.new(0, 10, 0, 30),
Size = UDim2.new(1, -20, 0, 16),
TextXAlignment = Enum.TextXAlignment.Left,
})
local ipBlockerToolbar = mk("Frame", {
Parent = ipBlockerPage,
BackgroundColor3 = Color3.fromRGB(233, 237, 244),
BorderSizePixel = 0,
Position = UDim2.new(0, 10, 0, 52),
Size = UDim2.new(1, -20, 0, 40),
})
round(ipBlockerToolbar, 8)
local ipBlockerInputBox = mk("TextBox", {
Parent = ipBlockerToolbar,
Name = "IPBlockerInputBox",
Text = "",
PlaceholderText = "Enter source IP to block",
Font = Enum.Font.Gotham,
TextSize = 12,
TextColor3 = Color3.new(0, 0, 0),
BackgroundColor3 = Color3.fromRGB(248, 250, 253),
BorderSizePixel = 0,
Position = UDim2.new(0, 6, 0, 6),
Size = UDim2.new(1, -110, 0, 28),
})
round(ipBlockerInputBox, 8)
local ipBlockerBlockBtn = mk("TextButton", {
Parent = ipBlockerToolbar,
Name = "IPBlockerBlockBtn",
Text = "Block",
Font = Enum.Font.GothamBold,
TextSize = 12,
TextColor3 = Color3.new(1, 1, 1),
BackgroundColor3 = Color3.fromRGB(188, 62, 62),
Position = UDim2.new(1, -100, 0, 6),
Size = UDim2.new(0, 92, 0, 28),
})
round(ipBlockerBlockBtn, 8)
local ipBlockerStatus = mk("TextLabel", {
Parent = ipBlockerPage,
Name = "IPBlockerStatus",
BackgroundTransparency = 1,
Text = "Enter a hostile source from the investigation feed.",
Font = Enum.Font.Gotham,
TextSize = 11,
TextColor3 = Color3.fromRGB(88, 98, 114),
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.new(0, 10, 0, 98),
Size = UDim2.new(1, -20, 0, 16),
})
local ipBlockerHistoryFrame = mk("ScrollingFrame", {
Parent = ipBlockerPage,
Name = "IPBlockerHistoryFrame",
BackgroundColor3 = Color3.fromRGB(238, 242, 248),
BorderSizePixel = 0,
ScrollBarThickness = 6,
Position = UDim2.new(0, 10, 0, 120),
Size = UDim2.new(1, -20, 1, -128),
})
round(ipBlockerHistoryFrame, 8)
mk("UIListLayout", {
Parent = ipBlockerHistoryFrame,
Name = "UIListLayout",
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
})
goBtn.MouseButton1Click:Connect(function()
navigateTo(UrlBox.Text)
end)
local function tryAdminLogin()
local u = tostring((AdminUserBox.Text or ""):lower())
local p = tostring(AdminPassBox:GetAttribute("RealPassword") or "")
if u == "bloxplay-admin" and p == "blox123" then
local result = submitScenarioAction("browser_admin_login bloxplay.com/admin", { "ch2_admin_login" })
getBrowserState().adminLoggedIn = true
getBrowserState().adminTab = "database"
AdminLoginStatus.Text = "Login successful (sim)"
AdminPassBox.Text = ""
AdminPassBox:SetAttribute("RealPassword", "")
navigateTo("bloxplay.com/admin")
if result and result.success then
setBrowserStatus("Admin login accepted. Mission step complete.")
end
else
AdminLoginStatus.Text = "Access denied (sim)"
AdminPassBox.Text = ""
AdminPassBox:SetAttribute("RealPassword", "")
end
end
adminLoginBtn.MouseButton1Click:Connect(tryAdminLogin)
adminDatabaseTabBtn.MouseButton1Click:Connect(function()
getBrowserState().adminTab = "database"
showAdminDashboard("bloxplay.com/admin")
setBrowserStatus("Database records open (sim).")
end)
adminLogsTabBtn.MouseButton1Click:Connect(function()
local result = submitScenarioAction("browser_admin_tab logs", { "ch3_admin_logs" })
getBrowserState().adminTab = "logs"
getBrowserState().logsLastRender = 0
showAdminDashboard("bloxplay.com/admin")
if result and result.success then
setBrowserStatus("Security logs opened. Mission step complete.")
else
setBrowserStatus("Security logs open (live feed).")
end
end)
AdminSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
if getBrowserState().adminTab ~= "logs" then
renderAdminResults(AdminSearchBox.Text)
end
end)
ipBlockerBlockBtn.MouseButton1Click:Connect(function()
local ip = tostring(ipBlockerInputBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
if ip == "" then
ipBlockerStatus.Text = "Enter a hostile source first."
setBrowserStatus("RBXIPBlocker needs a source IP.")
return
end
local alreadyBlocked = false
if type(getBrowserState().blockedIPs) ~= "table" then
getBrowserState().blockedIPs = {}
end
for _, existing in ipairs(getBrowserState().blockedIPs) do
if existing == ip then
alreadyBlocked = true
break
end
end
if not alreadyBlocked then
table.insert(getBrowserState().blockedIPs, ip)
table.sort(getBrowserState().blockedIPs)
end
renderIPBlockerHistory()
local result = submitScenarioAction(("browser_ipblocker_block %s"):format(ip), { "ch4_block_source" })
ipBlockerInputBox.Text = ""
ipBlockerStatus.Text = alreadyBlocked and ("Source %s was already blocked."):format(ip) or (("Source %s blocked (sim)."):format(ip))
if result and result.success then
if ip == WANNAWAIL_ATTACKER_IP then
if getBrowserState()._markWannaWailFlag then
		getBrowserState()._markWannaWailFlag(WANNAWAIL_ATTR_SOURCE_BLOCKED, true)
	end
end
setBrowserStatus(("RBXIPBlocker blocked %s. Mission step complete."):format(ip))
else
setBrowserStatus(("RBXIPBlocker blocked %s (sim)"):format(ip))
end
end)
PacketApplyBtn.MouseButton1Click:Connect(function()
local ip = tostring(PacketIPBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
local result = submitScenarioAction(("browser_capture %s"):format(ip ~= "" and ip or "unknown"), { "ch1_packets" })
if startPacketCaptureForIP(ip) then
populatePacketRows()
local host = getHostByIP(ip)
if result and result.success then
setBrowserStatus(("Capture verified for %s [%s]. Mission step complete."):format(host.label, host.ip))
else
setBrowserStatus(("Capturing packets for %s [%s] (sim)"):format(host.label, host.ip))
end
else
populatePacketRows()
setBrowserStatus("Unknown IP. No simulated capture available.")
end
end)
PacketClearBtn.MouseButton1Click:Connect(function()
if PacketIPBox then PacketIPBox.Text = "" end
if PacketDNSBox then PacketDNSBox.Text = "" end
ActivePacketCapture.targetIP = ""
ActivePacketCapture.targetLabel = ""
ActivePacketCapture.rows = {}
populatePacketRows()
setBrowserStatus("RBXPacketNet filters cleared (sim)")
end)
PacketFollowBtn.MouseButton1Click:Connect(function()
if PacketIPBox.Text == "" then
PacketIPBox.Text = "192.168.32.12"
end
startPacketCaptureForIP(PacketIPBox.Text)
if PacketDNSBox.Text == "" then
PacketDNSBox.Text = "admin"
end
populatePacketRows()
setBrowserStatus("Following simulated traffic stream.")
end)
UIS.InputBegan:Connect(function(input, gameProcessed)
	if MainGUI and MainGUI.Enabled then
		getBrowserState()._markInteraction()
	end
if gameProcessed then return end
if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
if input.KeyCode == Enum.KeyCode.Up then
local focused = nil
pcall(function() focused = UIS:GetFocusedTextBox() end)
if focused == TermInput then
historyUp()
end
return
elseif input.KeyCode == Enum.KeyCode.Down then
local focused = nil
pcall(function() focused = UIS:GetFocusedTextBox() end)
if focused == TermInput then
historyDown()
end
return
end
if input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.KeypadEnter then
return
end
local focused = nil
pcall(function() focused = UIS:GetFocusedTextBox() end)
if focused == UrlBox then
navigateTo(UrlBox.Text)
elseif focused == AdminPassBox or focused == AdminUserBox then
if AdminLoginPage and AdminLoginPage.Visible then
tryAdminLogin()
end
elseif focused == PacketIPBox or focused == PacketDNSBox then
if PacketPage and PacketPage.Visible then
if PacketIPBox.Text ~= "" then
startPacketCaptureForIP(PacketIPBox.Text)
end
populatePacketRows()
end
end
end)
UrlBox.FocusLost:Connect(function(enterPressed)
	if MainGUI and MainGUI.Enabled then
		getBrowserState()._markInteraction()
	end
if enterPressed then
navigateTo(UrlBox.Text)
end
end)
local function canRefocusTerminal()
if not (MainGUI and MainGUI.Enabled) then return false end
if not (TermFrame and TermFrame.Visible) then return false end
if not (TermInput and TermInput.Parent) then return false end
if not (isToolEquipped() and ctx.isStarted()) then return false end
local focused = nil
pcall(function() focused = UIS:GetFocusedTextBox() end)
return focused == nil or focused == TermInput
end
TermInput:GetPropertyChangedSignal("Text"):Connect(function()
if onTerminalTextChanged then
onTerminalTextChanged(TermInput.Text)
end
end)
TermInput.FocusLost:Connect(function(enter)
	if MainGUI and MainGUI.Enabled then
		getBrowserState()._markInteraction()
	end
if enter then
local c = TermInput.Text
TermInput.Text = ""
pushHistory(c)
handle(c)
end
task.defer(function()
if canRefocusTerminal() then
TermInput:CaptureFocus()
end
end)
end)
bTerm.MouseButton1Click:Connect(function()
setVisiblePanel("terminal")
end)
bBrowser.MouseButton1Click:Connect(function()
setVisiblePanel("browser")
end)
bMissions.MouseButton1Click:Connect(function()
setVisiblePanel("missions", { navigate = false, captureFocus = false })
end)
bJam.MouseButton1Click:Connect(function()
requestCameraJamFromTablet({ echoTerminal = TermFrame and TermFrame.Visible })
end)
bDistract.MouseButton1Click:Connect(function()
if requestGuardDistractFromTablet then
requestGuardDistractFromTablet({ echoTerminal = TermFrame and TermFrame.Visible })
end
end)
bSave.MouseButton1Click:Connect(function()
getBrowserState()._markInteraction()
saveNow({ force = true })
end)
task.defer(function()
if getBrowserState()._renderMailPage then
getBrowserState()._renderMailPage()
end
end)
return {
MainGUI = MainGUI,
TermFrame = TermFrame,
BrowserFrame = BrowserFrame,
TermOut = TermOut,
TermInput = TermInput,
UrlBox = UrlBox,
PageLabel = PageLabel,
ClockLabel = ClockLabel,
MissionsFrame = MissionsFrame,
MissionsList = MissionsList,
ObjectivesList = ObjectivesList,
BrowserStatusLabel = BrowserStatusLabel,
BrowserContent = BrowserContent,
LinkBar = LinkBar,
AdminLoginPage = AdminLoginPage,
AdminDashboardPage = AdminDashboardPage,
AdminUserBox = AdminUserBox,
AdminPassBox = AdminPassBox,
AdminLoginStatus = AdminLoginStatus,
AdminSearchBox = AdminSearchBox,
AdminResultsFrame = AdminResultsFrame,
PacketPage = PacketPage,
PacketToolbar = PacketToolbar,
PacketListFrame = PacketListFrame,
PacketIPBox = PacketIPBox,
PacketDNSBox = PacketDNSBox,
PacketApplyBtn = PacketApplyBtn,
PacketClearBtn = PacketClearBtn,
PacketFollowBtn = PacketFollowBtn,
}
end

return buildMainUI()
end

return TabletMainUI
