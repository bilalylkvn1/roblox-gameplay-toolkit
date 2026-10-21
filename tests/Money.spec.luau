return function(Money, check)
	local function eq(a, b, message)
		check(a == b, message or (tostring(a) .. " ~= " .. tostring(b)))
	end
	eq(Money.Normalize("000123"), "123", "leading zero normalization")
	eq(Money.Normalize("000"), "0")
	for _, value in ipairs({
		"",
		"-1",
		"1.0",
		"1e3",
		" 12",
		string.rep("1", 41),
		false,
		{},
		-1,
		0.5,
		math.huge,
		0 / 0,
		9007199254740992,
	}) do
		eq(Money.Normalize(value), nil, "reject invalid integer")
	end
	eq(Money.Normalize(9007199254740991), "9007199254740991")
	eq(Money.Compare("999", "1000"), -1)
	eq(Money.Compare("001", "1"), 0)
	eq(Money.Compare("1000000000000000000", "999999999999999999"), 1)
	eq(Money.Add("9007199254740991", "10"), "9007199254741001", "beyond float precision")
	eq(Money.Add("999999999999999999", "1"), Money.MAX)
	eq(Money.Add(Money.MAX, "1"), Money.MAX, "saturating cap")
	eq(
		Money.Add(string.rep("9", 40), string.rep("9", 40)),
		Money.MAX,
		"oversized input carry saturates"
	)
	eq(Money.Subtract(Money.MAX, "1"), "999999999999999999", "borrow across 18 zeroes")
	eq(Money.Subtract("0", "1"), nil, "underflow has no negative result")
	eq(Money.Subtract("1000", "1"), "999")
	eq(Money.Clamp(string.rep("9", 40)), Money.MAX)
	eq(Money.Format("1234567"), "1.2M")
	eq(Money.Format("999"), "999")
	for i = 0, 199 do
		local a = (i * 7919) % 1000000
		local b = (i * 1543 + 17) % 1000000
		eq(Money.Add(tostring(a), tostring(b)), tostring(a + b), "small integer reference addition")
		eq(
			Money.Subtract(tostring(a + b), tostring(b)),
			tostring(a),
			"addition / subtraction roundtrip"
		)
	end
	local a = "9007199254740991"
	for _ = 1, 100 do
		a = Money.Add(a, "1")
	end
	eq(a, "9007199254741091", "repeated addition remains exact")
	eq(Money.Multiply("9007199254740993", "3"), "27021597764222979", "exact multiplication")
	eq(Money.Multiply("0012", "0034"), "408")
	eq(Money.Multiply(Money.MAX, "2"), Money.MAX, "product saturates")
	eq(Money.Multiply(string.rep("9", 40), "0"), "0", "zero precedes saturation")
	eq(Money.Multiply(string.rep("9", 40), string.rep("9", 40)), Money.MAX)
	local q, r = Money.Divide("9007199254740993", "2")
	eq(q, "4503599627370496", "division beyond float precision")
	eq(r, "1")
	q, r = Money.Divide(string.rep("9", 40), "1" .. string.rep("0", 20))
	eq(q, string.rep("9", 20), "division does not cap quotient")
	eq(r, string.rep("9", 20), "large divisor / remainder")
	q, r = Money.Divide("12", "100")
	eq(q, "0")
	eq(r, "12")
	q, r = Money.Divide("0", "17")
	eq(q, "0")
	eq(r, "0")
	q, r = Money.Divide("00100", "00010")
	eq(q, "10")
	eq(r, "0")
	eq(Money.FormatFull("00012345678901234567890"), "12,345,678,901,234,567,890")
	eq(Money.FormatFull("100"), "100")
	eq(Money.FormatFull("1000"), "1,000")
	eq(Money.FormatFull("bad"), "0")
	check(not pcall(Money.Divide, "1", "000"), "reject division by zero")
	for _, fn in ipairs({ Money.Multiply, Money.Divide }) do
		check(not pcall(fn, "bad", "1"), "reject invalid dividend / multiplicand")
		check(not pcall(fn, "1", -1), "reject invalid divisor / multiplier")
	end
	for i = 0, 399 do
		local x = (i * 7919) % 1000000
		local y = (i * 1543 + 17) % 1000000 + 1
		eq(Money.Multiply(x, y), string.format("%.0f", x * y), "reference multiplication")
		local quotient, remainder = Money.Divide(x, y)
		eq(quotient, tostring(math.floor(x / y)), "reference floor division")
		eq(remainder, tostring(x % y), "reference remainder")
		local balance = Money.Add("9007199254740993", tostring(x))
		quotient, remainder = Money.Divide(balance, y)
		eq(Money.Add(Money.Multiply(quotient, y), remainder), balance, "large division identity")
		check(Money.Compare(remainder, y) < 0, "remainder smaller than divisor")
	end
end
