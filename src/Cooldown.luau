-- Per-key cooldowns with a monotonic clock and an explicit memory budget.
local Cooldown = {}
Cooldown.__index = Cooldown
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function validKey(key)
	assert(key ~= nil and (type(key) ~= "number" or finite(key)), "Expected a non-nil, finite key")
end

function Cooldown.new(options)
	assert(type(options) == "table", "Expected cooldown options")
	assert(
		finite(options.duration) and options.duration >= 0,
		"duration must be finite and non-negative"
	)
	local maxKeys = if options.maxKeys == nil then 1024 else options.maxKeys
	assert(
		finite(maxKeys) and maxKeys > 0 and maxKeys % 1 == 0,
		"maxKeys must be a positive integer"
	)
	local clock = if options.clock == nil then os.clock else options.clock
	assert(type(clock) == "function", "clock must be a function")
	return setmetatable({
		_duration = options.duration,
		_clock = clock,
		_maxKeys = maxKeys,
		_deadlines = {},
		_size = 0,
	}, Cooldown)
end

function Cooldown:_Now()
	local now = self._clock()
	assert(finite(now), "clock must return a finite number")
	now = math.max(now, self._lastTime or now)
	self._lastTime = now
	return now
end

function Cooldown:Try(key)
	validKey(key)
	local now = self:_Now()
	local expires = self._deadlines[key]
	if expires and expires > now then
		return false, expires - now
	end
	if self._duration == 0 then
		return true, 0
	end
	if not expires and self._size >= self._maxKeys then
		return false, math.huge
	end
	local deadline = now + self._duration
	assert(finite(deadline), "Cooldown deadline overflow")
	if not expires then
		self._size += 1
	end
	self._deadlines[key] = deadline
	return true, 0
end

function Cooldown:Remaining(key)
	validKey(key)
	local now = self:_Now()
	return math.max(0, (self._deadlines[key] or now) - now)
end

function Cooldown:Forget(key)
	validKey(key)
	if self._deadlines[key] == nil then
		return false
	end
	self._deadlines[key] = nil
	self._size -= 1
	return true
end

function Cooldown:Prune()
	local now, removed = self:_Now(), 0
	for key, deadline in pairs(self._deadlines) do
		if deadline <= now then
			self._deadlines[key] = nil
			self._size -= 1
			removed += 1
		end
	end
	return removed
end

function Cooldown:Clear()
	table.clear(self._deadlines)
	self._size = 0
end

function Cooldown:GetSize()
	return self._size
end

return Cooldown
