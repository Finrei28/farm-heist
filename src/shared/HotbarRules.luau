-- Which seeds the hotbar shows (docs/GameDesign.md §5.2). With more seeds than
-- it has room for, the last place goes to an ALL packet that opens the seed
-- picker, and the seed in your hand always keeps a place (the user, 2026-11-06:
-- with a full hotbar a seed picked from the picker wasn't on the bar, so you
-- couldn't put it away, and E only ever planted it). tests/hotbar.test.luau.
local HotbarRules = {}

-- ids: every seed you have, in the bar's order. held: the one in your hand.
-- room: places on the bar. Returns the seeds to show, and whether the ALL
-- packet goes after them.
function HotbarRules.shown(ids: { string }, held: string?, room: number): ({ string }, boolean)
	if #ids <= room then
		return ids, false
	end
	local shown = table.move(ids, 1, room - 1, 1, {})
	if held and table.find(ids, held) and not table.find(shown, held) then
		shown[#shown] = held
	end
	return shown, true
end

return HotbarRules
