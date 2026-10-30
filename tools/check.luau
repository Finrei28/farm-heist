-- The check to run before publishing (from the project folder):
--   lune run tools/check
-- 1. Compiles every script in src/, so a typo that would stop a script from
--    loading in Roblox (an unfinished string, a missing `end`) is caught here.
-- 2. Runs the tests (tests/run.luau).
-- Exits with code 1 if anything fails, so it can't be missed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local compiled = 0

local function walk(path: string)
	for _, name in fs.readDir(path) do
		local full = `{path}/{name}`
		if fs.isDir(full) then
			walk(full)
		elseif string.match(name, "%.luau?$") then
			local ok, err = pcall(luau.compile, fs.readFile(full))
			compiled += 1
			if not ok then
				failures += 1
				print(`\27[31mSYNTAX\27[0m {full}\n       {err}`)
			end
		end
	end
end

print("Compiling src/ ...")
walk("src")
if failures == 0 then
	print(`\27[32mAll {compiled} scripts compile.\27[0m`)
end

print("Running tests ...")
local result = process.exec("lune", { "run", "tests/run" }, { stdio = "inherit" })
if not result.ok then
	failures += 1
end

if failures == 0 then
	print("\27[32mReady to publish.\27[0m Remember: stop Play, then File > Publish to Roblox.")
	process.exit(0)
else
	print("\27[31mNot ready: fix the problems above before publishing.\27[0m")
	process.exit(1)
end
