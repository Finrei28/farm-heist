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
