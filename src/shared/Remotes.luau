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
--   CrimeAction    C→S  ("Steal" tile | "StealDone" | "StealCancel" | "Swing" | "ArrestStart" userId | "Arrest" userId
--                        | "Climb" | "LeaveFarm") -> { ok, reason?, result? }   raids (server/Services/CrimeService,
--                        shared/CrimeRules, shared/LootRules): the server times every hold
--   CrimeEvent     S→C  ("Alarm", { userId, name, crop, plot, tile, ends }) to an owner · ("Bonk", { userId, at, suspect })
--                        · ("Nudge", { at }) · ("Puff", { at }) to everyone · ("Busted", { name, charge, fine, paid,
--                        owed, owner, number }) to the thief · ("Arrested", { name, fine, paid, owed }) to the owner
--                        · ("Deposited", { text }) to the thief   effects and cards (client CrimeController)
--   PoliceAction   C→S  ("Pay" coins or "all") -> { ok, reason?, result? }   paying debts early at the police desk
--                        (server/Services/PayoutService)
--   DefenceAction  C→S  ("Buy" itemId | "Place" "itemId|spot" | "PutAway" spot | "Trust" userId | "Untrust" userId
--                        | "DropShield" | "Visitors") -> { ok, reason?, result? }   defences, the Trusted list, the
--                        Sprout Shield, the camera's visitors (server/Services/DefenceService, shared/DefenceRules)
--   DefenceEvent   S→C  ("Near", { name, userId }) the scarecrow's warning to an owner · ("ShieldOver") your
--                        Sprout Shield ended (the Farm Rules card) · ("Bark", { plot }) · ("Bell", { plot })
--   AuctionAction  C→S  ("Bid" amount) -> { ok, reason? } from inside the Auction House (server/Services/AuctionService;
--                        the lot on the board is ReplicatedStorage.Auction's attributes)
--   QuestAction    C→S  ("Claim" index | "Bonus") -> { ok, reason?, result = { coins } } (server/Services/QuestService)
--   GuideAction    C→S  ("Hide" | "Show") -> { ok, reason? }   the Farm Guide's card (server/Services/GuideService)
--   TradeAction    C→S  ("Request" userId | "Accept" userId | "Decline" userId | "Set" "kind|key|count" | "Coins" n
--                        | "Ready" "1"/"0" | "Confirm" | "Cancel") -> { ok, reason? }   trading (server/Services/TradeService,
--                        shared/TradeRules)
--   TradeEvent     S→C  { kind = "invite", userId, name, seconds } · { kind = "state", trade } · { kind = "problem", text }
--                        · { kind = "declined", name } · { kind = "closed", reason?, done?, with?, lines?, coins?, value? }
--   SettingsAction C→S  ("Set" "key=value") -> { ok, reason? }   the Settings window (server/Services/SettingsService,
--                        shared/SettingsRules)
--   RobuxAction    C→S  ("StartWeather" weatherId | "Equip" "kind|id" | "DevBuy" id (Studio only)) -> { ok, reason? }
--                        the Robux window (server/Services/MonetizationService, shared/RobuxRules; purchases
--                        themselves go through MarketplaceService)
--   RobuxFunnel    C→S  "Opened" | "Tab:x" | "Prompt:id"   the Robux shop's analytics funnel (its own remote, so a
--                        note never takes the action remote's cooldown from a purchase)
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
	CrimeAction = "RemoteFunction",
	CrimeEvent = "RemoteEvent",
	PoliceAction = "RemoteFunction",
	DefenceAction = "RemoteFunction",
	DefenceEvent = "RemoteEvent",
	AuctionAction = "RemoteFunction",
	QuestAction = "RemoteFunction",
	GuideAction = "RemoteFunction",
	TradeAction = "RemoteFunction",
	TradeEvent = "RemoteEvent",
	SettingsAction = "RemoteFunction",
	RobuxAction = "RemoteFunction",
	RobuxFunnel = "RemoteEvent",
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
