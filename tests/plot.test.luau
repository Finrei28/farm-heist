-- Handing out plots (shared/PlotRules): next to a friend if one's here,
-- else nearest the highway.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local PlotRules = harness.load("PlotRules")

	local function freeExcept(...)
		local free = {}
		for index = 1, 8 do
			free[index] = true
		end
		for _, taken in { ... } do
			free[taken] = nil
		end
		return free
	end

	describe("choosing a plot", function()
		it("fills from the highway out: 1 and 8 first, then 2 and 7", function()
			expect(PlotRules.choose(freeExcept())).toBe(1)
			expect(PlotRules.choose(freeExcept(1))).toBe(8)
			expect(PlotRules.choose(freeExcept(1, 8))).toBe(2)
			expect(PlotRules.choose(freeExcept(1, 8, 2))).toBe(7)
			expect(PlotRules.choose(freeExcept(1, 2, 3, 6, 7, 8))).toBe(4)
		end)
		it("puts you next to a friend when there's room", function()
			expect(PlotRules.choose(freeExcept(1, 8, 4), { 4 })).toBe(3)
			expect(PlotRules.choose(freeExcept(1, 8, 4, 3), { 4 })).toBe(5)
			-- plot 8's neighbours wrap round to 1
			expect(PlotRules.choose(freeExcept(8, 7), { 8 })).toBe(1)
		end)
		it("falls back to the highway rule when the friend has no free neighbour", function()
			expect(PlotRules.choose(freeExcept(1, 8, 2, 4, 3, 5), { 4 })).toBe(7)
		end)
		it("returns nil when the server is full", function()
			expect(PlotRules.choose({})).toBe(nil)
		end)
	end)
end
