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
local function scenario(
	stopDuringWait,
	clearance,
	expectedHeight,
	firstStage,
	secondStage,
	acceptSecond
)
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
	local part = { Touched = touched, CFrame = 0, Size = { Y = 2 }, CanTouch = true }
	if stopDuringWait == "disabled-pad" then
		part.CanTouch = false
		function touched:Connect()
			error("cannot connect Touched while CanTouch is false")
		end
	end
	function part:IsA(name)
		return name == "BasePart"
	end
	function part:IsDescendantOf()
		return true
	end
	local checkpointEnabled = true
	function part:GetAttribute(name)
		if name == "CheckpointStage" then
			return firstStage
		end
		if name == "CheckpointEnabled" then
			return checkpointEnabled
		end
		assert(name == "CheckpointSpawnClearance")
		return clearance
	end
	local tagged = true
	local tagAdded, tagRemoved = signal(), signal()
	local tags = {}
	function tags:GetTagged()
		return { part }
	end
	function tags:HasTag()
		return tagged
	end
	function tags:GetInstanceAddedSignal()
		return tagAdded
	end
	function tags:GetInstanceRemovedSignal()
		return tagRemoved
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
	local touchAttempts = 0
	function toolkit.Cooldown.new()
		return {
			Try = function()
				touchAttempts = touchAttempts + 1
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
			zero = 0,
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
	local secondTouched = signal()
	local secondPart = setmetatable({ Touched = secondTouched, CFrame = 20 }, { __index = part })
	function secondPart:GetAttribute(name)
		if name == "CheckpointStage" then
			return secondStage
		end
		return part:GetAttribute(name)
	end
	local pivots = 0
	local character = {}
	player.Character = character
	local humanoid = { Health = 100 }
	function character:FindFirstChildOfClass()
		return humanoid
	end
	function character:PivotTo(height)
		assert(height == (expectedHeight or 5), stopDuringWait .. " respawn height")
		pivots = pivots + 1
	end
	local hit = {
		FindFirstAncestorOfClass = function()
			return character
		end,
	}
	local root = { AssemblyLinearVelocity = 50, AssemblyAngularVelocity = 10 }
	local rootWaits = 0
	function character:WaitForChild()
		rootWaits = rootWaits + 1
		if stopDuringWait == "destroy" then
			destroyed:Fire()
		elseif stopDuringWait == "leave" then
			removing:Fire(player)
			player.Parent = nil
		elseif stopDuringWait == "touch-disabled-during-respawn" then
			part.CanTouch = false
		elseif stopDuringWait == "died-during-respawn" then
			humanoid.Health = 0
		elseif stopDuringWait == "missing-humanoid" then
			humanoid = nil
		elseif stopDuringWait == "checkpoint-disabled-during-respawn" then
			checkpointEnabled = false
		elseif stopDuringWait == "timeout" then
			return nil
		elseif stopDuringWait == "replaced" then
			player.Character = {}
		elseif stopDuringWait == "untagged" then
			tagged = false
		elseif stopDuringWait == "retagged-and-touched" then
			tagged = false
			tagRemoved:Fire(part)
			tagged = true
			tagAdded:Fire(part)
			touched:Fire(hit)
		end
		return root
	end
	if stopDuringWait == "stale-touch" then
		local queuedTouch = touched.callbacks[1][1]
		tagged = false
		tagRemoved:Fire(part)
		tagged = true
		tagAdded:Fire(part)
		queuedTouch(hit)
	elseif stopDuringWait == "departed-touch" then
		removing:Fire(player)
		touched:Fire(hit)
		assert(touchAttempts == 0, "departed-touch must not recreate player state")
	elseif stopDuringWait == "checkpoint-disabled-touch" then
		checkpointEnabled = false
		touched:Fire(hit)
		assert(touchAttempts == 0, "disabled checkpoint must reject touches")
	elseif stopDuringWait ~= "no-checkpoint" then
		touched:Fire(hit)
	end
	if stopDuringWait == "ordered" then
		tagAdded:Fire(secondPart)
		secondTouched:Fire(hit)
		assert(
			touchAttempts == (acceptSecond and 2 or 1),
			"rejected stages must not consume cooldown"
		)
	end
	characterAdded:Fire(character)
	if pivots > 0 then
		assert(root.AssemblyLinearVelocity == 0, "respawn must clear linear velocity")
		assert(root.AssemblyAngularVelocity == 0, "respawn must clear angular velocity")
	else
		assert(root.AssemblyLinearVelocity == 50, "skipped move must preserve velocity")
		assert(root.AssemblyAngularVelocity == 10, "skipped move must preserve spin")
	end
	if stopDuringWait == "no-checkpoint" then
		assert(rootWaits == 0, "no-checkpoint must not wait for the root")
	end
	assert(
		pivots == ((stopDuringWait == "normal" or stopDuringWait == "ordered") and 1 or 0),
		stopDuringWait
	)
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
scenario("stale-touch")
scenario("departed-touch")
scenario("no-checkpoint")
scenario("retagged-and-touched")
scenario("disabled-pad")
scenario("touch-disabled-during-respawn")
scenario("died-during-respawn")
scenario("missing-humanoid")
scenario("checkpoint-disabled-touch")
scenario("checkpoint-disabled-during-respawn")
scenario("ordered", nil, 25, 1, 2, true)
scenario("ordered", nil, 5, 2, 1, false)
scenario("ordered", nil, 5, 2, 2, false)
scenario("ordered", nil, 25, nil, 1, true)
scenario("ordered", nil, 25, 1, nil, true)
scenario("ordered", nil, 25, 2, 1.5, true)
scenario("ordered", nil, 25, 2, 0, true)
scenario("ordered", nil, 25, 2, math.huge, true)
scenario("ordered", nil, 25, 2, 0 / 0, true)
scenario("ordered", nil, 25, 2, "1", true)
print("checkpoint lifecycle: 32 mocked scenarios passed")
