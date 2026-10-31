-- Single source of truth for networking. The server creates the remotes on
-- first require; the client waits for them. Add a remote here before a
-- service uses it.
--
--   StateChanged   S→C  (state)  coins, level, land, seeds ... see DataService.getPublicState
--   GetState       C→S  () -> state?
--   Notify         S→C  { text, kind?, ... }  toasts, cards and announcements (server/Util/Notice)
--   FieldAction    C→S  ("Plant" "tile|cropId" | "Water" tile | "Harvest" tile | "Flag" tile) -> { ok, reason? }
--   SeedAction     C→S  ("Buy" "cropId|count") -> { ok, reason? }   Barley's Seeds (shared/SeedStock)
--   LandAction     C→S  ("Clear" block) -> { ok, reason? }   Land Permits (shared/LandRules; obstacles are server prompts)
--   TravelAction   C→S  ("Home" | "Town" | "Visit" userId | "Cancel") -> { ok, reason? }   (shared/TravelRules)
--   WarehouseAction C→S ("Wash" "stackKey|Truck" or "stackKey|Store" | "Pack" | "Upgrade" | "Route" "cropId|Truck/Store/Keep/0.7"
--                        | "DriverRule" share) -> { ok, reason?, result? }   the warehouse (server/Services/WarehouseService):
--                        at the bench Wash starts the hold, Pack is letting go (result = { grade, units, crop, to })
--   TruckAction    C→S  ("Dispatch" [truck]) -> { ok, reason? }   send the loaded trucks (shared/TruckRules)
--   WorkerAction   C→S  ("Hire" candidateId | "Train" uid | "Fire" uid | "Replant" "same"/"cheapest"/"none") -> { ok, reason?, result? }
--                        your crew (server/Services/WorkerService, shared/WorkerRules)
--   WorkerEvent    S→C  ("Crew", { plot, workers = { { id, type, name, level, look, at, face, strike } } }) where each
--                        worker stands · ("Do", { plot, id, at, to, carry?, back? }) a worker walks to `to` from
--                        server time `at` (and back) · ("Clear", { plot })   drawn by the clients (WorkerController)
--   StoreAction    C→S  ("Price" "cropId|coins" | "Fill" id or "all" | "SetSlot" "id|slot|cropId or Auto"
--                        | "Upgrade" | "Name" text | "Decorate" "On"/"Off" | "Layout" json) -> { ok, reason?, result? }
--                        your store (server/Services/StoreService, shared/ShopRules, shared/StoreLayout)
--   ShopperEvent   S→C  ("Path", { plot, id, look, at, points, face?, say?, basket, leave? }) a walk from
--                        server time `at` (replacing the last) · ("Paid", { plot, id, coins }) · ("Clear", { plot })
--                        NPC shoppers in the stores, drawn by the clients (ShopperController)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	StateChanged = "RemoteEvent",
	GetState = "RemoteFunction",
	Notify = "RemoteEvent",
	FieldAction = "RemoteFunction",
	SeedAction = "RemoteFunction",
	LandAction = "RemoteFunction",
	TravelAction = "RemoteFunction",
	WarehouseAction = "RemoteFunction",
	TruckAction = "RemoteFunction",
	StoreAction = "RemoteFunction",
	ShopperEvent = "RemoteEvent",
	WorkerAction = "RemoteFunction",
	WorkerEvent = "RemoteEvent",
}

local IS_SERVER = RunService:IsServer()

local folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function get(name: string, className: string)
	assert(DEFINITIONS[name] == className, `{name} is not a defined {className}`)
	return if IS_SERVER then folder[name] else folder:WaitForChild(name)
end

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	return get(name, "RemoteEvent")
end

function Remotes.func(name: string): RemoteFunction
	return get(name, "RemoteFunction")
end

return Remotes
