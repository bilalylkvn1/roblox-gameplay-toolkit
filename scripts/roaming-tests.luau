-- Portable math/transport regression suite. This is not a Roblox engine test.
-- Loads the real source and the same spec used by tests/Run in Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local root = process.cwd
-- Lune 0.10.5 lookAt mirrors the Z heading. Roaming uses upright frames only;
-- build that frame with the documented yaw convention instead. All other CFrame
-- and Vector3 operations below are the Lune implementations.
local frames = table.clone(roblox.CFrame)
frames.lookAt = function(position, target)
	local d = target - position
	assert(math.abs(d.Y) < 0.001 and d.Magnitude > 0, "Expected horizontal heading")
	return roblox.CFrame.new(position) * roblox.CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
end
assert(frames.lookAt(roblox.Vector3.zero, roblox.Vector3.new(0, 0, -1)).LookVector.Z == -1)
local http = {
	JSONEncode = function(_, state)
		return serde.encode("json", state)
	end,
	JSONDecode = function(_, value)
		return serde.decode("json", value)
	end,
}
local environment = {
	Vector3 = roblox.Vector3,
	CFrame = frames,
	game = {
		GetService = function(_, name)
			assert(name == "HttpService", "Unexpected engine dependency: " .. name)
			return http
		end,
	},
}
local function load(path)
	return luau.load(fs.readFile(root .. "/" .. path), {
		debugName = path,
		environment = table.clone(environment),
	})()
end
local Roaming = load("src/Roaming.luau")
local suite = load("tests/Roaming.spec.luau")
local passed = 0
suite(Roaming, function(ok, message)
	assert(ok, message)
	passed += 1
end)
print(string.format("Roaming (Lune math / JSON adapter): %d checks passed", passed))
