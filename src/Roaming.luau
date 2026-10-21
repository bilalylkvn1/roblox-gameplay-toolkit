-- Server chooses headings; all clients evaluate the same timed, curved movement segment.
local Http = game:GetService("HttpService")
local Roaming = { DecisionSeconds = 0.2, PredictionSeconds = 0.6, MaxCatchupSteps = 10 }
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function vector(v)
	return typeof(v) == "Vector3"
		and finite(v.X)
		and finite(v.Y)
		and finite(v.Z)
		and finite(v.Magnitude)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function unit(v, fallback)
	local d = flat(v)
	return d.Magnitude > 0.001 and d.Unit or fallback
end
local function yaw(v)
	return math.atan2(-v.X, -v.Z)
end
local function direction(a)
	return Vector3.new(-math.sin(a), 0, -math.cos(a))
end
local function angle(a, b)
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end
local function limits(plan)
	local margin = (plan.bodyHeight or 2.6) * 0.395 + (plan.edgePadding or 4)
	return plan.boundsSize.X / 2 - margin, plan.boundsSize.Z / 2 - margin
end
function Roaming.Clamp(plan, p)
	local x, z = limits(plan)
	local lp = plan.boundsFrame:PointToObjectSpace(p)
	lp = Vector3.new(math.clamp(lp.X, -x, x), lp.Y, math.clamp(lp.Z, -z, z))
	local bounded = plan.boundsFrame:PointToWorldSpace(lp)
	local offset = flat(bounded - plan.origin)
	if offset.Magnitude > plan.radius then
		bounded = plan.origin + offset.Unit * plan.radius
	end
	return Vector3.new(bounded.X, plan.origin.Y, bounded.Z)
end
function Roaming.Inside(plan, p, inset)
	local x, z = limits(plan)
	local lp = plan.boundsFrame:PointToObjectSpace(p)
	inset = inset or 0
	return math.abs(lp.X) <= x - inset
		and math.abs(lp.Z) <= z - inset
		and flat(p - plan.origin).Magnitude <= plan.radius - inset
end
local function raw(plan, age)
	local frame = plan.frame
	local start = frame.Position
	local a = yaw(frame.LookVector)
	local goal = yaw(plan.goal or frame.LookVector)
	local delta = angle(a, goal)
	local rate = math.max(math.rad(210), plan.speed / 12)
	local turn = math.min(age, math.abs(delta) / rate)
	local w = delta >= 0 and rate or -rate
	local heading = a + w * turn
	local offset
	if math.abs(delta) < 0.0001 then
		heading = a
		turn = 0
		offset = Vector3.zero
	else
		offset = Vector3.new(
			(math.cos(heading) - math.cos(a)) / w,
			0,
			-(math.sin(heading) - math.sin(a)) / w
		) * plan.speed
	end
	return start + offset + direction(heading) * plan.speed * (age - turn), direction(heading)
end
function Roaming.Sample(plan, now)
	assert(finite(now) and plan.frame, "Advance the plan before sampling")
	local age =
		math.clamp(math.min(now, plan.expiresAt) - plan.updatedAt, 0, Roaming.PredictionSeconds)
	local predicted, heading = raw(plan, age)
	local p = Roaming.Clamp(plan, predicted)
	-- An emergency inward pivot prevents a corner from holding the egg in place.
	-- Normal turns are curved; this only handles a prediction that reaches the hard boundary.
	local x, z = limits(plan)
	local lp = plan.boundsFrame:PointToObjectSpace(predicted)
	local localHeading = plan.boundsFrame:VectorToObjectSpace(heading)
	if math.abs(lp.X) > x and lp.X * localHeading.X > 0 then
		localHeading = Vector3.new(-localHeading.X, 0, localHeading.Z)
	end
	if math.abs(lp.Z) > z and lp.Z * localHeading.Z > 0 then
		localHeading = Vector3.new(localHeading.X, 0, -localHeading.Z)
	end
	heading = plan.boundsFrame:VectorToWorldSpace(localHeading).Unit
	local radial = flat(predicted - plan.origin)
	if radial.Magnitude > plan.radius and heading:Dot(radial) > 0 then
		heading = (heading - 2 * heading:Dot(radial.Unit) * radial.Unit).Unit
	end
	local before = Roaming.Clamp(plan, raw(plan, math.max(0, age - 0.002)))
	local speed = age > 0 and (p - before).Magnitude / math.min(age, 0.002) or plan.speed
	return p,
		heading,
		(plan.travel or 0) + age * plan.speed,
		(now >= plan.expiresAt and 0 or math.min(plan.speed, speed))
end
function Roaming.Choose(plan, playerPosition, random)
	random = random or math.random
	local p = plan.frame.Position
	local current = plan.frame.LookVector
	local away = unit(p - playerPosition, current)
	local drift = (random() * 2 - 1) * math.rad(18)
	local best, bestScore = current, -math.huge
	for _, degrees in { 0, -30, 30, -60, 60, -90, 90, -120, 120, 180 } do
		local candidate = direction(yaw(away) + math.rad(degrees) + drift)
		local saved = plan.goal
		plan.goal = candidate
		local safe = true
		local clearance = math.huge
		local endClearance = 0
		for _, age in { 0.1, 0.2, 0.35, 0.5 } do
			local future = raw(plan, age)
			if not Roaming.Inside(plan, future, 0.75) then
				safe = false
			end
			local lp = plan.boundsFrame:PointToObjectSpace(future)
			local x, z = limits(plan)
			endClearance = math.min(
				x - math.abs(lp.X),
				z - math.abs(lp.Z),
				plan.radius - flat(future - plan.origin).Magnitude
			)
			clearance = math.min(clearance, endClearance)
		end
		plan.goal = saved
		local score = candidate:Dot(away) * 3
			+ candidate:Dot(current) * 0.7
			+ math.clamp(clearance, -30, 15) * 0.08
			+ random() * 0.7
		-- If a turn starts beside a wall, favour clearing it rather than repeatedly grazing it.
		if not safe then
			score = -100 + endClearance * 2 + candidate:Dot(away) * 0.5 + random() * 0.2
		end
		if score > bestScore then
			bestScore = score
			best = candidate
		end
	end
	return best
end
function Roaming.Advance(plan, now, playerPosition, random)
	assert(finite(now) and vector(playerPosition), "Expected a finite time and player position")
	local runAt = plan.startsAt
	if now < runAt or not plan.boundsFrame then
		return false
	end
	now = math.min(now, plan.expiresAt)
	if plan.updatedAt and now < plan.updatedAt then
		return false
	end
	local changed = false
	if not plan.frame then
		local heading = unit(plan.origin - playerPosition, plan.direction)
		plan.frame = CFrame.lookAt(plan.origin, plan.origin + heading)
		plan.updatedAt = runAt
		plan.travel = 0
		plan.goal = Roaming.Choose(plan, playerPosition, random)
		-- Feet emerge facing the first safe direction; there is no outward run into a nearby edge.
		plan.frame = CFrame.lookAt(plan.origin, plan.origin + plan.goal)
		changed = true
	end
	-- A long server pause holds the last position and resumes a bounded number of decisions.
	if now - plan.updatedAt > Roaming.DecisionSeconds * Roaming.MaxCatchupSteps then
		plan.updatedAt = now - Roaming.DecisionSeconds * Roaming.MaxCatchupSteps
		changed = true
	end
	while plan.updatedAt + Roaming.DecisionSeconds <= now do
		local t = plan.updatedAt + Roaming.DecisionSeconds
		local p, heading, travel = Roaming.Sample(plan, t)
		plan.frame = CFrame.lookAt(p, p + heading)
		plan.updatedAt = t
		plan.travel = travel
		plan.goal = Roaming.Choose(plan, playerPosition, random)
		changed = true
	end
	return changed
end

-- The origin must lie inside the usable rectangle so radial clamping stays inside both bounds.
function Roaming.new(options)
	assert(type(options) == "table", "Expected roaming options")
	assert(typeof(options.boundsFrame) == "CFrame", "boundsFrame must be a CFrame")
	assert(vector(options.boundsFrame.Position), "boundsFrame must have a finite position")
	local components = { options.boundsFrame:GetComponents() }
	for _, n in ipairs(components) do
		assert(finite(n), "boundsFrame must be finite")
	end
	assert(
		options.boundsFrame.UpVector:Dot(Vector3.yAxis) > 0.999999,
		"boundsFrame must be upright (yaw rotation only)"
	)
	assert(
		vector(options.boundsSize) and options.boundsSize.X > 0 and options.boundsSize.Z > 0,
		"boundsSize must have positive X/Z dimensions"
	)
	assert(vector(options.origin), "origin must be a finite Vector3")
	local plan = {
		boundsFrame = options.boundsFrame,
		boundsSize = options.boundsSize,
		origin = options.origin,
		radius = options.radius or 20,
		speed = options.speed or 8,
		bodyHeight = options.bodyHeight or 2.6,
		edgePadding = options.edgePadding or 4,
		startsAt = options.startsAt or 0,
		expiresAt = options.expiresAt or math.huge,
		direction = options.direction or Vector3.new(0, 0, -1),
	}
	assert(finite(plan.radius) and plan.radius > 0, "radius must be positive and finite")
	assert(finite(plan.speed) and plan.speed >= 0, "speed must be non-negative and finite")
	assert(
		finite(plan.bodyHeight)
			and plan.bodyHeight >= 0
			and finite(plan.edgePadding)
			and plan.edgePadding >= 0,
		"Invalid body margin"
	)
	assert(
		finite(plan.startsAt)
			and type(plan.expiresAt) == "number"
			and plan.expiresAt >= plan.startsAt,
		"Invalid start / expiry"
	)
	assert(
		vector(plan.direction) and flat(plan.direction).Magnitude > 0.001,
		"direction must have a horizontal component"
	)
	local x, z = limits(plan)
	assert(x > 0 and z > 0, "boundsSize must leave room for the body margin and edgePadding")
	local lp = plan.boundsFrame:PointToObjectSpace(plan.origin)
	assert(
		math.abs(lp.X) <= x and math.abs(lp.Z) <= z,
		"origin must be inside the usable rectangle"
	)
	plan.direction = flat(plan.direction).Unit
	return plan
end

function Roaming.Snapshot(plan)
	assert(plan.frame and plan.goal, "Advance the plan before taking a snapshot")
	local p, d, g = plan.frame.Position, plan.frame.LookVector, plan.goal
	return {
		t = plan.updatedAt,
		p = { p.X, p.Y, p.Z },
		d = { d.X, d.Y, d.Z },
		g = { g.X, g.Y, g.Z },
		travel = plan.travel or 0,
	}
end

local function readVector(value)
	if
		type(value) ~= "table"
		or not finite(value[1])
		or not finite(value[2])
		or not finite(value[3])
	then
		return nil
	end
	local result = Vector3.new(value[1], value[2], value[3])
	return vector(result) and result or nil
end

-- Apply only trusted server snapshots on clients. This is validation, not gameplay authorization.
function Roaming.ApplySnapshot(plan, state)
	if
		type(state) ~= "table"
		or not finite(state.t)
		or not finite(state.travel)
		or state.travel < 0
	then
		return false
	end
	if
		state.t < plan.startsAt
		or state.t > plan.expiresAt
		or (plan.updatedAt and state.t < plan.updatedAt)
		or (plan.travel and state.travel < plan.travel - 0.000001)
	then
		return false
	end
	local p, d, g = readVector(state.p), readVector(state.d), readVector(state.g)
	if not p or not d or not g or flat(d).Magnitude < 0.001 or flat(g).Magnitude < 0.001 then
		return false
	end
	if math.abs(p.Y - plan.origin.Y) > 0.001 or not Roaming.Inside(plan, p, -0.001) then
		return false
	end
	d = flat(d).Unit
	g = flat(g).Unit
	plan.frame = CFrame.lookAt(p, p + d)
	plan.goal = g
	plan.updatedAt = state.t
	plan.travel = math.max(plan.travel or 0, state.travel)
	return true
end

function Roaming.Encode(plan)
	return Http:JSONEncode(Roaming.Snapshot(plan))
end

function Roaming.Decode(plan, value)
	if type(value) ~= "string" or #value > 4096 then
		return false
	end
	local ok, state = pcall(Http.JSONDecode, Http, value)
	return ok and Roaming.ApplySnapshot(plan, state) or false
end

return Roaming
