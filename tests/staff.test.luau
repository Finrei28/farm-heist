-- Who counts as staff (server/Util/Staff): the game's owner, whether a user
-- or a community (group) owns the game, anyone in USER_IDS, and everyone in
-- Studio.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local CreatorType = roblox.Enum.CreatorType

	local OWNER, GROUP = 1001, 5005

	-- A fake game: who owns it, and whether this is Studio.
	local studio = false
	local fakeGame = {
		CreatorType = CreatorType.User,
		CreatorId = OWNER,
		GetService = function(_, name)
			assert(name == "RunService", name)
			return { IsStudio = function()
				return studio
			end }
		end,
	}

	local function load(creatorType, creatorId)
		fakeGame.CreatorType, fakeGame.CreatorId = creatorType, creatorId
		studio = false
		return harness.loadServerWith("Util/Staff", { game = fakeGame })
	end

	-- A player with this rank in each community: { [groupId] = rank }, or
	-- "down" when Roblox can't be asked.
	local function player(userId: number, ranks)
		return {
			UserId = userId,
			GetRankInGroup = function(_, groupId)
				if ranks == "down" then
					error("HTTP 503 (Service Unavailable)")
				end
				return (ranks or {})[groupId] or 0
			end,
		}
	end

	describe("a game a user owns", function()
		it("counts its owner, and nobody else", function()
			local Staff = load(CreatorType.User, OWNER)
			expect(Staff.isStaff(player(OWNER))).toBe(true)
			expect(Staff.isStaff(player(2002))).toBe(false)
			expect(Staff.isStaff(player(2002, { [GROUP] = 255 }))).toBe(false) -- (communities don't come into it)
		end)
	end)

	describe("a game a community owns", function()
		it("counts the community's owner (rank 255)", function()
			local Staff = load(CreatorType.Group, GROUP)
			expect(Staff.isStaff(player(OWNER, { [GROUP] = 255 }))).toBe(true)
		end)
		it("doesn't count other members, people outside it, or someone whose user id is the community's id", function()
			local Staff = load(CreatorType.Group, GROUP)
			expect(Staff.isStaff(player(2002, { [GROUP] = 200 }))).toBe(false)
			expect(Staff.isStaff(player(2002, { [9009] = 255 }))).toBe(false) -- (the owner of another community)
			expect(Staff.isStaff(player(2002))).toBe(false)
			expect(Staff.isStaff(player(GROUP))).toBe(false)
		end)
		it("counts a role too when GROUP_RANK is lowered to its rank", function()
			local Staff = load(CreatorType.Group, GROUP)
			Staff.GROUP_RANK = 200
			expect(Staff.isStaff(player(2002, { [GROUP] = 200 }))).toBe(true)
			expect(Staff.isStaff(player(2003, { [GROUP] = 199 }))).toBe(false)
			expect(Staff.isStaff(player(OWNER, { [GROUP] = 255 }))).toBe(true)
		end)
		it("says no, without erroring, when Roblox can't be asked for the rank", function()
			local Staff = load(CreatorType.Group, GROUP)
			expect(Staff.isStaff(player(OWNER, "down"))).toBe(false)
		end)
	end)

	describe("either way", function()
		it("counts anyone in USER_IDS", function()
			for _, owner in { { CreatorType.User, OWNER }, { CreatorType.Group, GROUP } } do
				local Staff = load(owner[1], owner[2])
				Staff.USER_IDS[3003] = true
				expect(Staff.isStaff(player(3003, "down"))).toBe(true)
				expect(Staff.isStaff(player(3004))).toBe(false)
			end
		end)
		it("counts everyone in Studio", function()
			local Staff = load(CreatorType.Group, GROUP)
			studio = true
			expect(Staff.isStaff(player(4004))).toBe(true)
		end)
	end)
end
