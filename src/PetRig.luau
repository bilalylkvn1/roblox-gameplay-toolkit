-- Preserve the block art while replacing rigid root welds with articulated joints.
local PetRig = {}
PetRig.Version = 1
PetRig.Tag = "GameplayToolkitPet"
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local V, CF = Vector3.new, CFrame.new

local flying = {
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
local kinds = {
	"Hop",
	"Turtle",
	"Bird",
	"Insect",
	"Fairy",
	"Float",
	"Biped",
	"Crab",
	"Slither",
	"SkySerpent",
	"Octopus",
	"Jellyfish",
	"Swim",
	"Seal",
	"Crawl",
	"Bat",
	"Dragon",
	"WingedQuad",
	"Lizard",
	"Quad",
}
PetRig.Kinds = table.freeze(kinds)
local validKinds = {}
for _, kind in ipairs(kinds) do
	validKinds[kind] = true
end

function PetRig.Classify(model, options)
	options = options or {}
	local kind = options.Kind or model:GetAttribute("PetMotionKind")
	if not kind and options.Species then
		kind = options.Species[model:GetAttribute("DisplayName") or model.Name]
	end
	if kind then
		assert(validKinds[kind], "Unknown pet motion kind: " .. tostring(kind))
		return kind
	end
	if model:FindFirstChild("Wing", true) then
		return "Bird"
	end
	if model:FindFirstChild("Tentacle", true) then
		return "Octopus"
	end
	if model:FindFirstChild("Leg", true) then
		return "Quad"
	end
	return "Float"
end

function PetRig.Build(model, options)
	options = options or {}
	if model:GetAttribute("PetRigVersion") == PetRig.Version then
		return false
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	assert(root and root:IsA("BasePart"), model.Name .. " has no Root")
	local rootCF = root.CFrame
	local parts, rest, position, bones, owned = {}, {}, {}, {}, {}
	local minY = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			parts[#parts + 1] = p
			rest[p] = rootCF:ToObjectSpace(p.CFrame)
			position[p] = rest[p].Position
			for _, x in ipairs({ -1, 1 }) do
				for _, y in ipairs({ -1, 1 }) do
					for _, z in ipairs({ -1, 1 }) do
						minY = math.min(minY, rest[p]:PointToWorldSpace(p.Size * V(x, y, z) / 2).Y)
					end
				end
			end
		end
	end
	assert(#parts > 0, model.Name .. " has no geometry")
	model.PrimaryPart = root
	local kind = PetRig.Classify(model, options)
	local oldRig = model:FindFirstChild("AnimationRig")
	if oldRig then
		oldRig:Destroy()
	end
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("WeldConstraint") and rest[v.Part1] and (v.Part0 == root or rest[v.Part0]) then
			v:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "AnimationRig"
	folder.Parent = model
	local function matches(names)
		local result = {}
		for _, p in ipairs(parts) do
			if names[p.Name] then
				result[#result + 1] = p
			end
		end
		return result
	end
	local function largest(list)
		table.sort(list, function(a, b)
			return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
		end)
		return list[1]
	end
	local function bone(p, role, parent, pivot, index, side, phase)
		assert(not owned[p], "Part used twice as a joint: " .. p.Name)
		local parentPart = parent and parent.part or root
		local worldPivot = rootCF * CF(pivot or position[p])
		local motor = Instance.new("Motor6D")
		motor.Name = role .. "_" .. tostring(index or 1)
		motor.Part0 = parentPart
		motor.Part1 = p
		motor.C0 = parentPart.CFrame:ToObjectSpace(worldPivot)
		motor.C1 = p.CFrame:ToObjectSpace(worldPivot)
		motor:SetAttribute("Role", role)
		motor:SetAttribute("Index", index or 1)
		motor:SetAttribute("Side", side or 0)
		motor:SetAttribute("Phase", phase or 0)
		motor:SetAttribute("Front", position[p].Z < 0)
		motor.Parent = folder
		local entry = {
			part = p,
			motor = motor,
			role = role,
			parent = parent,
			pivot = pivot or position[p],
		}
		bones[#bones + 1] = entry
		owned[p] = entry
		return entry
	end
	local bodyParts = matches({ Body = true })
	local serpentine = (kind == "Slither" or kind == "SkySerpent") and #bodyParts > 1
	local bodyPart
	if serpentine then
		table.sort(bodyParts, function(a, b)
			return position[a].Z < position[b].Z
		end)
		bodyPart = bodyParts[1]
	else
		bodyPart = largest(matches({
			Torso = true,
			Thorax = true,
			Body = true,
			Segment = true,
			Shell = true,
			Sheet = true,
			Head = true,
			Foot = true,
			Bell = true,
		}))
		-- Prefer torso / body over a large decorative shell or oversized head.
		bodyPart = largest(matches({ Torso = true, Thorax = true, Body = true, Segment = true }))
			or bodyPart
	end
	assert(bodyPart, "No body anchor: " .. model.Name)
	local body = bone(bodyPart, "Body", nil, position[bodyPart])
	local spine = { body }
	if serpentine then
		local parent = body
		for i = 2, #bodyParts do
			local p = bodyParts[i]
			parent = bone(p, "Spine", parent, (position[p] + position[parent.part]) / 2, i)
			spine[#spine + 1] = parent
		end
	end
	local headPart = largest(matches({ Head = true }))
	local head = body
	if headPart and headPart ~= bodyPart then
		head = bone(headPart, "Head", body, position[headPart] - V(0, headPart.Size.Y * 0.39, 0))
	end
	local limbs = {}
	local arms = {}
	local feet = {}
	local legParts = matches({ Leg = true, FrontLeg = true, BackLeg = true })
	table.sort(legParts, function(a, b)
		if math.abs(position[a].Z - position[b].Z) > 0.01 then
			return position[a].Z < position[b].Z
		end
		return position[a].X < position[b].X
	end)
	for i, p in ipairs(legParts) do
		local pos = position[p]
		local side = pos.X < 0 and -1 or 1
		local lateral = kind == "Crab"
		local pivot = pos
			+ (lateral and V(-side * p.Size.X * 0.42, 0, 0) or rest[p].UpVector * p.Size.Y * 0.43)
		local phase = side < 0 and 0 or math.pi
		if lateral then
			phase += math.floor((i - 1) / 2) * math.pi * 0.67
		elseif pos.Z > position[bodyPart].Z + 0.15 then
			phase += math.pi
		end
		local b = bone(p, p.Name == "BackLeg" and "HindLeg" or "Leg", body, pivot, i, side, phase)
		b.motor:SetAttribute("Front", p.Name == "FrontLeg" or pos.Z < position[bodyPart].Z)
		limbs[#limbs + 1] = b
	end
	-- Bats have feet without separate leg pieces.
	if #legParts == 0 and kind == "Bat" then
		for i, p in ipairs(matches({ Foot = true })) do
			limbs[#limbs + 1] = bone(
				p,
				"Leg",
				body,
				position[p] + V(0, p.Size.Y * 0.4, 0),
				i,
				position[p].X < 0 and -1 or 1
			)
		end
	end
	for i, p in ipairs(matches({ Arm = true })) do
		local side = position[p].X < 0 and -1 or 1
		local pivot = position[p]
			+ (kind == "Crab" and V(-side * 0.18, 0, 0.24) or rest[p].UpVector * p.Size.Y * 0.44)
		arms[#arms + 1] = bone(p, "Arm", body, pivot, i, side, side < 0 and 0 or math.pi)
	end
	local wingParts = matches({ Wing = true })
	local wingOwners = {}
	local wingBones = {}
	for _, side in ipairs({ -1, 1 }) do
		local list = {}
		for _, p in ipairs(wingParts) do
			if position[p].X * side > 0 then
				list[#list + 1] = p
			end
		end
		table.sort(list, function(a, b)
			return position[a].Y > position[b].Y
		end)
		local ranges = options.WingRanges or { { 1, #list } }
		for set, range in ipairs(ranges) do
			local group = {}
			for i = range[1], math.min(range[2], #list) do
				group[#group + 1] = list[i]
			end
			local anchor = largest(group)
			if anchor then
				local pivot = rest[anchor]:PointToWorldSpace(V(-side * anchor.Size.X * 0.49, 0, 0))
				local b = bone(
					anchor,
					"Wing",
					body,
					pivot,
					(side < 0 and 0 or #ranges) + set,
					side,
					set * 0.14
				)
				wingBones[#wingBones + 1] = b
				for _, p in ipairs(group) do
					wingOwners[p] = b
				end
			end
		end
	end
	local tailParts = matches({ Tail = true, TailSeg = true, FishTail = true, Abdomen = true })
	if #tailParts == 0 then
		local feather = largest(matches({ TailFeather = true, PlumeTail = true }))
		if feather then
			tailParts[1] = feather
		end
	end
	table.sort(tailParts, function(a, b)
		return (position[a] - position[bodyPart]).Magnitude
			< (position[b] - position[bodyPart]).Magnitude
	end)
	local tails = {}
	for i, p in ipairs(tailParts) do
		if not owned[p] then
			local parent = body
			local distance = (position[p] - position[bodyPart]).Magnitude
			for _, candidate in ipairs(tails) do
				local d = (position[p] - position[candidate.part]).Magnitude
				local advance = (position[p] - position[bodyPart]).Magnitude
					- (position[candidate.part] - position[bodyPart]).Magnitude
				-- Separate tail bases stay attached to the torso; only downstream segments chain.
				if advance > 0.22 and d < distance and d < 2.2 then
					parent = candidate
					distance = d
				end
			end
			local pivot = (position[p] + position[parent.part]) / 2
			if parent == body then
				local d = position[p] - position[bodyPart]
				if d.Magnitude > 0.001 then
					pivot = position[p]
						- d.Unit * math.min(d.Magnitude * 0.38, p.Size.Magnitude * 0.25)
				end
			end
			local phase = parent ~= body and (parent.motor:GetAttribute("Phase") or 0) + 0.55
				or i * 0.58
			tails[#tails + 1] =
				bone(p, "Tail", parent, pivot, i, position[p].X < 0 and -1 or 1, phase)
		end
	end
	local tentacles = {}
	local tentacleParts = matches({ Tentacle = true, OralArm = true })
	local sectors = {}
	for _, p in ipairs(tentacleParts) do
		local pos = position[p]
		local sector = math.floor((math.atan2(pos.X, pos.Z) + math.pi) / (2 * math.pi) * 8) % 8
		sectors[sector] = sectors[sector] or {}
		table.insert(sectors[sector], p)
	end
	for sector, list in pairs(sectors) do
		table.sort(list, function(a, b)
			return position[a].Y > position[b].Y
		end)
		local parent = body
		for segment, p in ipairs(list) do
			local pivot = position[p] + V(0, p.Size.Y * 0.43, 0)
			local b = bone(
				p,
				"Tentacle",
				parent,
				pivot,
				sector * 4 + segment,
				position[p].X < 0 and -1 or 1,
				sector * 0.78 + segment * 0.45
			)
			tentacles[#tentacles + 1] = b
			parent = b
		end
	end
	local fins = {}
	for i, p in ipairs(matches({ Flipper = true, Fin = true, ChestFin = true, EarFin = true })) do
		if not owned[p] then
			local parent = p.Name == "EarFin" and head or body
			local side = position[p].X < 0 and -1 or 1
			fins[#fins + 1] = bone(
				p,
				"Fin",
				parent,
				position[p] - V(side * p.Size.X * 0.35, 0, 0),
				i,
				side,
				i * 0.8
			)
		end
	end
	local ears = {}
	for _, side in ipairs({ -1, 1 }) do
		local group = {}
		for _, p in ipairs(matches({ Ear = true, EarTuft = true })) do
			if position[p].X * side > 0 then
				group[#group + 1] = p
			end
		end
		local anchor = largest(group)
		if anchor then
			local b = bone(
				anchor,
				"Ear",
				head,
				position[anchor] - V(0, anchor.Size.Y * 0.38, 0),
				side < 0 and 1 or 2,
				side
			)
			ears[#ears + 1] = b
		end
	end
	local stalks = {}
	for i, p in ipairs(matches({ EyeStalk = true })) do
		stalks[#stalks + 1] = bone(
			p,
			"Stalk",
			head,
			position[p] - V(0, p.Size.Y * 0.4, 0),
			i,
			position[p].X < 0 and -1 or 1
		)
	end
	local wisps = {}
	for i, p in ipairs(matches({ Wisp = true, Hem = true, ScarfTail = true, WindRibbon = true })) do
		if not owned[p] then
			wisps[#wisps + 1] = bone(
				p,
				"Wisp",
				body,
				position[p] + V(0, p.Size.Y * 0.3, 0),
				i,
				position[p].X < 0 and -1 or 1,
				i * 0.8
			)
		end
	end
	local function nearest(list, p)
		local chosen, distance = nil, math.huge
		for _, b in ipairs(list) do
			local d = (position[p] - position[b.part]).Magnitude
			if d < distance then
				chosen = b
				distance = d
			end
		end
		return chosen
	end
	local headNames = {
		Eye = true,
		EyeShine = true,
		Blush = true,
		Mouth = true,
		HeadTop = true,
		Snout = true,
		Nose = true,
		Jaw = true,
		Tooth = true,
		Tongue = true,
		Beak = true,
		Fang = true,
		Hair = true,
		HairSide = true,
		HairBack = true,
		Crown = true,
		CrownSpike = true,
		CrownGem = true,
		CrownFlower = true,
		LeafCrown = true,
		LeafMask = true,
		Antler = true,
		AntlerGem = true,
		Horn = true,
		Forelock = true,
		Mane = true,
		Whisker = true,
		Turban = true,
		TurbanTop = true,
		TurbanFold = true,
		TurbanGem = true,
		Beard = true,
		Earring = true,
		Goggle = true,
		GoggleLens = true,
		GoggleStrap = true,
		Crest = true,
		Brow = true,
		EyeDisc = true,
		Antenna = true,
		AntennaTip = true,
		Barbel = true,
	}
	local handNames = {
		Hand = true,
		Bracelet = true,
		Armband = true,
		Wand = true,
		WandStar = true,
		Staff = true,
		StaffGem = true,
		StaffClaw = true,
		Trident = true,
		TridentTip = true,
		Scepter = true,
		ScepterGem = true,
		Scythe = true,
		Blade = true,
		LanternBase = true,
		LanternTop = true,
		LanternHandle = true,
		LanternGlow = true,
		Claw = true,
		Pincer = true,
	}
	local tailNames = {
		TailTip = true,
		TailBlade = true,
		TailFin = true,
		Fluke = true,
		TailFeather = true,
		PlumeTail = true,
		PlumeEye = true,
		FlameTail = true,
		Stinger = true,
	}
	for _, p in ipairs(parts) do
		if not owned[p] then
			local owner = body
			local name = p.Name
			if model:GetAttribute("PetDecorated") and p:GetAttribute("PetJointOwner") == "Wing" then
				owner = nearest(wingBones, p) or body
			elseif
				model:GetAttribute("PetDecorated") and p:GetAttribute("PetJointOwner") == "Tail"
			then
				owner = nearest(tails, p) or body
			elseif name:sub(1, 4) == "Wing" then
				owner = wingOwners[p]
				if not owner then
					local closest, distance = nil, math.huge
					for wing, b in pairs(wingOwners) do
						if position[wing].X * position[p].X >= 0 then
							local d = (position[wing] - position[p]).Magnitude
							if d < distance then
								closest = b
								distance = d
							end
						end
					end
					owner = closest or body
				end
			elseif name == "Paw" or name == "Foot" then
				owner = nearest(limbs, p) or body
			elseif name == "TentacleTip" or name == "Sucker" then
				owner = nearest(tentacles, p) or body
			elseif name == "Ear" or name == "EarInner" or name == "EarTuft" then
				owner = nearest(ears, p) or head
			elseif
				#stalks > 0
				and (
					name == "Eye"
					or name == "EyeShine"
					or name == "EyeBall"
					or name == "Pupil"
					or name == "StalkTip"
				)
			then
				owner = nearest(stalks, p) or head
			elseif handNames[name] then
				owner = nearest(arms, p)
					or (model:GetAttribute("PetDecorated") and nearest(limbs, p))
					or body
			elseif tailNames[name] then
				owner = nearest(tails, p)
					or (model:GetAttribute("PetDecorated") and serpentine and nearest(spine, p))
					or body
			elseif headNames[name] then
				owner = head
			elseif serpentine then
				owner = nearest(spine, p) or body
			elseif name == "Stripe" and model:FindFirstChild("Abdomen") then
				owner = nearest(tails, p) or body
			end
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ArtWeld"
			weld.Part0 = owner.part
			weld.Part1 = p
			weld.Parent = p
		end
	end
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	for _, p in ipairs(parts) do
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	model:SetAttribute("PetMotionKind", kind)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("PetCanFly", flying[kind] == true)
	model:SetAttribute("PetRestMinY", minY)
	model:SetAttribute("PetHoverLift", flying[kind] and math.max(0.35, 0.9 - minY) or 0)
	model:SetAttribute("PetAnimationEnabled", true)
	model:SetAttribute("PetRigVersion", PetRig.Version)
	model:SetAttribute("PetJointCount", #bones)
	model:SetAttribute("PetAnimationStates", flying[kind] and "Idle,Walk,Fly" or "Idle,Walk")
	CollectionService:AddTag(model, options.Tag or Config.PetTag)
	return true
end

return PetRig
