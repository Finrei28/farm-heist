-- Who may use the support commands in live servers (TradeService's /trades
-- and /rollback), and DevCommandService's commands, which run in Studio
-- only. That's the game's owner and anyone in USER_IDS; in Studio, everyone
-- (for testing). tests/staff.test.luau.
--
-- The owner: the user who owns the game, or, when a community (group) owns
-- it, any member of it ranked GROUP_RANK or higher (docs/RobloxPage.md,
-- "Publishing as a community").
local RunService = game:GetService("RunService")

local Staff = {}

-- [userId] = true: extra people (moderators) allowed, besides the owner.
Staff.USER_IDS = {}

-- In a community-owned game, the lowest rank that counts as staff. 255 is
-- the community's owner only; to let a role in too (a "Moderator" role
-- ranked 200, say: the community's Roles settings show each role's rank),
-- set this to that role's rank.
Staff.GROUP_RANK = 255

-- The player's rank in the community that owns the game (0: not in it, or
-- Roblox couldn't be asked, so they're not staff this time). Roblox keeps
-- the answer while they're in the server, so a rank changed meanwhile
-- counts from their next join.
local function rankInOwner(player: Player): number
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return if ok and typeof(rank) == "number" then rank else 0
end

function Staff.isStaff(player: Player): boolean
	if RunService:IsStudio() or Staff.USER_IDS[player.UserId] == true then
		return true
	elseif game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		return rankInOwner(player) >= Staff.GROUP_RANK
	end
	return false
end

return Staff
