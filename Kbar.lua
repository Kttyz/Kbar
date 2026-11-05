--!nonstrict
--[[
	Kbar 1.1 — a client-side notch bar for Roblox.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/Kbar/main/Kbar.lua"))()

	Top centre, flush with the screen edge:
		Indev | 12:00 | 1.1        tag and version come from Ver.txt
		the tray, four across: FPS Display, LSSR SW, Free Camera, Ping Display,
		                       Load Inf Yield, KHub, Anim Changer, Click 2 MEOW!
		the arrow, inside the box, at the bottom of whatever is showing

	Left and right of the notch: the FPS and Ping readouts, off until toggled on.
	Top right: the person orb (Roblox's own player list), the health bar and its
	red cross, and the K button, which opens the menu below it.
	The K strip slides out to the left of the K button: ALOG, SHOP, Exit, Notify.
	It fades its buttons in once it has finished opening, and fades them out fast
	before it closes.

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
	notchWidthClosed = 232,
	notchRadius = 14,
	infoRowHeight = 32,
	trayHeight = 94,
	chevronHeight = 16,

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

	menuStripHeight = 30,
	menuStripButton = 58,
	menuStripGap = 4,
	menuStripPadding = 4,
	menuStripOpenTime = 0.18,
	menuStripFadeIn = 0.16,
	menuStripFadeOut = 0.07,

	font = Enum.Font.Code,
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

local function make(class, properties, parent)
	local instance = Instance.new(class)
	for key, value in pairs(properties) do
		instance[key] = value
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

local cells = make("Frame", {
	Name = "Cells",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(1, -24, 1, 0),
}, infoRow)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10),
}, cells)

local function cellSeparator(order)
	return make("Frame", {
		Name = "Separator",
		BackgroundColor3 = CONFIG.colour.text,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 14),
		LayoutOrder = order,
	}, cells)
end

local tagLabel = label(cells, {
	Name = "Tag",
	Text = "Indev",
	LayoutOrder = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 14),
})
make("UISizeConstraint", { MaxSize = Vector2.new(88, 14) }, tagLabel)

cellSeparator(2)

local clockLabel = label(cells, {
	Name = "Clock",
	Text = "00:00",
	TextSize = CONFIG.textSize + 1,
	LayoutOrder = 3,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 16),
})
make("UIStroke", {
	Color = CONFIG.colour.text,
	Thickness = 0.4,
	Transparency = 0.55,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
}, clockLabel)

cellSeparator(4)

local verLabel = label(cells, {
	Name = "Ver",
	Text = "1.0",
	TextColor3 = CONFIG.colour.dim,
	LayoutOrder = 5,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 14),
})
make("UISizeConstraint", { MaxSize = Vector2.new(88, 14) }, verLabel)

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

for index, entry in ipairs(TRAY) do
	local button = make("TextButton", {
		Name = entry.id,
		Text = entry.label,
		Font = CONFIG.font,
		TextSize = CONFIG.buttonTextSize,
		TextColor3 = Color3.fromRGB(215, 220, 226),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundColor3 = CONFIG.colour.buttonFill,
		BackgroundTransparency = 0.96,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ZIndex = 4,
	}, tray)
	corner(button, 8)
	local buttonStroke = stroke(button, CONFIG.colour.buttonFill, CONFIG.strokeThickness, 0.82)

	track(button.MouseEnter:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.9 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.66 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.96 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.82 })
	end))
	track(button.Activated:Connect(function()
		tween(buttonStroke, motionInfo(0.12), {
			Color = CONFIG.colour.accent,
			Transparency = 0.15,
		})
		task.delay(0.28, function()
			if button.Parent then
				tween(buttonStroke, motionInfo(0.2), {
					Color = CONFIG.colour.buttonFill,
					Transparency = 0.82,
				})
			end
		end)
		press(entry.id)
	end))
end

-- the chevron lives inside the notch, at its bottom edge, and rides down with the tray
local chevron = make("TextButton", {
	Name = "Chevron",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, CONFIG.infoRowHeight),
	Size = UDim2.fromOffset(56, CONFIG.chevronHeight),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	ZIndex = 5,
}, bar)

local chevronPlate = make("Frame", {
	Name = "Plate",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CONFIG.colour.buttonFill,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
}, chevron)
corner(chevronPlate, 8)

local arrow = make("Frame", {
	Name = "Arrow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(11, 7),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, chevron)

local arrowLegs = {}
local function arrowLeg(xFraction, degrees)
	local leg = make("Frame", {
		Name = "Leg",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(xFraction, 0, 1, 0),
		Size = UDim2.fromOffset(2, 8),
		Rotation = degrees,
		BackgroundColor3 = CONFIG.colour.dim,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, arrow)
	corner(leg, 1)
	table.insert(arrowLegs, leg)
	return leg
end
arrowLeg(0.28, 38)
arrowLeg(0.72, -38)

local trayOpen = CONFIG.startOpen

local function setOpen(open)
	trayOpen = open
	tray.Visible = true
	tween(cluster, motionInfo(0.2), {
		Size = UDim2.fromOffset(
			open and CONFIG.notchWidth or CONFIG.notchWidthClosed,
			(open and openHeight or closedHeight) + CONFIG.notchRadius
		),
	})
	tween(chevron, motionInfo(0.2), {
		Position = UDim2.new(0.5, 0, 0, open and (CONFIG.infoRowHeight + CONFIG.trayHeight) or CONFIG.infoRowHeight),
	})
	tween(arrow, motionInfo(0.2), { Rotation = open and 180 or 0 })
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

local SIDE_BOX_HEIGHT = CONFIG.infoRowHeight + CONFIG.notchRadius
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

-- the K button, its own thing, beside the health bar
local keyButton = make("TextButton", {
	Name = "MenuKey",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -keyRight, 0, orbCentre),
	Size = UDim2.fromOffset(CONFIG.keySize, CONFIG.keySize),
	Text = "K",
	Font = CONFIG.font,
	TextSize = CONFIG.textSize + 2,
	TextColor3 = CONFIG.colour.text,
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.colour.background,
	ZIndex = 3,
}, gui)
corner(keyButton, 8)
local keyStroke = stroke(keyButton, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)

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

-- the strip grows out of the left of the K button, so its buttons slide out
-- from under the key rather than a panel dropping onto the screen
local STRIP = {
	{ id = "alog", text = "ALOG" },
	{ id = "hop", text = "SHOP" },
	{ id = "exit", text = "Exit" },
	{ id = "notify", text = "Notify" },
}

local stripWidth = CONFIG.menuStripPadding * 2
	+ #STRIP * CONFIG.menuStripButton
	+ (#STRIP - 1) * CONFIG.menuStripGap

local menuOpen = false
local menuToken = 0
local stripItems = {}

local strip = panelled(make("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -(keyRight + CONFIG.keySize + CONFIG.menuStripGap), 0, orbCentre),
	Size = UDim2.fromOffset(0, CONFIG.menuStripHeight),
	BackgroundColor3 = CONFIG.colour.background,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 8,
}), 0)
corner(strip, CONFIG.menuStripHeight / 2)
local stripStroke = stroke(strip, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)
strip.Parent = gui

make("UIPadding", {
	PaddingLeft = UDim.new(0, CONFIG.menuStripPadding),
	PaddingRight = UDim.new(0, CONFIG.menuStripPadding),
}, strip)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, CONFIG.menuStripGap),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, strip)

-- one number drives every transparency in the strip, so the fade in and the
-- fade out stay in step however many buttons sit in it
local stripFade = Instance.new("NumberValue")
stripFade.Name = "StripFade"
stripFade.Value = 0

local function applyStripFade(value)
	for _, item in ipairs(stripItems) do
		item.button.TextTransparency = 1 - value
		item.button.BackgroundTransparency = 1 - 0.94 * value
		item.stroke.Transparency = 1 - 0.55 * value
	end
	stripStroke.Transparency = 0.35 + (1 - value) * 0.65
end

track(stripFade:GetPropertyChangedSignal("Value"):Connect(function()
	applyStripFade(stripFade.Value)
end))

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
		BackgroundColor3 = CONFIG.colour.buttonFill,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CONFIG.menuStripButton, CONFIG.menuStripHeight - 8),
		LayoutOrder = index,
	}, strip)
	corner(button, 6)
	local buttonStroke = stroke(button, CONFIG.colour.buttonFill, 2, 1)

	table.insert(stripItems, { button = button, stroke = buttonStroke })

	track(button.MouseEnter:Connect(function()
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.3 })
	end))
	track(button.MouseLeave:Connect(function()
		applyStripFade(stripFade.Value)
	end))
	track(button.Activated:Connect(function()
		setMenuOpen(false)
		press(entry.id)
	end))
end

function setMenuOpen(open)
	if menuOpen == open then
		return
	end
	menuOpen = open
	menuToken += 1
	local token = menuToken

	tween(keyStroke, motionInfo(0.15), {
		Color = open and CONFIG.colour.accent or CONFIG.colour.edge,
		Transparency = open and 0.15 or 0.35,
	})

	if open then
		strip.Visible = true
		local grow = tween(strip, motionInfo(CONFIG.menuStripOpenTime), {
			Size = UDim2.fromOffset(stripWidth, CONFIG.menuStripHeight),
		})
		-- the buttons stay blank until the strip has finished sliding out
		grow.Completed:Connect(function()
			if token ~= menuToken or not menuOpen then
				return
			end
			tween(stripFade, motionInfo(CONFIG.menuStripFadeIn), { Value = 1 })
		end)
	else
		-- out fast, then the strip closes behind it
		tween(stripFade, TweenInfo.new(CONFIG.menuStripFadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = 0,
		})
		task.delay(CONFIG.menuStripFadeOut, function()
			if token ~= menuToken or menuOpen then
				return
			end
			local shrink = tween(strip, motionInfo(0.13), {
				Size = UDim2.fromOffset(0, CONFIG.menuStripHeight),
			})
			shrink.Completed:Connect(function()
				if token == menuToken and not menuOpen then
					strip.Visible = false
				end
			end)
		end)
	end
end

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
			local source = game:HttpGet(url)
			local chunk = loadstring(source)
			if not chunk then
				error("loadstring returned nothing")
			end
			chunk()
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
			local raw = game:HttpGet(
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

-- returns true when the text was a command, which is also how the chat uses it
-- to tell that the message should not be shown
local function runCommand(text)
	if typeof(text) ~= "string" then
		return false
	end
	local name = string.lower(string.gsub(text, "^%s+", ""))
	name = string.gsub(name, "%s+$", "")
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
	local okVersion, version = pcall(function()
		return TextChatService.ChatVersion
	end)
	if okVersion and version == Enum.ChatVersion.TextChatService then
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
			if source and source.UserId == player.UserId and runCommand(message.Text) then
				properties = properties or Instance.new("TextChatMessageProperties")
				properties.Text = ""
				return properties
			end
			return properties
		end
		return
	end
	track(player.Chatted:Connect(runCommand))
end

bindCommands()

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
	tween(keyButton, motionInfo(0.1), { BackgroundTransparency = 0.7 })
end))
track(keyButton.MouseLeave:Connect(function()
	tween(keyButton, motionInfo(0.1), { BackgroundTransparency = 0 })
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

task.spawn(function()
	while true do
		local ok, clock = pcall(function()
			return os.date("%H:%M")
		end)
		clockLabel.Text = ok and clock or "--:--"
		local now = os.time()
		task.wait(math.max(1, 60 - (now % 60)))
	end
end)

local function refreshVersion()
	local ok, body = pcall(function()
		return game:HttpGet(CONFIG.verUrl)
	end)
	if ok and typeof(body) == "string" and #body > 0 then
		local lines = {}
		for line in string.gmatch(body, "[^\r\n]+") do
			table.insert(lines, line)
		end
		tagLabel.Text = lines[1] or "Indev"
		verLabel.Text = lines[2] or "1.0"
	else
		tagLabel.Text = "Indev"
		verLabel.Text = "offline"
	end
end

task.spawn(function()
	while true do
		refreshVersion()
		task.wait(CONFIG.verRefresh)
	end
end)

----------------------------------------------------------------------
-- public handle
----------------------------------------------------------------------

_G.Kbar = {
	version = "1.1",
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
