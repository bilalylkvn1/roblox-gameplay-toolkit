-- Run with Lua 5.4: lua scripts/checkpoint-lifecycle-tests.lua examples/Checkpoints.server.luau
-- Mocks only: does not validate Roblox event delivery, geometry, or physics.
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn)
		local c = { connected = true }
		function c:Disconnect()
			self.connected = false
		end
		table.insert(self.callbacks, { fn, c })
		return c
	end
	function s:Fire(...)
		for _, entry in ipairs(self.callbacks) do
			if entry[2].connected then
				entry[1](...)
			end
		end
	end
	return s
end
local function scenario(stopDuringWait, clearance, expectedHeight)
	local added, removing, destroyed = signal(), signal(), signal()
	local characterAdded = signal()
	local players = { PlayerAdded = added, PlayerRemoving = removing }
	local player = { CharacterAdded = characterAdded, Parent = players }
	function players:GetPlayers()
		return { player }
	end
	function players:GetPlayerFromCharacter(c)
		return c == player.Character and player
	end
	local touched = signal()
	local part = { Touched = touched, CFrame = 0, Size = { Y = 2 } }
	function part:IsA(name)
		return name == "BasePart"
	end
	function part:IsDescendantOf()
		return true
	end
	function part:GetAttribute(name)
		assert(name == "CheckpointSpawnClearance")
		return clearance
	end
	local tagged = true
	local tags = {}
	function tags:GetTagged()
		return { part }
	end
	function tags:HasTag()
		return tagged
	end
	function tags:GetInstanceAddedSignal()
		return signal()
	end
	function tags:GetInstanceRemovedSignal()
		return signal()
	end
	local toolkit = { CleanupBag = {}, Cooldown = {} }
	function toolkit.CleanupBag.new()
		local b = { items = {} }
		function b:Add(item)
			table.insert(self.items, item)
		end
		function b:Destroy()
			for i = #self.items, 1, -1 do
				local item = self.items[i]
				if type(item) == "function" then
					item()
				else
					item:Disconnect()
				end
			end
			self.items = {}
		end
		return b
	end
	function toolkit.Cooldown.new()
		return {
			Try = function()
				return true
			end,
			Forget = function() end,
			Clear = function() end,
		}
	end
	local scriptMock = { Destroying = destroyed }
	local services = {
		Players = players,
		CollectionService = tags,
		ReplicatedStorage = {
			WaitForChild = function()
				return {}
			end,
		},
	}
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		script = scriptMock,
		workspace = {},
		require = function()
			return toolkit
		end,
		Vector3 = {
			new = function(_, y)
				return y
			end,
		},
		table = setmetatable({
			clear = function(t)
				for k in pairs(t) do
					t[k] = nil
				end
			end,
		}, { __index = table }),
	}, { __index = _G })
	assert(loadfile(arg[1], "t", env))()
	local pivots = 0
	local character = {}
	player.Character = character
	function character:FindFirstChildOfClass()
		return { Health = 100 }
	end
	function character:PivotTo(height)
		assert(height == (expectedHeight or 5), stopDuringWait .. " respawn height")
		pivots = pivots + 1
	end
	function character:WaitForChild()
		if stopDuringWait == "destroy" then
			destroyed:Fire()
		elseif stopDuringWait == "leave" then
			removing:Fire(player)
			player.Parent = nil
		elseif stopDuringWait == "timeout" then
			return nil
		elseif stopDuringWait == "replaced" then
			player.Character = {}
		elseif stopDuringWait == "untagged" then
			tagged = false
		end
		return {}
	end
	local hit = {
		FindFirstAncestorOfClass = function()
			return character
		end,
	}
	touched:Fire(hit)
	characterAdded:Fire(character)
	assert(pivots == (stopDuringWait == "normal" and 1 or 0), stopDuringWait)
end
scenario("normal")
scenario("destroy")
scenario("leave")
scenario("timeout")
scenario("replaced")
scenario("untagged")
scenario("normal", 8, 9)
scenario("normal", 0, 1)
scenario("normal", -1)
scenario("normal", math.huge)
scenario("normal", 0 / 0)
scenario("normal", "8")
print("checkpoint lifecycle: 12 mocked scenarios passed")
