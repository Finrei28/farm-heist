-- The player's settings (shared/SettingsRules): defaults, the values each
-- can take, and what the Settings window sends being checked.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local SettingsRules = harness.load("SettingsRules")

	describe("the settings", function()
		it("has every setting of the design doc (§5.6), each with a default", function()
			local keys = {}
			for _, setting in SettingsRules.LIST do
				table.insert(keys, setting.key)
				expect(setting.default ~= nil).toBe(true)
				if setting.kind == "steps" then
					expect(table.find(setting.steps, setting.default) ~= nil).toBe(true)
				end
			end
			expect(table.concat(keys, " ")).toBe("music sfx ambience flashing reducedMotion textSize trades quiet")
		end)
		it("flashing runs 0–100% and text size 80–125%", function()
			local flashing, text = SettingsRules.BY_KEY.flashing.steps, SettingsRules.BY_KEY.textSize.steps
			expect(flashing[1]).toBe(0)
			expect(flashing[#flashing]).toBe(1)
			expect(text[1]).toBe(0.8)
			expect(text[#text]).toBe(1.25)
		end)
		it("reads a value from a save, or its default", function()
			expect(SettingsRules.get(nil, "music")).toBe(true)
			expect(SettingsRules.get({ music = false }, "music")).toBe(false)
			expect(SettingsRules.get({ flashing = 0.5 }, "flashing")).toBe(0.5)
			expect(SettingsRules.get({ flashing = 0.4 }, "flashing")).toBe(1) -- (not a step: the default)
			expect(SettingsRules.get({ quiet = "yes" }, "quiet")).toBe(false)
			expect(SettingsRules.get({}, "nope")).toBe(nil)
		end)
	end)

	describe("what the window sends", function()
		it("takes switches as 1 or 0 and steps only as one of their values", function()
			local key, value = SettingsRules.parse("music=0")
			expect(key).toBe("music")
			expect(value).toBe(false)
			key, value = SettingsRules.parse("quiet=1")
			expect(value).toBe(true)
			key, value = SettingsRules.parse("flashing=0.25")
			expect(key).toBe("flashing")
			expect(value).toBe(0.25)
			key, value = SettingsRules.parse("textSize=1.25")
			expect(value).toBe(1.25)
		end)
		it("refuses anything else", function()
			for _, arg in { "music=2", "flashing=0.3", "textSize=3", "coins=1", "music", "", "music=1;coins=9" } do
				local key, reason = SettingsRules.parse(arg)
				expect(key).toBe(nil)
				expect(reason).toBe("BadRequest")
			end
			local key = SettingsRules.parse(nil)
			expect(key).toBe(nil)
		end)
		it("steps up and down and stops at the ends", function()
			expect(SettingsRules.step("flashing", 1, 1)).toBe(1)
			expect(SettingsRules.step("flashing", 1, -1)).toBe(0.75)
			expect(SettingsRules.step("flashing", 0, -1)).toBe(0)
			expect(SettingsRules.step("textSize", 1, 1)).toBe(1.1)
			expect(SettingsRules.step("textSize", 0.8, -1)).toBe(0.8)
		end)
		it("a new save's settings are the defaults", function()
			local defaults = SettingsRules.defaults()
			for _, setting in SettingsRules.LIST do
				expect(defaults[setting.key]).toBe(setting.default)
			end
		end)
	end)
end
