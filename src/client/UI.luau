-- The "Kraft & Crate" UI kit (docs/GameDesign.md §5.1): Farm Heist's own
-- look, built in code so it lives in git. Things you'd find on a farm:
--   UI.wood       plank boards (signs, crates, the seed rack)
--   UI.crimp      a seed packet's crimped top edge
--   UI.tag        a price tag on a string (the location chip, prices)
--   UI.stamp      a round rubber-stamp button (the big context button)
--   UI.crate      a crate with a stencilled label (the side bar)
--   UI.chalkboard a chalkboard strip, in chalk handwriting
--   UI.rosette    a county-fair prize ribbon (level-ups)
--   UI.coin       a gold coin (drawn: Roblox can't show the coin emoji)
--   UI.panel      a kraft-paper window: stitched border, a wooden sign hung
--                 on two ropes, seed-packet tabs
--   UI.toast      a paper note pinned with a tack, in handwriting
--   UI.button · UI.float · UI.onLayout
-- Colours mean the same everywhere: green = do it, gold = spend coins, red =
-- danger, blue = go somewhere / info.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local UI = {}

UI.C = {
	red = Color3.fromHex("C8452D"), -- Barn Red: headers, danger
	gold = Color3.fromHex("F2B33D"), -- Hay Gold: coins, buy buttons
	green = Color3.fromHex("4E9F3D"), -- Leaf Green: confirm, Your Farm, growth
	soil = Color3.fromHex("6B4A2F"), -- Soil Brown: wood, outlines
	soilDark = Color3.fromHex("4A3220"),
	kraft = Color3.fromHex("D9B98A"), -- panel body
	stitch = Color3.fromHex("B8935E"),
	cream = Color3.fromHex("FFF4DC"), -- cards, text on wood
	ink = Color3.fromHex("3A2A1C"), -- body text
	sky = Color3.fromHex("5BB6F0"), -- info, travel
	alarm = Color3.fromHex("E8352B"),
	chalk = Color3.fromRGB(240, 238, 226),
	board = Color3.fromRGB(44, 60, 50),
	white = Color3.new(1, 1, 1),
	shade = Color3.new(0, 0, 0),
}
local C = UI.C

UI.HEAD = Enum.Font.FredokaOne -- headers, numbers, buttons
UI.BODY = Enum.Font.BuilderSansMedium
UI.BODY_BOLD = Enum.Font.BuilderSansBold
UI.HAND = Enum.Font.PatrickHand -- paper notes and chalk

UI.compact = false -- a phone-sized screen (height under COMPACT_HEIGHT)
UI.touch = false -- a touch screen

-- make("Frame", { Size = ... }, { children }): Parent goes on last.
function UI.make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end
local make = UI.make

function UI.corner(radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.stroke(color: Color3, thickness: number?, transparency: number?)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Text that shrinks (to minSize) rather than spill out of its box.
function UI.fit(label: TextLabel, minSize: number?): TextLabel
	make("UITextSizeConstraint", { MaxTextSize = label.TextSize, MinTextSize = minSize or 10, Parent = label })
	label.TextScaled = true
	return label
end

function UI.label(props)
	local all = {
		BackgroundTransparency = 1,
		Font = UI.BODY,
		TextSize = 16,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		all[key] = value
	end
	return make("TextLabel", all)
end

-- 12345 → "12,345"
function UI.formatNumber(n: number): string
	local digits = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

-- 75 → "1:15", 3725 → "1:02:05"
function UI.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local h, m, s = seconds // 3600, seconds % 3600 // 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function UI.darker(color: Color3, by: number?): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.05), v * (by or 0.68))
end

------------------------------------------------------------------------
-- Wood

local PLANKS = { Color3.fromRGB(132, 91, 57), Color3.fromRGB(118, 80, 50), Color3.fromRGB(138, 96, 61), Color3.fromRGB(124, 85, 53) }
UI.SEAM = Color3.fromRGB(72, 48, 30)
local SEAM = UI.SEAM

-- Paints a frame as boards: `planks` of them, running across (signs) or
-- up and down (crates: vertical = true), with dark seams between. tint
-- stains the wood (a red barn sign, a green one).
function UI.wood(frame: GuiObject, planks: number?, vertical: boolean?, tint: Color3?)
	local n = math.clamp(planks or 4, 1, 5) -- (a gradient holds 20 colour stops)
	local keys = {}
	for i = 0, n - 1 do
		local a, b = i / n, (i + 1) / n
		local color = PLANKS[i % #PLANKS + 1]
		if tint then
			color = color:Lerp(tint, 0.55)
		end
		table.insert(keys, ColorSequenceKeypoint.new(if i == 0 then 0 else a + 0.012, color))
		table.insert(keys, ColorSequenceKeypoint.new(if i == n - 1 then 1 else b - 0.012, color:Lerp(SEAM, 0.12)))
		if i < n - 1 then
			table.insert(keys, ColorSequenceKeypoint.new(b - 0.006, SEAM))
			table.insert(keys, ColorSequenceKeypoint.new(b + 0.006, SEAM))
		end
	end
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	make("UIGradient", { Name = "Planks", Color = ColorSequence.new(keys), Rotation = if vertical then 0 else 90, Parent = frame })
	return frame
end

------------------------------------------------------------------------
-- Buttons: a darker edge under a raised face that squashes when pressed.

local BUTTON_KINDS = {
	green = { face = C.green, text = C.cream },
	gold = { face = C.gold, text = C.ink },
	red = { face = C.red, text = C.cream },
	blue = { face = C.sky, text = C.ink },
	cream = { face = C.cream, text = C.ink },
	wood = { face = Color3.fromRGB(128, 88, 55), text = C.cream },
}
local EDGE = 4

-- UI.button({ text, kind?, size?, position?, anchor?, textSize?, parent? })
-- returns the holder (position and size it) and the TextButton (connect it).
function UI.button(props)
	local kind = BUTTON_KINDS[props.kind or "green"]
	local holder = make("Frame", {
		Name = props.name or "Button",
		Size = props.size or UDim2.fromOffset(120, 44),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = UI.darker(kind.face),
		LayoutOrder = props.order or 0,
		ZIndex = props.zIndex or 1,
		Parent = props.parent,
	}, { UI.corner(props.radius or 8) })
	local button = make("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -EDGE),
		BackgroundColor3 = kind.face,
		AutoButtonColor = false,
		Font = UI.HEAD,
		Text = props.text or "",
		TextSize = props.textSize or 18,
		TextColor3 = kind.text,
		ZIndex = props.zIndex or 1,
		Parent = holder,
	}, { UI.corner(props.radius or 8), UI.stroke(SEAM, 1.5, 0.35) })
	UI.fit(button, 10)
	button.MouseButton1Down:Connect(function()
		button.Position = UDim2.fromOffset(0, EDGE - 1)
	end)
	local function release()
		button.Position = UDim2.new()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return holder, button
end

-- Recolours a button made by UI.button.
function UI.setButtonKind(holder: Frame, kindName: string)
	local kind = BUTTON_KINDS[kindName]
	holder.BackgroundColor3 = UI.darker(kind.face)
	holder.Face.BackgroundColor3 = kind.face
	holder.Face.TextColor3 = kind.text
end

------------------------------------------------------------------------
-- Farm things

-- A seed packet's crimped top: a row of little teeth along the top edge.
function UI.crimp(parent: GuiObject, color: Color3, teeth: number?, size: number?)
	local count = teeth or 6
	local s = size or 7
	local row = make("Frame", {
		Name = "Crimp", Size = UDim2.new(1, 0, 0, s), Position = UDim2.fromOffset(0, -s / 2),
		BackgroundTransparency = 1, ZIndex = parent.ZIndex, Parent = parent,
	})
	for i = 1, count do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((i - 0.5) / count, 0, 0.5, 0),
			Size = UDim2.fromOffset(s, s), Rotation = 45, BackgroundColor3 = color, BorderSizePixel = 0,
			ZIndex = parent.ZIndex, Parent = row,
		})
	end
	return row
end

-- A gold coin with a rim and a shine.
function UI.coin(props)
	local d = props.diameter or 22
	local z = props.zIndex or 1
	local coin = make("Frame", {
		Name = "Coin", Size = UDim2.fromOffset(d, d), Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero, BackgroundColor3 = C.gold, ZIndex = z, Parent = props.parent,
	}, { UI.corner(d), UI.stroke(Color3.fromRGB(150, 100, 22), 2) })
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1, ZIndex = z, Parent = coin,
	}, { UI.corner(d), UI.stroke(Color3.fromRGB(200, 140, 36), 1.5) })
	make("Frame", {
		Position = UDim2.fromScale(0.2, 0.16), Size = UDim2.fromScale(0.24, 0.24), BackgroundColor3 = C.white,
		BackgroundTransparency = 0.3, ZIndex = z + 1, Parent = coin,
	}, { UI.corner(d) })
	return coin
end

-- A price tag on a string: a card with a pointed end (a square turned on
-- its corner, behind the card), a hole and the string. props: text, color,
-- textColor, size, position, anchor, parent, autoWidth, font, textSize,
-- align, zIndex, coin (a coin before the text). Returns the tag and its label.
function UI.tag(props)
	local color = props.color or C.cream
	local z = props.zIndex or 1
	local height = (props.size and props.size.Y.Offset) or 30
	local tag = make("Frame", {
		Name = props.name or "Tag",
		Size = props.size or UDim2.fromOffset(120, height),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = props.parent,
	})
	make("Frame", {
		Name = "Point", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, height * 0.5, 0.5, 0),
		Size = UDim2.fromOffset(height * 0.72, height * 0.72), Rotation = 45,
		BackgroundColor3 = color, ZIndex = z, Parent = tag,
	}, { UI.corner(3), UI.stroke(C.soilDark, 2) })
	local card = make("Frame", {
		Name = "Card",
		Position = UDim2.fromOffset(height * 0.5, 0),
		Size = UDim2.new(if props.autoWidth then 0 else 1, if props.autoWidth then 0 else -height * 0.5, 1, 0),
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundColor3 = color,
		ZIndex = z + 1,
		Parent = tag,
	}, { UI.corner(5), UI.stroke(C.soilDark, 2), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10) }) })
	make("Frame", { -- (hides the point's outline where it meets the card)
		Name = "Join", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -13, 0.5, 0),
		Size = UDim2.fromOffset(4, height * 0.62), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z + 2, Parent = card,
	})
	make("Frame", {
		Name = "Hole", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -5, 0.5, 0),
		Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.cream, ZIndex = z + 3, Parent = card,
	}, { UI.corner(4), UI.stroke(C.soilDark, 1.5) })
	make("Frame", {
		Name = "String", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, -7, 0.5, -2),
		Size = UDim2.fromOffset(2, height * 0.7), Rotation = -40, BackgroundColor3 = C.soilDark, BorderSizePixel = 0,
		ZIndex = z + 3, Parent = card,
	})
	local indent = 4
	if props.coin then
		local d = math.floor(height * 0.6)
		UI.coin({ diameter = d, anchor = Vector2.new(0, 0.5), position = UDim2.new(0, 2, 0.5, 0), zIndex = z + 3, parent = card })
		indent = d + 7
	end
	local label = UI.label({
		Name = "Text",
		Position = UDim2.fromOffset(indent, 0),
		Size = UDim2.new(if props.autoWidth then 0 else 1, if props.autoWidth then 0 else -indent, 1, 0),
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Font = props.font or UI.HEAD, TextSize = props.textSize or 16, TextColor3 = props.textColor or C.ink,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		Text = props.text or "", ZIndex = z + 3, Parent = card,
	})
	return tag, label
end

-- Recolours a tag made by UI.tag.
function UI.setTagColor(tag: Frame, color: Color3, textColor: Color3?)
	tag.Point.BackgroundColor3 = color
	tag.Card.BackgroundColor3 = color
	tag.Card.Join.BackgroundColor3 = color
	if textColor then
		tag.Card.Text.TextColor3 = textColor
	end
end

-- A round rubber-stamp button: a dark rim, the coloured face with an inner
-- ring, a word across it. Returns the holder and the TextButton.
function UI.stamp(props)
	local kind = BUTTON_KINDS[props.kind or "green"]
	local d = props.diameter or 100
	local z = props.zIndex or 1
	local holder = make("Frame", {
		Name = props.name or "Stamp",
		Size = UDim2.fromOffset(d, d),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = UI.darker(kind.face, 0.55),
		ZIndex = z,
		Parent = props.parent,
	}, { UI.corner(d), UI.stroke(C.soilDark, 3) })
	local face = make("TextButton", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -3),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = kind.face,
		AutoButtonColor = false,
		Font = UI.HEAD,
		Text = props.text or "",
		TextSize = props.textSize or 20,
		TextColor3 = kind.text,
		ZIndex = z + 1,
		Parent = holder,
	}, { UI.corner(d) })
	make("Frame", { -- the stamp's inner ring
		Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1, ZIndex = z + 1, Parent = face,
	}, { UI.corner(d), UI.stroke(kind.text, 2, 0.45) })
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.new(0.5, 0, 0.5, 0)
	end)
	local function release()
		face.Position = UDim2.new(0.5, 0, 0.5, -3)
	end
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(release)
	return holder, face
end

function UI.setStampKind(holder: Frame, kindName: string)
	local kind = BUTTON_KINDS[kindName]
	holder.BackgroundColor3 = UI.darker(kind.face, 0.55)
	holder.Face.BackgroundColor3 = kind.face
	holder.Face.TextColor3 = kind.text
	holder.Face.Ring.UIStroke.Color = kind.text
end

-- A crate: up-and-down boards, dark rails, an icon and a cream stencilled
-- label. Returns the holder and a TextButton over all of it.
function UI.crate(props)
	local holder = make("Frame", {
		Name = props.name or "Crate",
		Size = props.size or UDim2.fromOffset(70, 66),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	}, { UI.corner(5), UI.stroke(SEAM, 3) })
	UI.wood(holder, 4, true)
	for _, y in { 0, 1 } do -- the top and bottom rails
		make("Frame", {
			AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = SEAM, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = holder,
		})
	end
	make("TextLabel", {
		Name = "Icon", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 7), BackgroundTransparency = 1,
		Font = UI.HEAD, Text = props.icon or "", TextSize = 26, Parent = holder,
	})
	local plate = make("Frame", {
		Name = "Label", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.new(1, -10, 0, 18),
		BackgroundColor3 = C.cream, Parent = holder,
	}, { UI.corner(3), UI.stroke(SEAM, 1.5) })
	UI.fit(make("TextLabel", { -- (shrinks to fit: "WAREHOUSE" is long for a crate)
		Size = UDim2.new(1, -4, 1, 0), Position = UDim2.fromOffset(2, 0), BackgroundTransparency = 1, Font = UI.HEAD, Text = string.upper(props.text or ""),
		TextSize = 13, TextColor3 = C.ink, Parent = plate,
	}), 7)
	local button = make("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = holder })
	button.MouseButton1Down:Connect(function()
		holder.Rotation = -4
	end)
	local function release()
		holder.Rotation = 0
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return holder, button
end

-- A chalkboard strip in a wooden frame, with chalk handwriting. Returns the
-- board and its label.
function UI.chalkboard(props)
	local z = props.zIndex or 1
	local board = make("Frame", {
		Name = props.name or "Chalkboard",
		Size = props.size or UDim2.fromOffset(170, 30),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundColor3 = C.board,
		ZIndex = z,
		Visible = props.visible ~= false,
		Parent = props.parent,
	}, { UI.corner(4), UI.stroke(Color3.fromRGB(150, 104, 64), 4), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local label = UI.label({
		Name = "Chalk",
		Size = UDim2.new(if props.autoWidth then 0 else 1, 0, 1, 0),
		AutomaticSize = if props.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Font = UI.HAND, TextSize = props.textSize or 20, TextColor3 = C.chalk,
		TextXAlignment = Enum.TextXAlignment.Center, Text = props.text or "", ZIndex = z + 1, Parent = board,
	})
	return board, label
end

-- A county-fair prize rosette: ruffled petals, a cream centre with the
-- text, two ribbon tails. Returns the holder and the centre's label.
function UI.rosette(props)
	local d = props.diameter or 110
	local color = props.color or C.red
	local holder = make("Frame", {
		Name = props.name or "Rosette", Size = UDim2.fromOffset(d, d * 1.4), Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero, BackgroundTransparency = 1, ZIndex = props.zIndex or 1, Parent = props.parent,
	})
	local z = holder.ZIndex
	for _, tail in { { -0.16, 14 }, { 0.16, -14 } } do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5 + tail[1], 0, 0, d * 0.5), Size = UDim2.fromOffset(d * 0.26, d * 0.85),
			Rotation = tail[2], BackgroundColor3 = UI.darker(color, 0.85), ZIndex = z, Parent = holder,
		}, { UI.stroke(C.soilDark, 2) })
	end
	for i = 0, 11 do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(d / 2, d / 2), Size = UDim2.fromOffset(d * 0.74, d * 0.74),
			Rotation = i * 7.5, BackgroundColor3 = if i % 2 == 0 then color else UI.darker(color, 0.85), ZIndex = z + 1, Parent = holder,
		}, { UI.corner(d * 0.1) })
	end
	local centre = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(d / 2, d / 2), Size = UDim2.fromOffset(d * 0.56, d * 0.56),
		BackgroundColor3 = C.cream, ZIndex = z + 2, Parent = holder,
	}, { UI.corner(d), UI.stroke(C.gold, 3) })
	local label = UI.label({
		Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = props.textSize or 22, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink, Text = props.text or "", ZIndex = z + 3, Parent = centre,
	})
	return holder, label
end

------------------------------------------------------------------------
-- The screen and layout

UI.screen = make("ScreenGui", {
	Name = "FarmHeistHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local COMPACT_HEIGHT = 500
local layoutCallbacks = {}

-- Runs fn now and whenever the layout changes (phone turned, window resized).
function UI.onLayout(callback: () -> ())
	table.insert(layoutCallbacks, callback)
	task.spawn(callback)
end

-- Pixels the jump button (and the Run button above it) take at the bottom
-- right of a touch screen, measured.
function UI.touchRoom(): number
	local screenRight = UI.screen.AbsolutePosition.X + UI.screen.AbsoluteSize.X
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0 then
		return math.max(16, screenRight - jump.AbsolutePosition.X + 10)
	end
	return 170
end

local lastKey = ""
local function relayout()
	local size = UI.screen.AbsoluteSize
	if size.Y <= 0 then
		return
	end
	local touch = UserInputService.TouchEnabled or player.PlayerGui:FindFirstChild("TouchGui") ~= nil
	local compact = size.Y < COMPACT_HEIGHT
	local key = `{size.X}x{size.Y}{touch}{if touch then UI.touchRoom() else 0}`
	if key == lastKey then
		return
	end
	lastKey = key
	UI.compact, UI.touch = compact, touch
	for _, callback in layoutCallbacks do
		task.spawn(callback)
	end
end
UI.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
task.spawn(function()
	while true do
		relayout()
		task.wait(1) -- (Roblox's touch buttons appear after the HUD, and move when the screen turns)
	end
end)

------------------------------------------------------------------------
-- Windows: one at a time, over a dimmed backdrop (tap outside to close).

local backdrop = make("TextButton", {
	Name = "Backdrop",
	Size = UDim2.new(1, 0, 1, 80),
	Position = UDim2.fromOffset(0, -60),
	BackgroundColor3 = C.shade,
	BackgroundTransparency = 0.55,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 20,
	Parent = UI.screen,
})

local openPanel = nil

function UI.closePanels()
	if openPanel then
		openPanel.frame.Visible = false
		if openPanel.onClose then
			task.spawn(openPanel.onClose)
		end
	end
	openPanel = nil
	backdrop.Visible = false
end
backdrop.Activated:Connect(UI.closePanels)

function UI.isOpen(panel): boolean
	return openPanel == panel
end

-- UI.panel("Barn", { tabs = { "Crops", "Seeds" }, tabColors = {...}, accent = Color3,
--   wood = true (a board body: the seed rack), toolbar = true, width, height })
-- returns { frame, list, toolbar, top, tabs = { [name] = button }, tab,
-- open(), close(), toggle(), setTab(name), onTab(fn), onOpen, onClose }.
function UI.panel(title: string, options)
	options = options or {}
	local panel = { tab = options.tabs and options.tabs[1] or nil, tabs = {} }
	local tabWidth = options.tabWidth or 96

	local frame = make("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		BackgroundColor3 = C.kraft,
		Visible = false,
		ZIndex = 21,
		Parent = UI.screen,
	}, { UI.corner(12), UI.stroke(C.soil, 3) })
	if options.wood then
		UI.wood(frame, 5, false)
	end
	panel.frame = frame
	-- the stitched inner border
	make("Frame", {
		Name = "Stitch",
		Size = UDim2.new(1, -14, 1, -14),
		Position = UDim2.fromOffset(7, 7),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = frame,
	}, { UI.corner(9), UI.stroke(if options.wood then C.kraft else C.stitch, 2, 0.2) })

	-- The painted wooden sign, hung over the top edge on two ropes.
	local sign = make("Frame", {
		Name = "Sign",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(math.max(180, #title * 15 + 76), 46),
		ZIndex = 23,
		Parent = frame,
	}, { UI.corner(6), UI.stroke(SEAM, 3) })
	UI.wood(sign, 2, false, options.accent)
	for _, x in { 0.12, 0.88 } do
		make("Frame", { -- the rope, going up out of the window
			Name = "Rope", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, 0, 6), Size = UDim2.fromOffset(3, 24),
			Rotation = if x < 0.5 then 20 else -20, BackgroundColor3 = Color3.fromRGB(206, 170, 112), BorderSizePixel = 0,
			ZIndex = 22, Parent = sign,
		})
		make("Frame", {
			Name = "Nail", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0, 9),
			Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(200, 200, 190), ZIndex = 24, Parent = sign,
		}, { UI.corner(4), UI.stroke(SEAM, 1) })
	end
	make("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0.8, 0, 1, -4),
		Position = UDim2.new(0.1, 0, 0, 2),
		BackgroundTransparency = 1,
		Font = UI.HEAD,
		Text = title,
		TextSize = 24,
		TextColor3 = C.cream,
		TextStrokeColor3 = SEAM,
		TextStrokeTransparency = 0,
		ZIndex = 24,
		Parent = sign,
	})

	local _, close = UI.stamp({ text = "X", kind = "red", diameter = 42, anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 12, 0, -16), zIndex = 25, parent = frame, textSize = 20 })
	close.Activated:Connect(UI.closePanels)

	-- Seed-packet tabs: a crimped top, a band of the tab's colour, the name.
	local top = 36
	if options.tabs then
		local tabBar = make("Frame", {
			Name = "Tabs",
			Size = UDim2.new(1, -36, 0, 40),
			Position = UDim2.fromOffset(18, top),
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = frame,
		}, { make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}) })
		for i, name in options.tabs do
			local color = options.tabColors and options.tabColors[i] or C.gold
			local tab = make("TextButton", {
				Name = name,
				Size = UDim2.fromOffset(tabWidth, 32),
				BackgroundColor3 = C.cream,
				Font = UI.HEAD,
				Text = name,
				TextSize = 16,
				TextColor3 = C.ink,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				AutoButtonColor = false,
				LayoutOrder = i,
				ZIndex = 22,
				Parent = tabBar,
			}, { UI.corner(3), UI.stroke(C.soil, 2), make("UIPadding", { PaddingBottom = UDim.new(0, 4) }) })
			make("Frame", { Name = "Band", Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 22, Parent = tab })
			UI.crimp(tab, C.cream, math.max(4, math.floor(tabWidth / 11)), 6)
			panel.tabs[name] = tab
			tab.Activated:Connect(function()
				panel.setTab(name)
			end)
		end
		top += 46
	end

	-- The body: an optional toolbar line, then a scrolling list.
	panel.toolbar = UI.label({
		Name = "Toolbar",
		Size = UDim2.new(1, -36, 0, 24),
		Position = UDim2.fromOffset(18, top),
		Font = UI.HAND,
		TextSize = 21,
		TextColor3 = if options.wood then C.cream else C.ink,
		Text = "",
		Visible = options.toolbar == true,
		ZIndex = 22,
		Parent = frame,
	})
	if options.toolbar then
		top += 28
	end
	panel.top = top
	panel.list = make("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -28, 1, -(top + 14)),
		Position = UDim2.fromOffset(14, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.soil,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 22,
		Parent = frame,
	}, {
		make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	})

	local tabCallbacks = {}
	function panel.setTab(name: string)
		panel.tab = name
		for tabName, tab in panel.tabs do
			local selected = tabName == name
			tab.Size = UDim2.fromOffset(tabWidth, if selected then 38 else 32) -- (the picked packet stands up)
			tab.BackgroundColor3 = if selected then C.white else C.cream
			tab.UIStroke.Thickness = if selected then 3 else 2
			tab.UIStroke.Color = if selected then SEAM else C.soil
		end
		for _, callback in tabCallbacks do
			task.spawn(callback, name)
		end
	end
	function panel.onTab(callback)
		table.insert(tabCallbacks, callback)
	end
	function panel.open()
		if openPanel and openPanel ~= panel then
			UI.closePanels()
		end
		openPanel = panel
		backdrop.Visible = true
		frame.Visible = true
		if panel.onOpen then
			task.spawn(panel.onOpen)
		end
	end
	function panel.close()
		if openPanel == panel then
			UI.closePanels()
		end
	end
	function panel.toggle()
		if openPanel == panel then
			UI.closePanels()
		else
			panel.open()
		end
	end

	UI.onLayout(function()
		local size = UI.screen.AbsoluteSize
		local width = math.min(options.width or 600, size.X - 40)
		local height = math.min(options.height or 400, size.Y - (if UI.compact then 40 else 90))
		frame.Size = UDim2.fromOffset(width, height)
	end)
	if panel.tab then
		panel.setTab(panel.tab)
	end
	return panel
end

-- Removes everything in a list but its layout helpers.
function UI.clear(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

------------------------------------------------------------------------
-- Toasts: paper notes pinned with a tack, top right, in handwriting.

local toastStack = make("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(320, 400),
	BackgroundTransparency = 1,
	ZIndex = 40,
	Parent = UI.screen,
}, { make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })
UI.onLayout(function()
	toastStack.Size = UDim2.fromOffset(if UI.compact then 250 else 320, 400)
end)

local TACKS = { Good = C.green, Error = C.alarm, Announce = C.sky }
local toastOrder = 0
local MAX_TOASTS = 4

-- kind: nil · "Good" · "Error" · "Announce" (on yellow paper)
function UI.toast(text: string, kind: string?, seconds: number?)
	toastOrder += 1
	local note = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = if kind == "Announce" then Color3.fromRGB(255, 236, 160) else C.cream,
		Rotation = (toastOrder % 3 - 1) * 1.5, -- (pinned up by hand)
		LayoutOrder = -toastOrder,
		ZIndex = 40,
		Parent = toastStack,
	}, {
		UI.corner(3),
		UI.stroke(C.stitch, 1.5),
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	})
	make("Frame", { -- the tack
		Name = "Tack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(12, 12), BackgroundColor3 = TACKS[kind] or C.red, ZIndex = 41, Parent = note,
	}, { UI.corner(6), UI.stroke(C.soilDark, 1.5) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Font = UI.HAND,
		TextSize = if UI.compact then 18 else 21,
		TextColor3 = if kind == "Error" then Color3.fromRGB(160, 40, 30) else C.ink,
		Text = text,
		ZIndex = 41,
		Parent = note,
	})
	local notes = {}
	for _, child in toastStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(notes, child)
		end
	end
	if #notes > MAX_TOASTS then -- (the oldest comes down)
		table.sort(notes, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		notes[1]:Destroy()
	end
	task.delay(seconds or 4, function()
		if note.Parent then
			note:Destroy()
		end
	end)
end

------------------------------------------------------------------------
-- Floating numbers: "+1 🥕" rises from a point on screen and fades.

function UI.float(text: string, at: UDim2, color: Color3?)
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(160, 32),
		BackgroundTransparency = 1,
		Font = UI.HEAD,
		Text = text,
		TextSize = 28,
		TextColor3 = color or C.cream,
		TextStrokeColor3 = SEAM,
		TextStrokeTransparency = 0,
		ZIndex = 45,
		Parent = UI.screen,
	})
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = at - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1, function()
		label:Destroy()
	end)
end

return UI
