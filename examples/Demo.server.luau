local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Toolkit = require(ReplicatedStorage:WaitForChild("GameplayToolkit"))
local makePet = require(ReplicatedStorage:WaitForChild("PetFactory"))
local folder = Instance.new("Folder")
folder.Name = "GameplayToolkitDemo"
folder.Parent = workspace
local colors =
	{ Color3.fromRGB(94, 214, 193), Color3.fromRGB(255, 189, 98), Color3.fromRGB(157, 164, 255) }
local kinds = { "Quad", "Hop", "Bird" }
local pets = {}
for i, kind in ipairs(kinds) do
	local pet = makePet(kind, kind, colors[i], Vector3.new((i - 2) * 14, 2, 0))
	Toolkit.PetRig.Build(pet, { Kind = kind })
	pet.Parent = folder
	pets[i] = pet
end
local target = pets[1]
local now = workspace:GetServerTimeNow()
local plan = Toolkit.Roaming.new({
	boundsFrame = CFrame.new(-14, 0, 0),
	boundsSize = Vector3.new(28, 1, 40),
	origin = target.PrimaryPart.Position,
	radius = 10,
	speed = 4,
	startsAt = now,
})
local elapsed = 0
local connection = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	local clock = workspace:GetServerTimeNow()
	Toolkit.Roaming.Advance(plan, clock, Vector3.new(-14, 2, 8))
	local p, heading = Toolkit.Roaming.Sample(plan, clock)
	target:PivotTo(CFrame.lookAt(p, p + heading))
	target:SetAttribute("PetWanderTarget", p + heading * 4)
	for i = 2, 3 do
		local center = Vector3.new((i - 2) * 14, 2, 0)
		local a = elapsed * 0.35 + i
		local pos = center + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5)
		pets[i]:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))))
	end
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	folder:Destroy()
end)
print("Exact currency demo:", Toolkit.Money.Add("9007199254740991", "10"))
