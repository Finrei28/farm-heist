-- Server entry point. Start order matters: data first, so other services can
-- rely on DataService.Get once a player's data has loaded.
--
-- Coming next (docs/GameDesign.md §9, week 1): PlotService, FieldService,
-- SeedShopService, LandService, TravelService, DevCommandService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- creates the remotes before clients look for them

-- The greybox of Cloverdale (shared/PlotLayout), rebuilt at every start.
require(script.World.WorldBuilder).Build()

local Services = script.Services
local DataService = require(Services.DataService)
local MovementService = require(Services.MovementService)

DataService.Start()
MovementService.Start()
