-- The Invite sign in the top bar (docs/GameDesign.md §5): opens Roblox's own
-- window for inviting friends. A new game only reaches under-16s after 250
-- highly engaged players have played it, and nobody's shown it until then, so
-- a player who likes it is the best way in (the user, 2026-11-05).
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local HudController = require(script.Parent.HudController)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local InviteController = {}

local MESSAGE = "Ask your friends to farm with you!" -- (Roblox drops one too long for its window)

local asking = false

local function invite()
	if asking then
		return
	end
	asking = true
	-- (it depends on the player and the device, and it's a call that can fail)
	local checked, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	local shown = false
	if checked and can then
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = MESSAGE
		shown = pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
	end
	if not shown then
		UI.toast("Invites aren't available right now. Try again later.", "Error", 3)
	end
	asking = false
end

function InviteController.Start()
	HudController.topButton("👥", "Invite", 0).Activated:Connect(invite)
end

return InviteController
