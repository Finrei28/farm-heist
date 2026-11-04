-- Messages to players over the Notify remote (the client's toasts and cards).
--   kind: nil (a toast) · "Good" · "Error" · "Announce" (yellow paper) · "LevelUp" (a card; extra = { level, permits })
--   extra.everyone = true: news that isn't about this player (Quiet mode hides it)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = Remotes.event("Notify")

local Notice = {}

function Notice.send(player: Player, text: string, kind: string?, extra: { [string]: any }?)
	local payload = { text = text, kind = kind }
	for key, value in extra or {} do
		payload[key] = value
	end
	Notify:FireClient(player, payload)
end

-- News for everyone (Quiet mode hides it: client Settings).
function Notice.all(text: string, kind: string?)
	Notify:FireAllClients({ text = text, kind = kind, everyone = true })
end

return Notice
