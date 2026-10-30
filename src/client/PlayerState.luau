-- The player's own state from the server (DataService.getPublicState):
-- coins, level, inventory, land, seed stock... Controllers read
-- PlayerState.current and listen to PlayerState.changed.
-- (The field itself isn't here: tiles carry their state as attributes, see
-- server/World/FarmArt.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local PlayerState = {}

local changedEvent = Instance.new("BindableEvent")
PlayerState.changed = changedEvent.Event -- (state)
PlayerState.current = nil

local function set(state)
	if state then
		PlayerState.current = state
		changedEvent:Fire(state)
	end
end

function PlayerState.Start()
	Remotes.event("StateChanged").OnClientEvent:Connect(set)
	task.spawn(function()
		while not PlayerState.current do
			set(Remotes.func("GetState"):InvokeServer())
			if not PlayerState.current then
				task.wait(1) -- (the save is still loading)
			end
		end
	end)
end

-- Runs callback(state) now (if loaded) and on every change.
function PlayerState.observe(callback)
	if PlayerState.current then
		task.spawn(callback, PlayerState.current)
	end
	return PlayerState.changed:Connect(callback)
end

return PlayerState
