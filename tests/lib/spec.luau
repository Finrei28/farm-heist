-- A tiny test framework: describe / it / expect. Test files return a
-- function(spec) that registers their tests; run.luau runs them all.
local Spec = {}

local results = { passed = 0, failed = 0, failures = {} }
local prefix = {}

local function show(value): string
	if typeof(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function Spec.describe(name: string, body: () -> ())
	table.insert(prefix, name)
	body()
	table.remove(prefix)
end

function Spec.it(name: string, body: () -> ())
	local fullName = table.concat(prefix, " > ") .. " > " .. name
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, { name = fullName, err = tostring(err) })
	end
end

function Spec.expect(actual)
	local checks = {}
	function checks.toBe(expected)
		if actual ~= expected then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function checks.toBeNear(expected: number, tolerance: number?)
		if typeof(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-6) then
			error(`expected about {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function checks.toBeTruthy()
		if not actual then
			error(`expected something truthy, got {show(actual)}`, 2)
		end
	end
	function checks.toBeFalsy()
		if actual then
			error(`expected nothing / false, got {show(actual)}`, 2)
		end
	end
	function checks.toBeGreaterThan(other: number)
		if not (actual > other) then
			error(`expected more than {show(other)}, got {show(actual)}`, 2)
		end
	end
	function checks.toBeLessThan(other: number)
		if not (actual < other) then
			error(`expected less than {show(other)}, got {show(actual)}`, 2)
		end
	end
	function checks.toBeAtLeast(other: number)
		if not (actual >= other) then
			error(`expected at least {show(other)}, got {show(actual)}`, 2)
		end
	end
	return checks
end

function Spec.results()
	return results
end

return Spec
