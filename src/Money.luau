-- Exact, non-negative decimal integers. NumberValues are display mirrors only.
local Money = {}
Money.MAX = "1000000000000000000"
Money.MAX_SAFE_NUMBER = 9007199254740991
function Money.Normalize(value)
	if type(value) == "number" then
		if value ~= value or value < 0 or value > Money.MAX_SAFE_NUMBER or value % 1 ~= 0 then
			return nil
		end
		value = string.format("%.0f", value)
	end
	if type(value) ~= "string" or #value > 40 or not value:match("^%d+$") then
		return nil
	end
	value = value:gsub("^0+", "")
	return value == "" and "0" or value
end
function Money.Compare(a, b)
	a = assert(Money.Normalize(a), "Invalid Money")
	b = assert(Money.Normalize(b), "Invalid Money")
	if #a ~= #b then
		return #a < #b and -1 or 1
	end
	if a == b then
		return 0
	end
	return a < b and -1 or 1
end
function Money.Clamp(value)
	local normalized = Money.Normalize(value)
	if not normalized then
		return nil
	end
	return Money.Compare(normalized, Money.MAX) > 0 and Money.MAX or normalized
end
function Money.Add(a, b)
	a = assert(Money.Normalize(a))
	b = assert(Money.Normalize(b))
	local digits, carry = {}, 0
	for i = 1, math.max(#a, #b) do
		local ai, bi = #a - i + 1, #b - i + 1
		local x = ai > 0 and tonumber(a:sub(ai, ai)) or 0
		local y = bi > 0 and tonumber(b:sub(bi, bi)) or 0
		local v = x + y + carry
		table.insert(digits, tostring(v % 10))
		carry = math.floor(v / 10)
	end
	if carry > 0 then
		table.insert(digits, tostring(carry))
	end
	local out = {}
	for i = #digits, 1, -1 do
		table.insert(out, digits[i])
	end
	local sum = table.concat(out)
	if #sum > #Money.MAX then
		return Money.MAX
	end
	return Money.Clamp(sum)
end
function Money.Subtract(a, b)
	a = assert(Money.Normalize(a))
	b = assert(Money.Normalize(b))
	if Money.Compare(a, b) < 0 then
		return nil
	end
	local digits, borrow = {}, 0
	for i = 1, #a do
		local ai, bi = #a - i + 1, #b - i + 1
		local x = tonumber(a:sub(ai, ai))
		local y = bi > 0 and tonumber(b:sub(bi, bi)) or 0
		local v = x - y - borrow
		borrow = v < 0 and 1 or 0
		if v < 0 then
			v += 10
		end
		table.insert(digits, tostring(v))
	end
	local out = {}
	for i = #digits, 1, -1 do
		table.insert(out, digits[i])
	end
	return Money.Normalize(table.concat(out))
end
function Money.Format(value)
	local s = Money.Normalize(value) or "0"
	if #s < 4 then
		return s
	end
	local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local group = math.min(math.floor((#s - 1) / 3), #units - 1)
	local leading = #s - group * 3
	return s:sub(1, leading) .. "." .. s:sub(leading + 1, leading + 1) .. units[group + 1]
end
return table.freeze(Money)
