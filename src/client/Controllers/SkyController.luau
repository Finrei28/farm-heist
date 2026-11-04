-- Day, night and the weather on your screen (docs/GameDesign.md §4.14,
-- ArtDirection.md §4). The sky's clock and the weather come from
-- shared/WeatherRules (worked out from the time, so every player sees the
-- same sky at the same moment); here the light eases between day, dusk and
-- night and each weather's look, rain and frost fall round the camera,
-- storms flash, the Harvest Moon hangs huge and orange in a violet sky, and
-- lamps and windows tagged for the night light up. These are the whole
-- valley's sky, the same for everyone, which is why they may set Lighting
-- (a local effect never does: RoofController).
--
-- The HUD's sky dial (left of the purse): the weather's icon, the clock (or
-- the Harvest Moon's countdown in its last 5 minutes), a badge with the
-- growth it gives; tap it for what the weather does. A note goes up when
-- the weather changes and 5 minutes before a Harvest Moon.
--
-- At night other players' name tags only show within 20 studs (sneakier
-- raids), except on a farm with Floodlights, where its owner also sees
-- anyone in it who isn't Trusted outlined in red (§4.11).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defences = require(Shared.Config.Defences)
local Weather = require(Shared.Config.Weather)
local WeatherRules = require(Shared.WeatherRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer

local SkyController = {}

-- What the sky's doing now, for the ambience (AmbienceController): the
-- weather's id, how far it has faded in (0–1), and whether it's night.
SkyController.state = { weather = "Clear", weight = 0, night = false }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------------
-- Looks: the day's values are World/LightingSetup's (ArtDirection §4).
-- Night keeps OutdoorAmbient at #6A7090 or more: bright enough to play on a
-- phone, and thieves stay findable.

local DAY = {
	brightness = 2.4, exposure = 0.1, ambient = rgb(90, 86, 80), outdoor = rgb(160, 154, 144), sun = rgb(255, 240, 214),
	density = 0.28, air = rgb(200, 225, 240), decay = rgb(120, 150, 170), haze = 1.2, glare = 0.15,
	saturation = 0.12, contrast = 0.06, tint = rgb(255, 255, 255), rays = 0.05,
}
local NIGHT = {
	brightness = 1.6, exposure = 0, ambient = rgb(70, 76, 104), outdoor = rgb(106, 112, 144), sun = rgb(170, 190, 255),
	density = 0.3, air = rgb(60, 74, 112), decay = rgb(28, 36, 64), haze = 1, glare = 0,
	saturation = 0, contrast = 0.1, tint = rgb(220, 228, 255), rays = 0,
}
local GOLDEN = { -- a low orange sun, the air glowing (not too saturated: red walls went neon in it)
	brightness = 2.5, exposure = 0.1, ambient = rgb(104, 90, 76), outdoor = rgb(170, 150, 126), sun = rgb(255, 184, 116),
	density = 0.3, air = rgb(246, 204, 160), decay = rgb(192, 128, 90), haze = 1.6, glare = 0.5,
	saturation = 0.08, contrast = 0.06, tint = rgb(255, 242, 224), rays = 0.1,
}
local RAIN = { -- grey and soft, the far hills lost in it
	brightness = 1.5, exposure = 0, ambient = rgb(84, 86, 90), outdoor = rgb(136, 140, 148), sun = rgb(210, 216, 224),
	density = 0.42, air = rgb(168, 180, 192), decay = rgb(110, 120, 132), haze = 2.2, glare = 0,
	saturation = -0.05, contrast = 0.04, tint = rgb(232, 238, 245), rays = 0,
}
local RAIN_NIGHT = {
	brightness = 1.3, exposure = 0, ambient = rgb(64, 70, 92), outdoor = rgb(106, 112, 144), sun = rgb(160, 176, 220),
	density = 0.38, air = rgb(56, 66, 96), decay = rgb(26, 32, 54), haze = 1.8, glare = 0,
	saturation = -0.08, contrast = 0.08, tint = rgb(210, 220, 245), rays = 0,
}
local STORM = { -- darker still
	brightness = 1.1, exposure = 0, ambient = rgb(72, 74, 82), outdoor = rgb(122, 126, 138), sun = rgb(196, 204, 220),
	density = 0.48, air = rgb(130, 140, 154), decay = rgb(80, 88, 100), haze = 2.6, glare = 0,
	saturation = -0.12, contrast = 0.08, tint = rgb(214, 222, 235), rays = 0,
}
local STORM_NIGHT = {
	brightness = 1.2, exposure = 0, ambient = rgb(60, 64, 86), outdoor = rgb(106, 112, 144), sun = rgb(150, 166, 210),
	density = 0.42, air = rgb(48, 56, 84), decay = rgb(22, 26, 46), haze = 2.2, glare = 0,
	saturation = -0.12, contrast = 0.1, tint = rgb(204, 214, 240), rays = 0,
}
local FROST = { -- a clear, icy night (greys the grass: it looked like any clear night)
	brightness = 1.7, exposure = 0, ambient = rgb(80, 92, 120), outdoor = rgb(120, 132, 168), sun = rgb(200, 220, 255),
	density = 0.26, air = rgb(120, 150, 200), decay = rgb(40, 56, 96), haze = 0.8, glare = 0,
	saturation = -0.25, contrast = 0.1, tint = rgb(208, 228, 255), rays = 0,
}
local MOON = { -- violet, warm where the big moon lights it
	brightness = 1.8, exposure = 0, ambient = rgb(96, 76, 120), outdoor = rgb(136, 116, 170), sun = rgb(255, 190, 140),
	density = 0.38, air = rgb(150, 96, 214), decay = rgb(96, 44, 156), haze = 2.4, glare = 0.3,
	saturation = 0.15, contrast = 0.08, tint = rgb(236, 220, 255), rays = 0,
}
local LOOKS = {
	Clear = { day = DAY, night = NIGHT },
	Rain = { day = RAIN, night = RAIN_NIGHT },
	Thunderstorm = { day = STORM, night = STORM_NIGHT },
	FrostNight = { day = FROST, night = FROST },
	GoldenHour = { day = GOLDEN, night = NIGHT },
	HarvestMoon = { day = MOON, night = MOON },
}
local FADE = 8 -- seconds a weather's look takes to come in and go

local function mix(a, b, w: number)
	if w <= 0 then
		return a
	elseif w >= 1 then
		return b
	end
	local out = {}
	for key, value in a do
		local other = b[key]
		out[key] = if typeof(value) == "Color3" then value:Lerp(other, w) else value + (other - value) * w
	end
	return out
end

-- 1 by day, 0 at night, easing across sunrise (05:00–07:00) and sunset
-- (17:00–19:00).
local function dayness(clock: number): number
	if clock >= 7 and clock <= 17 then
		return 1
	elseif clock >= 19 or clock <= 5 then
		return 0
	elseif clock > 17 then
		return (19 - clock) / 2
	end
	return (clock - 5) / 2
end

local function effect(className: string): Instance
	local instance = Lighting:FindFirstChildOfClass(className)
	if not instance then
		instance = Instance.new(className)
		instance.Parent = Lighting
	end
	return instance
end

------------------------------------------------------------------------
-- What falls round the camera: an invisible slab above it, moved with it,
-- that rain, frost and golden dust come out of (they fall in the world).

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- (looking up for a roof: solid parts only, so the Sprout Shield's dome and
-- leaves don't count; past every character and the weather's own parts)
local skyParams = RaycastParams.new()
skyParams.FilterType = Enum.RaycastFilterType.Exclude
skyParams.IgnoreWater = true
skyParams.RespectCanCollide = true

local around = make("Part", {
	Name = "WeatherAround", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
	CastShadow = false, Size = Vector3.new(64, 1, 64),
})

local function emitter(name: string, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = SPARKLE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	for key, value in props do
		e[key] = value
	end
	e.Parent = around
	return e
end

local rain = emitter("Rain", { -- (blue-grey streaks lit by nothing: they show against a pale sky and at night)
	Color = ColorSequence.new(rgb(150, 168, 192)), LightEmission = 0, LightInfluence = 0,
	Transparency = NumberSequence.new(0.1), Size = NumberSequence.new(0.7), Squash = NumberSequence.new(-3),
	Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.8, 0.9),
	Speed = NumberRange.new(60, 70), SpreadAngle = Vector2.new(4, 4),
})
local frost = emitter("Frost", { -- ice crystals glinting as they drift down past the camera (the first tiny ones hung out of sight)
	Color = ColorSequence.new(rgb(230, 245, 255)), LightEmission = 1, Size = NumberSequence.new(0.45),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(8, 10), Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(40, 40),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
})
local dust = emitter("GoldDust", { -- Golden Hour: gold specks floating in the low sun
	Color = ColorSequence.new(rgb(255, 210, 110)), LightEmission = 1, Size = NumberSequence.new(0.22),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
})
local RATES = { -- particles a second at full weight
	Rain = { rain = 1500 },
	Thunderstorm = { rain = 2400 },
	FrostNight = { frost = 220 },
	GoldenHour = { dust = 30 },
}

------------------------------------------------------------------------
-- Lightning: a jagged bolt far off ahead of the camera, lit with each of a
-- storm's flashes (the flash alone read as the screen glitching).

local BOLT_STEPS = 8
local BOLT_NEAR, BOLT_FAR, BOLT_HEIGHT = 200, 320, 240 -- (studs away, and tall: low enough to show under the HUD)
local bolt = make("Model", { Name = "Lightning" })
local boltParts = {}
for i = 1, BOLT_STEPS + 3 do -- (the trunk, then a short fork)
	boltParts[i] = make("Part", {
		Name = "Bolt", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = rgb(220, 232, 255), Transparency = 1, Size = Vector3.new(1, 1, 1), Parent = bolt,
	})
end

local function boltStep(part: BasePart, from: Vector3, to: Vector3, thickness: number)
	part.Size = Vector3.new(thickness, thickness, (to - from).Magnitude + thickness * 0.5)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
end

local function strike(at: Vector3, look: Vector3)
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	-- (12–35° off where the camera looks: at ±50° it struck behind the side
	-- bar, and dead ahead behind your own character)
	local turn = math.random(12, 35) * (if math.random() < 0.5 then -1 else 1)
	local ahead = CFrame.Angles(0, math.rad(turn), 0):VectorToWorldSpace(flat)
	local ground = at + ahead * math.random(BOLT_NEAR, BOLT_FAR)
	ground = Vector3.new(ground.X, at.Y - 30, ground.Z)
	-- the thunder, as far behind the flash as the strike is far away
	task.delay(math.clamp((ground - at).Magnitude / 340, 0.3, 1.2), Sfx.play, "Thunder", nil, 0.9 + math.random() * 0.2)
	local points = { ground + Vector3.new(0, BOLT_HEIGHT, 0) }
	for i = 1, BOLT_STEPS do
		local wobble = if i == BOLT_STEPS then Vector3.zero else Vector3.new(math.random(-22, 22), 0, math.random(-22, 22))
		points[i + 1] = ground + Vector3.new(0, BOLT_HEIGHT * (1 - i / BOLT_STEPS), 0) + wobble
	end
	for i = 1, BOLT_STEPS do
		boltStep(boltParts[i], points[i], points[i + 1], 3.2 - i * 0.2)
	end
	local side = CFrame.Angles(0, math.random() * math.pi * 2, 0):VectorToWorldSpace(Vector3.xAxis)
	local from = points[3]
	for i = 1, 3 do
		local to = from + side * math.random(14, 24) + Vector3.new(math.random(-6, 6), -math.random(22, 32), math.random(-6, 6))
		boltStep(boltParts[BOLT_STEPS + i], from, to, 1.5 - i * 0.3)
		from = to
	end
	bolt.Parent = workspace
end

local function showBolt(alpha: number)
	for _, part in boltParts do
		part.Transparency = 1 - alpha
	end
end

------------------------------------------------------------------------
-- The Harvest Moon: a huge orange moon low in the violet sky, a picture
-- hung far off. The haze washed it out to a faint pink disc, so it's drawn
-- over the haze (AlwaysOnTop) and fades out whenever something solid (a
-- roof, a hill) stands between it and the camera. The usual small moon
-- hides meanwhile.

local MOON_DIR = Vector3.new(0.25, 0.32, 0.91).Unit -- (low over the north: +Z, where the highway goes)
local MOON_DISTANCE = 1500
local moonPart = make("Part", {
	Name = "HarvestMoon", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
	CastShadow = false, Size = Vector3.new(1, 1, 1),
})
local moonGui = make("BillboardGui", {
	Name = "Moon", Size = UDim2.new(480, 0, 480, 0), LightInfluence = 0, MaxDistance = math.huge, AlwaysOnTop = true,
	ResetOnSpawn = false, Adornee = moonPart, Parent = moonPart,
})
local moonGlow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6),
	BackgroundColor3 = rgb(255, 170, 80), BackgroundTransparency = 0.82, Parent = moonGui,
}, { UI.corner(10000), make("UIGradient", { -- (fading out to its edge)
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) }),
}) })
local moonDisc = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = rgb(255, 255, 255), Parent = moonGui,
}, {
	UI.corner(10000),
	make("UIGradient", { Rotation = 35, Color = ColorSequence.new(rgb(255, 226, 140), rgb(255, 142, 52)) }),
})
for _, crater in { { 0.32, 0.36, 0.18 }, { 0.62, 0.3, 0.12 }, { 0.55, 0.62, 0.22 }, { 0.3, 0.68, 0.09 } } do
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(crater[1], crater[2]), Size = UDim2.fromScale(crater[3], crater[3]),
		BackgroundColor3 = rgb(236, 128, 52), BackgroundTransparency = 0.55, Parent = moonDisc,
	}, { UI.corner(10000) })
end

local function showMoon(weight: number)
	moonGlow.BackgroundTransparency = 1 - 0.45 * weight
	moonDisc.BackgroundTransparency = 1 - weight
	for _, crater in moonDisc:GetChildren() do
		if crater:IsA("Frame") then
			crater.BackgroundTransparency = 1 - 0.45 * weight
		end
	end
	moonGui.Enabled = weight > 0
end

------------------------------------------------------------------------
-- Lamps and windows for the night: Lights tagged "NightLight" switch on;
-- parts tagged "NightGlow" glow in their NightColor attribute. On a farm
-- nobody has (for rent), the farmhouse stays dark.

local glows = {} -- [BasePart] = { color, material } by day

local function lived(instance: Instance): boolean
	local node = instance.Parent
	while node and node ~= workspace do
		if string.match(node.Name, "^Plot%d+$") then
			return node:GetAttribute("OwnerName") ~= nil
		end
		node = node.Parent
	end
	return true
end

local function setNight(on: boolean)
	for _, light in CollectionService:GetTagged("NightLight") do
		if light:IsA("Light") then
			light.Enabled = on and lived(light)
		end
	end
	for _, part in CollectionService:GetTagged("NightGlow") do
		if part:IsA("BasePart") then
			if not glows[part] then
				glows[part] = { color = part.Color, material = part.Material }
			end
			local day = glows[part]
			local glow = on and lived(part)
			part.Color = if glow then part:GetAttribute("NightColor") or rgb(255, 214, 140) else day.color
			part.Material = if glow then Enum.Material.Neon else day.material
		end
	end
end

------------------------------------------------------------------------
-- The clocktower's four clocks (World/PlazaArt: "ClockFace" parts, their
-- hands "Hour" and "Minute") show the sky's time.

local function setClocks(clock: number)
	local hour, minute = (clock % 12) * 30, (clock % 1) * 360
	for _, face in CollectionService:GetTagged("ClockFace") do
		local gui = face:FindFirstChildOfClass("SurfaceGui")
		local hourHand = gui and gui:FindFirstChild("Hour")
		local minuteHand = gui and gui:FindFirstChild("Minute")
		if hourHand and minuteHand then
			hourHand.Rotation = hour
			minuteHand.Rotation = minute
		end
	end
end

------------------------------------------------------------------------
-- Name tags at night, and the Floodlights' outlines

local DAY_TAGS = 100 -- (Roblox's own distance)
local outlines = {} -- [Player] = Highlight

local function trusted(other: Player): boolean
	local state = PlayerState.current
	for _, entry in if state and state.trusted then state.trusted else {} do
		if entry.id == other.UserId then
			return true
		end
	end
	return false
end

local function updateTags(night: boolean)
	local world = workspace:FindFirstChild("World")
	local mine = player:GetAttribute("Plot") or 0
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local plot = other:GetAttribute("InFarm") or 0
		local model = world and plot > 0 and world:FindFirstChild(`Plot{plot}`)
		local floodlit = model and model:GetAttribute("Floodlights") == true
		if humanoid then
			humanoid.NameDisplayDistance = if night and not floodlit then Defences.NIGHT_TAGS else DAY_TAGS
		end
		local outlined = night and floodlit and plot == mine and character ~= nil and not trusted(other)
		local outline = outlines[other]
		if outlined and not (outline and outline.Parent and outline.Adornee == character) then
			if outline then
				outline:Destroy()
			end
			outlines[other] = make("Highlight", {
				Name = "FloodlitOutline", Adornee = character, FillTransparency = 1, OutlineColor = rgb(255, 60, 48), OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.Occluded, Parent = character,
			})
		elseif not outlined and outline then
			outline:Destroy()
			outlines[other] = nil
		end
	end
	for other, outline in outlines do
		if other.Parent ~= Players then
			outline:Destroy()
			outlines[other] = nil
		end
	end
end

------------------------------------------------------------------------
-- The sky dial on the HUD

local dial = make("TextButton", { -- (hung from the purse's frame, left of the coin sign: SkyController.Start)
	Name = "Sky", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -8, 0, 0), Size = UDim2.fromOffset(66, 96),
	BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = UI.screen,
})
make("Frame", { -- the rope it hangs from, up off the top of the screen (as the purse's)
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(3, 400),
	BackgroundColor3 = rgb(206, 170, 112), BorderSizePixel = 0, ZIndex = 0, Parent = dial,
})
local rim = make("Frame", {
	Name = "Rim", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = C.soil, Parent = dial,
}, { UI.corner(30), UI.stroke(UI.SEAM, 3) })
local face = make("Frame", {
	Name = "Face", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = C.cream, ZIndex = 2, Parent = rim,
}, { UI.corner(23), UI.stroke(C.stitch, 2) })
local icon = UI.label({
	Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center,
	Text = "☀️", ZIndex = 3, Parent = face,
})
local growthBadge = make("Frame", { -- what the weather does to growth, while it's not ×1
	Name = "Growth", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.fromOffset(36, 20),
	BackgroundColor3 = C.green, Visible = false, ZIndex = 4, Parent = rim,
}, { UI.corner(10), UI.stroke(UI.SEAM, 2) })
local growthLabel = UI.label({
	Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 13, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center,
	Text = "×1.5", ZIndex = 5, Parent = growthBadge,
})
local clockTag, clockLabel = UI.tag({ name = "Clock", text = "12:00", autoWidth = true, size = UDim2.fromOffset(0, 26), textSize = 15,
	anchor = Vector2.new(0.5, 0), position = UDim2.new(0.5, -6, 0, 64), parent = dial })

-- 14:30 on the sky's clock.
local function clockText(clock: number): string
	return string.format("%02d:%02d", math.floor(clock) % 24, math.floor(clock % 1 * 60))
end

local function growthText(id: string): string
	return `×{Weather.TYPES[id].growth}`
end

-- What a weather does, in a sentence or two (from the config, so the numbers
-- never drift from the rules).
local function describe(id: string): string
	local w = Weather.TYPES[id]
	if id == "Clear" then
		return "Clear skies. Ripe crops left out can still turn Golden (×2) or, very rarely, Rainbow (×8)."
	end
	local value = Weather.MUTATIONS[w.mutation].value
	local growth = if w.growth > 1 then `Crops grow {growthText(id)}. ` elseif w.growth < 1 then `Crops grow slower ({growthText(id)}). ` else ""
	local turn = if id == "GoldenHour" then `Ripe crops left out are 10 times as likely to turn Golden (×{value}).`
		else `Ripe crops left out may turn {w.mutation} (×{value}).`
	local heist = if id == "HarvestMoon" then " It's Heist Night: steals are quicker. Guard your farm!" else ""
	return `{w.icon} {w.name}! {growth}{turn}{heist}`
end

local shownId = nil
local warnedMoon = nil

local function updateDial(t: number, weather, clock: number)
	local id = weather.id
	local night = WeatherRules.isNight(t)
	icon.Text = if id == "Clear" then (if night then "🌙" else "☀️") else Weather.TYPES[id].icon
	local growth = Weather.TYPES[id].growth
	growthBadge.Visible = growth ~= 1
	growthLabel.Text = growthText(id)
	growthBadge.BackgroundColor3 = if growth > 1 then C.green else C.sky
	local moonIn = WeatherRules.nextMoon(t) - t
	if id ~= "HarvestMoon" and moonIn <= Weather.WARNING then
		clockLabel.Text = `🌕 {UI.formatTime(moonIn)}`
		UI.setTagColor(clockTag, C.gold, C.ink)
	else
		clockLabel.Text = clockText(clock)
		UI.setTagColor(clockTag, if id == "HarvestMoon" then rgb(196, 150, 255) else C.cream, C.ink)
	end
	-- the notes: when the weather changes, and 5 minutes before a Harvest Moon
	if shownId and id ~= shownId and id ~= "Clear" then
		UI.toast(describe(id), "Announce", 8)
	end
	shownId = id
	local next = WeatherRules.nextMoon(t)
	if moonIn <= Weather.WARNING and warnedMoon ~= next and id ~= "HarvestMoon" then
		warnedMoon = next
		UI.toast(`🌕 The Harvest Moon rises in {math.ceil(moonIn / 60)} minutes: crops grow ×{Weather.TYPES.HarvestMoon.growth} and steals are quicker. Guard your farm!`, "Announce", 8)
	end
end

dial.Activated:Connect(function()
	local t = WeatherRules.now()
	local weather = WeatherRules.weather(t)
	local left = if weather.id == "Clear" then "" else ` ({UI.formatTime(weather.endsAt - t)} left)`
	local night = WeatherRules.untilNight(t)
	local after = if WeatherRules.isNight(t) then "It's night: name tags only show up close." else `Night falls in {UI.formatTime(night)}.`
	UI.toast(`{describe(weather.id)}{left}\n{after} The next Harvest Moon: in {UI.formatTime(WeatherRules.nextMoon(t) - t)}.`, "Announce", 9)
end)

------------------------------------------------------------------------

function SkyController.Start()
	local purse = UI.screen:WaitForChild("Purse", 10)
	if purse then
		dial.Parent = purse
	end
	local camera = workspace.CurrentCamera
	local sky = Lighting:FindFirstChildOfClass("Sky") or make("Sky", { Name = "Sky", Parent = Lighting })
	local moonSize = sky.MoonAngularSize
	local atmosphere = effect("Atmosphere") :: Atmosphere
	local grade = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	local rays = effect("SunRaysEffect") :: SunRaysEffect
	around.Parent = workspace
	moonPart.Parent = workspace

	local shown = WeatherRules.clock(WeatherRules.now())
	local night = nil
	local toldNight = false
	local ticks = 0
	local moonShown = 0
	local flash, nextFlash = 0, 0
	local boltLit = false
	local acc = 0
	local function ignore()
		local list = { around, moonPart }
		for _, other in game:GetService("Players"):GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		skyParams.FilterDescendantsInstances = list
	end
	ignore()
	local at = camera.CFrame.Position
	RunService.RenderStepped:Connect(function(dt)
		at = camera.CFrame.Position
		around.CFrame = CFrame.new(at + Vector3.new(0, 32, 0))
		moonPart.CFrame = CFrame.new(at + MOON_DIR * MOON_DISTANCE)
		flash = math.max(0, flash - dt * 4)
		if flash > 0 or boltLit then
			boltLit = flash > 0
			showBolt(math.min(1, flash * 1.5))
		end
		acc += dt
		if acc < 0.1 and flash <= 0 then
			return
		end
		local step = acc
		acc = 0
		if math.random() < 0.05 then
			ignore() -- (now and then: characters come and go)
		end

		local t = WeatherRules.now()
		local weather = WeatherRules.weather(t)
		local id = weather.id
		local weight = if id == "Clear" then 0 else math.clamp((t - weather.startsAt) / FADE, 0, 1) * math.clamp((weather.endsAt - t) / FADE, 0, 1)

		-- the clock eases round when it jumps (the Harvest Moon, /time)
		local target = WeatherRules.clock(t)
		local diff = (target - shown + 12) % 24 - 12
		shown = if math.abs(diff) > 0.05 then (shown + math.sign(diff) * math.min(math.abs(diff), 8 * step)) % 24 else target
		Lighting.ClockTime = shown
		setClocks(shown)

		local looks = LOOKS[id]
		local look = mix(mix(NIGHT, looks.night, weight), mix(DAY, looks.day, weight), dayness(shown))
		Lighting.Brightness = look.brightness
		Lighting.ExposureCompensation = look.exposure
		Lighting.Ambient = look.ambient
		Lighting.OutdoorAmbient = look.outdoor
		Lighting.ColorShift_Top = look.sun
		atmosphere.Density = look.density
		atmosphere.Color = look.air
		atmosphere.Decay = look.decay
		atmosphere.Haze = look.haze
		atmosphere.Glare = look.glare
		grade.Saturation = look.saturation
		grade.Contrast = look.contrast
		grade.TintColor = look.tint
		grade.Brightness = flash * 0.35 * UI.flashing -- (Settings: Flashing effects)
		rays.Intensity = look.rays

		-- what falls, the moon, and lightning in a storm
		local rates = RATES[id] or {}
		-- (phones: half as many; none under a roof, where it fell straight
		-- through the Auction House's)
		local thin = if UI.touch then 0.5 else 1
		local roof = workspace:Raycast(at, Vector3.new(0, 60, 0), skyParams)
		if roof then
			thin = 0
		end
		rain.Rate = (rates.rain or 0) * weight * thin
		frost.Rate = (rates.frost or 0) * weight * thin
		dust.Rate = (rates.dust or 0) * weight * thin
		local moonWant = if id == "HarvestMoon" then weight else 0
		if moonWant > 0 and workspace:Raycast(at, MOON_DIR * (MOON_DISTANCE - 20), skyParams) then
			moonWant = 0 -- (behind a roof or a hill)
		end
		moonShown += (moonWant - moonShown) * math.min(1, step * 8)
		showMoon(moonShown)
		sky.MoonAngularSize = if id == "HarvestMoon" and weight > 0.5 then 0 else moonSize
		if id == "Thunderstorm" and weight > 0.5 and os.clock() >= nextFlash then
			nextFlash = os.clock() + 6 + math.random() * 8
			flash = 1
			strike(at, camera.CFrame.LookVector)
			task.delay(0.22, function()
				flash = 0.7 -- (the second flicker)
			end)
		end

		local isNight = dayness(shown) < 0.4 or id == "HarvestMoon"
		SkyController.state.weather, SkyController.state.weight, SkyController.state.night = id, weight, isNight
		if isNight ~= night then
			if isNight and night == false and not toldNight then
				toldNight = true
				UI.toast(`🌙 Night falls: name tags only show within {Defences.NIGHT_TAGS} studs. Floodlights light up your farm.`, "Announce", 7)
			end
			night = isNight
			setNight(isNight)
		end
		updateDial(t, weather, shown)
		ticks += 1
		if ticks % 5 == 0 then
			updateTags(isNight)
		end
	end)
	CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(light)
		if light:IsA("Light") then
			light.Enabled = night == true and lived(light)
		end
	end)
	CollectionService:GetInstanceAddedSignal("NightGlow"):Connect(function()
		setNight(night == true)
	end)
	-- (a farm someone takes after dark lights up; one they leave goes dark)
	local world = workspace:WaitForChild("World")
	local function watch(plot: Instance)
		if string.match(plot.Name, "^Plot%d+$") then
			plot:GetAttributeChangedSignal("OwnerName"):Connect(function()
				setNight(night == true)
			end)
		end
	end
	for _, plot in world:GetChildren() do
		watch(plot)
	end
	world.ChildAdded:Connect(watch)
end

return SkyController
