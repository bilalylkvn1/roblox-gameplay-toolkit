-- Portable lifecycle tests with explicit service/event mocks. No posing or physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { Connected = true, Callback = callback }
			function connection:Disconnect()
				self.Connected = false
			end
			listeners[#listeners + 1] = connection
			return connection
		end,
		Fire = function(_, ...)
			for _, connection in ipairs(listeners) do
				if connection.Connected then
					connection.Callback(...)
				end
			end
		end,
		Count = function()
			local count = 0
			for _, connection in ipairs(listeners) do
				count += connection.Connected and 1 or 0
			end
			return count
		end,
	}
end
local added, removed, descendants, simulation = signal(), signal(), signal(), signal()
local deferred, tagged = {}, {}
local world = { DescendantAdded = descendants }
local services = {
	RunService = {
		IsClient = function()
			return true
		end,
		PreSimulation = simulation,
	},
	CollectionService = {
		GetTagged = function()
			return {}
		end,
		HasTag = function(_, model)
			return tagged[model] == true
		end,
		GetInstanceAddedSignal = function()
			return added
		end,
		GetInstanceRemovedSignal = function()
			return removed
		end,
	},
}
local config = { PetTag = "TestPet" }
local Animator = luau.load(fs.readFile(process.cwd .. "/src/PetAnimator.luau"), {
	debugName = "src/PetAnimator.luau",
	environment = {
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		workspace = world,
		game = {
			GetService = function(_, name)
				return assert(services[name])
			end,
		},
		script = { Parent = { Config = config } },
		require = function(module)
			assert(module == config)
			return config
		end,
		task = {
			defer = function(callback)
				deferred[#deferred + 1] = callback
			end,
		},
	},
})()
local function flush()
	local queue = deferred
	deferred = {}
	for _, callback in ipairs(queue) do
		callback()
	end
end
local pet = {
	IsDescendantOf = function(_, root)
		return root == world
	end,
	GetAttribute = function()
		return false
	end,
	IsA = function(_, class)
		return class == "Model"
	end,
}
local animator = Animator.new({ WorldRoot = world })
local attached, stepped = 0, 0
-- Replace only geometry-dependent operations; scheduling remains the real implementation.
function animator:Attach(model)
	attached += 1
	self.Rigs[model] = {}
end
function animator:Detach(model)
	self.Rigs[model] = nil
end
function animator:Step()
	stepped += 1
end
animator:Start()
animator:Start()
check(added.Count() == 1 and simulation.Count() == 1, "Start is idempotent")
tagged[pet] = true
added:Fire(pet)
descendants:Fire(pet)
added:Fire(pet)
check(#deferred == 1, "coalesce duplicate streaming/tag notifications")
tagged[pet] = nil
removed:Fire(pet)
flush()
check(attached == 0, "removed tag cancels pending attachment")
tagged[pet] = true
added:Fire(pet)
animator:Stop()
animator:Start()
flush()
check(attached == 0, "old lifecycle cannot attach after restart")
added:Fire(pet)
flush()
check(attached == 1 and animator.Rigs[pet] ~= nil, "new lifecycle attaches normally")
simulation:Fire(0.1)
check(stepped == 1, "single simulation listener after restart")
animator:Stop()
animator:Stop()
simulation:Fire(0.1)
check(stepped == 1 and next(animator.Rigs) == nil, "Stop clears rigs and simulation listener")
check(
	added.Count() == 0 and removed.Count() == 0 and descendants.Count() == 0,
	"Stop disconnects all listeners"
)
local actions = { Example = { { "Jump", 1, "idle" } } }
local custom = Animator.new({ ActionsByName = actions })
actions.Example[1][2] = 0
check(custom.ActionsByName.Example[1][2] == 1, "action options are copied")
check(table.isfrozen(custom.ActionsByName.Example[1]), "copied actions are immutable")
for _, duration in ipairs({ 0, -1, math.huge, 0 / 0, "1" }) do
	check(
		not pcall(Animator.new, { ActionsByName = { Example = { { "Jump", duration, "idle" } } } }),
		"reject invalid action duration"
	)
end
check(
	not pcall(Animator.new, { ActionsByName = { Example = { { "Jump", 1, "bad" } } } }),
	"reject invalid action mode"
)
check(
	not pcall(Animator.new, { ActionsByName = { Example = { { "", 1, "any" } } } }),
	"reject empty action name"
)
print(string.format("Animator (mocked lifecycle only): %d checks passed", passed))
