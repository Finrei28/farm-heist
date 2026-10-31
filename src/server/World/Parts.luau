-- Building blocks for the world (WorldBuilder, FarmArt): the palette from
-- docs/ArtDirection.md §3 and a few part helpers. Everything is
-- SmoothPlastic: one material language, no photo textures.
local Parts = {}

Parts.COLORS = {
	meadow = Color3.fromRGB(140, 195, 106), -- the valley
	lawn = Color3.fromRGB(125, 190, 90), -- inside farms
	lawnStripe = Color3.fromRGB(134, 199, 99),
	hill = Color3.fromRGB(112, 168, 84),
	plaza = Color3.fromRGB(226, 214, 186),
	road = Color3.fromRGB(142, 138, 132),
	trail = Color3.fromRGB(216, 180, 122), -- paths and the back trail
	soil = Color3.fromRGB(104, 70, 46),
	ridge = Color3.fromRGB(118, 80, 52), -- the rounded rows on tilled soil
	wetSoil = Color3.fromRGB(78, 52, 34),
	wetRidge = Color3.fromRGB(90, 60, 40),
	overgrown = Color3.fromRGB(108, 154, 68),
	tuft = Color3.fromRGB(92, 140, 56),
	rock = Color3.fromRGB(146, 150, 156),
	stump = Color3.fromRGB(122, 86, 56),
	stumpTop = Color3.fromRGB(214, 176, 122),
	bush = Color3.fromRGB(70, 132, 60),
	hedge = Color3.fromRGB(63, 138, 58),
	fence = Color3.fromRGB(255, 244, 220), -- painted rails
	post = Color3.fromRGB(107, 74, 47),
	edging = Color3.fromRGB(150, 108, 70), -- the field's block edging
	barnRed = Color3.fromRGB(200, 69, 45),
	cream = Color3.fromRGB(255, 244, 220),
	kraft = Color3.fromRGB(217, 185, 138),
	slate = Color3.fromRGB(127, 140, 153),
	metal = Color3.fromRGB(154, 167, 180),
	hay = Color3.fromRGB(242, 179, 61),
	water = Color3.fromRGB(91, 182, 240),
	dark = Color3.fromRGB(28, 23, 18),
	leaf = Color3.fromRGB(78, 159, 61),
	leafDark = Color3.fromRGB(56, 128, 48),
}

-- Each farm's own colour (docs/ArtDirection.md §3, §7), by plot number: the
-- gate flag, the store's awning and trim, the pickup.
Parts.FARM_COLORS = {
	Color3.fromRGB(232, 83, 63), -- Tomato
	Color3.fromRGB(242, 145, 61), -- Tangerine
	Color3.fromRGB(245, 200, 66), -- Sunflower
	Color3.fromRGB(92, 191, 74), -- Clover
	Color3.fromRGB(47, 181, 168), -- Teal
	Color3.fromRGB(76, 155, 232), -- Sky
	Color3.fromRGB(139, 108, 217), -- Grape
	Color3.fromRGB(232, 106, 168), -- Rose
}

function Parts.farmColor(index: number): Color3
	return Parts.FARM_COLORS[(index - 1) % #Parts.FARM_COLORS + 1]
end

-- An anchored SmoothPlastic part with these properties.
function Parts.part(props, parent: Instance?): BasePart
	local p: any = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Decoration you walk through and the camera ignores.
function Parts.prop(props, parent: Instance?): BasePart
	local p = Parts.part(props, parent)
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = props.CastShadow ~= false
	return p
end

-- A box from plot-space corners (min.Y is the ground it stands on).
function Parts.plotBox(name: string, frame: CFrame, min: Vector3, max: Vector3, props, parent: Instance): BasePart
	local size = Vector3.new(math.max(0.2, max.X - min.X), math.max(0.2, max.Y - min.Y), math.max(0.2, max.Z - min.Z))
	local centre = Vector3.new((min.X + max.X) / 2, min.Y + size.Y / 2, (min.Z + max.Z) / 2)
	local all = table.clone(props)
	all.Name = name
	all.Size = size
	all.CFrame = frame * CFrame.new(centre)
	return Parts.part(all, parent)
end

-- An upright cylinder (Roblox cylinders lie along X).
function Parts.cylinder(name: string, cframe: CFrame, diameter: number, height: number, props, parent: Instance): BasePart
	local all = table.clone(props)
	all.Name = name
	all.Shape = Enum.PartType.Cylinder
	all.Size = Vector3.new(height, diameter, diameter)
	all.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return Parts.prop(all, parent)
end

-- A white picket fence along X in plot space, from min to max (min.Z..max.Z
-- is its thickness), as tall as PlotLayout's fences (`height`): pointed
-- pickets with gaps you can see through, two rails behind them, a post
-- every 8 studs, and an invisible wall up to `block` named `<name>Blocker`
-- (characters climb rails like a ladder, ArtDirection §7). Returns the
-- fence model.
function Parts.picketFence(frame: CFrame, min: Vector3, max: Vector3, parent: Instance, name: string, height: number?, block: number?): Model
	local top = height or 8
	local fence = Instance.new("Model")
	fence.Name = name
	local z = (min.Z + max.Z) / 2
	local length = max.X - min.X
	for _, y in { 1.6, top - 2.2 } do
		Parts.plotBox("Rail", frame, Vector3.new(min.X, y, z + 0.1), Vector3.new(max.X, y + 0.45, z + 0.4), { Color = Parts.COLORS.fence }, fence)
	end
	local pickets = math.max(1, math.floor(length / 1.6))
	local step = length / pickets
	for i = 0, pickets - 1 do
		local x = min.X + (i + 0.5) * step
		local picket = Parts.prop({ Name = "Picket", Size = Vector3.new(0.75, top - 0.7, 0.25), CFrame = frame * CFrame.new(x, (top - 0.7) / 2, z - 0.05),
			Color = Parts.COLORS.fence }, fence)
		picket.CanCollide = true
		Parts.prop({ Name = "PicketTip", Size = Vector3.new(0.53, 0.53, 0.21), CFrame = frame * CFrame.new(x, top - 0.7, z - 0.05) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Parts.COLORS.fence }, fence)
	end
	local posts = math.max(1, math.round(length / 8))
	for i = 0, posts do
		local x = min.X + length * i / posts
		Parts.plotBox("Post", frame, Vector3.new(x - 0.45, 0, z - 0.45), Vector3.new(x + 0.45, top + 0.3, z + 0.45), { Color = Parts.COLORS.fence }, fence)
		Parts.plotBox("PostCap", frame, Vector3.new(x - 0.6, top + 0.3, z - 0.6), Vector3.new(x + 0.6, top + 0.55, z + 0.6), { Color = Parts.COLORS.fence }, fence)
	end
	Parts.plotBox(`{name}Blocker`, frame, Vector3.new(min.X, 0, min.Z), Vector3.new(max.X, block or 11, max.Z),
		{ Transparency = 1, CanQuery = false, CanTouch = false }, fence)
	fence.Parent = parent
	return fence
end

function Parts.ball(name: string, position: CFrame, diameter: number, props, parent: Instance): BasePart
	local all = table.clone(props)
	all.Name = name
	all.Shape = Enum.PartType.Ball
	all.Size = Vector3.new(diameter, diameter, diameter)
	all.CFrame = position
	return Parts.prop(all, parent)
end

return Parts
