-- Requiring the toolkit starts no loops and creates no instances.
return table.freeze({
	Version = "0.2.0",
	Money = require(script.Money),
	Roaming = require(script.Roaming),
	PetRig = require(script.PetRig),
	PetAnimator = require(script.PetAnimator),
})
