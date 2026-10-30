-- Who may use the commands that work in live servers: event commands
-- (DevCommandService) and support tools such as trade rollback and undoing
-- an arrest. That's the game's owner and anyone in USER_IDS; in Studio,
-- everyone (for testing).
local RunService = game:GetService("RunService")

local Staff = {}

-- [userId] = true: extra people (moderators) allowed, besides the owner.
Staff.USER_IDS = {}

function Staff.isStaff(player: Player): boolean
	return RunService:IsStudio() or Staff.USER_IDS[player.UserId] == true
		or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

return Staff
