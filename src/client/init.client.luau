-- Client entry point: a "Farm Heist" cover until your character appears at
-- your farmhouse door (the server only spawns you once your farm is ready),
-- then the HUD and its controllers (Kraft & Crate, docs/GameDesign.md §5).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Phones: sideways only (the HUD is laid out for landscape). Either way up
-- is fine (the sensor flips it); never portrait.
player:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local UI = require(script.UI)
local PlayerState = require(script.PlayerState)

do
	local cover = UI.make("ScreenGui", {
		Name = "LoadingCover",
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 100,
		ResetOnSpawn = false,
		Parent = player.PlayerGui,
	})
	-- kraft paper, and the farm's sign hung on two ropes
	local paper = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.C.kraft, Parent = cover })
	local sign = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(460, 110), Parent = paper,
	}, { UI.corner(8), UI.stroke(UI.SEAM, 5) })
	UI.wood(sign, 3, false, UI.C.red)
	for _, x in { 0.1, 0.9 } do
		UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, 0, 10), Size = UDim2.fromOffset(5, 400),
			Rotation = if x < 0.5 then 8 else -8, BackgroundColor3 = Color3.fromRGB(206, 170, 112), BorderSizePixel = 0, ZIndex = 0, Parent = sign,
		})
	end
	local title = UI.make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, Text = "FARM HEIST", TextSize = 64,
		TextColor3 = UI.C.cream, TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Parent = sign,
	})
	local subtitle = UI.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(520, 34),
		BackgroundTransparency = 1, Font = UI.HAND, Text = "Heading to your farm...", TextSize = 30, TextColor3 = UI.C.ink, Parent = paper,
	})
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.6) -- (the server moves you to your door straight after spawning)
		local info = TweenInfo.new(0.5)
		TweenService:Create(paper, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(sign, info, { Position = UDim2.fromScale(0.5, -0.3) }):Play() -- (the sign is hauled up out of sight)
		TweenService:Create(title, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(subtitle, info, { TextTransparency = 1 }):Play()
		task.wait(0.5)
		cover:Destroy()
	end)
end

PlayerState.Start()

local Controllers = script.Controllers
for _, name in {
	"HudController", "HotbarController", "FieldController", "SeedRackController", "BarnController", "StoreController", "DecorateController",
	"MarketController", "ShedController", "TruckController", "ShopperController", "PromptController", "SprintController", "RoofController",
	"WarehouseController", "WorkersController", "WorkerController",
} do
	task.spawn(function() -- (one waiting on the world doesn't hold up the rest)
		local ok, err = pcall(function()
			require(Controllers[name]).Start()
		end)
		if not ok then
			warn(`[Farm Heist] {name} failed to start: {err}`)
		end
	end)
end
