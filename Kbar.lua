--!nonstrict
--[[
	Kbar 1.3b — a client-side notch bar for Roblox.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/Kbar/main/Kbar.lua"))()

	Top centre, flush with the screen edge:
		Indev | 12:00 | 1.3b       tag and version come from Ver.txt
		the tray, four across: FPS Display, LSSR SW, Free Camera, Ping Display,
		                       Load Inf Yield, KHub, Anim Changer, Click 2 MEOW!
		the arrow, inside the box, bottom right of whatever is showing
	The row above is one centred line of rich text, so Roblox centres it itself at
	any width, and the notch closes around it rather than to a fixed number.

	Left and right of the notch: the FPS and Ping readouts, off until toggled on.
	Top right: the person orb (Roblox's own player list), the health bar and its
	red cross, and the K button, which opens the menu below it.
	The K strip slides out to the left of the K button: ALOG, SHOP, Exit, Notify.
	It slides out empty, fades its labels in only once it is fully open, and on the
	way back it fades them out fast before the strip itself closes.
	The notch's own tray fades the same way, in behind the opening and out fast
	before it closes.

	When Ver.txt holds a number newer than this file, a prompt asks whether to
	update. Update drops this copy and runs the file at updateUrl; Deny keeps this
	copy for the rest of the game and the prompt never returns.

	Chat commands, prefix k-: k-hop, k-alog, k-lssrsw, k-fc, k-iy, k-anim, k-hub.
	Type one in the chat box and it runs.

	_g.Kbar.notify(title, body) shows a notification, _g.Kbar.destroy() unloads.
]]

local CONFIG = {
	verUrl = "https://raw.githubusercontent.com/Kttyz/Kbar/refs/heads/main/Ver.txt",
	verRefresh = 60,
	statRefresh = 0.5,

	startOpen = false,

	notchWidth = 384,
	-- the closed notch only has to hold the info row, so it is measured off that
	-- row: this is the ceiling it is allowed to grow back to
	notchWidthClosed = 188,
	notchRadius = 12,
	infoRowHeight = 24,
	trayHeight = 94,
	chevronHeight = 14,
	chevronArrowInset = 8,

	cellWidth = 76,
	cellHeight = 38,
	cellPadding = 6,

	sideBoxWidth = 92,
	sideBoxGap = 8,

	barWidth = 152,
	barHeight = 12,
	crossSize = 15,
	orbSize = 34,
	keySize = 34,
	orbMargin = 16,
	orbTop = 7,
	hideDefaultHealth = true,

	menuStripHeight = 42,
	menuStripKey = 34,
	menuStripButton = 62,
	menuStripButtonHeight = 34,
	menuStripGap = 8,
	menuStripPadding = 6,
	menuStripOpenTime = 0.2,
	menuStripFadeIn = 0.14,
	menuStripFadeOut = 0.07,
	menuStripCloseTime = 0.12,

	-- what this file is. Ver.txt is compared against it, and a newer number
	-- there is what puts the update prompt on screen
	runningVersion = "1.3b",
	-- shown until Ver.txt answers; never a placeholder
	versionFallback = "1.3b",
	updateUrl = "https://raw.githubusercontent.com/Kttyz/Kbar/refs/heads/main/Kbar.lua",
	-- the tray fades like the K strip does, so nothing pops in at the end
	trayFadeIn = 0.16,
	trayFadeOut = 0.07,

	font = Enum.Font.Code,
	-- Code has no bold cut, and its capital A comes up shorter than the other caps,
	-- so every label gets this face instead: bold, monospaced, even cap heights.
	fontFamily = "rbxasset://fonts/families/RobotoMono.json",
	fontWeight = Enum.FontWeight.Bold,
	textSize = 14,
	smallTextSize = 10,
	buttonTextSize = 12,
	strokeThickness = 2,

	meowSound = "rbxassetid://134881862056957", -- KHub's startup sound
	clickSound = "rbxassetid://12221976", -- KHub's click sound

	scripts = {
		lssr = "https://raw.githubusercontent.com/Kttyz/Scripts/main/LSSR%20Staff%20Watch.lua",
		freecam = "https://raw.githubusercontent.com/Kttyz/Scripts/main/freecam.lua",
		khub = "https://raw.githubusercontent.com/Kttyz/Scripts/main/KHub.lua",
		anim = "https://raw.githubusercontent.com/Kttyz/Scripts/main/animations.lua",
		infyield = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
		alogger = "https://raw.githubusercontent.com/Kttyz/Scripts/main/Alogger.lua",
	},

	colour = {
		background = Color3.fromRGB(10, 11, 12),
		backgroundTop = Color3.fromRGB(24, 26, 29),
		edge = Color3.fromRGB(64, 70, 79),
		text = Color3.fromRGB(236, 238, 241),
		dim = Color3.fromRGB(140, 148, 158),
		dimmer = Color3.fromRGB(116, 124, 133),
		accent = Color3.fromRGB(224, 73, 47),
		green = Color3.fromRGB(88, 214, 120),
		red = Color3.fromRGB(226, 62, 50),
		panel = Color3.fromRGB(36, 36, 37),
		panelTop = Color3.fromRGB(46, 46, 47),
		buttonFill = Color3.fromRGB(255, 255, 255),
	},
}

-- id, label, and what the button says on its two lines
-- eight of them, four across, two rows
local TRAY = {
	{ id = "fps", label = "FPS\nDisplay" },
	{ id = "lssr", label = "LSSR\nSW" },
	{ id = "freecam", label = "Free\nCamera" },
	{ id = "ping", label = "Ping\nDisplay" },
	{ id = "infyield", label = "Load\nInf Yield" },
	{ id = "khub", label = "KHub" },
	{ id = "anim", label = "Anim\nChanger" },
	{ id = "meow", label = "Click 2\nMEOW!" },
}

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

-- game:HttpGet is an executor global; Studio and vanilla clients do not have it,
-- so fall back to HttpService. Same call shape either way.
local function httpGet(url)
	local direct = game.HttpGet
	if typeof(direct) == "function" then
		local ok, body = pcall(direct, game, url)
		if ok and body then
			return body
		end
	end
	return HttpService:GetAsync(url)
end

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui")

if _G.Kbar and typeof(_G.Kbar.destroy) == "function" then
	pcall(_G.Kbar.destroy)
end
local previous = playerGui:FindFirstChild("Kbar")
if previous then
	previous:Destroy()
end

local connections = {}
local function track(connection)
	table.insert(connections, connection)
	return connection
end

local transparentRegistry = {}

local function preferredTransparency()
	local ok, value = pcall(function()
		return GuiService.PreferredTransparency
	end)
	if ok and typeof(value) == "number" then
		return value
	end
	return 0
end

local function applyTransparency()
	local pref = preferredTransparency()
	for frame, design in pairs(transparentRegistry) do
		if frame.Parent then
			frame.BackgroundTransparency = design * pref
		else
			transparentRegistry[frame] = nil
		end
	end
end

-- the bold face, resolved once. Font.new is the modern way to ask for a weight;
-- where it is missing the labels keep CONFIG.font and still work.
local BOLD_FACE
pcall(function()
	if typeof(Font) == "table" and Font.new then
		BOLD_FACE = Font.new(CONFIG.fontFamily, CONFIG.fontWeight)
	end
end)

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function make(class, properties, parent)
	local instance = Instance.new(class)
	for key, value in pairs(properties) do
		instance[key] = value
	end
	-- every label in this script is built here, so this is the one place that has to
	-- know about the face: nothing can be drawn and miss it.
	if BOLD_FACE and TEXT_CLASSES[class] then
		local ok = pcall(function()
			instance.FontFace = BOLD_FACE
		end)
		if not ok then
			BOLD_FACE = nil
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(instance, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end

local function stroke(instance, colour, thickness, transparency)
	return make("UIStroke", {
		Color = colour,
		Thickness = thickness or CONFIG.strokeThickness,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, instance)
end

local function panelled(frame, design)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = design
	transparentRegistry[frame] = design
	return frame
end

local function tween(instance, info, goals)
	local animation = TweenService:Create(instance, info, goals)
	animation:Play()
	return animation
end

local function motionInfo(duration)
	local reduced = false
	pcall(function()
		reduced = GuiService.ReducedMotionEnabled
	end)
	return TweenInfo.new(reduced and 0 or duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function label(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		Font = CONFIG.font,
		TextSize = CONFIG.textSize,
		TextColor3 = CONFIG.colour.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in pairs(properties or {}) do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

----------------------------------------------------------------------
-- sound
----------------------------------------------------------------------

local function playSound(id, volume)
	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume or 0.7
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
	return ok
end

----------------------------------------------------------------------
-- notify — the toast from KHub, same shape, same stack
----------------------------------------------------------------------

local notifyGui = make("ScreenGui", {
	Name = "KbarNotifications",
	ResetOnSpawn = false,
	DisplayOrder = 700,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function()
	notifyGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
notifyGui.Parent = playerGui
local notifySlot = 0

local function notify(titleText, bodyText, length, muted)
	if not muted then
		playSound(CONFIG.clickSound, 0.5)
	end
	notifySlot += 1
	local slot = notifySlot

	local toast = make("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, 18),
		Size = UDim2.fromOffset(272, 92),
		BackgroundColor3 = CONFIG.colour.panel,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, notifyGui)
	corner(toast, 6)
	stroke(toast, CONFIG.colour.edge, 1, 0.55)

	local titlePlate = make("Frame", {
		Name = "TitlePlate",
		Size = UDim2.new(1, 0, 0, 23),
		BackgroundColor3 = CONFIG.colour.panelTop,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, toast)
	corner(titlePlate, 6)

	label(toast, {
		Name = "Title",
		Text = titleText or "Kbar",
		Size = UDim2.new(1, 0, 0, 23),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	label(toast, {
		Name = "Body",
		Text = bodyText or "",
		Position = UDim2.fromOffset(9, 27),
		Size = UDim2.new(1, -18, 1, -33),
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
	})

	tween(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -18, 1, -18 - ((slot - 1) * 102)),
	})

	task.delay(length or 4, function()
		if not toast.Parent then
			return
		end
		tween(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(1, -18, 1, 18),
		})
		task.wait(0.35)
		if toast.Parent then
			toast:Destroy()
		end
		notifySlot = math.max(notifySlot - 1, 0)
	end)
end

----------------------------------------------------------------------
-- the screen gui
----------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "Kbar",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 500,
})

-- the notch is meant to meet the top edge of the screen, so this gui measures from the
-- real edge instead of from under Roblox's top bar. The notch is centred, where Roblox
-- draws nothing of its own. The health bar and orb are insetted by hand below.
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.None
end)
pcall(function()
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
end)

gui.Parent = playerGui
applyTransparency()
track(GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(applyTransparency))

----------------------------------------------------------------------
-- the notch
----------------------------------------------------------------------

local openHeight = CONFIG.infoRowHeight + CONFIG.trayHeight + CONFIG.chevronHeight
local closedHeight = CONFIG.infoRowHeight + CONFIG.chevronHeight

-- the cluster is exactly as wide as the notch, so the FPS and Ping boxes hug its edges
-- and slide with it when the tray opens or closes
local cluster = make("Frame", {
	Name = "Cluster",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(CONFIG.startOpen and CONFIG.notchWidth or CONFIG.notchWidthClosed, openHeight + CONFIG.notchRadius),
	BackgroundTransparency = 1,
}, gui)

-- the shape runs above the top edge, so only its bottom corners are rounded
local notch = panelled(make("Frame", {
	Name = "Notch",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -CONFIG.notchRadius),
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = CONFIG.colour.background,
	ClipsDescendants = true,
	ZIndex = 3,
}), 0)
corner(notch, CONFIG.notchRadius)
stroke(notch, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)
notch.Parent = cluster

local bar = make("Frame", {
	Name = "Bar",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, CONFIG.notchRadius),
	Size = UDim2.new(1, 0, 0, openHeight),
}, notch)

-- info row
local infoRow = make("Frame", {
	Name = "Info",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, CONFIG.infoRowHeight),
}, bar)

-- The line is one rich-text label that fills the row, so Roblox centres it itself:
-- TextXAlignment.Center centres the rendered line inside the label, the label fills
-- the row, the row fills the notch, and the notch is cut from TextBounds plus equal
-- padding on both sides. The width Roblox centres and the width the notch is built
-- from are the same number, so they cannot drift apart: not at any width, not open or
-- shut, and there is no pixel offset or measured glyph anywhere in this.
local SEPARATOR_COLOUR = "#2E2F31"

local function hexOf(colour)
	local ok, hex = pcall(function()
		return colour:ToHex()
	end)
	if ok and typeof(hex) == "string" and #hex == 6 then
		return "#" .. hex
	end
	return "#ECEEF1"
end

local function escaped(text)
	return (string.gsub(tostring(text), "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

local infoLabel = label(infoRow, {
	Name = "Line",
	Text = "",
	RichText = true,
	TextSize = CONFIG.textSize,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
})

-- what the line says. The three pieces are composed into one string, so they share
-- one baseline and one centring decision instead of three separate ones.
local infoText = {
	tag = "Indev",
	clock = "00:00",
	version = CONFIG.versionFallback,
}

local function composeInfo()
	infoLabel.Text = table.concat({
		'<font color="' .. hexOf(CONFIG.colour.text) .. '">' .. escaped(infoText.tag) .. "</font>",
		'<font color="' .. SEPARATOR_COLOUR .. '"> | </font>',
		'<stroke color="' .. hexOf(CONFIG.colour.dim) .. '" thickness="0.4" transparency="0.55">'
			.. escaped(infoText.clock)
			.. "</stroke>",
		'<font color="' .. SEPARATOR_COLOUR .. '"> | </font>',
		'<font color="' .. hexOf(CONFIG.colour.dim) .. '">' .. escaped(infoText.version) .. "</font>",
	})
end

composeInfo()

-- the width of the line Roblox actually renders. TextBounds is the same measurement
-- the text renderer uses to centre that line, so padding it equally on both sides is
-- centring by construction, not by arithmetic that can drift.
local function infoWidthNow()
	local ok, bounds = pcall(function()
		return infoLabel.TextBounds
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end
	return 0
end

-- set once the notch and its widths exist, further down: a longer tag or version
-- re-cuts a shut notch around the text it now holds
local relayoutNotch

track(infoLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
	if relayoutNotch then
		relayoutNotch()
	end
end))

-- the tray, four across
local tray = make("Frame", {
	Name = "Tray",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, CONFIG.infoRowHeight),
	Size = UDim2.new(1, 0, 0, CONFIG.trayHeight),
	Visible = CONFIG.startOpen,
}, bar)

make("UIGridLayout", {
	CellSize = UDim2.fromOffset(CONFIG.cellWidth, CONFIG.cellHeight),
	CellPadding = UDim2.fromOffset(CONFIG.cellPadding, CONFIG.cellPadding),
	FillDirectionMaxCells = 4,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	StartCorner = Enum.StartCorner.TopLeft,
}, tray)

local handlers = {}

local function press(buttonId)
	local handler = handlers[buttonId]
	if typeof(handler) == "function" then
		local ok, err = pcall(handler)
		if not ok then
			warn("[Kbar] " .. buttonId .. " failed: " .. tostring(err))
		end
		return true
	end
	return false
end

-- every tray button paints from one number, so the tray fades as a whole the way
-- the K strip does, instead of popping in on the last frame of the size tween
local trayItems = {}
local trayFade = CONFIG.startOpen and 1 or 0
local paintTray

for index, entry in ipairs(TRAY) do
	local button = make("TextButton", {
		Name = entry.id,
		Text = entry.label,
		Font = CONFIG.font,
		TextSize = CONFIG.buttonTextSize,
		TextColor3 = Color3.fromRGB(215, 220, 226),
		TextTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundColor3 = CONFIG.colour.buttonFill,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ZIndex = 4,
	}, tray)
	corner(button, 8)
	local buttonStroke = stroke(button, CONFIG.colour.buttonFill, CONFIG.strokeThickness, 1)

	local item = { button = button, stroke = buttonStroke, hovered = false }
	table.insert(trayItems, item)

	track(button.MouseEnter:Connect(function()
		item.hovered = true
		paintTray()
	end))
	track(button.MouseLeave:Connect(function()
		item.hovered = false
		paintTray()
	end))
	track(button.Activated:Connect(function()
		tween(buttonStroke, motionInfo(0.12), {
			Color = CONFIG.colour.accent,
			Transparency = 0.15,
		})
		task.delay(0.28, function()
			if button.Parent then
				buttonStroke.Color = CONFIG.colour.buttonFill
				paintTray()
			end
		end)
		press(entry.id)
	end))
end

-- how solid a tray button is at full fade: the faint fill and border it has
-- always drawn, and the brighter pair it takes under the pointer
local TRAY_FILL = 0.04
local TRAY_HOVER_FILL = 0.1
local TRAY_STROKE = 0.18
local TRAY_HOVER_STROKE = 0.34

local trayToken = 0

paintTray = function()
	for _, item in ipairs(trayItems) do
		local fill = item.hovered and TRAY_HOVER_FILL or TRAY_FILL
		local edge = item.hovered and TRAY_HOVER_STROKE or TRAY_STROKE
		item.button.TextTransparency = 1 - trayFade
		item.button.BackgroundTransparency = 1 - fill * trayFade
		item.stroke.Transparency = 1 - edge * trayFade
	end
end

-- walks the tray's fade to a goal, a frame at a time. A newer open or close takes
-- over by bumping the token, so an interrupted fade never fights the next one.
local function fadeTray(goal, duration)
	trayToken += 1
	local token = trayToken
	local from = trayFade
	local start = os.clock()
	local span = motionInfo(duration).Time
	task.spawn(function()
		while true do
			if token ~= trayToken then
				return
			end
			local alpha = span > 0 and math.min((os.clock() - start) / span, 1) or 1
			trayFade = from + (goal - from) * alpha
			paintTray()
			if alpha >= 1 then
				return
			end
			task.wait()
		end
	end)
end

paintTray()

-- the chevron is a full-width strip along the bottom of the notch, so the arrow can
-- sit at the right edge with the info row's text staying centred above it
local chevron = make("TextButton", {
	Name = "Chevron",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(0, CONFIG.infoRowHeight),
	Size = UDim2.new(1, 0, 0, CONFIG.chevronHeight),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	ZIndex = 5,
}, bar)

local chevronPlate = make("Frame", {
	Name = "Plate",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(34, CONFIG.chevronHeight),
	BackgroundColor3 = CONFIG.colour.buttonFill,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
}, chevron)
corner(chevronPlate, 7)

local arrow = make("Frame", {
	Name = "Arrow",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -CONFIG.chevronArrowInset, 0.5, 0),
	Size = UDim2.fromOffset(13, 8),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, chevron)

local arrowLegs = {}
local function arrowLeg(xFraction, degrees)
	local leg = make("Frame", {
		Name = "Leg",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(xFraction, 0, 1, 0),
		Size = UDim2.fromOffset(2, 9),
		Rotation = degrees,
		BackgroundColor3 = CONFIG.colour.dim,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, arrow)
	corner(leg, 1)
	table.insert(arrowLegs, leg)
	return leg
end
arrowLeg(0.28, 40)
arrowLeg(0.72, -40)

local trayOpen = CONFIG.startOpen

-- the notch closes to the width of its own info row plus a margin, and never past
-- the ceiling in CONFIG: the text is never clipped and never leaves a wide gap
local function closedWidth()
	return math.max(CONFIG.notchWidthClosed, infoWidthNow() + 32)
end

-- the width the notch is settled at or travelling to. Laying the row out again
-- compares against this, so a pass mid-tween cannot snap the notch to its target.
local lastClosedWidth = -1

-- the one tween that owns the cluster's width. Ver.txt can land inside the closing
-- tween, and a tween left running would write its stale goal over the width the new
-- text asked for, leaving the shut notch permanently a few pixels too wide.
local clusterTween

local function setOpen(open)
	trayOpen = open
	local targetWidth = open and CONFIG.notchWidth or closedWidth()
	if not open then
		lastClosedWidth = targetWidth
	end
	-- the tray fades as it measures, so nothing appears on the last frame of the
	-- size change: out fast on the way shut, in behind the opening
	if open then
		tray.Visible = true
		fadeTray(1, CONFIG.trayFadeIn)
	else
		fadeTray(0, CONFIG.trayFadeOut)
	end
	if clusterTween then
		pcall(function()
			clusterTween:Cancel()
		end)
	end
	clusterTween = tween(cluster, motionInfo(0.2), {
		Size = UDim2.fromOffset(
			targetWidth,
			(open and openHeight or closedHeight) + CONFIG.notchRadius
		),
	})
	tween(chevron, motionInfo(0.2), {
		Position = UDim2.new(0, 0, 0, open and (CONFIG.infoRowHeight + CONFIG.trayHeight) or CONFIG.infoRowHeight),
	})
	-- closed the arrow points down, into the tray; open it flips up, back to the bar
	tween(arrow, motionInfo(0.2), { Rotation = open and 0 or 180 })
	for _, leg in ipairs(arrowLegs) do
		tween(leg, motionInfo(0.2), {
			BackgroundColor3 = open and CONFIG.colour.text or CONFIG.colour.dim,
		})
	end
	if not open then
		task.delay(0.21, function()
			if not trayOpen then
				tray.Visible = false
			end
		end)
	end
end

-- a shut notch stays exactly as wide as the text it is showing: the version can
-- come back longer than the one this file shipped with, and the tag is whatever
-- Ver.txt says. Guarded so setting the same width twice cannot bounce.
relayoutNotch = function()
	if trayOpen then
		return
	end
	local width = closedWidth()
	if width == lastClosedWidth then
		return
	end
	lastClosedWidth = width
	if clusterTween then
		pcall(function()
			clusterTween:Cancel()
		end)
		clusterTween = nil
	end
	cluster.Size = UDim2.fromOffset(width, closedHeight + CONFIG.notchRadius)
end

setOpen(CONFIG.startOpen)

track(chevron.MouseEnter:Connect(function()
	tween(chevronPlate, motionInfo(0.12), { BackgroundTransparency = 0.9 })
end))
track(chevron.MouseLeave:Connect(function()
	tween(chevronPlate, motionInfo(0.12), { BackgroundTransparency = 1 })
end))
track(chevron.Activated:Connect(function()
	setOpen(not trayOpen)
end))

----------------------------------------------------------------------
-- the fps and ping readouts, flanking the notch
----------------------------------------------------------------------

-- the FPS and Ping boxes are exactly as tall as the closed bar, so their bottom
-- edge lines up with the notch instead of stopping short of it
local SIDE_BOX_HEIGHT = CONFIG.infoRowHeight + CONFIG.chevronHeight + CONFIG.notchRadius
local SIDE_TITLE_TOP = CONFIG.notchRadius + 2
local SIDE_TITLE_HEIGHT = 10
local SIDE_VALUE_TOP = SIDE_TITLE_TOP + SIDE_TITLE_HEIGHT + 1
local SIDE_VALUE_HEIGHT = SIDE_BOX_HEIGHT - SIDE_VALUE_TOP - 1

local function sideBox(name, title, side)
	local frame = panelled(make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(side == "left" and 1 or 0, 0),
		Position = side == "left" and UDim2.new(0, -CONFIG.sideBoxGap, 0, -CONFIG.notchRadius)
			or UDim2.new(1, CONFIG.sideBoxGap, 0, -CONFIG.notchRadius),
		Size = UDim2.fromOffset(CONFIG.sideBoxWidth, SIDE_BOX_HEIGHT),
		BackgroundColor3 = CONFIG.colour.background,
		ClipsDescendants = false,
		Visible = false,
		ZIndex = 3,
	}), 0)
	corner(frame, CONFIG.notchRadius)
	stroke(frame, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)
	frame.Parent = cluster

	label(frame, {
		Name = "Title",
		Text = title,
		TextColor3 = CONFIG.colour.dimmer,
		TextSize = CONFIG.smallTextSize,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, SIDE_TITLE_TOP),
		Size = UDim2.new(1, -8, 0, SIDE_TITLE_HEIGHT),
		ZIndex = 4,
	})

	local value = label(frame, {
		Name = "Value",
		Text = "0",
		TextSize = CONFIG.textSize,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, SIDE_VALUE_TOP),
		Size = UDim2.new(1, -8, 0, SIDE_VALUE_HEIGHT),
		ZIndex = 4,
	})

	return frame, value
end

local fpsBox, fpsValue = sideBox("Fps", "FPS", "left")
local pingBox, pingValue = sideBox("Ping", "Ping", "right")

----------------------------------------------------------------------
-- health bar, its red cross, the person orb and the K button
----------------------------------------------------------------------

local orbY = CONFIG.orbTop
local orbCentre = orbY + CONFIG.orbSize / 2

-- everything on the right is measured off the right edge, right to left:
-- orb, gap, health bar, gap, red cross, gap, K button
local orbRight = CONFIG.orbMargin
local barRight = orbRight + CONFIG.orbSize + 10
local barLeft = barRight + CONFIG.barWidth
local crossRight = barLeft + 8
local crossLeft = crossRight + CONFIG.crossSize
local keyRight = crossLeft + 10

local healthBar = panelled(make("Frame", {
	Name = "Health",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -barRight, 0, orbCentre),
	Size = UDim2.fromOffset(CONFIG.barWidth, CONFIG.barHeight),
	BackgroundColor3 = Color3.fromRGB(28, 30, 33),
	ClipsDescendants = true,
	ZIndex = 3,
}), 0)
stroke(healthBar, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)
healthBar.Parent = gui

local healthFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CONFIG.colour.green,
	BorderSizePixel = 0,
	ZIndex = 4,
}, healthBar)

-- the red cross sits just left of the bar
local cross = make("Frame", {
	Name = "Cross",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -crossRight, 0, orbCentre),
	Size = UDim2.fromOffset(CONFIG.crossSize, CONFIG.crossSize),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, gui)

make("Frame", {
	Name = "Vertical",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.34, 0, 1, 0),
	BackgroundColor3 = CONFIG.colour.red,
	BorderSizePixel = 0,
	ZIndex = 4,
}, cross)
make("Frame", {
	Name = "Horizontal",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 0, 0.34, 0),
	BackgroundColor3 = CONFIG.colour.red,
	BorderSizePixel = 0,
	ZIndex = 4,
}, cross)

local orb = make("TextButton", {
	Name = "People",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -orbRight, 0, orbY),
	Size = UDim2.fromOffset(CONFIG.orbSize, CONFIG.orbSize),
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.colour.background,
	ZIndex = 3,
}, gui)
corner(orb, CONFIG.orbSize / 2)
stroke(orb, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)

local glyph = make("Frame", {
	Name = "Glyph",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(18, 18),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, orb)

local head = make("Frame", {
	Name = "Head",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 1),
	Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = CONFIG.colour.accent,
	BorderSizePixel = 0,
	ZIndex = 5,
}, glyph)
corner(head, 4)

local shoulders = make("Frame", {
	Name = "Shoulders",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 11),
	Size = UDim2.fromOffset(16, 8),
	BackgroundColor3 = CONFIG.colour.accent,
	BorderSizePixel = 0,
	ZIndex = 5,
}, glyph)
corner(shoulders, 4)

-- the K button is created with the pill below, so it can sit inside it

-- health follows the local character, and rebinds on respawn
local healthConnection = nil

-- Roblox's own health bar, off: this gui draws one instead
local function hideCoreHealth()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end

local function bindHealth(character)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	healthFill.Size = UDim2.fromScale(0, 1)
	if not character then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	if CONFIG.hideDefaultHealth then
		pcall(function()
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end)
	end
	local function update()
		if not humanoid.Parent then
			return
		end
		local maxHealth = math.max(humanoid.MaxHealth, 1)
		local fraction = math.clamp(humanoid.Health / maxHealth, 0, 1)
		healthFill.Size = UDim2.fromScale(fraction, 1)
	end
	update()
	healthConnection = humanoid.HealthChanged:Connect(update)
	track(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
end

hideCoreHealth()
bindHealth(player.Character)
track(player.CharacterAdded:Connect(function(character)
	bindHealth(character)
	task.delay(1, hideCoreHealth)
end))

----------------------------------------------------------------------
-- the K strip
----------------------------------------------------------------------

-- the strip grows out of the left of the K button, so its buttons are uncovered
-- in place rather than a panel dropping onto the screen
local STRIP = {
	{ id = "alog", text = "ALOG" },
	{ id = "hop", text = "SHOP" },
	{ id = "exit", text = "Exit" },
	{ id = "notify", text = "Notify" },
}

-- closed, the pill is the K alone; open, it is the K plus every button
local stripClosedWidth = CONFIG.menuStripPadding * 2 + CONFIG.menuStripKey
local stripOpenWidth = stripClosedWidth + #STRIP * (CONFIG.menuStripButton + CONFIG.menuStripGap)

-- where a button sits, measured from the pill's right edge at the open width. That
-- number never changes: the right edge is pinned, so growing the pill leftward
-- uncovers the buttons where they already are. A list layout would re-place all
-- four of them every frame the width moved, which is the squirming this removes.
local function buttonOffsetFromRight(index)
	local offset = CONFIG.menuStripPadding
	for _ = index + 1, #STRIP do
		offset += CONFIG.menuStripButton + CONFIG.menuStripGap
	end
	return offset
end

local menuOpen = false
local menuToken = 0
local stripItems = {}

-- how far the strip is out, and how solid its labels are, both 0..1. The
-- animation writes these two numbers every frame and drawStrip paints from
-- them, so an interrupted open can be closed from wherever it got to.
local stripFill = 0
local stripFade = 0

-- the pill's right edge is pinned where the K sits, so every pixel it grows
-- comes out of its left side and the buttons slide out from under the K
local strip = panelled(make("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -keyRight, 0, orbCentre),
	Size = UDim2.fromOffset(stripClosedWidth, CONFIG.menuStripHeight),
	BackgroundColor3 = CONFIG.colour.background,
	ClipsDescendants = true,
	Visible = true,
	ZIndex = 8,
}), 0)
corner(strip, 10)
local stripStroke = stroke(strip, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)
strip.Parent = gui

-- nothing here uses a layout or padding: both would re-place every button each
-- frame the width moved, and the whole point is that the buttons stand still
local keyButton = make("TextButton", {
	Name = "MenuKey",
	Text = "K",
	Font = CONFIG.font,
	TextSize = CONFIG.textSize + 2,
	TextColor3 = CONFIG.colour.text,
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.colour.buttonFill,
	BackgroundTransparency = 0.94,
	BorderSizePixel = 0,
	-- pinned to the left edge, so the K rides out with the pill and back
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, CONFIG.menuStripPadding, 0.5, 0),
	Size = UDim2.fromOffset(CONFIG.menuStripKey, CONFIG.menuStripKey),
	LayoutOrder = 0,
	ZIndex = 9,
}, strip)
corner(keyButton, 8)
local keyStroke = stroke(keyButton, CONFIG.colour.edge, CONFIG.strokeThickness, 0.4)

local function drawStrip()
	strip.Size = UDim2.fromOffset(
		stripClosedWidth + (stripOpenWidth - stripClosedWidth) * stripFill,
		CONFIG.menuStripHeight
	)
	for _, item in ipairs(stripItems) do
		item.button.TextTransparency = 1 - stripFade
		item.button.BackgroundTransparency = 1 - 0.85 * stripFade
		item.stroke.Transparency = 1 - 0.45 * stripFade
	end
end

-- walks one number to `goal` over `duration`, a frame at a time, and paints
-- through drawStrip as it goes. Returns false the moment a newer open or close
-- takes over, so an interrupted animation never lands on top of the next one.
local function animate(duration, goal, get, set)
	-- `from` is read once: alpha is the fraction of the whole move, so applying
	-- it to a value that is already moving would race ahead of the clock
	local from = get()
	local start = os.clock()
	local token = menuToken
	-- TweenInfo's length is .Time; there is no .Duration on it
	local span = motionInfo(duration).Time
	while true do
		if token ~= menuToken then
			return false
		end
		local elapsed = os.clock() - start
		local alpha = span > 0 and math.min(elapsed / span, 1) or 1
		set(from + (goal - from) * alpha)
		if alpha >= 1 then
			return true
		end
		task.wait()
	end
end

local setMenuOpen

for index, entry in ipairs(STRIP) do
	local button = make("TextButton", {
		Name = entry.id,
		Text = entry.text,
		Font = CONFIG.font,
		TextSize = CONFIG.buttonTextSize,
		TextColor3 = CONFIG.colour.text,
		TextTransparency = 1,
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.colour.panelTop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- pinned to the right edge at the offset it holds when the pill is fully
		-- open: the growing pill uncovers it there, it never slides or squashes
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -buttonOffsetFromRight(index), 0.5, 0),
		Size = UDim2.fromOffset(CONFIG.menuStripButton, CONFIG.menuStripButtonHeight),
		-- hidden while the pill is shut: the rightmost button's box reaches into
		-- the closed pill and would eat clicks meant for the K
		Visible = false,
		LayoutOrder = index + 1,
		ZIndex = 9,
	}, strip)
	corner(button, 6)
	local buttonStroke = stroke(button, CONFIG.colour.edge, 2, 1)

	table.insert(stripItems, { button = button, stroke = buttonStroke })

	track(button.MouseEnter:Connect(function()
		if stripFade < 0.5 then
			return
		end
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.3 })
	end))
	track(button.MouseLeave:Connect(function()
		buttonStroke.Transparency = 1 - 0.45 * stripFade
	end))
	track(button.Activated:Connect(function()
		if not menuOpen then
			return
		end
		setMenuOpen(false)
		press(entry.id)
	end))
end

setMenuOpen = function(open)
	open = not not open
	if menuOpen == open then
		return
	end
	menuOpen = open
	menuToken += 1

	tween(keyStroke, motionInfo(0.15), {
		Color = open and CONFIG.colour.accent or CONFIG.colour.edge,
		Transparency = open and 0.15 or 0.35,
	})

	local function runFill(duration, goal)
		return animate(duration, goal, function()
			return stripFill
		end, function(value)
			stripFill = value
			drawStrip()
		end)
	end

	local function runFade(duration, goal)
		return animate(duration, goal, function()
			return stripFade
		end, function(value)
			stripFade = value
			drawStrip()
		end)
	end

	-- the buttons only take clicks while the pill is out
	local function setStripHit(enabled)
		for _, item in ipairs(stripItems) do
			item.button.Visible = enabled
		end
	end

	if open then
		setStripHit(true)
		task.spawn(function()
			-- one gesture: the pill opens and its labels fade in together. The buttons
			-- hold their position the whole time, so there is nothing to watch move.
			task.spawn(runFill, CONFIG.menuStripOpenTime, 1)
			runFade(CONFIG.menuStripFadeIn, 1)
		end)
	else
		task.spawn(function()
			-- out fast, then the pill closes behind it
			if not runFade(CONFIG.menuStripFadeOut, 0) then
				return
			end
			if runFill(CONFIG.menuStripCloseTime, 0) then
				setStripHit(false)
			end
		end)
	end
end

drawStrip()

----------------------------------------------------------------------
-- features
----------------------------------------------------------------------

local fpsEnabled = false
local pingEnabled = false

local frameCount = 0
local frameTime = 0
local fpsReading = 0

track(RunService.RenderStepped:Connect(function(delta)
	frameCount += 1
	frameTime += delta
	if frameTime >= CONFIG.statRefresh then
		fpsReading = math.floor(frameCount / frameTime + 0.5)
		frameCount = 0
		frameTime = 0
	end
end))

local function currentPing()
	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and typeof(value) == "number" and value == value then
		return math.floor(value * 1000 + 0.5)
	end
	local okStats, stats = pcall(function()
		return game:GetService("Stats")
	end)
	if okStats and stats then
		local okItem, item = pcall(function()
			return stats.Network.ServerStatsItem["Data Ping"]
		end)
		if okItem and item then
			local okValue, ping = pcall(function()
				return item:GetValue()
			end)
			if okValue and typeof(ping) == "number" then
				return math.floor(ping + 0.5)
			end
		end
	end
	return 0
end

task.spawn(function()
	while true do
		fpsValue.Text = fpsEnabled and tostring(fpsReading) or ""
		if pingEnabled then
			pingValue.Text = tostring(currentPing())
		else
			pingValue.Text = ""
		end
		task.wait(math.max(CONFIG.statRefresh, 0.25))
	end
end)

local function setFpsDisplay(on)
	fpsEnabled = on
	fpsBox.Visible = on
	notify("FPS Display", on and "Enabled" or "Disabled")
end

local function setPingDisplay(on)
	pingEnabled = on
	pingBox.Visible = on
	notify("Ping Display", on and "Enabled" or "Disabled")
end

local function runScript(name, url)
	notify(name, "Loading " .. name)
	task.spawn(function()
		local ok, err = pcall(function()
			local source = httpGet(url)
			if typeof(loadstring) == "function" then
				local chunk = loadstring(source)
				if not chunk then
					error("loadstring returned nothing")
				end
				chunk()
				return
			end
			-- Studio clients have no loadstring: compile it as a real LocalScript instead
			local holder = Instance.new("LocalScript")
			holder.Name = name .. "Script"
			holder.Source = source
			holder.Parent = playerGui
		end)
		if not ok then
			warn("[Kbar] " .. name .. ": " .. tostring(err))
			notify(name, "Failed to load")
		end
	end)
end

-- server hop, the method Infinite Yield uses
local function serverHop()
	notify("SHOP", "Switching servers")
	task.spawn(function()
		local ok, err = pcall(function()
			local servers = {}
			local raw = httpGet(
				"https://games.roblox.com/v1/games/"
					.. tostring(game.PlaceId)
					.. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
			)
			local body = HttpService:JSONDecode(raw)
			if body and body.data then
				for _, entry in next, body.data do
					if
						type(entry) == "table"
						and tonumber(entry.playing)
						and tonumber(entry.maxPlayers)
						and entry.playing < entry.maxPlayers
						and entry.id ~= game.JobId
					then
						table.insert(servers, entry.id)
					end
				end
			end
			if #servers > 0 then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player)
				return
			end
			notify("SHOP", "No server found. Try again later.")
		end)
		if not ok then
			warn("[Kbar] server hop: " .. tostring(err))
			notify("SHOP", "No server found. Try again later.")
		end
	end)
end

-- leave the game, back to the app's home screen
local function leaveGame()
	notify("Exit", "Bye")
	task.delay(0.7, function()
		local ok = pcall(function()
			game:Shutdown()
		end)
		if not ok then
			pcall(function()
				player:Kick("Bye")
			end)
		end
	end)
end

-- Roblox's own player list, the one Tab opens
local function togglePlayerList()
	local usedExecutorKeypress = false
	pcall(function()
		if typeof(keypress) == "function" and typeof(keyrelease) == "function" then
			keypress(Enum.KeyCode.Tab)
			keyrelease(Enum.KeyCode.Tab)
			usedExecutorKeypress = true
		end
	end)
	if usedExecutorKeypress then
		return
	end
	pcall(function()
		local virtualInput = game:GetService("VirtualInputManager")
		virtualInput:SendKeyEvent(true, Enum.KeyCode.Tab, false, false)
		task.wait(0.05)
		virtualInput:SendKeyEvent(false, Enum.KeyCode.Tab, false, false)
	end)
end

handlers.fps = function()
	setFpsDisplay(not fpsEnabled)
end
handlers.ping = function()
	setPingDisplay(not pingEnabled)
end
handlers.lssr = function()
	runScript("LSSR SW", CONFIG.scripts.lssr)
end
handlers.freecam = function()
	runScript("Free Camera", CONFIG.scripts.freecam)
end
handlers.khub = function()
	runScript("KHub", CONFIG.scripts.khub)
end
handlers.anim = function()
	runScript("Anim Changer", CONFIG.scripts.anim)
end
handlers.infyield = function()
	runScript("Inf Yield", CONFIG.scripts.infyield)
end
handlers.meow = function()
	playSound(CONFIG.meowSound, 0.8)
	notify("Click 2 MEOW!", "Meow", nil, true)
end
handlers.alog = function()
	runScript("Audio Logger", CONFIG.scripts.alogger)
end
handlers.hop = serverHop
handlers.exit = leaveGame
handlers.notify = function()
	notify("Notify", "Test Notify!")
end

----------------------------------------------------------------------
-- chat commands, k- prefix
----------------------------------------------------------------------

local COMMANDS = {
	["k-hop"] = { title = "SHOP", run = handlers.hop },
	["k-alog"] = { title = "Audio Logger", run = handlers.alog },
	["k-lssrsw"] = { title = "LSSR SW", run = handlers.lssr },
	["k-fc"] = { title = "Free Camera", run = handlers.freecam },
	["k-iy"] = { title = "Inf Yield", run = handlers.infyield },
	["k-anim"] = { title = "Anim Changer", run = handlers.anim },
	["k-hub"] = { title = "KHub", run = handlers.khub },
}

local lastCommand = nil
local lastCommandAt = 0

local function commandName(text)
	if typeof(text) ~= "string" then
		return nil
	end
	return string.match(string.lower(text), "^%s*(.-)%s*$")
end

-- does this text name a command, without running it: the chat hook uses it to
-- decide whether the message should be swallowed
local function isCommand(text)
	local name = commandName(text)
	return name ~= nil and COMMANDS[name] ~= nil
end

-- returns true when the text was a command
local function runCommand(text)
	local name = commandName(text)
	if name == nil then
		return false
	end
	local entry = COMMANDS[name]
	if not entry then
		return false
	end
	local now = os.clock()
	-- one message can arrive down both chat paths; run it once
	if name == lastCommand and now - lastCommandAt < 0.4 then
		return true
	end
	lastCommand = name
	lastCommandAt = now
	task.spawn(entry.run)
	return true
end

local function bindCommands()
	-- Chatted fires whichever chat system the game runs, so it is the path that
	-- is always there
	track(player.Chatted:Connect(function(text)
		runCommand(text)
	end))

	-- this hook only hides the command from the chat log. It is optional, so its
	-- failure is reported rather than thrown
	local okHook = pcall(function()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			return
		end
		local previousCallback = TextChatService.OnIncomingMessage
		TextChatService.OnIncomingMessage = function(message)
			local properties = nil
			if typeof(previousCallback) == "function" then
				local ok, result = pcall(previousCallback, message)
				if ok then
					properties = result
				end
			end
			local source = message.TextSource
			if source and source.UserId == player.UserId and isCommand(message.Text) then
				properties = properties or Instance.new("TextChatMessageProperties")
				properties.Text = ""
				return properties
			end
			return properties
		end
	end)
	if not okHook then
		warn("[Kbar] commands will show in chat")
	end
end

-- the person orb opens and closes Roblox's own list
track(orb.Activated:Connect(togglePlayerList))
track(orb.MouseEnter:Connect(function()
	tween(glyph, motionInfo(0.12), { Size = UDim2.fromOffset(21, 21) })
end))
track(orb.MouseLeave:Connect(function()
	tween(glyph, motionInfo(0.12), { Size = UDim2.fromOffset(18, 18) })
end))

-- the K button opens and closes its menu
track(keyButton.MouseEnter:Connect(function()
	tween(keyButton, motionInfo(0.1), { BackgroundTransparency = 0.84 })
end))
track(keyButton.MouseLeave:Connect(function()
	tween(keyButton, motionInfo(0.1), { BackgroundTransparency = 0.94 })
end))
track(keyButton.Activated:Connect(function()
	setMenuOpen(not menuOpen)
end))

-- K toggles the menu, Escape closes it
track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		setMenuOpen(not menuOpen)
	elseif input.KeyCode == Enum.KeyCode.Escape and menuOpen then
		setMenuOpen(false)
	end
end))

----------------------------------------------------------------------
-- clock and version
----------------------------------------------------------------------

-- DateTime gives the player's own local time, which is what a clock in the corner
-- should show. os.date is the fallback for executors that hide DateTime, and a
-- raw os.time stamp is the last resort, so the label never sits on a placeholder.
local function localClock()
	-- FormatLocalTime already answers in the player's own zone, and it takes a
	-- strftime pattern. Putting ToLocalTime() in front of it returns something
	-- with no such method, and "HH:mm" is not a pattern, so the clock never moved.
	local okDate, text = pcall(function()
		return DateTime.now():FormatLocalTime("%H:%M", "en-us")
	end)
	if okDate and typeof(text) == "string" and string.match(text, "^%d%d:%d%d$") then
		return text
	end
	local okOs, dated = pcall(function()
		return os.date("%H:%M")
	end)
	if okOs and typeof(dated) == "string" and string.match(dated, "^%d%d:%d%d$") then
		return dated
	end
	return nil
end

task.spawn(function()
	while true do
		local reading = localClock()
		if reading and reading ~= infoText.clock then
			infoText.clock = reading
			composeInfo()
		end
		local okNow, now = pcall(function()
			return os.time()
		end)
		local untilNextMinute = 5
		if okNow and typeof(now) == "number" then
			untilNextMinute = 60 - (now % 60)
		end
		-- wake on the minute, so the number changes when the minute does
		task.wait(math.clamp(untilNextMinute, 1, 60))
	end
end)

----------------------------------------------------------------------
-- update prompt
----------------------------------------------------------------------

-- A number in Ver.txt newer than the one this file carries is the only thing that
-- puts this on screen. Deny silences it for the rest of this session; Update drops
-- this copy and runs the file at CONFIG.updateUrl in its place.
local updateShown = false
local updateDenied = false

local function versionParts(text)
	local parts = {}
	for piece in string.gmatch(text or "", "%d+") do
		table.insert(parts, tonumber(piece) or 0)
	end
	return parts
end

-- the build letter after the number: 1.3b is one build past 1.3, and b is past a,
-- so a lettered file is newer than the bare number it shares
local function versionSuffix(text)
	return string.match(string.lower(tostring(text or "")), "(%a)$") or ""
end

local function isNewer(latest, running)
	local a = versionParts(latest)
	local b = versionParts(running)
	if #a == 0 then
		return false
	end
	for index = 1, math.max(#a, #b) do
		local x = a[index] or 0
		local y = b[index] or 0
		if x > y then
			return true
		elseif x < y then
			return false
		end
	end
	return versionSuffix(latest) > versionSuffix(running)
end

local function applyUpdate()
	-- drop this copy first, so the rerun never stacks a second bar on this one
	if _G.Kbar and typeof(_G.Kbar.destroy) == "function" then
		pcall(_G.Kbar.destroy)
	end
	task.wait(0.1)
	local ok, err = pcall(function()
		local source = httpGet(CONFIG.updateUrl)
		if typeof(loadstring) == "function" then
			local chunk = loadstring(source)
			if not chunk then
				error("loadstring returned nothing")
			end
			chunk()
			return
		end
		-- Studio has no loadstring: run the new file as a LocalScript instead
		local holder = Instance.new("LocalScript")
		holder.Name = "KbarUpdate"
		holder.Source = source
		holder.Parent = playerGui
	end)
	if not ok then
		warn("[Kbar] update failed: " .. tostring(err))
	end
end

local function showUpdatePrompt(latest)
	if updateShown or updateDenied then
		return
	end
	updateShown = true

	local overlay = make("Frame", {
		Name = "UpdatePrompt",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, gui)
	-- swallow clicks on the shade, so nothing behind the panel can be pressed
	overlay.Active = true

	local panel = panelled(make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 130),
		BackgroundColor3 = CONFIG.colour.background,
		ZIndex = 41,
	}), 0)
	corner(panel, 10)
	stroke(panel, CONFIG.colour.edge, CONFIG.strokeThickness, 0.2)
	panel.Parent = overlay

	label(panel, {
		Name = "Title",
		Text = "Update available: " .. tostring(latest),
		Position = UDim2.fromOffset(0, 13),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = CONFIG.textSize,
		ZIndex = 42,
	})

	label(panel, {
		Name = "Body",
		Text = "An update is available, do you want to update now?",
		Position = UDim2.fromOffset(20, 36),
		Size = UDim2.new(1, -40, 0, 32),
		TextSize = CONFIG.buttonTextSize,
		TextColor3 = CONFIG.colour.dim,
		TextWrapped = true,
		ZIndex = 42,
	})

	local function promptButton(name, text, fill, textColour, offsetX)
		local button = make("TextButton", {
			Name = name,
			Text = text,
			Font = CONFIG.font,
			TextSize = CONFIG.buttonTextSize,
			TextColor3 = textColour,
			AutoButtonColor = false,
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, offsetX, 0, 80),
			Size = UDim2.fromOffset(124, 32),
			ZIndex = 42,
		}, panel)
		corner(button, 7)
		stroke(button, CONFIG.colour.edge, 2, 0.45)
		return button
	end

	local updateButton = promptButton("Update", "Update", CONFIG.colour.buttonFill, CONFIG.colour.background, -66)
	local denyButton = promptButton("Deny", "Deny", CONFIG.colour.red, CONFIG.colour.text, 66)

	track(updateButton.Activated:Connect(function()
		overlay:Destroy()
		task.spawn(applyUpdate)
	end))

	track(denyButton.Activated:Connect(function()
		-- denied: gone for the rest of this game, and not asked again this session
		updateDenied = true
		overlay:Destroy()
	end))
end

local function refreshVersion()
	local ok, body = pcall(function()
		return httpGet(CONFIG.verUrl)
	end)
	if ok and typeof(body) == "string" and #body > 0 then
		local tag, version
		for line in string.gmatch(body, "[^\r\n]+") do
			local trimmed = string.match(line, "^%s*(.-)%s*$") or ""
			if #trimmed > 0 then
				if not tag then
					tag = trimmed
				elseif not version then
					version = trimmed
				end
			end
		end
		-- a version is digits, an optional dot, digits, and an optional build letter,
		-- so 1.3b is a version and 1.3 is too. Anything else in that line is noise,
		-- not a number to print, so it is dropped rather than shown.
		if version and not string.match(version, "^%d+%.?%d*%a?$") then
			version = nil
		end
		-- a tag from the file is drawn inside the notch, so it is capped: a long one
		-- would stretch the shut bar past the screen edge
		if tag and #tag > 14 then
			tag = string.sub(tag, 1, 14)
		end
		if tag then
			infoText.tag = tag
		end
		infoText.version = version or CONFIG.versionFallback
		composeInfo()
		if version and isNewer(version, CONFIG.runningVersion) then
			-- the file is ahead of this copy: offer the swap, once
			task.spawn(showUpdatePrompt, version)
		end
		return
	end
	-- no answer: show what this file says it is, not a placeholder
	infoText.tag = "Indev"
	infoText.version = CONFIG.versionFallback
	composeInfo()
end

task.spawn(function()
	while true do
		refreshVersion()
		task.wait(CONFIG.verRefresh)
	end
end)

----------------------------------------------------------------------
-- chat commands, bound last
----------------------------------------------------------------------

-- The chat hook is the only part of this file that depends on how the executor
-- exposes TextChatService, so it runs after everything else and inside a pcall:
-- a chat that refuses the callback must never take the bar down with it.
local okChat, chatError = pcall(bindCommands)
if not okChat then
	warn("[Kbar] chat commands unavailable: " .. tostring(chatError))
end

----------------------------------------------------------------------
-- public handle
----------------------------------------------------------------------

_G.Kbar = {
	version = CONFIG.runningVersion,
	notify = notify,
	setOpen = setOpen,
	setMenuOpen = setMenuOpen,
	commands = COMMANDS,
	runCommand = runCommand,
	toggleMenu = function()
		setMenuOpen(not menuOpen)
	end,
	toggleFps = function()
		setFpsDisplay(not fpsEnabled)
	end,
	togglePing = function()
		setPingDisplay(not pingEnabled)
	end,
	destroy = function()
		for _, connection in ipairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections = {}
		if gui.Parent then
			gui:Destroy()
		end
		if notifyGui.Parent then
			notifyGui:Destroy()
		end
	end,
}
