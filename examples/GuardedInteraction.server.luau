-- Optional standalone example: copy into ServerScriptService after installing the toolkit.
-- This preview does not grant pets, items, currency, or purchases. It is not in the demo place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Toolkit = require(ReplicatedStorage:WaitForChild("GameplayToolkit"))
assert(
	not ReplicatedStorage:FindFirstChild("ToolkitInteractionPreview"),
	"Preview is already installed"
)
local bag = Toolkit.CleanupBag.new()
local requests = Toolkit.RateLimiter.new({ capacity = 6, refillRate = 2, maxKeys = 250 })
local rolls = Toolkit.Cooldown.new({ duration = 3, maxKeys = 250 })
local choices = Toolkit.WeightedRandom.new({
	{ value = "Green preview", weight = 70 },
	{ value = "Blue preview", weight = 25 },
	{ value = "Gold preview", weight = 5 },
})
local random = Random.new()
local remote = bag:Add(Instance.new("RemoteEvent"))
remote.Name = "ToolkitInteractionPreview"
remote.Parent = ReplicatedStorage
bag:Add(remote.OnServerEvent:Connect(function(player, action)
	-- Key by the server-provided Player, never by a client-provided identity.
	if not requests:Try(player) or action ~= "RollPreview" then
		return
	end
	if not rolls:Try(player) then
		return
	end
	local value = choices:Pick(function()
		return random:NextNumber()
	end)
	remote:FireClient(player, value)
end))
bag:Add(Players.PlayerRemoving:Connect(function(player)
	requests:Forget(player)
	rolls:Forget(player)
end))
local elapsed = 0
bag:Add(RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 15 then
		elapsed = 0
		requests:Prune()
		rolls:Prune()
	end
end))
bag:Add(function()
	requests:Clear()
	rolls:Clear()
end)
bag:Add(script.Destroying:Connect(function()
	for _, err in ipairs(bag:Destroy()) do
		warn(err)
	end
end))
