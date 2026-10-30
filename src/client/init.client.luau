-- Client entry point. The HUD (Kraft & Crate, docs/GameDesign.md §5) and the
-- controllers come with week 1; for now this keeps phones in landscape and
-- picks up the player's state so the project runs end to end.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

-- Phones: sideways only (the HUD is laid out for landscape). Either way up
-- is fine (the sensor flips it); never portrait.
Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local state = Remotes.func("GetState"):InvokeServer()
Remotes.event("StateChanged").OnClientEvent:Connect(function(newState)
	state = newState
end)
if state then
	print(`[Farm Heist] Loaded: {state.coins} coins, level {state.level}`)
end
