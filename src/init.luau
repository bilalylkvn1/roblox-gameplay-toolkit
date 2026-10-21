-- Requiring the toolkit starts no loops and creates no instances.
return table.freeze({
	Version = "0.2.0",
	Money = require(script.Money),
	CleanupBag = require(script.CleanupBag),
	Cooldown = require(script.Cooldown),
	RateLimiter = require(script.RateLimiter),
	WeightedRandom = require(script.WeightedRandom),
	Roaming = require(script.Roaming),
	PetRig = require(script.PetRig),
	PetAnimator = require(script.PetAnimator),
})
