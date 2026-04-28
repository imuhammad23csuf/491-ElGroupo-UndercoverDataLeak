-- ReplicatedStorage/NewsCutscene
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local M = {}

-- ================= helpers =================

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	t.Completed:Wait()
end

local function findGameMusic()
	for _, d in ipairs(SoundService:GetDescendants()) do
		if d:IsA("Sound") and d.Name == "GameMusic" then
			return d
		end
	end
	return nil
end

local function createSound(id, volume, looped)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Looped = looped or false
	s.RollOffMode = Enum.RollOffMode.Linear
	s.Parent = SoundService
	pcall(function() ContentProvider:PreloadAsync({s}) end)
	return s
end

-- Find a rig Model named rigName inside a container (defaults to "News"), with fallbacks
local function getRig(rigName, containerName)
	rigName = rigName or "NewsAgent"
	containerName = containerName or "News"

	-- choose search root: container if present, else workspace
	local searchRoot = workspace
	local container = workspace:FindFirstChild(containerName)
	if not container then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") and d.Name == containerName then
				container = d; break
			end
		end
	end
	if container and container:IsA("Model") then
		searchRoot = container
	end

	-- fast path: direct child
	local rig = searchRoot:FindFirstChild(rigName)
	if rig and rig:IsA("Model") then return rig end

	-- recursive search
	for _, d in ipairs(searchRoot:GetDescendants()) do
		if d:IsA("Model") and d.Name == rigName then
			return d
		end
	end

	warn(("[NewsCutscene] Rig '%s' not found under '%s' (or workspace)."):format(rigName, containerName))
	return nil
end

-- Accept BasePart or Model, return CFrame
local function getPosCF(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart.CFrame
		else
			return inst:GetPivot()
		end
	end
	return nil
end

-- Prefer CameraPath/CamFront, else CameraPath/Cam1
local function getFrontCamCF(rig)
	local folder = rig and rig:FindFirstChild("CameraPath")
	if folder then
		local node = folder:FindFirstChild("CamFront") or folder:FindFirstChild("Cam1")
		local nodeCF = node and getPosCF(node)
		if nodeCF then
			local main = rig:FindFirstChildWhichIsA("BasePart", true)
			local lookAt = main and (main.Position + Vector3.new(0,1.5,0)) or nodeCF.Position
			return CFrame.new(nodeCF.Position, lookAt)
		end
	end
	-- Fallback: 8 studs in front of PrimaryPart
	local main = rig and (rig.PrimaryPart or rig:FindFirstChildWhichIsA("BasePart", true))
	if main then
		local pos = main.CFrame.Position - main.CFrame.LookVector * 8 + Vector3.new(0,1.5,0)
		return CFrame.new(pos, main.Position + Vector3.new(0,1.5,0))
	end
	return nil
end

-- Get numbered camera path Cam1..CamN (BasePart or Model)
local function getPathNodes(rig)
	local nodes = {}
	local folder = rig and rig:FindFirstChild("CameraPath")
	if not folder then return nodes end
	for _, child in ipairs(folder:GetChildren()) do
		if (child:IsA("BasePart") or child:IsA("Model")) and child.Name:match("^Cam%d+$") then
			table.insert(nodes, child)
		end
	end
	table.sort(nodes, function(a,b) return a.Name < b.Name end)
	return nodes
end

-- Build an orbit CFrame list around a center
local function buildOrbitNodes(center, radius, height, count)
	local list = {}
	for i = 1, count do
		local t = (i-1)/count * math.pi*2
		local pos = center + Vector3.new(math.cos(t)*radius, height, math.sin(t)*radius)
		local lookAt = center + Vector3.new(0, height-1, 0)
		list[i] = CFrame.new(pos, lookAt)
	end
	return list
end

-- ===== Lens support (Lens under CameraPath/Cam1) =====
-- Returns a function that yields Lens CFrame (supports Part or Model)
local function getLensGetter(rig)
	if not rig then return nil end
	local folder = rig:FindFirstChild("CameraPath")
	if not folder then return nil end

	-- Expect Lens under Cam1 (Model) per your setup
	local cam1 = folder:FindFirstChild("Cam1")
	if cam1 then
		local lens = cam1:FindFirstChild("Lens")
		if lens then
			if lens:IsA("BasePart") then
				return function() return lens.CFrame end
			elseif lens:IsA("Model") then
				return function()
					if lens.PrimaryPart then return lens.PrimaryPart.CFrame end
					return lens:GetPivot()
				end
			end
		end
	end

	-- Fallbacks (if you ever rename/move it)
	local lens = folder:FindFirstChild("Lens")
	if lens then
		if lens:IsA("BasePart") then
			return function() return lens.CFrame end
		elseif lens:IsA("Model") then
			return function()
				if lens.PrimaryPart then return lens.PrimaryPart.CFrame end
				return lens:GetPivot()
			end
		end
	end
	return nil
end

-- Follow the lens every frame; keep looking at a point
local function startLensFollow(getLensCF, lookAtPos, camOffsetCF)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local lensCF = getLensCF()
		if not lensCF then return end
		local camCF = camOffsetCF and (lensCF * camOffsetCF) or lensCF
		workspace.CurrentCamera.CFrame = CFrame.new(camCF.Position, lookAtPos)
	end)
	return function() if conn then conn:Disconnect() end end
end

-- Make a model invisible and non-collidable
local function makeModelInvisible(model)
	if not model then return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

-- Jumping animation loop: plays, waits, repeats
local function startJumpLoop(rig, assetId, interval)
	if not rig then return function() end end

	local hum = rig:FindFirstChildOfClass("Humanoid")
	if not hum then
		warn("[NewsCutscene] No Humanoid found on rig for jump loop.")
		return function() end
	end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = assetId
	local track = animator:LoadAnimation(anim)
	track.Looped = false

	local running = true

	task.spawn(function()
		while running and hum.Parent do
			track:Play()
			-- Wait for the jump animation to finish, then wait a bit before replaying
			track.Stopped:Wait()
			task.wait(interval or 3)
		end
	end)

	return function()
		running = false
		if track.IsPlaying then
			track:Stop()
		end
		anim:Destroy()
	end
end

-- Minimal UI container (center card can be hidden via flag)
local function buildGui(player)
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "NewsGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.ResetOnSpawn = false
	gui.Parent = pg

	-- dim overlay
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1,1)
	dim.BackgroundColor3 = Color3.new(0,0,0)
	dim.BackgroundTransparency = 1
	dim.Parent = gui

	-- headline card (hidden via opts.showCenterCard=false)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.56)
	card.Size = UDim2.fromScale(0.78, 0.32)
	card.BackgroundColor3 = Color3.fromRGB(18,18,20)
	card.BackgroundTransparency = 0.25
	card.Parent = gui

	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = card
	local stroke = Instance.new("UIStroke"); stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Color = Color3.fromRGB(255,255,255); stroke.Thickness = 1.2; stroke.Transparency = 0.75; stroke.Parent = card
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 18); pad.PaddingBottom = UDim.new(0, 18); pad.PaddingLeft = UDim.new(0, 24); pad.PaddingRight = UDim.new(0, 24); pad.Parent = card
	local scaler = Instance.new("UIScale"); scaler.Scale = 0.98; scaler.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Headline"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1,1)
	label.Text = ""
	label.TextWrapped = true
	label.TextScaled = true
	label.Font = Enum.Font.GothamSemibold
	label.TextColor3 = Color3.fromRGB(235,235,240)
	label.TextTransparency = 1
	label.Parent = card

	return gui, dim, card, label, scaler
end

-- Broadcast HUD (LIVE + Breaking bar + clock)
local function buildBroadcastHUD(gui)
	local live = Instance.new("TextLabel")
	live.Name = "LiveTag"
	live.AnchorPoint = Vector2.new(1,0)
	live.Position = UDim2.fromScale(0.985, 0.04)
	live.Size = UDim2.fromOffset(96, 36)
	live.BackgroundColor3 = Color3.fromRGB(220, 26, 26)
	live.Text = "LIVE"
	live.TextScaled = true
	live.TextColor3 = Color3.new(1,1,1)
	live.Font = Enum.Font.GothamBold
	live.ZIndex = 2
	live.Parent = gui
	do
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = live
		local s = Instance.new("UIStroke"); s.Thickness = 1; s.Transparency = 0.35; s.Parent = live
	end

	local bar = Instance.new("Frame")
	bar.Name = "BreakingBar"
	bar.AnchorPoint = Vector2.new(0,1)
	bar.Position = UDim2.new(0.015, 0, 0.985, 0)
	bar.Size = UDim2.new(0.62, 0, 0, 54)
	bar.BackgroundColor3 = Color3.fromRGB(18,18,20)
	bar.BackgroundTransparency = 0.2
	bar.ZIndex = 1
	bar.Parent = gui
	do
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,10); bc.Parent = bar
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft  = UDim.new(0,12)
		pad.PaddingRight = UDim.new(0,12)
		pad.Parent = bar
	end

	local red = Instance.new("TextLabel")
	red.Name = "BreakingChip"
	red.Size = UDim2.new(0, 180, 1, 0)
	red.BackgroundColor3 = Color3.fromRGB(220,26,26)
	red.Text = "BREAKING NEWS"
	red.TextScaled = true
	red.TextColor3 = Color3.new(1,1,1)
	red.Font = Enum.Font.GothamBold
	red.ZIndex = 2
	red.Parent = bar
	do
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,10); rc.Parent = red
	end

	local headline = Instance.new("TextLabel")
	headline.Name = "BreakingText"
	headline.BackgroundTransparency = 1
	headline.TextXAlignment = Enum.TextXAlignment.Left
	headline.Text = ""
	headline.TextScaled = true
	headline.TextWrapped = true
	headline.TextTruncate = Enum.TextTruncate.AtEnd
	headline.TextColor3 = Color3.fromRGB(235,235,240)
	headline.Font = Enum.Font.GothamSemibold
	headline.ZIndex = 1
	headline.Parent = bar

	local clock = Instance.new("TextLabel")
	clock.Name = "Clock"
	clock.AnchorPoint = Vector2.new(1,0)
	clock.Position = UDim2.new(1, -6, 0, 0)
	clock.Size = UDim2.fromOffset(78, 54)
	clock.BackgroundTransparency = 1
	clock.Text = " 00:00"
	clock.TextScaled = true
	clock.TextColor3 = Color3.fromRGB(210,210,215)
	clock.Font = Enum.Font.GothamMedium
	clock.ZIndex = 2
	clock.Parent = bar

	-- dynamic layout so text never runs under the clock
	local RIGHT_MARGIN = 6
	local GAP_AFTER_RED = 12
	local function relayout()
		local leftOffset = red.AbsoluteSize.X + GAP_AFTER_RED
		local rightReserved = clock.AbsoluteSize.X + RIGHT_MARGIN
		headline.Position = UDim2.new(0, leftOffset, 0, 0)
		headline.Size = UDim2.new(1, -(leftOffset + rightReserved), 1, 0)
	end
	task.defer(relayout)
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	red:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	clock:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	return live, bar, headline, clock
end

-- Fake clock (HH:MM) that ticks forward
local function parseClockStart(str)
	if type(str) ~= "string" then return 19, 0 end
	local h, m = string.match(str, "^(%d%d?):(%d%d)$")
	h = tonumber(h) or 19
	m = tonumber(m) or 0
	if h < 0 then h = 0 elseif h > 23 then h = 23 end
	if m < 0 then m = 0 elseif m > 59 then m = 59 end
	return h, m
end

local function startFakeClock(label, startHH, startMM)
	local hh, mm, ss = startHH or 19, startMM or 0, 0
	local running = true
	task.spawn(function()
		while running and label and label.Parent do
			label.Text = string.format("%02d:%02d", hh, mm)
			task.wait(1)
			ss += 1
			if ss >= 60 then
				ss = 0
				mm += 1
				if mm >= 60 then
					mm = 0
					hh = (hh + 1) % 24
				end
			end
		end
	end)
	return function() running = false end
end

-- Skip button
local function buildSkipButton(gui, text)
	local btn = Instance.new("TextButton")
	btn.Name = "SkipButton"
	btn.AnchorPoint = Vector2.new(1,1)
	btn.Position = UDim2.fromScale(0.985, 0.965)     -- bottom-right
	btn.Size = UDim2.fromOffset(120, 40)
	btn.AutoButtonColor = true
	btn.BackgroundColor3 = Color3.fromRGB(30,30,32)
	btn.Text = text or "Skip"
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(235,235,240)
	btn.Font = Enum.Font.GothamSemibold
	btn.ZIndex = 3
	btn.Parent = gui

	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = btn
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 1; stroke.Transparency = 0.35; stroke.Parent = btn
	return btn
end

-- ================= main =================

-- opts:
--   headlines { {text, duration}, ... }  required
--   totalTime = (default 60)
--   musicId   = rbxasset id for news soundtrack
--   useRigName = "NewsAgent"
--   rigContainerName = "News"
--   showBroadcastHUD = true/false
--   showCenterCard = true/false
--   clockStart = "HH:MM"
--   skipButtonText = "Skip"
function M.Play(player, opts)
	opts = opts or {}
	local headlines = opts.headlines or {}
	if #headlines == 0 then return end

	-- tell other scripts: cutscene not done yet
	if player and player.SetAttribute then
		player:SetAttribute("NewsCutsceneCompleted", false)
	end

	local targetTotal = tonumber(opts.totalTime) or 60
	local sum = 0
	for _,h in ipairs(headlines) do sum += (h.duration or 3) end
	local scale = (sum > 0) and (targetTotal / sum) or 1

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable

	-- freeze movement
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local ws, jp
	if hum then
		ws, jp = hum.WalkSpeed, hum.JumpPower
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	-- UI on
	local gui, dim, card, label, scaler = buildGui(player)
	local live, breakingBar, breakingText, clock
	if opts.showBroadcastHUD then
		live, breakingBar, breakingText, clock = buildBroadcastHUD(gui)
	end
	if opts.showCenterCard == false then
		card.Visible = false
	end

	-- Skip button only (no keyboard)
	local skipBtn = buildSkipButton(gui, opts.skipButtonText)
	local skip = false
	skipBtn.MouseButton1Click:Connect(function()
		skip = true
	end)

	-- fade in overlay
	tween(dim, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.35})
	tween(scaler, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {Scale = 1.0})

	-- ===== Camera sequence =====
	-- 1) FRONT ZOOM-IN (1.75s)
	local rig = getRig(opts.useRigName, opts.rigContainerName)

	-- start jump loop on NewsAgent
	local stopJumpLoop
	if rig then
		stopJumpLoop = startJumpLoop(rig, "rbxassetid://125750702", 3)
	end

	local frontCF = rig and getFrontCamCF(rig) or nil
	if frontCF then
		local startCF = frontCF * CFrame.new(0, 0, 6)
		cam.CFrame = startCF
		tween(cam, TweenInfo.new(1.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = frontCF})
	end

	-- 2) LENS FOLLOW for the rest of the time (fallbacks handled later)
	local stopLensFollow
	local main = rig and rig:FindFirstChildWhichIsA("BasePart", true)
	local lookAtPos = main and (main.Position + Vector3.new(0,1.5,0)) or (frontCF and frontCF.Position) or Vector3.new(0,5,0)
	local lensGetter = rig and getLensGetter(rig) or nil
	local panTime = math.max(1, targetTotal - 1.75)

	if lensGetter then
		local camOffsetCF = CFrame.new(0, 0, 0)
		stopLensFollow = startLensFollow(lensGetter, lookAtPos, camOffsetCF)
		task.delay(panTime, function()
			if stopLensFollow then stopLensFollow() end
		end)
	elseif rig then
		-- Fallback: numbered path or orbit
		local pathNodes = getPathNodes(rig)
		local camFrames = {}
		if #pathNodes >= 2 then
			for _, node in ipairs(pathNodes) do
				local ncf = getPosCF(node)
				if ncf then table.insert(camFrames, CFrame.new(ncf.Position, lookAtPos)) end
			end
		else
			local center = (frontCF and frontCF.Position) or lookAtPos
			camFrames = buildOrbitNodes(center, 14, 6, 8)
		end
		if #camFrames > 1 then
			local perHop = panTime / (#camFrames - 1)
			cam.CFrame = camFrames[1]
			task.spawn(function()
				for i = 2, #camFrames do
					local ti = TweenInfo.new(math.max(0.75, perHop), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					TweenService:Create(cam, ti, {CFrame = camFrames[i]}):Play()
					local t0 = time()
					while time() - t0 < perHop do
						if skip then break end
						RunService.Heartbeat:Wait()
					end
					if skip then break end
				end
			end)
		end
	end

	-- ===== audio crossfade: game -> news (and keep game paused until news fully ends)
	local gameMusic = findGameMusic()
	local gameWasPlaying, gamePrevVolume, gameTimePos = false, nil, 0
	if gameMusic then
		gameWasPlaying = gameMusic.IsPlaying
		gamePrevVolume = gameMusic.Volume
		gameTimePos = gameMusic.TimePosition
		-- fade out quickly, then pause
		local t0, dur = time(), 0.35
		while time() - t0 < dur do
			local a = (time() - t0)/dur
			gameMusic.Volume = (gamePrevVolume or 0.6) * (1-a)
			RunService.Heartbeat:Wait()
		end
		if gameWasPlaying then gameMusic:Pause() end
	end

	local news
	if opts.musicId and opts.musicId ~= "" then
		news = createSound(opts.musicId, 0.7, false)
		news:Play()
	end

	-- start fake clock
	local stopClock
	if clock then
		local sh, sm = parseClockStart(opts.clockStart)
		stopClock = startFakeClock(clock, sh, sm)
	end

	-- headlines loop (scaled to ~totalTime)
	for _, item in ipairs(headlines) do
		if skip then break end

		if opts.showCenterCard ~= false then
			label.Text = item.text
			label.TextTransparency = 1
			tween(label, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {TextTransparency = 0})
		end

		if breakingText then
			breakingText.Text = item.text
		end

		local dur = math.max(1, (item.duration or 3) * scale)
		local t0 = time()
		while time() - t0 < dur do
			if skip then break end
			RunService.Heartbeat:Wait()
		end

		if opts.showCenterCard ~= false then
			tween(label, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {TextTransparency = 1})
		end
	end

	-- stop clock & lens follow (safety)
	if stopClock then stopClock() end
	if stopLensFollow then stopLensFollow() end

	-- stop jump loop
	if stopJumpLoop then
		stopJumpLoop()
	end

	-- ===== end audio: fade out news completely, THEN resume game
	if news and news.IsPlaying then
		local nv = news.Volume
		local t0, dur = time(), 0.35
		while time() - t0 < dur do
			local a = (time() - t0)/dur
			news.Volume = nv * (1-a)
			RunService.Heartbeat:Wait()
		end
		news:Stop()
		news:Destroy()
	end

	-- Only after news is fully stopped do we resume game music
	if gameMusic and gameWasPlaying then
		gameMusic.TimePosition = gameTimePos
		gameMusic:Resume()
		local t0, dur = time(), 0.45
		while time() - t0 < dur do
			local a = (time() - t0)/dur
			gameMusic.Volume = (gamePrevVolume or 0.6) * a
			RunService.Heartbeat:Wait()
		end
		gameMusic.Volume = gamePrevVolume or 0.6
	end

	-- make the News model invisible & non-collidable so players can walk through
	if rig then
		local rootModel = rig.Parent or rig
		makeModelInvisible(rootModel)
	end

	-- UI off & cleanup
	tween(dim, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
	if live then live:Destroy() end
	if breakingBar then breakingBar:Destroy() end
	if skipBtn then skipBtn:Destroy() end
	card.Visible = false
	task.delay(0.1, function()
		if gui and gui.Parent then gui:Destroy() end
	end)

	-- restore control
	cam.CameraType = Enum.CameraType.Custom
	if hum then
		hum.WalkSpeed = ws or 16
		hum.JumpPower = jp or 50
	end

	-- mark cutscene as done (finished or skipped)
	if player and player.SetAttribute then
		player:SetAttribute("NewsCutsceneCompleted", true)
	end
end

return M
