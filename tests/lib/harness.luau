-- Loads the game's shared modules (src/shared) outside Roblox, under Lune,
-- with just enough of Roblox faked for them: `script` and `require` walk
-- the src/shared folders like ReplicatedStorage.Shared, `workspace` and
-- `os.time` read a clock the tests control, and Roblox's value types come
-- from @lune/roblox. Random is a stand-in (Lune has none): seeded and
-- repeatable, but its numbers aren't Roblox's.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

local ROOT = "src/shared"

------------------------------------------------------------------------
-- The clock and attributes

local clock = 1_760_000_000 -- unix seconds
local workspaceAttributes = {}
local storageAttributes = {}

function Harness.setTime(seconds: number)
	clock = seconds
end

function Harness.getTime(): number
	return clock
end

function Harness.setWorkspaceAttribute(name: string, value: any)
	workspaceAttributes[name] = value
end

function Harness.setStorageAttribute(name: string, value: any)
	storageAttributes[name] = value
end

function Harness.reset()
	clock = 1_760_000_000
	table.clear(workspaceAttributes)
	table.clear(storageAttributes)
end

local workspace = {
	GetServerTimeNow = function()
		return clock
	end,
	GetAttribute = function(_, name)
		return workspaceAttributes[name]
	end,
	SetAttribute = function(_, name, value)
		workspaceAttributes[name] = value
	end,
}

local services = {
	RunService = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsStudio = function()
			return false
		end,
	},
	ReplicatedStorage = {
		GetAttribute = function(_, name)
			return storageAttributes[name]
		end,
		SetAttribute = function(_, name, value)
			storageAttributes[name] = value
		end,
	},
	Players = { LocalPlayer = nil },
}

local game = {
	GetService = function(_, name)
		return services[name] or error(`[harness] no fake for game:GetService("{name}")`)
	end,
}

local fakeOs = setmetatable({
	time = function()
		return math.floor(clock)
	end,
}, { __index = os })

------------------------------------------------------------------------
-- Random: a seeded xorshift stand-in.

local Random = {}
Random.__index = Random

function Random.new(seed: number?)
	local state = math.floor(seed or os.clock() * 1e6) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	local self = setmetatable({ state = state }, Random)
	-- Stir the seed so nearby seeds don't give nearby first numbers.
	for _ = 1, 4 do
		self:_next()
	end
	return self
end

function Random:_next(): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x / 4294967296
end

function Random:NextNumber(min: number?, max: number?): number
	min, max = min or 0, max or 1
	return min + (max - min) * self:_next()
end

function Random:NextInteger(min: number, max: number): number
	return min + math.floor(self:_next() * (max - min + 1))
end

------------------------------------------------------------------------
-- Fake instances for src/shared, and require

local cache = {}
local nodeMeta = {}

-- The folder tree, read once up front (file reads can't happen inside the
-- metatable lookups below): kinds[path] = "dir" | "file".
local kinds = {}
local function scan(path: string)
	kinds[path] = "dir"
	for _, name in fs.readDir(path) do
		local full = `{path}/{name}`
		if fs.isDir(full) then
			scan(full)
		elseif string.match(name, "%.luau$") then
			kinds[full] = "file"
		end
	end
end
scan(ROOT)
scan("src/server")

local loadModule

local function node(path: string, name: string, parent)
	return setmetatable({ __path = path, Name = name, Parent = parent }, nodeMeta)
end

local function child(self, name: string)
	local path = rawget(self, "__path")
	if kinds[`{path}/{name}`] == "dir" then
		return node(`{path}/{name}`, name, self)
	elseif kinds[`{path}/{name}.luau`] == "file" then
		return node(`{path}/{name}.luau`, name, self)
	end
	return nil
end

nodeMeta.__index = function(self, key)
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(this, name)
			return child(this, name)
		end
	end
	local found = child(self, key)
	if found == nil then
		error(`[harness] {key} is not a valid member of {rawget(self, "__path")}`)
	end
	return found
end

-- game.ReplicatedStorage.Shared, for server modules that reach it that way.
services.ReplicatedStorage.Shared = node(ROOT, "Shared", nil)

local function fakeRequire(target)
	if typeof(target) == "string" then
		return require(target)
	end
	return loadModule(rawget(target, "__path"), target)
end

function loadModule(path: string, scriptNode, extraGlobals)
	if cache[path] ~= nil and not extraGlobals then
		return cache[path]
	end
	local source = fs.readFile(path)
	local env = {
		script = scriptNode,
		-- (modules it requires get the same extra globals: WorldBuilder's helpers need real Instances too)
		require = if extraGlobals
			then function(target)
				if typeof(target) == "string" then
					return require(target)
				end
				return loadModule(rawget(target, "__path"), target, extraGlobals)
			end
			else fakeRequire,
		game = game,
		workspace = workspace,
		os = fakeOs,
		Random = Random,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Enum = roblox.Enum,
	}
	for name, value in extraGlobals or {} do
		env[name] = value
	end
	local chunk = luau.load(source, { debugName = path, environment = env })
	local result = chunk()
	if not extraGlobals then
		cache[path] = result
	end
	return result
end

-- Loads a module by its path under src/shared, e.g. "Valuation" or
-- "Config/Fish". Modules are cached, like in Roblox; Harness.fresh() clears
-- the cache (for modules that read the clock or attributes at load).
function Harness.load(name: string)
	local parts = string.split(name, "/")
	local current = node(ROOT, "Shared", nil)
	for _, part in parts do
		current = child(current, part) or error(`[harness] no module {name}`)
	end
	return loadModule(rawget(current, "__path"), current)
end

-- Loads a pure server module by its path under src/server, e.g.
-- "Util/SaveData" (only ones that don't need live Roblox services).
function Harness.loadServer(name: string)
	local current = node("src/server", "Server", nil)
	for _, part in string.split(name, "/") do
		current = child(current, part) or error(`[harness] no server module {name}`)
	end
	return loadModule(rawget(current, "__path"), current)
end

-- Loads a server module with extra globals, uncached: e.g. real Instances
-- and a workspace from @lune/roblox, to run World/WorldBuilder for real.
function Harness.loadServerWith(name: string, globals)
	local current = node("src/server", "Server", nil)
	for _, part in string.split(name, "/") do
		current = child(current, part) or error(`[harness] no server module {name}`)
	end
	return loadModule(rawget(current, "__path"), current, globals)
end

function Harness.fresh()
	table.clear(cache)
end

Harness.Random = Random

return Harness
