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

function Parts.ball(name: string, position: CFrame, diameter: number, props, parent: Instance): BasePart
	local all = table.clone(props)
	all.Name = name
	all.Shape = Enum.PartType.Ball
	all.Size = Vector3.new(diameter, diameter, diameter)
	all.CFrame = position
	return Parts.prop(all, parent)
end

return Parts
