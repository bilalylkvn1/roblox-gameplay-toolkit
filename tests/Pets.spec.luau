return function(Toolkit, check)
	local PetRig, Animator = Toolkit.PetRig, Toolkit.PetAnimator
	local testWorld = Instance.new("WorldModel")
	local function modelFor(kind)
		local model = Instance.new("Model")
		model.Parent = testWorld
		model.Name = "Example" .. kind
		model:SetAttribute("PetViewport", true)
		local function part(name, size, position)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = CFrame.new(position)
			p.Anchored = true
			p.Parent = model
			return p
		end
		local root = part("Root", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 3, 0))
		root.Transparency = 1
		part("Body", Vector3.new(2, 1, 2), Vector3.new(0, 3, 0))
		part("Head", Vector3.new(1, 1, 1), Vector3.new(0, 3.7, -1))
		part("Eye", Vector3.new(0.2, 0.2, 0.1), Vector3.new(0.3, 3.9, -1.55))
		for _, x in ipairs({ -0.8, 0.8 }) do
			part("FrontLeg", Vector3.new(0.4, 1, 0.4), Vector3.new(x, 2, -0.6))
			part("BackLeg", Vector3.new(0.4, 1, 0.4), Vector3.new(x, 2, 0.6))
			part("Wing", Vector3.new(1, 0.2, 1), Vector3.new(x * 2, 3.5, 0))
		end
		part("Tail", Vector3.new(0.3, 0.3, 1), Vector3.new(0, 3, 1.4))
		part("Ear", Vector3.new(0.3, 0.5, 0.3), Vector3.new(-0.3, 4.4, -1))
		part("Ear", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0.3, 4.4, -1))
		return model
	end
	local tag = "GameplayToolkitIsolatedTests"
	local animator = Animator.new({ Tag = tag, WorldRoot = testWorld })
	local models = { testWorld }
	local ok, err = xpcall(function()
		for _, kind in ipairs(PetRig.Kinds) do
			local model = modelFor(kind)
			models[#models + 1] = model
			check(PetRig.Build(model, { Kind = kind, Tag = tag }), "build " .. kind)
			check(model.PrimaryPart ~= nil, "assign PrimaryPart from Root")
			check(not PetRig.Build(model, { Kind = kind, Tag = tag }), "idempotent build")
			local rig = animator:Attach(model)
			check(rig ~= nil and #rig.Joints > 0, "attach " .. kind)
			for _, state in ipairs({ "Idle", "Walk", "Fly" }) do
				local allowed = animator:SetState(model, state)
				check(
					allowed == (state ~= "Fly" or model:GetAttribute("PetCanFly") == true),
					"state validation"
				)
				if allowed then
					for frame = 1, 8 do
						animator:Pose(rig, frame * 0.1, 0.1, state)
						for _, joint in ipairs(rig.Joints) do
							local c = { joint.Motor.C0:GetComponents() }
							for _, value in ipairs(c) do
								check(
									value == value and math.abs(value) < math.huge,
									"finite joint transform"
								)
							end
						end
					end
				end
			end
			animator:Detach(model)
			check(animator.Rigs[model] == nil, "detach removes registration")
			for _, joint in ipairs(rig.Joints) do
				check(joint.Motor.C0 == joint.Base, "restore base pose")
				check(joint.Motor.Enabled, "restore enabled joints")
			end
		end
		local model = modelFor("Quad")
		models[#models + 1] = model
		PetRig.Build(model, { Kind = "Quad", Tag = tag })
		local rig = animator:Attach(model)
		check(animator:Attach(model) == nil, "duplicate attach")
		check(not pcall(animator.SetState, animator, model, "Invalid"), "reject unknown state")
		model:SetAttribute("PetAnimationEnabled", false)
		animator:Step(0.1)
		check(rig.Enabled == false, "animation disabled")
		model:SetAttribute("PetAnimationEnabled", true)
		animator:Step(0.1)
		check(rig.Enabled == true, "animation resumed")
		check(not pcall(animator.Step, animator, -1), "reject negative delta")
		check(not pcall(animator.Step, animator, 0 / 0), "reject NaN delta")
		animator:Stop()
		check(next(animator.Rigs) == nil, "stop clears rigs")
		local world = Instance.new("WorldModel")
		models[#models + 1] = world
		local skinModel = modelFor("Quad")
		models[#models + 1] = skinModel
		skinModel:SetAttribute("PetViewport", false)
		skinModel.Parent = world
		PetRig.Build(skinModel, { Kind = "Quad", Tag = tag })
		local skinner = Animator.new({ Tag = tag, WorldRoot = world })
		local skin = skinner:Attach(skinModel)
		check(skin and skin.Skin ~= nil, "client skinning works in isolated WorldModel")
		for _, joint in ipairs(skin.Joints) do
			check(not joint.Motor.Enabled, "skin disables physics joints")
			check(joint.Motor.Part1.Anchored, "skin anchors posed parts")
		end
		skinner:Pose(skin, 1, 0.1, "Walk")
		skinner:Step(0.1)
		skinModel:SetAttribute("PetAnimationEnabled", false)
		skinner:Step(0.1)
		skinner:Stop()
		for _, joint in ipairs(skin.Joints) do
			check(joint.Motor.Enabled, "stop restores joints after skinning")
			check(not joint.Motor.Part1.Anchored, "stop restores original anchoring")
		end
		local invalid = modelFor("Invalid")
		models[#models + 1] = invalid
		check(
			not pcall(PetRig.Build, invalid, { Kind = "NotAKind", Tag = tag }),
			"reject unknown kind"
		)
	end, debug.traceback)
	animator:Stop()
	for _, model in ipairs(models) do
		model:Destroy()
	end
	assert(ok, err)
end
