local suite = require("../tests/Utilities.spec")
local passed = 0
suite({
	CleanupBag = require("../src/CleanupBag"),
	Cooldown = require("../src/Cooldown"),
	RateLimiter = require("../src/RateLimiter"),
	WeightedRandom = require("../src/WeightedRandom"),
}, function(ok, message)
	assert(ok, message)
	passed += 1
end)
print(string.format("Utilities: %d checks passed", passed))
