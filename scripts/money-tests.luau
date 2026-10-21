local Money = require("../src/Money")
local suite = require("../tests/Money.spec")
local passed = 0
suite(Money, function(ok, message)
	assert(ok, message)
	passed += 1
end)
print(string.format("Money: %d checks passed", passed))
