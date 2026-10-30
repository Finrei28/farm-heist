-- The light and sky (docs/ArtDirection.md §4), set at every server start so
-- every server looks the same and the values live in git. (Lighting.Technology
-- isn't ours to pick any more: Studio doesn't show it and scripts can't
-- touch it. Roblox chooses the lighting engine itself.)
--
-- The 24-minute day (§4.14) comes with the weather; until then it's always
-- early afternoon.
local Lighting = game:GetService("Lighting")

local LightingSetup = {}

LightingSetup.CLOCK_TIME = 14.5

local function effect(className: string, props)
	local instance = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = Lighting
	return instance
end

function LightingSetup.Apply()
	Lighting.ClockTime = LightingSetup.CLOCK_TIME
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = Color3.fromRGB(90, 86, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 154, 144) -- light shadows: nothing important hides in the dark
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 214) -- a warm sun
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.1,
		Color = Color3.fromRGB(200, 225, 240),
		Decay = Color3.fromRGB(120, 150, 170),
		Haze = 1.2,
		Glare = 0.15,
	})
	effect("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.06, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	effect("BloomEffect", { Intensity = 0.35, Size = 24, Threshold = 1.6 }) -- only glowing things bloom
	effect("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
	-- No Depth of Field: it blurs the far end of the field, where thieves stand.
	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") then
			child:Destroy()
		end
	end
end

return LightingSetup
