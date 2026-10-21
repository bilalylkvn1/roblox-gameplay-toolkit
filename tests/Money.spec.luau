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
end
