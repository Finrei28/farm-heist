-- The leaderboards in town (docs/GameDesign.md §4.15; shared/LeaderRules;
-- LeaderboardService writes the names on them): notice boards on two posts
-- under a little gable roof, each a chalkboard in a wooden frame with its
-- title on a painted plank, standing either side of a building's walk,
-- facing the square:
--   * the Exchange: RICHEST FARMS (net worth) and TOP STORES
--   * the Police Station: SHERIFF OF THE WEEK and MOST WANTED (a wanted
--     poster: cream paper, #1's photo at the top)
-- Each board is a model Board_<id> in the Town folder; its Face part holds a
-- SurfaceGui with What (the line under the title), Photo (Most Wanted),
-- Rows (filled by the service) and Footer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderRules = require(ReplicatedStorage.Shared.LeaderRules)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)

local BoardArt = {}

local COLORS = Parts.COLORS
local WOOD = Color3.fromRGB(120, 82, 50)
local WOOD_DARK = Color3.fromRGB(86, 58, 36)
local CHALKBOARD = Color3.fromRGB(44, 60, 50)
local PAPER = Color3.fromRGB(246, 232, 196)
local SLATE = Color3.fromRGB(98, 104, 116)
local CHALK = Color3.fromRGB(240, 238, 226)
local INK = Color3.fromRGB(58, 40, 26)

BoardArt.PIXELS = 40 -- the SurfaceGui's pixels a stud (the face is 9 × 8.2 studs)
BoardArt.SPOT = Vector3.new(21, 0, 17) -- in the building's frame (x either side), on the lawn beside its walk

-- Which building each board stands by, and on which side of its walk.
BoardArt.PLACES = {
	NetWorth = { building = "Exchange", side = -1, color = COLORS.barnRed },
	TopStore = { building = "Exchange", side = 1, color = Color3.fromRGB(70, 140, 70) },
	Sheriff = { building = "Police", side = -1, color = Color3.fromRGB(52, 88, 160) },
	Wanted = { building = "Police", side = 1, color = COLORS.barnRed, poster = true },
}

local function box(name: string, frame: CFrame, x0, y0, z0, x1, y1, z1, color: Color3, parent: Instance, solid: boolean?)
	local p = Parts.plotBox(name, frame, Vector3.new(math.min(x0, x1), y0, math.min(z0, z1)), Vector3.new(math.max(x0, x1), y1, math.max(z0, z1)), { Color = color }, parent)
	if not solid then
		p.CanCollide = false
		p.CanTouch = false
	end
	return p
end

local function slab(name, frame: CFrame, xa, ya, xb, yb, z0, z1, width, color, parent)
	local dx, dy = xb - xa, yb - ya
	local cf = frame * CFrame.new((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	return Parts.prop({ Name = name, Size = Vector3.new(math.sqrt(dx * dx + dy * dy), width, math.abs(z1 - z0)), CFrame = cf, Color = color }, parent)
end

local function label(props, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextScaled = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

-- One board, `frame` at the foot of its middle, facing +Z.
function BoardArt.board(def, frame: CFrame, place, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = `Board_{def.id}`
	for _, x in { -5.05, 5.05 } do -- (either side of the board, not across its face)
		box("Post", frame, x - 0.35, 0, -0.35, x + 0.35, 13.2, 0.35, WOOD_DARK, model, true)
	end
	box("Frame", frame, -4.9, 3.2, -0.25, 4.9, 12.2, 0.25, WOOD, model, true)
	local face = box("Face", frame, -4.5, 3.6, 0.25, 4.5, 11.8, 0.32, if place.poster then PAPER else CHALKBOARD, model)
	local plank = box("TitlePlank", frame, -5.6, 12.2, -0.45, 5.6, 13.6, 0.45, place.color, model)
	-- the little roof
	for _, side in { -1, 1 } do
		slab("Roof", frame, side * 6.2, 13.45, 0, 15.35, -1.1, 1.25, 0.4, SLATE, model)
	end
	box("RidgeCap", frame, -0.35, 15.25, -1.2, 0.35, 15.7, 1.35, SLATE:Lerp(COLORS.dark, 0.3), model)

	-- the title, painted on the plank
	local titleGui = Instance.new("SurfaceGui")
	titleGui.Face = Enum.NormalId.Back
	titleGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	titleGui.PixelsPerStud = BoardArt.PIXELS
	titleGui.LightInfluence = 0.5
	label({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, Text = def.title, TextColor3 = CHALK,
		TextStrokeColor3 = INK, TextStrokeTransparency = 0.4 }, titleGui)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	padding.Parent = titleGui:FindFirstChildOfClass("TextLabel")
	titleGui.Parent = plank

	-- the face: what it ranks, (#1's photo), the rows, the all-time line
	local ink = if place.poster then INK else CHALK
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = BoardArt.PIXELS
	gui.LightInfluence = 0.5
	gui:SetAttribute("Ink", ink)
	local top = 34
	label({ Name = "What", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Font = Enum.Font.PatrickHand,
		Text = def.what, TextColor3 = ink, TextTransparency = 0.15 }, gui)
	if place.poster then
		local photo = Instance.new("ImageLabel")
		photo.Name = "Photo"
		photo.AnchorPoint = Vector2.new(0.5, 0)
		photo.Position = UDim2.new(0.5, 0, 0, 32)
		photo.Size = UDim2.fromOffset(74, 74)
		photo.BackgroundColor3 = Color3.fromRGB(226, 208, 170)
		photo.Image = ""
		local corner = Instance.new("UIStroke")
		corner.Color = INK
		corner.Thickness = 2
		corner.Parent = photo
		photo.Parent = gui
		top = 112
	end
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.Position = UDim2.fromOffset(12, top)
	rows.Size = UDim2.new(1, -24, 1, -(top + 34))
	rows.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows
	rows.Parent = gui
	label({ Name = "Footer", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, 26),
		Font = Enum.Font.PatrickHand, Text = "", TextColor3 = ink, TextTransparency = 0.25 }, gui)
	gui.Parent = face
	model.Parent = parent
	return model
end

function BoardArt.build(town: Instance)
	for _, def in LeaderRules.BOARDS do
		local place = BoardArt.PLACES[def.id]
		local frame = PlotLayout.buildingFrame(place.building) * CFrame.new(place.side * BoardArt.SPOT.X, 0, BoardArt.SPOT.Z)
		BoardArt.board(def, frame, place, town)
	end
end

return BoardArt
