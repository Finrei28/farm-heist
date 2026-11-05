-- Wires a RemoteFunction to a table of named actions, with argument checks,
-- a per-player cooldown and a { ok, reason? } response. arg is at most
-- maxArg characters (default MAX_ARG): the actions run string patterns on it,
-- and a pattern over a long enough string can stall the whole server.
--
-- Each action is action(player, data, arg) where arg is a string or nil, and
-- returns nil on success or a failure reason string; on success it may also
-- return a result for the client ({ ok = true, result }). A successful
-- action triggers a state sync to the client.
local Players = game:GetService("Players")

local MAX_ARG = 200

return function(remote: RemoteFunction, actions, DataService, cooldown: number, maxArg: number?)
	local lastActionAt = {} -- [Player] = os.clock()
	local longest = maxArg or MAX_ARG

	remote.OnServerInvoke = function(player, actionName, arg)
		if typeof(actionName) ~= "string" or not actions[actionName] or (arg ~= nil and (typeof(arg) ~= "string" or #arg > longest)) then
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

		local failure, result = actions[actionName](player, data, arg)
		if failure then
			return { ok = false, reason = failure }
		end
		DataService.NotifyState(player)
		return { ok = true, result = result }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
	end)
end
