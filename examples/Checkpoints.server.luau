-- Optional example: place in ServerScriptService; not installed by the demo.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Toolkit = require(game:GetService("ReplicatedStorage"):WaitForChild("GameplayToolkit"))
local bag = Toolkit.CleanupBag.new()
local touches = Toolkit.Cooldown.new({ duration = 1, maxKeys = 1024 })
local checkpoints = {}
local partBags = {}
local playerBags = {}
local stopped = false

-- Only positive, finite integer stages participate in ordering.
local function getStage(part)
	local stage = part:GetAttribute("CheckpointStage")
	if type(stage) == "number" and stage >= 1 and stage < math.huge and stage % 1 == 0 then
		return stage
	end
	return nil
end

local function trackPlayer(player)
	if playerBags[player] then
		return
	end
	local owned = Toolkit.CleanupBag.new()
	playerBags[player] = owned
	owned:Add(player.CharacterAdded:Connect(function(character)
		local part = checkpoints[player]
		if not part then
			return
		end
		local checkpointConnection = partBags[part]
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if
			not stopped
			and playerBags[player] == owned
			and player.Parent == Players
			and root
			and humanoid
			and humanoid.Health > 0
			and player.Character == character
			and checkpoints[player] == part
			and partBags[part] == checkpointConnection
			and part:GetAttribute("CheckpointEnabled") ~= false
			and part.CanTouch
			and part:IsDescendantOf(workspace)
			and CollectionService:HasTag(part, "ToolkitCheckpoint")
		then
			local clearance = part:GetAttribute("CheckpointSpawnClearance")
			if type(clearance) ~= "number" or not (clearance >= 0 and clearance < math.huge) then
				clearance = 4
			end
			character:PivotTo(part.CFrame + Vector3.new(0, part.Size.Y / 2 + clearance, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end))
end

local function untrackPart(part)
	local owned = partBags[part]
	if owned then
		owned:Destroy()
		partBags[part] = nil
	end
	for player, checkpoint in pairs(checkpoints) do
		if checkpoint == part then
			checkpoints[player] = nil
		end
	end
end

local function trackPart(part)
	if not part:IsA("BasePart") or not part.CanTouch or partBags[part] then
		return
	end
	local owned = Toolkit.CleanupBag.new()
	partBags[part] = owned
	owned:Add(part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		while character and not player do
			character = character:FindFirstAncestorOfClass("Model")
			player = character and Players:GetPlayerFromCharacter(character)
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			stopped
			or part:GetAttribute("CheckpointEnabled") == false
			or partBags[part] ~= owned
			or not CollectionService:HasTag(part, "ToolkitCheckpoint")
			or not player
			or not playerBags[player]
			or player.Parent ~= Players
			or not humanoid
			or humanoid.Health <= 0
			or not part:IsDescendantOf(workspace)
		then
			return
		end
		local previous = checkpoints[player]
		local previousStage = previous and getStage(previous)
		local nextStage = getStage(part)
		if previousStage and nextStage and nextStage <= previousStage then
			return
		end
		if previous ~= part and touches:Try(player) then
			checkpoints[player] = part
		end
	end))
end

bag:Add(Players.PlayerAdded:Connect(trackPlayer))
bag:Add(Players.PlayerRemoving:Connect(function(player)
	checkpoints[player] = nil
	touches:Forget(player)
	if playerBags[player] then
		playerBags[player]:Destroy()
		playerBags[player] = nil
	end
end))
bag:Add(CollectionService:GetInstanceAddedSignal("ToolkitCheckpoint"):Connect(trackPart))
bag:Add(CollectionService:GetInstanceRemovedSignal("ToolkitCheckpoint"):Connect(untrackPart))
for _, player in ipairs(Players:GetPlayers()) do
	trackPlayer(player)
end
for _, part in ipairs(CollectionService:GetTagged("ToolkitCheckpoint")) do
	trackPart(part)
end
bag:Add(function()
	stopped = true
	for _, owned in pairs(partBags) do
		owned:Destroy()
	end
	for _, owned in pairs(playerBags) do
		owned:Destroy()
	end
	table.clear(partBags)
	table.clear(playerBags)
	table.clear(checkpoints)
	touches:Clear()
end)
script.Destroying:Connect(function()
	bag:Destroy()
end)
