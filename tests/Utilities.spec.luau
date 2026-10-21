-- Engine-independent scenarios, shared by Luau CLI and Studio.
return function(Toolkit, check)
	local Bag, Cooldown, Limiter, Weighted =
		Toolkit.CleanupBag, Toolkit.Cooldown, Toolkit.RateLimiter, Toolkit.WeightedRandom
	local function fails(fn, message)
		check(not pcall(fn), message)
	end
	local bag, order = Bag.new(), {}
	local first = function()
		table.insert(order, "first")
	end
	bag:Add(first)
	bag:Add(function()
		table.insert(order, "second")
		error("expected cleanup failure")
	end)
	bag:Add(function()
		table.insert(order, "third")
	end)
	fails(function()
		bag:Add(first)
	end, "duplicate registration rejected")
	local errors = bag:Clean()
	check(table.concat(order, ",") == "third,second,first", "LIFO cleanup survives callback errors")
	check(
		#errors == 1 and errors[1]:find("expected cleanup failure", 1, true),
		"errors returned to caller"
	)
	check(#bag:Clean() == 0 and #order == 3, "cleanup is idempotent")
	local calls = 0
	local object = {
		Destroy = function()
			calls += 1
		end,
	}
	check(bag:Add(object) == object, "Add returns original resource")
	check(bag:Remove(object), "Remove runs registered cleanup")
	check(not bag:Remove(object) and calls == 1, "Remove only runs once")
	bag:Clean()
	check(calls == 1, "removed resource is not cleaned again")
	bag:Add({
		Disconnect = function()
			calls += 1
		end,
	})
	bag:Add({
		Close = function()
			calls += 1
		end,
	}, "Close")
	bag:Clean()
	check(calls == 3, "table connections and explicit methods supported")
	local nestedCount
	bag:Add(function()
		nestedCount = #bag:Clean()
		bag:Add(function()
			calls += 1
		end)
	end)
	bag:Clean()
	check(nestedCount == 0, "nested Clean is safe")
	check(calls == 4, "resources added during cleanup are immediately cleaned")
	bag:Destroy()
	bag:Destroy()
	bag:Add(function()
		calls += 1
	end)
	check(calls == 5, "resources added after Destroy are immediately cleaned")
	local _, lateError = bag:Add(function()
		error("late cleanup")
	end)
	check(type(lateError) == "string", "late cleanup errors returned")
	fails(function()
		bag:Add(bag)
	end, "bag cannot own itself")
	fails(function()
		Bag.new():Add({})
	end, "invalid cleanup resource rejected")
	local failingBag = Bag.new()
	local failing = function()
		error("remove failure")
	end
	failingBag:Add(failing)
	local removed, removeError = failingBag:Remove(failing)
	check(removed and type(removeError) == "string", "Remove reports callback failure")
	local nestedErrors = Bag.new()
	nestedErrors:Add(function()
		nestedErrors:Add(function()
			error("nested failure")
		end)
	end)
	check(#nestedErrors:Clean() == 1, "immediate nested errors join the cleanup report")
	local unprintable = Bag.new()
	unprintable:Add(function()
		error(setmetatable({}, {
			__tostring = function()
				error("broken error formatter")
			end,
		}))
	end)
	local safe, report = pcall(unprintable.Clean, unprintable)
	check(
		safe and #report == 1 and type(report[1]) == "string",
		"error formatting cannot interrupt cleanup"
	)

	local now = 0
	local function clock()
		return now
	end
	local cooldown = Cooldown.new({ duration = 2, clock = clock, maxKeys = 2 })
	check(cooldown:Try("a"), "first cooldown attempt allowed")
	local allowed, wait = cooldown:Try("a")
	check(not allowed and wait == 2, "cooldown returns remaining delay")
	now = 1
	check(cooldown:Remaining("a") == 1, "cooldown time decreases")
	now = -10
	check(cooldown:Remaining("a") == 1, "backwards clock cannot extend cooldown")
	check(cooldown:Try("b"), "keys have independent cooldowns")
	allowed, wait = cooldown:Try("c")
	check(
		not allowed and wait == math.huge and cooldown:GetSize() == 2,
		"cooldown key budget bounded"
	)
	now = 2
	check(cooldown:Try("a"), "exact deadline admits next attempt")
	check(cooldown:Prune() == 0, "prune preserves active cooldowns")
	check(cooldown:Forget("b") and not cooldown:Forget("b"), "cooldown Forget is idempotent")
	check(cooldown:Try("c"), "Forget releases key budget")
	now = 10
	check(cooldown:Prune() == 2 and cooldown:GetSize() == 0, "expired cooldowns release memory")
	check(cooldown:Remaining("missing") == 0 and cooldown:GetSize() == 0, "read does not allocate")
	cooldown:Try("a")
	cooldown:Clear()
	check(cooldown:GetSize() == 0 and cooldown:Try("a"), "Clear resets all cooldowns")
	local zero = Cooldown.new({ duration = 0, clock = clock, maxKeys = 1 })
	check(zero:Try("a") and zero:Try("b") and zero:GetSize() == 0, "zero cooldown retains no keys")
	now = 0 / 0
	fails(function()
		cooldown:Try("invalid-clock")
	end, "invalid clock rejected")
	check(cooldown:GetSize() == 1, "invalid clock leaves key storage unchanged")
	now = 0
	for _, duration in ipairs({ -1, math.huge, 0 / 0, "1" }) do
		fails(function()
			Cooldown.new({ duration = duration })
		end, "invalid duration rejected")
	end
	fails(function()
		Cooldown.new({ duration = 1, clock = false })
	end, "invalid cooldown clock rejected")
	fails(function()
		Cooldown.new({ duration = 1, maxKeys = 0 })
	end, "invalid key budget rejected")
	fails(function()
		cooldown:Try(nil)
	end, "nil cooldown key rejected")
	fails(function()
		cooldown:Try(0 / 0)
	end, "NaN cooldown key rejected")

	local limiter = Limiter.new({ capacity = 3, refillRate = 2, clock = clock, maxKeys = 2 })
	check(limiter:Peek("missing") == 3 and limiter:GetSize() == 0, "token read does not allocate")
	allowed, wait = limiter:Try("a", 2)
	check(allowed and wait == 0 and limiter:Peek("a") == 1, "weighted request spends tokens")
	allowed, wait = limiter:Try("a", 2)
	check(
		not allowed and wait == 0.5 and limiter:Peek("a") == 1,
		"rejected request does not spend tokens"
	)
	now = 0.5
	check(limiter:Try("a", 2) and limiter:Peek("a") == 0, "tokens refill at configured rate")
	now = -1
	check(limiter:Peek("a") == 0, "backwards clock cannot mint tokens")
	check(limiter:Try("b", 3), "separate keys get separate burst capacity")
	allowed, wait = limiter:Try("c")
	check(
		not allowed and wait == math.huge and limiter:GetSize() == 2,
		"limiter key budget bounded"
	)
	check(limiter:Prune() == 0, "prune does not forgive incomplete debt")
	now = 2
	check(limiter:Prune() == 2 and limiter:GetSize() == 0, "full buckets safely pruned")
	check(limiter:Try("c", 3), "pruning releases budget without extra burst")
	check(limiter:Forget("c") and not limiter:Forget("c"), "limiter Forget idempotent")
	limiter:Try("a")
	limiter:Clear()
	check(limiter:GetSize() == 0, "limiter Clear resets key state")
	for _, cost in ipairs({ 0, -1, 4, math.huge, 0 / 0 }) do
		fails(function()
			limiter:Try("a", cost)
		end, "invalid token cost rejected")
	end
	check(limiter:GetSize() == 0, "invalid costs allocate no state")
	fails(function()
		Limiter.new({ capacity = 0, refillRate = 1 })
	end, "invalid capacity rejected")
	fails(function()
		Limiter.new({ capacity = 3, refillRate = 0 })
	end, "zero refill rejected")
	fails(function()
		Limiter.new({ capacity = 3, refillRate = 1, maxKeys = 0.5 })
	end, "fractional budget rejected")
	fails(function()
		limiter:Try(nil)
	end, "nil limiter key rejected")
	local budget = Limiter.new({ capacity = 5, refillRate = 2, clock = clock })
	local started, spent = now, 0
	for i = 1, 200 do
		now += (i % 3) * 0.25
		local cost = i % 3 + 1
		if budget:Try("same-player", cost) then
			spent += cost
		end
		check(
			spent <= 5 + 2 * (now - started),
			"aggregate spend never exceeds initial burst plus refill"
		)
		local tokens = budget:Peek("same-player")
		check(tokens >= 0 and tokens <= 5, "tokens stay within capacity")
	end

	local entries = {
		{ value = "excluded", weight = 0 },
		{ value = "common", weight = 1 },
		{ value = "rare", weight = 3 },
	}
	local pool = Weighted.new(entries)
	local value, index = pool:Pick(function()
		return 0
	end)
	check(
		value == "common" and index == 2,
		"zero roll selects first positive weight with original index"
	)
	check(pool:Pick(function()
		return 0.249
	end) == "common", "lower interval boundary")
	check(pool:Pick(function()
		return 0.25
	end) == "rare", "exact boundary selects next interval")
	check(pool:Pick(function()
		return 1
	end) == "rare", "inclusive upper endpoint selects final entry")
	entries[2].weight = 1000
	entries[2].value = "changed"
	check(pool:Pick(function()
		return 0
	end) == "common", "source mutation cannot change choices")
	local probabilities = pool:GetProbabilities()
	check(
		#probabilities == 2
			and probabilities[1].probability == 0.25
			and probabilities[2].probability == 0.75,
		"probabilities omit zero weights and sum to one"
	)
	probabilities[1].value = "changed"
	check(pool:GetProbabilities()[1].value == "common", "probabilities are detached copies")
	local common = 0
	for i = 1, 40 do
		if pool:Pick(function()
			return (i - 0.5) / 40
		end) == "common" then
			common += 1
		end
	end
	check(common == 10, "deterministic uniform grid matches expected weight proportions")
	local huge = Weighted.new({ { value = 1, weight = 1e308 }, { value = 2, weight = 1e308 } })
	check(huge:GetProbabilities()[1].probability == 0.5, "weight normalization avoids sum overflow")
	for _, roll in ipairs({ -1, 1.1, math.huge, 0 / 0, "0.5" }) do
		fails(function()
			pool:Pick(function()
				return roll
			end)
		end, "invalid random output rejected")
	end
	fails(function()
		pool:Pick(false)
	end, "invalid random callback rejected")
	fails(function()
		Weighted.new({})
	end, "empty pool rejected")
	fails(function()
		Weighted.new({ { value = 1, weight = 0 } })
	end, "all-zero weights rejected")
	fails(function()
		Weighted.new({ { weight = 1 } })
	end, "nil value rejected")
	fails(function()
		Weighted.new({ { value = 1, weight = -1 } })
	end, "negative weight rejected")
	fails(function()
		Weighted.new({ { value = 1, weight = math.huge } })
	end, "non-finite weight rejected")
	fails(function()
		Weighted.new({ [1] = { value = 1, weight = 1 }, [3] = { value = 3, weight = 1 } })
	end, "sparse entry array rejected")
	fails(function()
		Weighted.new({ { value = 1, weight = 1 }, { value = 2, weight = 1e-300 } })
	end, "unrepresentable weight interval rejected")
end
