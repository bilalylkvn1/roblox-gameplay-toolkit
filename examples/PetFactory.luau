-- Original primitive demo geometry; no uploaded mesh, sound, texture or animation IDs.
return function(name, kind, color, origin)
	local model = Instance.new("Model")
	model.Name = name
	local function part(label, size, offset)
		local p = Instance.new("Part")
		p.Name = label
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(origin + offset)
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
		return p
	end
	local root = part("Root", Vector3.new(0.2, 0.2, 0.2), Vector3.zero)
	root.Transparency = 1
	model.PrimaryPart = root
	part("Body", Vector3.new(2, 1, 2), Vector3.zero)
	part("Head", Vector3.new(1, 1, 1), Vector3.new(0, 0.6, -1.1))
	local eye = part("Eye", Vector3.new(0.2, 0.24, 0.12), Vector3.new(-0.3, 0.8, -1.65))
	eye.Color = Color3.new()
	eye = part("Eye", Vector3.new(0.2, 0.24, 0.12), Vector3.new(0.3, 0.8, -1.65))
	eye.Color = Color3.new()
	for _, x in ipairs({ -0.7, 0.7 }) do
		part("FrontLeg", Vector3.new(0.4, 0.8, 0.4), Vector3.new(x, -0.65, -0.6))
		part("BackLeg", Vector3.new(0.4, 0.8, 0.4), Vector3.new(x, -0.65, 0.6))
	end
	if kind == "Bird" or kind == "Dragon" then
		for _, side in ipairs({ -1, 1 }) do
			part("Wing", Vector3.new(1.8, 0.2, 1.1), Vector3.new(side * 1.5, 0.3, 0.1))
		end
	end
	if kind == "Hop" then
		for _, side in ipairs({ -1, 1 }) do
			part("Ear", Vector3.new(0.3, 1, 0.3), Vector3.new(side * 0.3, 1.5, -1.1))
		end
	end
	part("Tail", Vector3.new(0.3, 0.3, 1), Vector3.new(0, 0, 1.4))
	model:SetAttribute("PetMotionKind", kind)
	return model
end
