-- Client-side procedural animation for every rigged pet and future template clones.
-- Logical Root movement belongs to the pet / follow system; articulation stays local.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PetAnimator = {}
PetAnimator.__index = PetAnimator
local Config = require(script.Parent.Config)
local TAU = math.pi * 2
local CF, V = CFrame.new, Vector3.new
local hovering = {
	Bird = true,
	Insect = true,
	Fairy = true,
	Float = true,
	SkySerpent = true,
	Octopus = true,
	Jellyfish = true,
	Swim = true,
	Bat = true,
	Dragon = true,
	WingedQuad = true,
}
local function ease(t)
	return t * t * (3 - 2 * t)
end
local function hash(text)
	local h = 0
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 100003
	end
	return h / 100003
end
local function showcase(t, kind)
	if hovering[kind] then
		return "Idle", 0, 0, 0
	end
	local cycle = t % 17
	if cycle < 9 then
		return "Idle", 0, 0, 0
	end
	if cycle < 12 then
		return "Walk", -1.15 * ease((cycle - 9) / 3), 0, 0.65
	end
	if cycle < 13 then
		return "Idle", -1.15, math.pi * ease(cycle - 12), 0
	end
	if cycle < 16 then
		return "Walk", -1.15 * (1 - ease((cycle - 13) / 3)), math.pi, 0.65
	end
	return "Idle", 0, math.pi * (1 - ease(cycle - 16)), 0
end

-- Signature moves: every kind (and a few species) plays its own little trick every so often.
-- mode: "fly" needs the pet to be airborne, "idle" needs it standing still, "any" has no condition.
local ACTIONS = {
	Bird = { { "Barrel", 1.3, "fly" }, { "Loop", 1.9, "fly" }, { "Preen", 2.2, "idle" } },
	Insect = { { "Loop", 1.0, "fly" }, { "Zip", 0.9, "fly" } },
	Fairy = { { "Twirl", 1.5, "fly" }, { "Loop", 1.4, "fly" } },
	Bat = { { "Barrel", 1.1, "fly" }, { "Loop", 1.4, "fly" }, { "Dive", 1.3, "fly" } },
	Dragon = { { "Backflip", 2.0, "fly" }, { "WingSpin", 2.3, "fly" }, { "Roar", 1.7, "any" } },
	WingedQuad = { { "Backflip", 1.9, "fly" }, { "Loop", 2.2, "fly" }, { "Stretch", 2.2, "idle" } },
	SkySerpent = { { "Ring", 5.0, "any" }, { "Coil", 2.8, "any" }, { "Ring", 6.5, "any" } },
	Slither = { { "Coil", 2.6, "idle" }, { "Stretch", 2.2, "idle" } },
	Float = { { "Twirl", 1.7, "any" }, { "Bob", 2.2, "any" } },
	Octopus = { { "Spin", 2.2, "any" }, { "Pulse", 2.0, "any" } },
	Jellyfish = { { "Pulse", 2.0, "any" } },
	Swim = { { "Flip", 2.8, "any" }, { "Spout", 2.0, "any" } },
	Seal = { { "Clap", 1.8, "idle" }, { "Roll", 1.6, "idle" } },
	Quad = { { "Stretch", 2.2, "idle" }, { "Shake", 1.2, "idle" }, { "Jump", 1.0, "idle" } },
	Hop = { { "Binky", 1.3, "idle" } },
	Turtle = { { "Stretch", 2.4, "idle" }, { "Spin", 3.0, "idle" } },
	Crab = { { "Wave", 2.0, "idle" }, { "Scuttle", 1.6, "idle" } },
	Lizard = { { "Pushup", 2.0, "idle" }, { "TailWhip", 1.3, "idle" } },
	Crawl = { { "Stretch", 2.6, "idle" } },
	Biped = { { "Wave", 2.0, "idle" }, { "Jump", 1.0, "idle" } },
}
local ACTION_MOD = {}
local function applyAction(M, name, u, e, s)
	if name == "Barrel" then
		M.roll = TAU * e
		M.wing = 1.7
		M.wingHz = 1.5
		M.spine = 1.8
	elseif name == "Loop" or name == "Backflip" then
		M.pitch = TAU * e
		M.lift = 1.3 * s
		M.wing = 1.7
		M.wingHz = 1.5
		M.spine = 1.5
	elseif name == "Spin" or name == "Twirl" then
		M.yaw = TAU * e
		M.lift = 0.35 * s
		M.wing = 1.5
		M.tent = 2
		M.spine = 1.4
	elseif name == "WingSpin" then
		M.yaw = TAU * e
		M.lift = 0.7 * s
		M.wing = 1.8
		M.wingHz = 1.9
	elseif name == "Roar" then
		M.headP = -0.45 * s
		M.pitch = 0.22 * s
		M.wing = 1.9
		M.wingHz = 1.5
		M.lift = 0.25 * s
	elseif name == "Dive" then
		M.pitch = 0.9 * s
		M.lift = -0.5 * s
		M.wing = 0.5
	elseif name == "Zip" then
		M.yaw = TAU * e * 2
		M.lift = 0.2 * s
		M.wing = 1.3
	elseif name == "Preen" then
		M.headP = 0.55 * s
		M.headY = 0.8 * math.sin(u * TAU * 1.5) * s
	elseif name == "HeadSpin" then
		M.headY = 1.7 * math.sin(u * TAU) * s
		M.headP = 0.1 * s
	elseif name == "Coil" then
		M.spine = 2.6
		M.roll = 0.35 * math.sin(u * TAU) * s
	elseif name == "Stretch" then
		M.headP = 0.5 * s
		M.pitch = -0.14 * s
		M.tail = 1.8
	elseif name == "Shake" then
		M.yaw = 0.38 * math.sin(u * TAU * 5) * (1 - u)
		M.roll = 0.1 * math.sin(u * TAU * 5) * (1 - u)
	elseif name == "Jump" then
		M.lift = 0.8 * s
	elseif name == "Binky" then
		M.lift = 1.1 * s
		M.yaw = TAU * e
		M.roll = 0.25 * math.sin(u * TAU * 2) * s
	elseif name == "Wave" then
		M.arm = 0.9 * s * (1 + 0.3 * math.sin(u * TAU * 4))
	elseif name == "Pushup" then
		M.lift = 0.14 * math.sin(u * TAU * 3) * s
		M.headP = 0.2 * s
	elseif name == "TailWhip" then
		M.tail = 3.2
		M.yaw = 0.15 * math.sin(u * TAU * 3) * s
	elseif name == "Clap" then
		M.fin = 4
		M.headP = -0.2 * s
	elseif name == "Flip" then
		M.pitch = -TAU * e
		M.lift = 0.9 * s
		M.fin = 2
	elseif name == "Roll" then
		M.roll = TAU * e
	elseif name == "Pulse" then
		M.lift = 0.35 * math.sin(u * TAU * 2) * s
		M.tent = 2.4
	elseif name == "Scuttle" then
		M.yaw = 0.5 * math.sin(u * TAU * 4) * s
		M.arm = 0.4 * s
	elseif name == "Spout" then
		M.headP = -0.4 * s
		M.lift = 0.4 * s
		M.fin = 1.6
	elseif name == "Bob" then
		M.lift = 0.45 * s
	elseif name == "TailFan" then
		M.tail = 2.8
		M.headP = -0.18 * s
		M.lift = 0.25 * s
		M.yaw = 0.12 * math.sin(u * TAU * 2) * s
	elseif name == "Ascend" then
		-- An optional rising action; no game assets or effects are required.
		local up = u < 0.28 and ease(u / 0.28) or (u > 0.8 and ease((1 - u) / 0.2) or 1)
		local crouch = u < 0.1 and math.sin(u / 0.1 * math.pi) * 0.25 or 0
		M.lift = 3.2 * up - crouch + 0.22 * math.sin(u * TAU * 2.5) * up
		M.wing = 10
		M.wingHz = 0.6
		M.tail = 2.6
		M.pitch = 0.42 * up
		M.headP = -0.35 * up
		M.paw = (2.3 + 0.18 * math.sin(u * TAU * 3)) * up
		M.yaw = TAU * ease(math.clamp((u - 0.3) / 0.45, 0, 1))
		M.vis = u < 0.12 and ease(u / 0.12) or (u > 0.88 and ease((1 - u) / 0.12) or 1)
	elseif name == "Ring" then
		local k = u < 0.25 and ease(u / 0.25) or (u > 0.75 and ease((1 - u) / 0.25) or 1)
		M.curl = k * 2.4 / math.max(M.n or 12, 1)
		M.spin = -TAU * 1.5 * ease(u)
		M.spine = 0.3
		M.lift = 0.25 * k
	end
end

-- Client skinning: welded / motored pet parts made the physics solver re-solve every assembly each
-- frame (5-6k parts for a full plot). On the client every pet part is anchored instead and placed
-- with one BulkMoveTo per pose: bone = parent bone * Motor.C0 * Motor.C1^-1, part = bone * rest offset.
local function buildSkin(rig)
	local model, root = rig.Model, rig.Root
	local bones = { [root] = true }
	for _, j in ipairs(rig.Joints) do
		bones[j.Motor.Part1] = true
	end
	local parent0 = {}
	for _, d in ipairs(model:GetDescendants()) do
		if
			(d:IsA("WeldConstraint") or (d:IsA("JointInstance") and not d:IsA("Motor6D")))
			and d.Part0
			and d.Part1
		then
			if not bones[d.Part1] then
				parent0[d.Part1] = parent0[d.Part1] or d.Part0
			end
		end
	end
	local parts, owners, offsets = {}, {}, {}
	for p, _ in pairs(parent0) do
		if p:IsDescendantOf(model) and p ~= root then
			local o = parent0[p]
			local guard = 0
			while o and not bones[o] and guard < 8 do
				o = parent0[o]
				guard += 1
			end
			if o and bones[o] then
				table.insert(parts, p)
				table.insert(owners, o)
				table.insert(offsets, o.CFrame:ToObjectSpace(p.CFrame))
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	-- switch the client copy to anchored, joint-free geometry
	for _, d in ipairs(model:GetDescendants()) do
		if
			(d:IsA("WeldConstraint") or d:IsA("JointInstance"))
			and d.Part1 ~= nil
			and (bones[d.Part1] or parent0[d.Part1])
		then
			d.Enabled = false
		end
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
	end
	for _, j in ipairs(rig.Joints) do
		if j.Motor.Part1 then
			j.Motor.Part1.Anchored = true
		end
	end
	local list, cfs = {}, {}
	for _, j in ipairs(rig.Joints) do
		if j.Motor.Part1 then
			table.insert(list, j.Motor.Part1)
		end
	end
	for _, p in ipairs(parts) do
		table.insert(list, p)
	end
	return { Parts = parts, Owners = owners, Offsets = offsets, List = list, CFs = cfs, BoneCF = {} }
end
local function applySkin(rig)
	local S = rig.Skin
	if not S then
		return
	end
	local rootCF = rig.Root.CFrame
	local boneCF = S.BoneCF
	boneCF[rig.Root] = rootCF
	local cfs = S.CFs
	local n = 0
	for _, j in ipairs(rig.Joints) do
		local m = j.Motor
		if m.Part1 then
			local p0 = boneCF[m.Part0] or (m.Part0 and m.Part0.CFrame) or rootCF
			local cf = p0 * m.C0 * j.InverseC1
			boneCF[m.Part1] = cf
			n += 1
			cfs[n] = cf
		end
	end
	for i, p in ipairs(S.Parts) do
		n += 1
		cfs[n] = (boneCF[S.Owners[i]] or rootCF) * S.Offsets[i]
	end
	for i = n + 1, #cfs do
		cfs[i] = nil
	end
	rig.WorldRoot:BulkMoveTo(S.List, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	rig.SkinRoot = rootCF
end

function PetAnimator.new(options)
	options = options or {}
	local actions = {}
	assert(type(options.ActionsByName or {}) == "table", "ActionsByName must be a table")
	for name, list in pairs(options.ActionsByName or {}) do
		assert(type(name) == "string" and type(list) == "table", "Expected action lists by name")
		local copied = {}
		for _, action in ipairs(list) do
			assert(
				type(action) == "table" and type(action[1]) == "string" and #action[1] > 0,
				"Action must have a non-empty name"
			)
			assert(
				type(action[2]) == "number" and action[2] > 0 and action[2] < math.huge,
				"Action duration must be positive and finite"
			)
			assert(
				action[3] == "idle" or action[3] == "fly" or action[3] == "any",
				"Action mode must be idle, fly, or any"
			)
			copied[#copied + 1] = table.freeze({ action[1], action[2], action[3] })
		end
		actions[name] = table.freeze(copied)
	end
	return setmetatable({
		Rigs = {},
		Connections = {},
		Pending = {},
		Generation = 0,
		Elapsed = 0,
		Started = false,
		Tag = options.Tag or Config.PetTag,
		ActionsByName = table.freeze(actions),
		ClientSkinning = options.ClientSkinning ~= false,
		WorldRoot = options.WorldRoot or workspace,
	}, PetAnimator)
end

function PetAnimator:Attach(model)
	-- PetViewport: a pet shown inside a ViewportFrame WorldModel (hatch presentation UI)
	if
		self.Rigs[model]
		or not model:IsA("Model")
		or not (model:IsDescendantOf(self.WorldRoot) or model:GetAttribute("PetViewport"))
	then
		return
	end
	local root = model.PrimaryPart
	local folder = model:FindFirstChild("AnimationRig")
	if not root or not folder or model:GetAttribute("PetRigVersion") ~= 1 then
		return
	end
	local seed = hash((model:GetAttribute("Zone") or "") .. model.Name)
	local rig = {
		Model = model,
		Root = root,
		WorldRoot = self.WorldRoot,
		Kind = model:GetAttribute("PetMotionKind") or "Quad",
		Joints = {},
		Eyes = {},
		Shines = {},
		Seed = seed,
		Phase = seed * TAU,
		Scale = model:GetScale(),
		LastPosition = root.Position,
		LastTime = workspace:GetServerTimeNow(),
		Bounds = {},
		Predicted = {},
		Speed = 0,
		Move = 0,
		FlyBlend = 0,
		GaitPhase = seed * TAU,
		Accumulator = 0,
		PoseCount = 0,
		LastState = "Idle",
		Enabled = true,
		Profile = model:GetAttribute("PetMotionProfile"),
		NextAt = workspace:GetServerTimeNow() + 3 + seed * 9,
		Rng = Random.new(math.floor(seed * 1000003)),
		WingPhase = 0,
	}
	for _, joint in ipairs(folder:GetChildren()) do
		if joint:IsA("Motor6D") then
			-- Streaming may deliver the joint before either endpoint is ready.
			if not joint.Part0 or not joint.Part1 then
				return
			end
			rig.Joints[#rig.Joints + 1] = {
				Motor = joint,
				Base = joint.C0,
				InverseC1 = joint.C1:Inverse(),
				Role = joint:GetAttribute("Role"),
				Side = joint:GetAttribute("Side") or 0,
				Index = joint:GetAttribute("Index") or 1,
				Phase = joint:GetAttribute("Phase") or 0,
				Front = joint:GetAttribute("Front") == true,
				Chain = joint:GetAttribute("Chain"),
				ChainYaw = joint:GetAttribute("ChainYaw") or 0.05,
				ChainPitch = joint:GetAttribute("ChainPitch") or 0.02,
				ChainStraight = joint:GetAttribute("ChainStraight") or 0,
			}
		end
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if (p.Name == "Eye" or p.Name == "Pupil") and p.Size.Y > 0.14 then
				rig.Eyes[#rig.Eyes + 1] = { Part = p, Size = p.Size }
			end
			if p.Name == "EyeShine" then
				rig.Shines[#rig.Shines + 1] = { Part = p, Transparency = p.Transparency }
			end
		end
	end
	if #rig.Joints == 0 or #rig.Joints ~= (model:GetAttribute("PetJointCount") or 0) then
		return
	end
	-- Capture client changes so Stop / Detach can restore the model at its current root position.
	rig.RestoreParts = {}
	rig.RestoreEnabled = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item ~= root then
			table.insert(rig.RestoreParts, {
				Part = item,
				Anchored = item.Anchored,
				Relative = root.CFrame:ToObjectSpace(item.CFrame),
			})
		elseif item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			table.insert(rig.RestoreEnabled, { Item = item, Enabled = item.Enabled })
		end
	end
	local owners = {}
	for _, j in ipairs(rig.Joints) do
		owners[j.Motor.Part1] = j
	end
	local visiting = {}
	local function depth(j)
		assert(not visiting[j], "Cycle in pet joint hierarchy")
		if j.Depth then
			return j.Depth
		end
		visiting[j] = true
		local parent = owners[j.Motor.Part0]
		j.Depth = parent and depth(parent) + 1 or 1
		visiting[j] = nil
		return j.Depth
	end
	for _, j in ipairs(rig.Joints) do
		depth(j)
	end
	table.sort(rig.Joints, function(a, b)
		return a.Depth < b.Depth
	end)
	local restMin = (model:GetAttribute("PetRestMinY") or -0.5) * rig.Scale
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			local relative = root.CFrame:ToObjectSpace(p.CFrame)
			local half = p.Size / 2
			local extent = math.abs(relative.RightVector.Y) * half.X
				+ math.abs(relative.UpVector.Y) * half.Y
				+ math.abs(relative.LookVector.Y) * half.Z
			-- Only geometry close enough to touch the floor needs bounds every frame.
			if relative.Position.Y - extent <= restMin + 0.7 * rig.Scale then
				local weld = p:FindFirstChild("ArtWeld")
				local owner = owners[p] and p or weld and weld.Part0 or root
				rig.Bounds[#rig.Bounds + 1] = {
					Owner = owner,
					Relative = owner.CFrame:ToObjectSpace(p.CFrame),
					Half = half,
					Low = relative.Position.Y - extent,
				}
			end
		end
	end
	-- only the lowest pieces can touch the floor: keep the 24 lowest (big pets had hundreds)
	if #rig.Bounds > 24 then
		table.sort(rig.Bounds, function(a, b)
			return a.Low < b.Low
		end)
		for i = #rig.Bounds, 25, -1 do
			rig.Bounds[i] = nil
		end
	end
	-- client skinning (viewport pets are placed by their own presentation code)
	if self.ClientSkinning and not model:GetAttribute("PetViewport") then
		local ok, skin = pcall(buildSkin, rig)
		if ok and skin then
			rig.Skin = skin
			applySkin(rig)
		end
	end
	-- emitters / trails / lights of the pet, switched off when far away or off screen
	rig.Fx = {}
	for _, d in ipairs(model:GetDescendants()) do
		if
			(d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light"))
			and d.Enabled
		then
			table.insert(rig.Fx, d)
		end
	end
	rig.FxOn = true
	self.Rigs[model] = rig
	return rig
end

function PetAnimator:Detach(model, restore)
	local rig = self.Rigs[model]
	if not rig then
		return
	end
	if restore ~= false then
		for _, joint in ipairs(rig.Joints) do
			if joint.Motor.Parent then
				joint.Motor.C0 = joint.Base
			end
		end
		for _, eye in ipairs(rig.Eyes) do
			if eye.Part.Parent then
				eye.Part.Size = eye.Size
			end
		end
		for _, shine in ipairs(rig.Shines) do
			if shine.Part.Parent then
				shine.Part.Transparency = shine.Transparency
			end
		end
	end
	if restore ~= false then
		for _, entry in ipairs(rig.RestoreParts) do
			if entry.Part.Parent then
				entry.Part.CFrame = rig.Root.CFrame * entry.Relative
				entry.Part.Anchored = entry.Anchored
			end
		end
		for _, entry in ipairs(rig.RestoreEnabled) do
			if entry.Item.Parent then
				entry.Item.Enabled = entry.Enabled
			end
		end
		for _, fx in ipairs(rig.Fx) do
			if fx.Parent then
				fx.Enabled = true
			end
		end
	end
	self.Rigs[model] = nil
end

function PetAnimator:SetState(model, state)
	assert(
		state == nil or state == "Idle" or state == "Walk" or state == "Fly",
		"State must be Idle, Walk, Fly, or nil for automatic"
	)
	if state == "Fly" and model:GetAttribute("PetCanFly") ~= true then
		return false
	end
	model:SetAttribute("PetAnimationState", state)
	return true
end

function PetAnimator:Pose(rig, t, dt, forcedState)
	dt = math.clamp(dt, 0, 0.15)
	local model, kind = rig.Model, rig.Kind
	local now = workspace:GetServerTimeNow()
	local delta = rig.Root.Position - rig.LastPosition
	local interval = math.max(now - rig.LastTime, 1 / 240)
	local speed = V(delta.X, 0, delta.Z).Magnitude / interval
	-- Teleports should not trigger a huge running stride.
	if speed > 60 then
		speed = 0
	end
	rig.LastPosition = rig.Root.Position
	rig.LastTime = now
	rig.Speed += (speed - rig.Speed) * (1 - math.exp(-dt * 9))
	local state = forcedState or model:GetAttribute("PetAnimationState")
	local offsetZ, yaw, demoSpeed = 0, 0, 0
	if not state then
		if
			model:GetAttribute("PetShowcase") == true
			and model:GetAttribute("PetShowcaseDemo") ~= false
		then
			state, offsetZ, yaw, demoSpeed = showcase(t + rig.Seed * 17, kind)
		else
			state = rig.Speed > 0.18 and (model:GetAttribute("PetCanFly") and "Fly" or "Walk")
				or "Idle"
		end
	end
	if state ~= "Idle" and state ~= "Walk" and state ~= "Fly" then
		state = "Idle"
	end
	local flying = model:GetAttribute("PetCanFly") == true
		and state ~= "Walk"
		and model:GetAttribute("PetGrounded") ~= true
	if state == "Fly" and model:GetAttribute("PetCanFly") == true then
		flying = true
	end
	local moving = (state == "Walk" or state == "Fly") and 1 or 0
	local blend = 1 - math.exp(-math.max(dt, 0.001) * 10)
	rig.Move += (moving - rig.Move) * blend
	rig.FlyBlend += ((flying and 1 or 0) - rig.FlyBlend) * blend
	local move, flight, phase = rig.Move, rig.FlyBlend, rig.Phase
	local animationSpeed = math.max(rig.Speed, demoSpeed)
	local customProfile = rig.Profile ~= nil
	local capy = rig.Profile == "Heavy"
	local kirin = rig.Profile == "Graceful"
	local mini = rig.Profile == "Coiled"
	local phoenix = rig.Profile == "SlowWings"
	local sit = capy and (1 - rig.Move) * (0.5 + 0.5 * math.sin(t * 0.22 + phase)) ^ 4 or 0
	local curl = mini and (1 - rig.Move) * math.max(0, math.sin(t * 0.32 + phase)) ^ 4 or 0
	local gaitHz = capy and 1.15
		or kirin and 1.4
		or kind == "Turtle" and 1.05
		or kind == "Crawl" and 0.7
		or math.clamp(1.65 + animationSpeed * 0.12, 1.65, 3.5)
	rig.GaitPhase = (rig.GaitPhase + math.max(dt, 0) * TAU * gaitHz) % TAU
	local gait = rig.GaitPhase
	local slow = t * 1.8 + phase
	local hover = t * TAU * 0.65 + phase
	local scale = rig.Scale
	local lift = (model:GetAttribute("PetHoverLift") or 0) * flight * scale
	local groundCorrection = math.max(0, -0.45 - (model:GetAttribute("PetRestMinY") or -0.5))
		* (1 - flight)
		* scale
	local breathing = 0.025 * math.sin(slow) * scale
	local hop = (kind == "Hop") and math.max(0, math.sin(gait)) * 0.22 * move * scale or 0
	local bounce = (kind == "Turtle" or kind == "Crawl") and 0.015 * move * scale
		or 0.045 * math.abs(math.sin(gait)) * move * scale
	local bob = 0.12 * math.sin(hover) * flight * scale
	local bodyY = lift + groundCorrection + breathing + hop + bounce + bob - sit * 0.22 * scale
	if capy then
		bodyY += 0.035 * math.abs(math.sin(gait)) * move * scale
	end
	local driftX = 0.075 * math.sin(hover * 0.7) * flight * scale
	local driftZ = 0.08 * math.cos(hover * 0.8) * flight * scale + offsetZ * scale
	local pitch = -0.075 * move * flight + 0.016 * math.sin(slow * 0.8)
	local roll = 0.018 * math.sin(gait) * move * (1 - flight)
		+ 0.032 * math.sin(hover * 0.72) * flight
	if kind == "Seal" then
		pitch += 0.085 * math.sin(gait) * move
		bodyY += 0.045 * math.abs(math.sin(gait)) * move * scale
	end
	if kind == "Jellyfish" then
		bodyY += 0.1 * math.sin(hover * 1.5) * scale
	end
	local wingHz = phoenix and 0.8
		or kind == "Insect" and 7.5
		or kind == "Fairy" and 3.8
		or kind == "Dragon" and 1.15
		or kind == "Bat" and 3.4
		or 2.2
	if kind == "SkySerpent" and not rig.RingR then
		local chain = {}
		for _, j in ipairs(rig.Joints) do
			if j.Role == "Body" or j.Role == "Spine" then
				chain[#chain + 1] = j
			end
		end
		table.sort(chain, function(a, b)
			return (a.Index or 1) < (b.Index or 1)
		end)
		local len = 0
		for i = 2, #chain do
			len += (chain[i].Motor.Part1.Position - chain[i - 1].Motor.Part1.Position).Magnitude
		end
		rig.RingR = len / 2.4
		rig.NSpine = math.max(#chain - 1, 1)
	end
	local act = rig.Action
	if act and t >= act.Start + act.Dur then
		rig.Action = nil
		act = nil
	end
	-- Optional motion profiles and viewport pets stay calm.
	local signature = not (customProfile or model:GetAttribute("PetViewport"))
	if signature and not act and t >= rig.NextAt then
		local list = self.ActionsByName[model:GetAttribute("DisplayName") or model.Name]
			or ACTIONS[kind]
		local choices = {}
		if list then
			for _, a in ipairs(list) do
				if
					(a[3] == "fly" and flight > 0.6)
					or (a[3] == "idle" and move < 0.25 and flight < 0.5)
					or a[3] == "any"
				then
					choices[#choices + 1] = a
				end
			end
		end
		if #choices > 0 then
			local a = choices[rig.Rng:NextInteger(1, #choices)]
			act = { Name = a[1], Dur = a[2], Start = t }
			rig.Action = act
			rig.NextAt = t + a[2] + 5 + rig.Rng:NextNumber() * 9
		else
			rig.NextAt = t + 2
		end
	end
	local aRoll, aPitch, aYaw, aLift, aHeadP, aHeadY, aWing, aWingHz, aTail, aArm, aTent, aFin, aSpine, aCurl, aSpin =
		0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0
	if act then
		local u = math.clamp((t - act.Start) / act.Dur, 0, 1)
		local M = ACTION_MOD
		M.roll, M.pitch, M.yaw, M.lift, M.headP, M.headY, M.wing, M.wingHz, M.tail, M.arm, M.tent, M.fin, M.spine, M.curl, M.spin =
			0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0
		M.n = rig.NSpine
		M.vis = 0
		M.paw = 0
		applyAction(M, act.Name, u, ease(u), math.sin(u * math.pi))
		aRoll, aPitch, aYaw, aLift, aHeadP, aHeadY, aWing, aWingHz, aTail, aArm, aTent, aFin, aSpine, aCurl, aSpin =
			M.roll,
			M.pitch,
			M.yaw,
			M.lift,
			M.headP,
			M.headY,
			M.wing,
			M.wingHz,
			M.tail,
			M.arm,
			M.tent,
			M.fin,
			M.spine,
			M.curl,
			M.spin
	end
	local aPaw = act and ACTION_MOD.paw or 0
	rig.WingPhase = (rig.WingPhase + math.max(dt, 0) * TAU * wingHz * aWingHz) % TAU
	local wingTime = rig.WingPhase + phase
	-- every pet: turn rate (for lean / tail lag) and where the head looks (toward the wander target)
	local TS = rig.TurnState or { Look = 0, YawRate = 0 }
	rig.TurnState = TS
	do
		local lv = rig.Root.CFrame.LookVector
		local ry = math.atan2(-lv.X, -lv.Z)
		local yr = TS.LastYaw
				and ((ry - TS.LastYaw + math.pi) % TAU - math.pi) / math.max(dt, 1 / 240)
			or 0
		TS.LastYaw = ry
		TS.YawRate += (math.clamp(yr, -4, 4) - TS.YawRate) * math.min(1, dt * 3)
		local want = 0
		local goal = model:GetAttribute("PetWanderTarget")
		if typeof(goal) == "Vector3" and state ~= "Idle" then
			local rel = rig.Root.CFrame:PointToObjectSpace(goal)
			if V(rel.X, 0, rel.Z).Magnitude > 0.5 * scale then
				want = math.clamp(math.atan2(-rel.X, -rel.Z), -0.6, 0.6)
			end
		end
		TS.Look += (math.clamp(want + TS.YawRate * 0.18, -0.7, 0.7) - TS.Look) * math.min(1, dt * 3)
	end
	-- Motion profiles keep their own gait blend.
	local gen = customProfile and 0 or 1
	local turn = TS.YawRate * gen
	local lookT = TS.Look * gen
	-- lean into turns, lean slightly forward while walking, slow weight shift while standing
	roll += math.clamp(-turn * 0.07, -0.12, 0.12) * move * (1 - flight)
	pitch += -0.03 * move * (1 - flight) * gen
	roll += 0.012 * math.sin(t * 0.45 + phase) * (1 - move) * (1 - flight) * gen
	for _, j in ipairs(rig.Joints) do
		local pose = CFrame.identity
		local role, side, index = j.Role, j.Side, j.Index
		if role == "Body" then
			local ringC = V((rig.RingR or 0) * math.min(aCurl * (rig.NSpine or 12) / 2.4, 1), 0, 0)
			pose = CF(driftX, bodyY + aLift * scale, driftZ)
				* CF(ringC)
				* CFrame.Angles(
					pitch + sit * 0.05 + aPitch,
					yaw + curl * 0.35 + aYaw + aSpin,
					roll + (capy and 0.035 * math.sin(gait) * move or 0) + aRoll
				)
				* CF(-ringC)
		elseif role == "Head" then
			local look = 0.065 * math.sin(t * 0.6 + phase) + 0.026 * math.sin(t * 0.23 + phase)
			pose = CFrame.Angles(
				0.028 * math.sin(slow * 0.85) - 0.035 * move + aHeadP,
				look * (1 - 0.5 * math.abs(lookT)) + lookT * 0.65 + aHeadY,
				0.014 * math.sin(slow * 0.6) - lookT * 0.08
			)
			if kind == "Crawl" then
				pose = CF(0, 0, -0.055 * math.sin(gait) * move * scale) * pose
			end
		elseif role == "Leg" or role == "HindLeg" then
			local step = math.sin(gait + j.Phase)
			local stride = (kind == "Turtle" and 0.24 or kind == "Lizard" and 0.28 or 0.46)
				* (customProfile and 1 or (0.8 + 0.35 * math.clamp(rig.Speed / (3 * scale), 0, 1)))
			local angle = step * stride * move * (1 - flight)
			if j.Front and aPaw ~= 0 then
				angle += aPaw
			end
			local raise = math.max(0, math.cos(gait + j.Phase))
				* 0.055
				* move
				* (1 - flight)
				* scale
			if kind == "Hop" then
				angle = math.sin(gait + ((role == "HindLeg" or not j.Front) and math.pi or 0))
					* 0.42
					* move
					* (1 - flight)
			end
			if kind == "Crab" then
				pose = CF(0, raise, 0)
					* CFrame.Angles(0, step * 0.20 * move, side * step * 0.14 * move)
			else
				pose = CF(0, raise, 0)
					* CFrame.Angles(angle + flight * 0.18 + sit * 0.65, 0, side * 0.03 * flight)
			end
		elseif role == "Arm" then
			local swing = -math.sin(gait + j.Phase) * 0.3 * move * (1 - flight)
			pose = CFrame.Angles(
				swing + 0.05 * math.sin(slow + j.Phase) - aArm,
				0,
				side * (0.035 * math.sin(slow * 0.8) + flight * 0.06 + aArm * 0.6)
			)
			if kind == "Crab" then
				pose = CFrame.Angles(
					0.08 * math.sin(slow + j.Phase) - aArm * 0.7,
					side * 0.12 * math.sin(slow * 0.65 + j.Phase),
					side * aArm * 0.5
				)
			end
		elseif role == "Wing" then
			local strength = math.min((0.12 + 0.88 * flight) * aWing, 1.7)
			local wave = math.sin(wingTime + j.Phase)
			if kind == "Insect" then
				pose =
					CFrame.Angles(0, side * wave * 0.65 * strength, side * wave * 0.12 * strength)
			elseif kind ~= "Fairy" then
				-- Real wing beat: wings rest raised and folded back on the ground; in flight a slow powerful
				-- downstroke sweeps forward with the leading edge tipped down, the upstroke folds back.
				local w = wingTime + j.Phase
				local beat = math.sin(w) + 0.22 * math.sin(2 * w)
				local fold = 1 - flight
				local amp = (kind == "Dragon" or kind == "Bat") and 0.42 or 0.5
				local flap = side
					* ((0.22 + 0.08 * fold) + beat * amp * strength * (0.25 + 0.75 * flight))
				local sweep = side * (-0.32 * fold - 0.16 * math.cos(w) * strength * flight)
				local twist = (0.1 * math.cos(w) * strength - 0.06) * flight
					+ 0.05 * fold * math.sin(slow * 0.7)
				pose = CFrame.Angles(twist, sweep, flap)
			else
				pose = CFrame.Angles(
					0.07 * math.sin(wingTime + j.Phase + 0.4) * strength,
					side * 0.035 * math.cos(wingTime),
					side * wave * 0.62 * strength
				)
			end
		elseif role == "Tail" then
			local wave = math.sin(t * 2.7 + phase - j.Phase)
			if kind == "Swim" or kind == "Seal" then
				pose =
					CFrame.Angles(wave * (0.11 + 0.12 * move), 0.07 * math.sin(slow - j.Phase), 0)
			else
				pose = CFrame.Angles(
					0.035 * math.sin(slow + j.Phase) - 0.08 * move * gen,
					wave * (0.07 + 0.11 * move) * aTail * (model:GetAttribute("TailSway") or 1)
						- turn * 0.15,
					0.025 * math.cos(slow + j.Phase)
				)
			end
		elseif role == "Spine" and j.Chain then
			-- hand-built chain (cobra coil / neck): a slow travelling wave, livelier while moving
			local amp = (1 + 0.6 * move) * aSpine
			local wave = math.sin(t * 1.7 + phase - index * 0.5)
			local rise = math.cos(t * 1.3 + phase - index * 0.45)
			pose = CFrame.Angles(
				j.ChainPitch * rise * amp,
				j.ChainYaw * wave * amp * (1 - 0.6 * move) + j.ChainStraight * move,
				j.ChainPitch * 0.5 * wave * amp
			)
		elseif role == "Spine" and customProfile then
			local wave = math.sin(t * (mini and 1.9 or 1.45) + phase - index * 0.7)
			pose = CFrame.Angles(0, wave * (0.045 + 0.075 * move) + curl * 0.22, 0)
		elseif role == "Spine" then
			local sp = kind == "SkySerpent"
			local wave = math.sin(t * (sp and 1.9 or 3.2) + phase - index * (sp and 0.62 or 0.7))
			local rise = math.cos(t * 1.4 + phase - index * 0.5)
			pose = CFrame.Angles(
				sp and (0.075 + 0.04 * move) * rise * aSpine or 0,
				wave * ((sp and 0.10 or 0.035) + (sp and 0.09 or 0.10) * move) * aSpine + aCurl,
				sp and 0.03 * wave * aSpine or 0
			)
		elseif role == "Tentacle" then
			local wave = math.sin(t * 2.25 + phase - j.Phase)
			pose = CFrame.Angles(
				wave * (0.12 + 0.09 * move) * aTent,
				0.07 * math.cos(slow + j.Phase),
				side * 0.055 * math.sin(slow * 0.9 + j.Phase) * aTent
			)
		elseif role == "Fin" then
			local wave = math.sin(t * 3.0 + phase + j.Phase)
			pose = CFrame.Angles(
				wave * (kind == "Seal" and 0.25 * move + 0.05 or 0.18) * aFin,
				0,
				side * wave * 0.12 * aFin
			)
		elseif role == "Ear" then
			local window = (t + rig.Seed * 4.7) % 4.7
			local twitch = window < 0.34 and math.sin(window / 0.34 * TAU) * 0.13 or 0
			pose = CFrame.Angles(
				0.024 * math.sin(slow) + 0.08 * move * gen,
				0,
				side * (twitch + 0.015 * math.sin(slow * 0.8)) - turn * 0.05
			)
		elseif role == "Stalk" then
			pose = CFrame.Angles(
				0.05 * math.sin(slow + j.Phase),
				0,
				side * 0.06 * math.sin(slow * 0.8)
			)
		elseif role == "Wisp" then
			pose = CF(0, 0.035 * math.sin(slow + j.Phase) * scale, 0)
				* CFrame.Angles(
					0.04 * math.sin(slow + j.Phase),
					0.08 * math.sin(slow * 0.6 + j.Phase),
					0.04 * math.cos(slow + j.Phase)
				)
		end
		if j.Motor.Parent and j.Motor.Part0 and j.Motor.Part1 then
			j.Motor.C0 = j.Base * pose
		end
	end
	-- Evaluate the articulated lower geometry before the physics solver runs.
	-- The Root remains the follow system's anchor; only the visual body rises.
	if flight < 0.95 and #rig.Bounds > 0 then
		local predicted = rig.Predicted
		table.clear(predicted)
		predicted[rig.Root] = CFrame.identity
		local bodyJoint
		for _, j in ipairs(rig.Joints) do
			local motor = j.Motor
			predicted[motor.Part1] = (predicted[motor.Part0] or CFrame.identity)
				* motor.C0
				* j.InverseC1
			if j.Role == "Body" then
				bodyJoint = motor
			end
		end
		local bottom = math.huge
		for _, bound in ipairs(rig.Bounds) do
			local cf = (predicted[bound.Owner] or CFrame.identity) * bound.Relative
			local half = bound.Half
			local extent = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			bottom = math.min(bottom, cf.Position.Y - extent)
		end
		local clearance = math.max(0, -0.48 * scale - bottom)
		if bodyJoint and clearance > 0 then
			bodyJoint.C0 = bodyJoint.C0 + V(0, clearance, 0)
		end
	end
	local blinkCycle = (t + rig.Seed * 5.4) % (3.6 + rig.Seed * 1.8)
	local blink = blinkCycle < 0.18 and math.sin(blinkCycle / 0.18 * math.pi) ^ 2 or 0
	for _, eye in ipairs(rig.Eyes) do
		if eye.Part.Parent then
			eye.Part.Size = V(eye.Size.X, eye.Size.Y * (1 - 0.93 * blink), eye.Size.Z)
		end
	end
	local closed = blink > 0.65
	for _, shine in ipairs(rig.Shines) do
		if shine.Part.Parent then
			shine.Part.Transparency = closed and 1 or shine.Transparency
		end
	end
	rig.LastState = state
	rig.PoseCount += 1
end

function PetAnimator:Step(dt)
	assert(
		type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge,
		"dt must be finite and non-negative"
	)
	local camera = workspace.CurrentCamera
	local now = workspace:GetServerTimeNow()
	for model, rig in pairs(self.Rigs) do
		local viewport = model:GetAttribute("PetViewport") == true
		if
			not (model:IsDescendantOf(self.WorldRoot) or (viewport and model:IsDescendantOf(game)))
			or not rig.Root.Parent
		then
			self:Detach(model)
		elseif model:GetAttribute("PetAnimationEnabled") == false then
			if rig.Enabled then
				rig.Enabled = false
				for _, j in ipairs(rig.Joints) do
					if j.Motor.Parent then
						j.Motor.C0 = j.Base
					end
				end
				for _, eye in ipairs(rig.Eyes) do
					if eye.Part.Parent then
						eye.Part.Size = eye.Size
					end
				end
				for _, shine in ipairs(rig.Shines) do
					if shine.Part.Parent then
						shine.Part.Transparency = shine.Transparency
					end
				end
				applySkin(rig)
			end
			if rig.Skin and rig.SkinRoot ~= rig.Root.CFrame then
				applySkin(rig)
			end
			rig.LastPosition = rig.Root.Position
			rig.LastTime = now
		else
			rig.Enabled = true
			rig.Accumulator += dt
			local distance = camera and (camera.CFrame.Position - rig.Root.Position).Magnitude or 0
			-- the pet's real size (a giant can fill the screen while its Root is far away)
			if not rig.Radius then
				local ok, s = pcall(function()
					return model:GetExtentsSize()
				end)
				rig.Radius = ok and s.Magnitude / 2 or rig.Scale * 2
			end
			local radius = rig.Radius
			-- off screen (with a margin for big pets) or far away: pose rarely or not at all
			local onScreen = true
			if camera and not viewport then
				local _, vis = camera:WorldToViewportPoint(rig.Root.Position)
				if not vis then
					local toPet = rig.Root.Position - camera.CFrame.Position
					onScreen = toPet.Magnitude < math.max(rig.Scale * 8, radius * 1.6)
						or camera.CFrame.LookVector:Dot(toPet.Unit) > 0.2
				end
			end
			local interval = viewport and 0
				or (not onScreen) and (distance - radius < 60 and 1 / 6 or math.huge)
				or distance < 70 and 1 / 30
				or distance < 140 and 1 / 20
				or distance < 260 and 1 / 12
				or distance < 450 and 1 / 6
				or math.huge
			-- big pets on screen: the rate follows how large the pet looks (size / distance), not only the
			-- distance to its Root, so a giant filling the screen is animated smoothly instead of at 12-20 fps
			if onScreen and not viewport then
				local look = radius / math.max(distance, 1)
				local bySize = look > 0.22 and 0
					or look > 0.12 and 1 / 40
					or look > 0.07 and 1 / 30
					or look > 0.04 and 1 / 20
					or look > 0.02 and 1 / 12
					or math.huge
				interval = math.min(interval, bySize)
			end
			-- effects only when it can be seen nearby
			local fxWant = viewport or (onScreen and distance - radius < 160)
			if rig.Fx and fxWant ~= rig.FxOn then
				rig.FxOn = fxWant
				for _, fx in ipairs(rig.Fx) do
					if fx.Parent and not fx:GetAttribute("AnimatorManaged") then
						fx.Enabled = fxWant
					end
				end
			end
			if rig.Accumulator >= interval then
				local elapsed = math.min(rig.Accumulator, 0.15)
				rig.Accumulator = 0
				self:Pose(rig, now, elapsed)
				applySkin(rig)
			elseif rig.Skin and (onScreen or distance < 60) and rig.SkinRoot ~= rig.Root.CFrame then
				-- not posed this frame but the pet walked: carry the last pose along
				applySkin(rig)
			end
		end
	end
end

-- Tag/streaming events can arrive repeatedly before deferred work is evaluated.
-- Coalesce them, then check tag membership and lifecycle again at execution time.
local function scheduleAttach(self, model)
	if not self.Started or self.Pending[model] then
		return
	end
	local generation = self.Generation
	self.Pending[model] = generation
	task.defer(function()
		if self.Generation ~= generation or self.Pending[model] ~= generation then
			return
		end
		self.Pending[model] = nil
		if self.Started and CollectionService:HasTag(model, self.Tag) then
			self:Attach(model)
		end
	end)
end

function PetAnimator:Start()
	assert(RunService:IsClient(), "PetAnimator:Start() must run from a LocalScript")
	if self.Started then
		return
	end
	self.Started = true
	self.Generation += 1
	for _, model in ipairs(CollectionService:GetTagged(self.Tag)) do
		self:Attach(model)
	end
	self.Connections[#self.Connections + 1] = CollectionService:GetInstanceAddedSignal(self.Tag)
		:Connect(function(model)
			if model:IsDescendantOf(self.WorldRoot) or model:GetAttribute("PetViewport") then
				scheduleAttach(self, model)
			end
		end)
	self.Connections[#self.Connections + 1] = CollectionService:GetInstanceRemovedSignal(self.Tag)
		:Connect(function(model)
			self.Pending[model] = nil
			self:Detach(model)
		end)
	-- Streaming can place a tagged model in Workspace before its joints arrive.
	self.Connections[#self.Connections + 1] = self.WorldRoot.DescendantAdded:Connect(function(v)
		if v:IsA("Motor6D") or v:IsA("Model") or v:IsA("BasePart") then
			local model = v:IsA("Model") and v or v:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, self.Tag) and not self.Rigs[model] then
				scheduleAttach(self, model)
			end
		end
	end)
	self.Connections[#self.Connections + 1] = RunService.PreSimulation:Connect(function(dt)
		self:Step(dt)
	end)
end

function PetAnimator:Stop()
	self.Started = false
	self.Generation += 1
	table.clear(self.Pending)
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	table.clear(self.Connections)
	local models = {}
	for model in pairs(self.Rigs) do
		models[#models + 1] = model
	end
	for _, model in ipairs(models) do
		self:Detach(model)
	end
end

return PetAnimator
