-- Wires a RemoteFunction to a table of named actions, with argument checks,
-- a per-player cooldown and a { ok, reason? } response.
--
-- Each action is action(player, data, arg) where arg is a string or nil, and
-- returns nil on success or a failure reason string. A successful action
-- triggers a state sync to the client.
local Players = game:GetService("Players")

return function(remote: RemoteFunction, actions, DataService, cooldown: number)
	local lastActionAt = {} -- [Player] = os.clock()

	remote.OnServerInvoke = function(player, actionName, arg)
		if typeof(actionName) ~= "string" or not actions[actionName] or (arg ~= nil and typeof(arg) ~= "string") then
			return { ok = false, reason = "BadRequest" }
		end
		local now = os.clock()
		if lastActionAt[player] and now - lastActionAt[player] < cooldown then
			return { ok = false, reason = "Cooldown" }
		end
		lastActionAt[player] = now

		local data = DataService.Get(player)
		if not data then
			return { ok = false, reason = "NotLoaded" }
		end

		local failure = actions[actionName](player, data, arg)
		if failure then
			return { ok = false, reason = failure }
		end
		DataService.NotifyState(player)
		return { ok = true }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
	end)
end
