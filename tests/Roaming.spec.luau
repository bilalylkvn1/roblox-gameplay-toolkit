return function(Roaming, check)
	local function options(frame)
		return {
			boundsFrame = frame or CFrame.new(),
			boundsSize = Vector3.new(80, 1, 60),
			origin = Vector3.new(0, 2, 0),
			radius = 18,
			speed = 9,
			startsAt = 10,
			expiresAt = 80,
		}
	end
	local plan = Roaming.new(options())
	check(not Roaming.Advance(plan, 9, Vector3.new(0, 2, 5)), "before start")
	local seed = 17
	local function random()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	check(Roaming.Advance(plan, 10, Vector3.new(0, 2, 5), random), "initialize")
	for i = 0, 500 do
		local t = 10 + i * 0.1
		Roaming.Advance(
			plan,
			t,
			Vector3.new(math.sin(i * 0.1) * 12, 2, math.cos(i * 0.1) * 12),
			random
		)
		local p, h, travel, speed = Roaming.Sample(plan, t)
		check(Roaming.Inside(plan, p, -0.001), "path remains inside rectangle and radius")
		check(math.abs(h.Magnitude - 1) < 0.001, "unit heading")
		check(
			p.Y == 2 and travel >= 0 and speed >= 0 and speed <= plan.speed,
			"height / travel / speed contract"
		)
	end
	local frame = CFrame.new(100, 0, 50) * CFrame.Angles(0, math.rad(37), 0)
	local opt = options(frame)
	opt.origin = frame:PointToWorldSpace(Vector3.new(0, 2, 0))
	local rotated = Roaming.new(opt)
	Roaming.Advance(rotated, 10, opt.origin + Vector3.new(0, 0, 2), random)
	for i = 1, 100 do
		local t = 10 + i * 0.2
		Roaming.Advance(rotated, t, opt.origin + Vector3.new(10, 0, 0), random)
		check(Roaming.Inside(rotated, Roaming.Sample(rotated, t), -0.001), "rotated bounds")
	end
	local copy = Roaming.new(options())
	check(Roaming.Decode(copy, Roaming.Encode(plan)), "JSON roundtrip")
	local a = Roaming.Sample(plan, plan.updatedAt + 0.05)
	local b = Roaming.Sample(copy, plan.updatedAt + 0.05)
	check((a - b).Magnitude < 0.001, "same deterministic prediction after snapshot")
	check(Roaming.Decode(plan, Roaming.Encode(plan)), "reapplying own JSON snapshot is idempotent")
	check(plan.travel >= copy.travel, "serialization cannot reduce accumulated travel")
	local original = copy.updatedAt
	for _, state in ipairs({
		{},
		{ t = original, p = { 0, 2, 0 }, d = { 0, 0, 0 }, g = { 1, 0, 0 }, travel = 0 },
		{ t = original, p = { 0, 2, 0 }, d = { 1, 0, 0 }, g = { 0, 0, 0 }, travel = 0 },
		{ t = original, p = { 0 / 0, 2, 0 }, d = { 1, 0, 0 }, g = { 1, 0, 0 }, travel = 0 },
		{ t = original, p = { 10000, 2, 0 }, d = { 1, 0, 0 }, g = { 1, 0, 0 }, travel = 0 },
		{ t = original - 1, p = { 0, 2, 0 }, d = { 1, 0, 0 }, g = { 1, 0, 0 }, travel = 0 },
		{ t = original, p = { 0, 2, 0 }, d = { 1, 0, 0 }, g = { 1, 0, 0 }, travel = -1 },
	}) do
		check(not Roaming.ApplySnapshot(copy, state), "reject bad / stale snapshot")
	end
	check(copy.updatedAt == original, "rejection leaves state intact")
	check(not Roaming.Decode(copy, "broken"), "invalid JSON")
	local pause = Roaming.new({
		boundsFrame = CFrame.new(),
		boundsSize = Vector3.new(80, 1, 80),
		origin = Vector3.new(0, 2, 0),
	})
	Roaming.Advance(pause, 0, Vector3.new(0, 2, 1), random)
	local decisions = 0
	local function countingRandom()
		decisions += 1
		return 0.5
	end
	Roaming.Advance(pause, 100000, Vector3.new(0, 2, 1), countingRandom)
	check(decisions < 500, "catch-up work stays bounded after long pause")
	local ok = pcall(Roaming.new, {
		boundsFrame = CFrame.Angles(0.3, 0, 0),
		boundsSize = Vector3.new(80, 1, 80),
		origin = Vector3.zero,
	})
	check(not ok, "reject tilted bounds")
	ok = pcall(Roaming.new, {
		boundsFrame = CFrame.new(),
		boundsSize = Vector3.new(80, 1, 80),
		origin = Vector3.new(100, 0, 0),
	})
	check(not ok, "reject origin outside usable rectangle")
	for _, size in ipairs({ Vector3.new(1, 1, 1), Vector3.new(10, 1, 80) }) do
		local small = options()
		small.boundsSize = size
		check(not pcall(Roaming.new, small), "reject bounds consumed by body margin")
	end
	local tinyOptions = options()
	tinyOptions.boundsSize = Vector3.new(0.8, 1, 0.6)
	tinyOptions.bodyHeight = 0
	tinyOptions.edgePadding = 0
	tinyOptions.origin = Vector3.zero
	tinyOptions.radius = 2
	local tiny = Roaming.new(tinyOptions)
	for i = 0, 100 do
		local t = 10 + i * 0.1
		Roaming.Advance(tiny, t, Vector3.new(0, 0, 1), random)
		local p = Roaming.Sample(tiny, t)
		check(math.abs(p.X) <= 0.401 and math.abs(p.Z) <= 0.301, "tiny bounds never expand")
	end
	local stationaryOptions = options()
	stationaryOptions.speed = 0
	stationaryOptions.expiresAt = 11
	local stationary = Roaming.new(stationaryOptions)
	Roaming.Advance(stationary, 10, Vector3.zero, random)
	Roaming.Advance(stationary, 20, Vector3.zero, random)
	local p, _, travel, speed = Roaming.Sample(stationary, 20)
	check(
		(p - stationary.origin).Magnitude < 0.001 and travel == 0 and speed == 0,
		"zero speed plan"
	)
	local expiredOptions = options()
	expiredOptions.expiresAt = 10.35
	local expired = Roaming.new(expiredOptions)
	Roaming.Advance(expired, 10, Vector3.zero, random)
	Roaming.Advance(expired, 20, Vector3.zero, random)
	local final = Roaming.Sample(expired, 10.35)
	local later, _, _, finalSpeed = Roaming.Sample(expired, 100)
	check(
		(final - later).Magnitude < 0.001 and finalSpeed == 0,
		"expiry freezes position and speed"
	)
	local before = Roaming.Encode(plan)
	check(
		not Roaming.Advance(plan, plan.updatedAt - 1, Vector3.zero, random),
		"ignore backwards clock"
	)
	check(Roaming.Encode(plan) == before, "backwards clock leaves state intact")
	local regression = Roaming.Snapshot(plan)
	regression.t += 0.1
	regression.travel -= 1
	check(not Roaming.ApplySnapshot(plan, regression), "travel cannot move backwards")
	for _, huge in ipairs({ 1e39, 1e300 }) do
		local state = Roaming.Snapshot(plan)
		state.d = { huge, 0, 1 }
		check(not Roaming.ApplySnapshot(plan, state), "reject vector component overflow")
	end
	check(not Roaming.Decode(plan, string.rep("x", 4097)), "reject oversized transport")
	check(not Roaming.Decode(plan, "null"), "reject JSON null")
	check(Roaming.Encode(plan) == before, "malformed snapshots leave all state intact")
	for _, value in ipairs({ -1, math.huge, 0 / 0 }) do
		local invalid = options()
		invalid.speed = value
		check(not pcall(Roaming.new, invalid), "reject invalid speed")
	end
end
