--!nonstrict
--[[
	Kbar 1.01 — a client-side top notch for Roblox.

	Run it from an executor:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/Kbar/main/Kbar.lua"))()

	What it draws:
	  • the notch, flush with the top edge of the screen, centred:
	      Indev | 12:00 | 1.0         (tag and version come from Ver.txt)
	      chevron, inside the box at the bottom centre
	      the tray: FPS Display, LSSR SW, Free Camera, Ping Display,
	                Load Inf Yield, KHub, Anim Changer, Click 2 MEOW!
	  • the person orb at the top right, which opens and closes the player list

	Roblox's own top bar is left alone: the notch is centred, and the orb sits under the top bar
	inset so it can never cover the chat button (CONFIG.orbBelowTopbar = false pins it to the corner).

	Tray buttons have no behaviour yet. Drop a function into _G.Kbar.Features under the button id
	(fps, lssr, freecam, ping, infyield, khub, anim, meow) and pressing it runs that instead.
]]

local CONFIG = {
	verUrl = "https://raw.githubusercontent.com/Kttyz/Kbar/refs/heads/main/Ver.txt",
	verRefresh = 60,
	clockTick = 1,
	statRefresh = 1.5,

	startOpen = true,

	notchWidth = 340,
	notchWidthClosed = 200,
	notchRadius = 12,
	infoRowHeight = 26,
	chevronStripHeight = 12,
	trayHeight = 80,

	orbSize = 30,
	orbMargin = 14,
	orbBelowTopbar = true,

	panelWidth = 252,
	panelMaxRows = 8,
	rowHeight = 30,

	font = Enum.Font.Code,
	textSize = 12,

	colour = {
		background = Color3.fromRGB(10, 11, 12),
		backgroundTop = Color3.fromRGB(24, 26, 29),
		edge = Color3.fromRGB(58, 64, 72),
		text = Color3.fromRGB(236, 238, 241),
		dim = Color3.fromRGB(140, 148, 158),
		dimmer = Color3.fromRGB(116, 124, 133),
		accent = Color3.fromRGB(224, 73, 47),
		row = Color3.fromRGB(24, 26, 30),
		dot = Color3.fromRGB(74, 79, 87),
		buttonFill = Color3.fromRGB(255, 255, 255),
	},
}

-- id, label, and what the button says on its two lines
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

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui")

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
		Thickness = thickness or 1,
		Transparency = transparency or 0.75,
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
-- the screen gui
----------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "Kbar",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 500,
})

-- the notch is meant to meet the top edge of the screen, so this gui measures from the real
-- screen edge rather than from under Roblox's top bar. Nothing tappable sits where a native
-- button does: the notch is centred, and the orb is pushed below the top bar inset.
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.None
end)
pcall(function()
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
end)

gui.Parent = playerGui
applyTransparency()
track(GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(applyTransparency))

local topInset = 0
pcall(function()
	local inset = GuiService:GetGuiInset()
	topInset = inset.Y
end)

----------------------------------------------------------------------
-- the notch
----------------------------------------------------------------------

local openHeight = CONFIG.infoRowHeight + CONFIG.chevronStripHeight + CONFIG.trayHeight
local closedHeight = CONFIG.infoRowHeight + CONFIG.chevronStripHeight

-- the shape runs above the top edge, so only its bottom corners are rounded
local notch = panelled(make("Frame", {
	Name = "Notch",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -CONFIG.notchRadius),
	Size = UDim2.fromOffset(
		CONFIG.startOpen and CONFIG.notchWidth or CONFIG.notchWidthClosed,
		(CONFIG.startOpen and openHeight or closedHeight) + CONFIG.notchRadius
	),
	BackgroundColor3 = CONFIG.colour.background,
	ClipsDescendants = true,
	ZIndex = 3,
}), 0)
corner(notch, CONFIG.notchRadius)
stroke(notch, CONFIG.colour.edge, 1, 0.7)
notch.Parent = gui

local bar = make("Frame", {
	Name = "Bar",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, CONFIG.notchRadius),
	Size = UDim2.new(1, 0, 0, openHeight),
}, notch)

-- info row
local infoRow = make("Frame", {
	Name = "Info",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(CONFIG.notchWidthClosed, CONFIG.infoRowHeight),
	BackgroundTransparency = 1,
}, bar)

local cells = make("Frame", {
	Name = "Cells",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -16, 1, 0),
}, infoRow)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, cells)

local function cellSeparator(order)
	return make("Frame", {
		Name = "Separator",
		BackgroundColor3 = CONFIG.colour.text,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 12),
		LayoutOrder = order,
	}, cells)
end

local tagLabel = label(cells, {
	Name = "Tag",
	Text = "Indev",
	TextColor3 = CONFIG.colour.text,
	LayoutOrder = 1,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 12),
})
make("UISizeConstraint", { MaxSize = Vector2.new(72, 12) }, tagLabel)

cellSeparator(2)

local clockLabel = label(cells, {
	Name = "Clock",
	Text = "00:00",
	TextColor3 = CONFIG.colour.text,
	TextSize = CONFIG.textSize + 1,
	LayoutOrder = 3,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 12),
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
	Size = UDim2.fromOffset(0, 12),
})
make("UISizeConstraint", { MaxSize = Vector2.new(72, 12) }, verLabel)

-- the tray
local tray = make("Frame", {
	Name = "Tray",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, CONFIG.infoRowHeight + CONFIG.chevronStripHeight),
	Size = UDim2.fromOffset(CONFIG.notchWidth, CONFIG.trayHeight),
	Visible = CONFIG.startOpen,
}, bar)

make("UIGridLayout", {
	CellSize = UDim2.fromOffset(76, 30),
	CellPadding = UDim2.fromOffset(6, 6),
	FillDirectionMaxCells = 4,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	StartCorner = Enum.StartCorner.TopLeft,
}, tray)

local buttons = {}

local function press(buttonId)
	local features = _G.Kbar and _G.Kbar.Features
	local handler = features and features[buttonId]
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
		TextSize = 10,
		TextColor3 = Color3.fromRGB(215, 220, 226),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundColor3 = CONFIG.colour.buttonFill,
		BackgroundTransparency = 0.97,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ZIndex = 4,
	}, tray)
	corner(button, 6)
	local buttonStroke = stroke(button, CONFIG.colour.buttonFill, 1, 0.84)

	track(button.MouseEnter:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.91 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.72 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.97 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.84 })
	end))
	track(button.Activated:Connect(function()
		tween(buttonStroke, motionInfo(0.12), {
			Color = CONFIG.colour.accent,
			Transparency = 0.25,
		})
		task.delay(0.28, function()
			if button.Parent then
				tween(buttonStroke, motionInfo(0.2), {
					Color = CONFIG.colour.buttonFill,
					Transparency = 0.84,
				})
			end
		end)
		press(entry.id)
	end))

	table.insert(buttons, button)
end

-- the chevron lives inside the notch: two bars hinged into an arrow which turns over to show
-- whether the tray is out or tucked away
local chevron = make("TextButton", {
	Name = "Chevron",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, CONFIG.infoRowHeight),
	Size = UDim2.fromOffset(48, CONFIG.chevronStripHeight),
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
corner(chevronPlate, 6)

local arrow = make("Frame", {
	Name = "Arrow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(9, 6),
	BackgroundTransparency = 1,
	ZIndex = 6,
}, chevron)

local arrowLegs = {}
local function arrowLeg(xFraction, degrees)
	local leg = make("Frame", {
		Name = "Leg",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(xFraction, 0, 1, 0),
		Size = UDim2.fromOffset(2, 7),
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
	local height = open and openHeight or closedHeight
	tray.Visible = true
	tween(notch, motionInfo(0.18), {
		Size = UDim2.fromOffset(open and CONFIG.notchWidth or CONFIG.notchWidthClosed, height + CONFIG.notchRadius),
	})
	tween(arrow, motionInfo(0.18), { Rotation = open and 0 or 180 })
	for _, leg in ipairs(arrowLegs) do
		tween(leg, motionInfo(0.18), {
			BackgroundColor3 = open and CONFIG.colour.dim or CONFIG.colour.text,
		})
	end
	if not open then
		task.delay(0.18, function()
			if not trayOpen then
				tray.Visible = false
			end
		end)
	end
end

if CONFIG.startOpen then
	tween(arrow, motionInfo(0), { Rotation = 0 })
end

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
-- the person orb
----------------------------------------------------------------------

local orbY = CONFIG.orbBelowTopbar and (topInset + 4) or 7

local orb = make("TextButton", {
	Name = "People",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -CONFIG.orbMargin, 0, orbY),
	Size = UDim2.fromOffset(CONFIG.orbSize, CONFIG.orbSize),
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.colour.background,
	ZIndex = 3,
}, gui)
corner(orb, CONFIG.orbSize / 2)
stroke(orb, CONFIG.colour.edge, 1, 0.7)

local glyph = make("Frame", {
	Name = "Glyph",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(16, 16),
	BackgroundTransparency = 1,
}, orb)

local head = make("Frame", {
	Name = "Head",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 1),
	Size = UDim2.fromOffset(7, 7),
	BackgroundColor3 = CONFIG.colour.accent,
	BorderSizePixel = 0,
}, glyph)
corner(head, 4)

local shoulders = make("Frame", {
	Name = "Shoulders",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(14, 7),
	BackgroundColor3 = CONFIG.colour.accent,
	BorderSizePixel = 0,
}, glyph)
corner(shoulders, 4)

local listOpen = false

----------------------------------------------------------------------
-- the player list
----------------------------------------------------------------------

local panel = panelled(make("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -CONFIG.orbMargin, 0, orbY + CONFIG.orbSize + 8),
	Size = UDim2.fromOffset(CONFIG.panelWidth, 40),
	BackgroundColor3 = CONFIG.colour.backgroundTop,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 6,
}), 0)
corner(panel, 12)
stroke(panel, CONFIG.colour.edge, 1, 0.7)
panel.Parent = gui

local header = make("Frame", {
	Name = "Header",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 36),
	ZIndex = 7,
}, panel)

label(header, {
	Name = "Title",
	Text = "PLAYERS",
	TextColor3 = CONFIG.colour.dimmer,
	TextSize = CONFIG.textSize - 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(13, 0),
	Size = UDim2.new(1, -60, 1, 0),
	ZIndex = 7,
})

local countLabel = label(header, {
	Name = "Count",
	Text = "0",
	TextColor3 = CONFIG.colour.accent,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -13, 0, 0),
	Size = UDim2.fromOffset(40, 36),
	ZIndex = 7,
})

make("Frame", {
	Name = "Rule",
	BackgroundColor3 = CONFIG.colour.buttonFill,
	BackgroundTransparency = 0.92,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 36),
	Size = UDim2.new(1, 0, 0, 1),
	ZIndex = 7,
}, panel)

local scroller = make("ScrollingFrame", {
	Name = "Rows",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 37),
	Size = UDim2.new(1, 0, 1, -37),
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = CONFIG.colour.dot,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BorderSizePixel = 0,
	ZIndex = 7,
}, panel)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, scroller)
make("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
}, scroller)

local function healthOf(other)
	local character = other.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return math.floor(humanoid.Health + 0.5)
	end
	return nil
end

local rows = {}

local function buildRow(other, index)
	local row = make("Frame", {
		Name = "Row",
		BackgroundColor3 = CONFIG.colour.row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CONFIG.rowHeight),
		LayoutOrder = index,
		ZIndex = 7,
	}, scroller)
	corner(row, 8)

	local dot = make("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = CONFIG.colour.dot,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, row)
	corner(dot, 10)

	local displayName = other.DisplayName ~= "" and other.DisplayName or other.Name
	label(dot, {
		Name = "Initial",
		Text = string.upper(string.sub(displayName, 1, 1)),
		TextSize = CONFIG.textSize - 2,
		TextColor3 = Color3.fromRGB(215, 220, 226),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
	})

	label(row, {
		Name = "Name",
		Text = displayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.new(1, -86, 0, 14),
		ZIndex = 8,
	})

	local stat = label(row, {
		Name = "Stat",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = CONFIG.colour.dimmer,
		TextSize = CONFIG.textSize - 2,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(46, 14),
		ZIndex = 8,
	})

	track(row.MouseEnter:Connect(function()
		tween(row, motionInfo(0.1), { BackgroundTransparency = 0.9 })
	end))
	track(row.MouseLeave:Connect(function()
		tween(row, motionInfo(0.1), { BackgroundTransparency = 1 })
	end))

	return { player = other, frame = row, stat = stat, isSelf = other == player }
end

local function refreshStats()
	for _, row in ipairs(rows) do
		if row.isSelf then
			row.stat.Text = "you"
			row.stat.TextColor3 = CONFIG.colour.accent
		else
			local health = healthOf(row.player)
			row.stat.Text = health and tostring(health) or "--"
			row.stat.TextColor3 = CONFIG.colour.dimmer
		end
	end
end

local function rebuild()
	for _, row in ipairs(rows) do
		row.frame:Destroy()
	end
	rows = {}

	local others = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	table.insert(rows, buildRow(player, 1))
	for index, other in ipairs(others) do
		table.insert(rows, buildRow(other, index + 1))
	end

	countLabel.Text = tostring(#rows)
	refreshStats()

	local visibleRows = math.min(#rows, CONFIG.panelMaxRows)
	panel.Size = UDim2.fromOffset(CONFIG.panelWidth, 37 + visibleRows * (CONFIG.rowHeight + 4) + 10)
end

local function setListOpen(open)
	listOpen = open
	if open then
		rebuild()
	end
	panel.Visible = open
	tween(glyph, motionInfo(0.12), { Size = open and UDim2.fromOffset(14, 14) or UDim2.fromOffset(16, 16) })
	tween(head, motionInfo(0.12), {
		BackgroundColor3 = open and CONFIG.colour.text or CONFIG.colour.accent,
	})
	tween(shoulders, motionInfo(0.12), {
		BackgroundColor3 = open and CONFIG.colour.text or CONFIG.colour.accent,
	})
end

track(orb.Activated:Connect(function()
	setListOpen(not listOpen)
end))

track(orb.MouseEnter:Connect(function()
	tween(glyph, motionInfo(0.12), { Size = UDim2.fromOffset(18, 18) })
end))
track(orb.MouseLeave:Connect(function()
	tween(glyph, motionInfo(0.12), { Size = listOpen and UDim2.fromOffset(14, 14) or UDim2.fromOffset(16, 16) })
end))

track(Players.PlayerAdded:Connect(function()
	if listOpen then
		rebuild()
	end
end))
track(Players.PlayerRemoving:Connect(function()
	if listOpen then
		rebuild()
	end
end))

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and listOpen then
		setListOpen(false)
	end
end))

-- a tap anywhere else closes the list
track(UserInputService.InputBegan:Connect(function(input)
	if not listOpen then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		local position = input.Position
		local insideOrb = orb.AbsolutePosition.X <= position.X
			and position.X <= orb.AbsolutePosition.X + orb.AbsoluteSize.X
			and orb.AbsolutePosition.Y <= position.Y
			and position.Y <= orb.AbsolutePosition.Y + orb.AbsoluteSize.Y
		local insidePanel = panel.AbsolutePosition.X <= position.X
			and position.X <= panel.AbsolutePosition.X + panel.AbsoluteSize.X
			and panel.AbsolutePosition.Y <= position.Y
			and position.Y <= panel.AbsolutePosition.Y + panel.AbsoluteSize.Y
		if not insideOrb and not insidePanel then
			setListOpen(false)
		end
	end
end))

----------------------------------------------------------------------
-- clock: the player's own local time, 24h
----------------------------------------------------------------------

local function clockText()
	local ok, text = pcall(function()
		local now = DateTime.now():ToLocalTime()
		return string.format("%02d:%02d", now.Hour, now.Minute)
	end)
	if ok and text then
		return text
	end
	return os.date("%H:%M")
end

task.spawn(function()
	while gui.Parent do
		clockLabel.Text = clockText()
		task.wait(CONFIG.clockTick)
	end
end)

----------------------------------------------------------------------
-- Ver.txt: line 1 = tag, line 2 = version
----------------------------------------------------------------------

local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end

	local okService, serviceBody = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	if okService and type(serviceBody) == "string" and #serviceBody > 0 then
		return serviceBody
	end

	return nil
end

local function trim(text)
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function loadVersion()
	local body = httpGet(CONFIG.verUrl)
	if not body then
		verLabel.Text = "offline"
		return
	end

	local lines = {}
	for line in string.gmatch(body, "[^\r\n]+") do
		table.insert(lines, trim(line))
	end

	if lines[1] and lines[1] ~= "" then
		tagLabel.Text = lines[1]
	end
	if lines[2] and lines[2] ~= "" then
		verLabel.Text = lines[2]
	end
end

task.spawn(function()
	while gui.Parent do
		loadVersion()
		task.wait(CONFIG.verRefresh)
	end
end)

----------------------------------------------------------------------
-- keep the live stats fresh while the list is open
----------------------------------------------------------------------

task.spawn(function()
	while gui.Parent do
		if listOpen then
			refreshStats()
		end
		task.wait(CONFIG.statRefresh)
	end
end)

----------------------------------------------------------------------
-- teardown
----------------------------------------------------------------------

local function destroy()
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	connections = {}
	if gui then
		gui:Destroy()
	end
end

_G.Kbar = {
	Version = "1.01",
	Destroy = destroy,
	Features = {},
	SetOpen = setOpen,
	SetListOpen = setListOpen,
}

if RunService:IsStudio() then
	print("[Kbar] 1.01 mounted")
end
