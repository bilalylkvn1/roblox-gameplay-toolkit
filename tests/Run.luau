-- Run from Studio's Command Bar after installing the demo project.
return function(Toolkit)
	local total, results = 0, {}
	local function run(name, fn)
		local passed = 0
		fn(function(ok, message)
			assert(ok, name .. ": " .. (message or "check failed"))
			passed += 1
			total += 1
		end)
		results[name] = passed
	end
	run("Money", function(check)
		require(script.Parent["Money.spec"])(Toolkit.Money, check)
	end)
	run("Roaming", function(check)
		require(script.Parent["Roaming.spec"])(Toolkit.Roaming, check)
	end)
	run("Pets", function(check)
		require(script.Parent["Pets.spec"])(Toolkit, check)
	end)
	results.total = total
	print("Gameplay Toolkit: " .. total .. " checks passed")
	return results
end
