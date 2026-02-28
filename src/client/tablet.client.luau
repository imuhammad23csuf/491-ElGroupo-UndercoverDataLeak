-- HackTablet OS (StarterPlayerScripts) - FULL CODE
-- Fix included: URL box typing no longer gets focus stolen by terminal

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Http = game:GetService("HttpService")
local Tween = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local TOOL_NAME = "HackTablet"
local Tool = nil

local PROMPT = "rbxplayer@hackos:~$ "
local AUDIO_TAG = "HackTablet_Audio"
local E_BIND = "HackTablet_E_Block"
local BLUR_NAME = "HackStartBlur"

local SAVE_KEYS = { "Obj_Admin", "TimesLeaked" }

local isEquipped = false
local started = false
local MainGUI, HintGUI
local TermFrame, BrowserFrame, TermOut, TermInput, UrlBox, PageLabel, ClockLabel

local DEBUG = true

local function notify(t)
	pcall(function()
		StarterGui:SetCore("SendNotification", t)
	end)
end

local function dbg(msg)
	if not DEBUG then return end
	warn("[HackTablet]", msg)
	notify({ Title = "HackTablet (debug)", Text = tostring(msg), Duration = 2 })
end

local function mk(t, p)
	local i = Instance.new(t)
	for k, v in pairs(p or {}) do
		i[k] = v
	end
	return i
end

local function round(o, r)
	mk("UICorner", { Parent = o, CornerRadius = UDim.new(0, r or 10) })
end

local function fadeVol(s, v, d)
	if not s then return end
	pcall(function()
		Tween:Create(s, TweenInfo.new(d or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Volume = math.clamp(v, 0, 10),
		}):Play()
	end)
end

notify({ Title = "SIMULATION WARNING", Text = "Simulated interface. Do not replicate in real life.", Duration = 5 })

pcall(function()
	if Player:GetAttribute("HasKeycardData") ~= nil then
		Player:SetAttribute("HasKeycardData", nil)
	end
end)

local function getSound()
	local s = SoundService:FindFirstChild(AUDIO_TAG)
	if s and s:IsA("Sound") then
		return s
	end
	s = mk("Sound", {
		Name = AUDIO_TAG,
		SoundId = "rbxassetid://74606780873749",
		Volume = 0,
		Looped = false,
		Parent = SoundService,
	})
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ s })
		end)
	end)
	return s
end

local function playAudio()
	local s = getSound()
	if not s.IsPlaying then
		s.TimePosition = 0
		s:Play()
	end
	fadeVol(s, 0.95, 0.4)
end

local function stopAudio()
	local s = SoundService:FindFirstChild(AUDIO_TAG)
	if not s then return end
	fadeVol(s, 0, 0.25)
	task.delay(0.3, function()
		if s and s.IsPlaying then
			s:Stop()
		end
	end)
end

local function isToolEquipped()
	local c = Player.Character
	return (Tool and c and Tool.Parent == c) or isEquipped
end

local function setEquipped(on)
	isEquipped = on
	Player:SetAttribute("HackTabletEquipped", on)
end

local function saveNow()
	local out = {}
	for _, k in ipairs(SAVE_KEYS) do
		local v = Player:GetAttribute(k)
		if v ~= nil then
			out[k] = v
		end
	end
	Player:SetAttribute("SaveBlob", Http:JSONEncode(out))
	notify({ Title = "HackTablet", Text = "Progress saved.", Duration = 2 })
end

local function loadNow()
	local raw = Player:GetAttribute("SaveBlob")
	if type(raw) ~= "string" or #raw == 0 then
		return
	end
	local ok, data = pcall(function()
		return Http:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	for k, v in pairs(data) do
		Player:SetAttribute(k, v)
	end
	notify({ Title = "HackTablet", Text = "Progress loaded.", Duration = 2 })
end

local function teardownStart()
	local blur = Lighting:FindFirstChild(BLUR_NAME)
	if blur then blur:Destroy() end
	local boot = PlayerGui:FindFirstChild("HackStart")
	if boot then boot:Destroy() end
end

local function addLine(txt)
	mk("TextLabel", {
		Parent = TermOut,
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(172, 255, 198),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Text = txt,
	})
	task.defer(function()
		local layout = TermOut:FindFirstChild("UIListLayout")
		if layout then
			TermOut.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
			TermOut.CanvasPosition = Vector2.new(0, math.huge)
		end
	end)
end

local PAGES = {
	["hackos://home"] =
		"Welcome to HackOS (SIM)\n\nTry:\n- help\n- apps\n- missions\n- tips\n\nThis is a learning/simulation UI.",

	["hackos://tips"] =
		"Safety Tips (SIM)\n\n- Use strong passwords\n- Turn on 2FA\n- Do not click weird links\n- Ask an adult if unsure",

	["hackos://missions"] =
		"Missions (SIM)\n1) password-check\n2) phish-spotter\n3) safe-browsing\n\nType: mission <name>",

	["hackos://apps"] =
		"Apps (SIM)\n- Terminal\n- Browser\n- Notes (soon)\n\nType: open <app>",

	["bloxplay.com/admin"] =
		"BLOXPLAY ADMIN (SIM)\n\nLogin is simulated.\nHint: `admin on` in terminal.",

	["www.bloxplay.com/admin"] =
		"BLOXPLAY ADMIN (SIM)\n\nLogin is simulated.\nHint: `admin on` in terminal.",

	["bloxplay.com/admin/employees"] =
		"Employees (SIM)\n- rick_dev\n- novaplayz\n- marcus_lee\n- junpark",

	["www.bloxplay.com/admin/employees"] =
		"Employees (SIM)\n- rick_dev\n- novaplayz\n- marcus_lee\n- junpark",
}

local function normalizeUrl(url)
	local u = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if u == "" then return "about:blank" end
	local low = u:lower()

	if low == "home" then return "hackos://home" end
	if low == "tips" then return "hackos://tips" end
	if low == "missions" then return "hackos://missions" end
	if low == "apps" then return "hackos://apps" end

	if low:sub(1, 8) == "hackos://" then
		return low
	end

	low = low:gsub("^https?://", ""):gsub("/+$", "")
	return low
end

local function navigateTo(url)
	local uNorm = normalizeUrl(url)

	if uNorm == "about:blank" then
		PageLabel.Text = ""
		return
	end

	if uNorm == "bloxplay.com/admin/employees" or uNorm == "www.bloxplay.com/admin/employees" then
		local base = PAGES[uNorm] or ""
		if Player:GetAttribute("Obj_Admin") then
			base ..= "\n\n[Admin Mode: ON] (sim)"
		end
		PageLabel.Text = base
		return
	end

	PageLabel.Text = PAGES[uNorm] or ('No renderer for "%s" (sim).'):format(url)
end

local function showHelp()
	addLine("Kid-friendly SIM commands:")
	addLine("help                        - show this list")
	addLine("apps                        - list apps")
	addLine("open <terminal|browser|notes> - switch screens")
	addLine("visit <url|home|tips|missions|apps> - open a page (sim)")
	addLine("ping <thing>                - check if something is reachable (sim)")
	addLine("scan <place>                - safety scan (sim)")
	addLine("phish <text>                - spot phishing clues (sim)")
	addLine("password <text>             - password strength check (sim)")
	addLine("mission <name>              - run a learning mission (sim)")
	addLine("admin <on|off>              - toggle admin mode (sim)")
	addLine("save | load                 - save/load progress")
	addLine("clear                        - clear terminal")
	addLine("time                         - show time")
end

local function phishCheck(text)
	local t = (text or ""):lower()
	local flags = 0
	local clues = {}

	local function flag(clue)
		flags += 1
		table.insert(clues, "- " .. clue)
	end

	if t:find("urgent") or t:find("immediately") then flag("It tries to rush you (pressure).") end
	if t:find("password") or t:find("verify") then flag("Asks for passwords or verification.") end
	if t:find("free") or t:find("winner") or t:find("prize") then flag("Too-good-to-be-true reward.") end
	if t:find("gift card") then flag("Gift card request is a common scam.") end
	if t:find("click") and (t:find("link") or t:find("http")) then flag("Wants you to click a link.") end

	if flags == 0 then
		addLine("Phish check (sim): looks okay, but always be careful.")
	else
		addLine(("Phish check (sim): %d suspicious clue(s) found:"):format(flags))
		for _, c in ipairs(clues) do addLine(c) end
	end
end

local function passwordCheck(pw)
	local s = tostring(pw or "")
	if #s == 0 then
		addLine("Try: password MyCoolPass123!")
		return
	end

	local score = 0
	if #s >= 12 then score += 2 elseif #s >= 8 then score += 1 end
	if s:match("%d") then score += 1 end
	if s:match("%l") and s:match("%u") then score += 1 end
	if s:match("[%p%W_]") then score += 1 end

	if score <= 1 then
		addLine("Password check (sim): weak")
		addLine("Tip: use 12+ chars, mix letters/numbers/symbols.")
	elseif score <= 3 then
		addLine("Password check (sim): okay")
		addLine("Tip: longer is stronger. Try a fun passphrase.")
	else
		addLine("Password check (sim): strong")
	end
end

local function handle(cmdLine)
	local raw = tostring(cmdLine or ""):gsub("^%s+", ""):gsub("%s+$", "")
	addLine(PROMPT .. raw)

	local args = {}
	for w in raw:gmatch("%S+") do
		args[#args + 1] = w
	end
	local cmd = (args[1] or ""):lower()

	if cmd == "" then
		addLine(PROMPT)
		return
	end

	local function rest(from)
		local t = {}
		for i = from, #args do t[#t+1] = args[i] end
		return table.concat(t, " ")
	end

	if cmd == "help" then
		showHelp()

	elseif cmd == "apps" then
		addLine("Apps (SIM): terminal, browser, notes (soon)")
		addLine("Tip: open browser")

	elseif cmd == "open" then
		local which = (args[2] or ""):lower()
		if which == "terminal" then
			TermFrame.Visible = true
			BrowserFrame.Visible = false
			if TermInput then TermInput:CaptureFocus() end
			addLine("Switched to Terminal.")
		elseif which == "browser" then
			TermFrame.Visible = false
			BrowserFrame.Visible = true
			addLine("Switched to Browser.")
			if UrlBox and UrlBox.Text == "" then
				UrlBox.Text = "home"
				navigateTo("home")
			end
			pcall(function() UrlBox:CaptureFocus() end)
		elseif which == "notes" then
			addLine("Notes app (sim) coming soon")
		else
			addLine("Try: open terminal OR open browser")
		end

	elseif cmd == "visit" then
		local target = rest(2)
		addLine("Opening " .. (target ~= "" and target or "about:blank") .. " ... (sim)")
		if UrlBox then UrlBox.Text = target end
		navigateTo(target)

	elseif cmd == "ping" then
		local target = rest(2)
		if target == "" then target = "server" end
		addLine(("Pinging %s ... (sim)"):format(target))
		addLine("Reply from " .. target .. ": time=12ms (sim)")

	elseif cmd == "scan" then
		local where = rest(2)
		if where == "" then where = "this device" end
		addLine(("Running safety scan on %s ... (sim)"):format(where))
		addLine("Result: 0 threats found (sim)")

	elseif cmd == "phish" then
		phishCheck(rest(2))

	elseif cmd == "password" then
		passwordCheck(rest(2))

	elseif cmd == "mission" then
		local name = (args[2] or ""):lower()
		if name == "" then
			addLine("Try: mission phish-spotter")
		elseif name == "phish-spotter" then
			addLine("Mission: Phish Spotter (SIM)")
			addLine("Try: phish \"URGENT! Click link to win a prize\"")
		elseif name == "password-check" then
			addLine("Mission: Password Check (SIM)")
			addLine("Try: password MyCoolPass123!")
		elseif name == "safe-browsing" then
			addLine("Mission: Safe Browsing (SIM)")
			addLine("Tip: Only visit pages you trust.")
		else
			addLine("Unknown mission. Try: visit missions OR mission phish-spotter")
		end

	elseif cmd == "admin" then
		local on = (args[2] or ""):lower() == "on"
		Player:SetAttribute("Obj_Admin", on)
		addLine("Admin mode (sim) = " .. tostring(on))

	elseif cmd == "save" then
		saveNow()
	elseif cmd == "load" then
		loadNow()

	elseif cmd == "time" then
		addLine(os.date("%Y-%m-%d %H:%M:%S"))

	elseif cmd == "clear" or cmd == "reset" then
		TermOut:ClearAllChildren()
		mk("UIListLayout", { Parent = TermOut, Name = "UIListLayout", Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
		addLine(PROMPT)
		return

	else
		addLine("I do not know that command. Type: help")
	end

	addLine(PROMPT)
end

local function buildMainUI()
	local gui = mk("ScreenGui", { Parent = PlayerGui, Name = "TabletGUI", IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false })
	local desktop = mk("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 22) })
	mk("UIGradient", {
		Parent = desktop,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 34, 58)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 10, 16)),
		}),
		Rotation = 120,
	})

	local top = mk("Frame", { Parent = desktop, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(17, 22, 32), BackgroundTransparency = 0.08 })
	mk("TextLabel", {
		Parent = top,
		BackgroundTransparency = 1,
		Text = "HackOS v1.4",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(220, 236, 255),
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.fromOffset(180, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ClockLabel = mk("TextLabel", {
		Parent = top,
		BackgroundTransparency = 1,
		Text = "--:--:--",
		Font = Enum.Font.Code,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 208, 240),
		Position = UDim2.new(1, -170, 0, 0),
		Size = UDim2.fromOffset(160, 50),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function button(text, x, w)
		local b = mk("TextButton", {
			Parent = top,
			Text = text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(45, 57, 84),
			Size = UDim2.fromOffset(w or 92, 30),
			Position = UDim2.new(0, x, 0, 10),
		})
		round(b, 9)
		return b
	end

	local bTerm = button("Terminal", 200)
	local bBrowser = button("Browser", 300)
	local bSave = button("Save", 400, 72)
	local bLoad = button("Load", 478, 72)
	local bClose = button("Close", 556, 72)

	local pad = mk("Frame", {
		Parent = desktop,
		Position = UDim2.new(0, 14, 0, 64),
		Size = UDim2.new(1, -28, 1, -78),
		BackgroundColor3 = Color3.fromRGB(15, 19, 28),
		BackgroundTransparency = 0.1,
	})
	round(pad, 14)

	TermFrame = mk("Frame", {
		Parent = pad,
		BackgroundColor3 = Color3.fromRGB(11, 14, 18),
		Size = UDim2.new(0.52, -6, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
	})
	BrowserFrame = mk("Frame", {
		Parent = pad,
		BackgroundColor3 = Color3.fromRGB(236, 238, 243),
		Size = UDim2.new(0.48, -6, 1, -12),
		Position = UDim2.new(0.52, 0, 0, 6),
		Visible = false,
	})
	round(TermFrame, 12)
	round(BrowserFrame, 12)

	TermOut = mk("ScrollingFrame", {
		Parent = TermFrame,
		BackgroundColor3 = Color3.fromRGB(8, 10, 13),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, -16, 1, -78),
		Position = UDim2.new(0, 8, 0, 8),
	})
	round(TermOut, 10)
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
		ClearTextOnFocus = true,
		PlaceholderText = "Type command...",
		Font = Enum.Font.Code,
		TextSize = 16,
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
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(72, 126, 255),
			Size = UDim2.fromOffset(90, h),
			Position = UDim2.new(1, -98, 1, -(8 + h)),
		})
		round(run, 9)
		run.MouseButton1Click:Connect(function()
			local c = TermInput.Text
			TermInput.Text = ""
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
		TextSize = 15,
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

	PageLabel = mk("TextLabel", {
		Parent = BrowserFrame,
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(0, 0, 0),
		Text = "",
		Size = UDim2.new(1, -16, 1, -48),
		Position = UDim2.new(0, 8, 0, 44),
	})

	goBtn.MouseButton1Click:Connect(function()
		navigateTo(UrlBox.Text)
	end)

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.KeypadEnter then return end

		local focused = nil
		pcall(function() focused = UIS:GetFocusedTextBox() end)
		if focused == UrlBox then
			navigateTo(UrlBox.Text)
		end
	end)

	UrlBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			navigateTo(UrlBox.Text)
		end
	end)

	-- FIX: Do not force terminal focus when browser is open or another textbox is focused.
	local function canRefocusTerminal()
		if not (MainGUI and MainGUI.Enabled) then return false end
		if not (TermFrame and TermFrame.Visible) then return false end
		if not (TermInput and TermInput.Parent) then return false end
		if not (isToolEquipped() and started) then return false end
		local focused = nil
		pcall(function() focused = UIS:GetFocusedTextBox() end)
		return focused == nil or focused == TermInput
	end

	TermInput.FocusLost:Connect(function(enter)
		if enter then
			local c = TermInput.Text
			TermInput.Text = ""
			handle(c)
		end
		task.defer(function()
			if canRefocusTerminal() then
				TermInput:CaptureFocus()
			end
		end)
	end)

	bTerm.MouseButton1Click:Connect(function()
		TermFrame.Visible = true
		BrowserFrame.Visible = false
		TermInput:CaptureFocus()
	end)

	bBrowser.MouseButton1Click:Connect(function()
		TermFrame.Visible = false
		BrowserFrame.Visible = true
		if UrlBox and UrlBox.Text == "" then
			UrlBox.Text = "home"
			navigateTo("home")
		end
		pcall(function() UrlBox:CaptureFocus() end)
	end)

	bSave.MouseButton1Click:Connect(saveNow)
	bLoad.MouseButton1Click:Connect(loadNow)
	bClose.MouseButton1Click:Connect(function()
		gui.Enabled = false
		stopAudio()
	end)

	addLine(PROMPT)
	return gui
end

local function playStart(onDone)
	local blur = mk("BlurEffect", { Parent = Lighting, Name = BLUR_NAME, Size = 12 })
	local gui = mk("ScreenGui", { Parent = PlayerGui, Name = "HackStart", IgnoreGuiInset = true, ResetOnSpawn = false })
	local bg = mk("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 14) })
	local card = mk("Frame", {
		Parent = bg,
		Size = UDim2.fromOffset(420, 180),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(16, 22, 35),
	})
	round(card, 16)
	mk("UIStroke", { Parent = card, Color = Color3.fromRGB(80, 123, 255), Thickness = 1, Transparency = 0.2 })
	mk("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Text = "Booting HackOS",
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(220, 235, 255),
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 0, 18),
	})

	local bar = mk("Frame", {
		Parent = card,
		BackgroundColor3 = Color3.fromRGB(30, 40, 62),
		Size = UDim2.new(1, -40, 0, 12),
		Position = UDim2.new(0, 20, 1, -42),
	})
	round(bar, 8)

	local fill = mk("Frame", { Parent = bar, BackgroundColor3 = Color3.fromRGB(86, 140, 255), Size = UDim2.new(0, 0, 1, 0) })
	round(fill, 8)

	local t = Tween:Create(fill, TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	t:Play()

	t.Completed:Connect(function()
		gui:Destroy()
		Tween:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
		task.delay(0.22, function()
			if blur then blur:Destroy() end
		end)
		if onDone then onDone() end
	end)
end

local function buildHint()
	local gui = mk("ScreenGui", { Parent = PlayerGui, Name = "TabletHint", IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false })
	local shade = mk("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 8, 12), BackgroundTransparency = 0.3 })
	local panel = mk("Frame", {
		Parent = shade,
		BackgroundColor3 = Color3.fromRGB(15, 20, 32),
		Size = UDim2.fromOffset(430, 190),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	round(panel, 16)

	mk("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(225, 235, 255),
		Text = "HackOS Tablet",
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 0, 16),
	})

	mk("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(180, 200, 230),
		TextWrapped = true,
		Text = UIS.TouchEnabled and "Tap START to boot." or "Click START to boot.",
		Size = UDim2.new(1, -40, 0, 42),
		Position = UDim2.new(0, 20, 0, 60),
	})

	local startBtn = mk("TextButton", {
		Parent = panel,
		Text = "START",
		Font = Enum.Font.GothamSemibold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(79, 131, 255),
		Size = UDim2.fromOffset(210, 42),
		Position = UDim2.new(0.5, -105, 1, -58),
	})
	round(startBtn, 12)

	startBtn.MouseButton1Click:Connect(function()
		if not isToolEquipped() then
			gui.Enabled = false
			dbg("Start clicked but tool not equipped.")
			return
		end
		gui.Enabled = false
		playStart(function()
			if isToolEquipped() and MainGUI then
				MainGUI.Enabled = true
				started = true
				playAudio()
				if TermInput then TermInput:CaptureFocus() end
				dbg("Boot complete; main UI enabled.")
			else
				stopAudio()
				dbg("Boot finished but not equipped; stopping audio.")
			end
		end)
	end)

	return gui
end

local function allowE()
	return isToolEquipped() and started and MainGUI and MainGUI.Enabled
end

local function bindEGuard()
	CAS:UnbindAction(E_BIND)
	CAS:BindActionAtPriority(E_BIND, function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return allowE() and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E)
end

MainGUI = buildMainUI()
HintGUI = buildHint()
bindEGuard()
dbg("UI built. Waiting for tool: " .. TOOL_NAME)

task.spawn(function()
	while MainGUI and MainGUI.Parent do
		if ClockLabel then
			ClockLabel.Text = os.date("%H:%M:%S")
		end
		task.wait(1)
	end
end)

local function onEquipped()
	setEquipped(true)
	if HintGUI and not started then
		HintGUI.Enabled = true
	end
	bindEGuard()
	dbg("Tool equipped; showing hint.")
end

local function onUnequipped()
	setEquipped(false)
	started = false
	if HintGUI then HintGUI.Enabled = false end
	if MainGUI then MainGUI.Enabled = false end
	stopAudio()
	teardownStart()
	bindEGuard()
	dbg("Tool unequipped; hiding UI.")
end

local function hookTool(t)
	if Tool == t then return end
	Tool = t
	dbg("Found tool instance: " .. t:GetFullName())

	t.AncestryChanged:Connect(function(_, parent)
		if not parent and Tool == t then
			dbg("Tool removed/destroyed.")
			onUnequipped()
			Tool = nil
		end
	end)

	t.Equipped:Connect(onEquipped)
	t.Unequipped:Connect(onUnequipped)

	local char = Player.Character
	if char and t.Parent == char then
		onEquipped()
	end
end

local function findTool()
	local char = Player.Character
	local backpack = Player:FindFirstChildOfClass("Backpack")

	if char then
		local t = char:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	if backpack then
		local t = backpack:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	return nil
end

local function scanForToolNow()
	local t = findTool()
	if t then hookTool(t) end
end

local function watch(container)
	if not container then return end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			hookTool(child)
		end
	end)
	local existing = container:FindFirstChild(TOOL_NAME)
	if existing and existing:IsA("Tool") then
		hookTool(existing)
	end
end

watch(Player:WaitForChild("Backpack"))
watch(Player.Character or Player.CharacterAdded:Wait())
scanForToolNow()

Player.CharacterAdded:Connect(function(char)
	started = false
	stopAudio()
	teardownStart()
	bindEGuard()
	watch(char)
	task.defer(scanForToolNow)
	dbg("CharacterAdded; re-watching for tool.")
end)

local lastEquipped = false
RunService.Heartbeat:Connect(function()
	if not Tool then
		scanForToolNow()
		return
	end
	local equippedNow = isToolEquipped()
	if equippedNow ~= lastEquipped then
		lastEquipped = equippedNow
		if equippedNow then
			onEquipped()
		else
			onUnequipped()
		end
	end
end)

if MainGUI then
	MainGUI:GetPropertyChangedSignal("Enabled"):Connect(bindEGuard)
end
