-- Token buckets per trusted key. Rejected attempts do not spend tokens.
local RateLimiter = {}
RateLimiter.__index = RateLimiter
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function validKey(key)
	assert(key ~= nil and (type(key) ~= "number" or finite(key)), "Expected a non-nil, finite key")
end

function RateLimiter.new(options)
	assert(type(options) == "table", "Expected limiter options")
	assert(
		finite(options.capacity) and options.capacity > 0,
		"capacity must be positive and finite"
	)
	assert(
		finite(options.refillRate) and options.refillRate > 0,
		"refillRate must be positive and finite"
	)
	local maxKeys = if options.maxKeys == nil then 1024 else options.maxKeys
	assert(
		finite(maxKeys) and maxKeys > 0 and maxKeys % 1 == 0,
		"maxKeys must be a positive integer"
	)
	local clock = if options.clock == nil then os.clock else options.clock
	assert(type(clock) == "function", "clock must be a function")
	return setmetatable({
		_capacity = options.capacity,
		_rate = options.refillRate,
		_clock = clock,
		_maxKeys = maxKeys,
		_buckets = {},
		_size = 0,
	}, RateLimiter)
end

function RateLimiter:_Now()
	local now = self._clock()
	assert(finite(now), "clock must return a finite number")
	now = math.max(now, self._lastTime or now)
	self._lastTime = now
	return now
end

function RateLimiter:_Tokens(bucket, now)
	return math.min(self._capacity, bucket.tokens + (now - bucket.at) * self._rate)
end

-- allowed, secondsUntilCostAvailable, tokensLeft. A full key budget returns false, infinity, 0.
function RateLimiter:Try(key, cost)
	validKey(key)
	cost = cost == nil and 1 or cost
	assert(finite(cost) and cost > 0 and cost <= self._capacity, "cost must be in (0, capacity]")
	local now = self:_Now()
	local bucket = self._buckets[key]
	if not bucket then
		if self._size >= self._maxKeys then
			return false, math.huge, 0
		end
		bucket = { tokens = self._capacity, at = now }
		self._buckets[key] = bucket
		self._size += 1
	end
	local tokens = self:_Tokens(bucket, now)
	local allowed = tokens >= cost
	if allowed then
		tokens -= cost
	end
	bucket.tokens, bucket.at = tokens, now
	return allowed, (allowed and 0 or (cost - tokens) / self._rate), tokens
end

function RateLimiter:Peek(key)
	validKey(key)
	local now = self:_Now()
	local bucket = self._buckets[key]
	return bucket and self:_Tokens(bucket, now) or self._capacity
end

function RateLimiter:Forget(key)
	validKey(key)
	if not self._buckets[key] then
		return false
	end
	self._buckets[key] = nil
	self._size -= 1
	return true
end

-- Only remove fully refilled buckets, so pruning never grants extra tokens.
function RateLimiter:Prune()
	local now, removed = self:_Now(), 0
	for key, bucket in pairs(self._buckets) do
		if self:_Tokens(bucket, now) >= self._capacity then
			self._buckets[key] = nil
			self._size -= 1
			removed += 1
		end
	end
	return removed
end

function RateLimiter:Clear()
	table.clear(self._buckets)
	self._size = 0
end

function RateLimiter:GetSize()
	return self._size
end

return RateLimiter
