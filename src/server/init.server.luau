-- Server entry point. Start order matters: data first, so other services can
-- rely on DataService.Get once a player's data has loaded; plots before the
-- services that draw on them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Characters load once the player's farm is ready (PlotService), never in
-- town first: set before anyone can join.
Players.CharacterAutoLoads = false

require(ReplicatedStorage.Shared.Remotes) -- creates the remotes before clients look for them

-- Cloverdale (shared/PlotLayout), rebuilt at every start, and its light.
require(script.World.WorldBuilder).Build()
require(script.World.LightingSetup).Apply()

local Services = script.Services
local DataService = require(Services.DataService)
local MovementService = require(Services.MovementService)
local PlotService = require(Services.PlotService)
local FieldService = require(Services.FieldService)
local SeedShopService = require(Services.SeedShopService)
local LandService = require(Services.LandService)
local TravelService = require(Services.TravelService)
local MarketService = require(Services.MarketService)
local StoreService = require(Services.StoreService)
local WarehouseService = require(Services.WarehouseService)
local TruckService = require(Services.TruckService)
local DevCommandService = require(Services.DevCommandService)

DataService.Start()
MovementService.Start()
PlotService.Start()
FieldService.Start()
SeedShopService.Start()
LandService.Start()
TravelService.Start()
MarketService.Start()
StoreService.Start()
WarehouseService.Start()
TruckService.Start()
DevCommandService.Start()
