-- Immutable weighted choice table. Use trusted server randomness for gameplay rewards.
local WeightedRandom = {}
WeightedRandom.__index = WeightedRandom
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function WeightedRandom.new(entries)
	assert(type(entries) == "table" and #entries > 0, "Expected a non-empty entry array")
	local count, maxWeight = 0, 0
	for key, entry in pairs(entries) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #entries,
			"Entries must be a dense array"
		)
		assert(type(entry) == "table" and entry.value ~= nil, "Entry must have a non-nil value")
		assert(
			finite(entry.weight) and entry.weight >= 0,
			"Weights must be finite and non-negative"
		)
		count += 1
		maxWeight = math.max(maxWeight, entry.weight)
	end
	assert(count == #entries and maxWeight > 0, "Expected a dense array with a positive weight")
	local choices, total = {}, 0
	for index, entry in ipairs(entries) do
		if entry.weight > 0 then
			local scaled = entry.weight / maxWeight
			local nextTotal = total + scaled
			assert(scaled > 0 and nextTotal > total, "Weight range exceeds numeric precision")
			total = nextTotal
			choices[#choices + 1] = table.freeze({
				value = entry.value,
				index = index,
				weight = scaled,
				cumulative = total,
			})
		end
	end
	return setmetatable({ _choices = table.freeze(choices), _total = total }, WeightedRandom)
end

function WeightedRandom:Pick(random)
	random = if random == nil then math.random else random
	assert(type(random) == "function", "random must be a function")
	local roll = random()
	assert(finite(roll) and roll >= 0 and roll <= 1, "random must return a number in [0, 1]")
	local target = roll * self._total
	local low, high = 1, #self._choices
	while low < high do
		local middle = math.floor((low + high) / 2)
		if target < self._choices[middle].cumulative then
			high = middle
		else
			low = middle + 1
		end
	end
	local choice = self._choices[low]
	return choice.value, choice.index
end

function WeightedRandom:GetProbabilities()
	local result = {}
	for _, choice in ipairs(self._choices) do
		result[#result + 1] = {
			value = choice.value,
			index = choice.index,
			probability = choice.weight / self._total,
		}
	end
	return result
end

return WeightedRandom
