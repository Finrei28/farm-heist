-- Runs every tests/*.test.luau file against the shared game rules:
--   lune run tests/run
-- (from the project folder). Exits with code 1 if anything fails.
local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./lib/harness")
local Spec = require("./lib/spec")

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.test%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	Harness.reset()
	Harness.fresh()
	local register = require(`./{string.gsub(name, "%.luau$", "")}`)
	register(Spec, Harness)
end

local results = Spec.results()
for _, failure in results.failures do
	print(`\27[31mFAIL\27[0m {failure.name}\n     {failure.err}`)
end
local colour = if results.failed == 0 then "\27[32m" else "\27[31m"
print(`{colour}{results.passed} passed, {results.failed} failed\27[0m ({#files} files)`)
process.exit(if results.failed == 0 then 0 else 1)
