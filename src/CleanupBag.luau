-- Owns callbacks, connections, and instances. No loops or services are started.
local CleanupBag = {}
CleanupBag.__index = CleanupBag

local function cleanupFor(resource, method)
	if type(resource) == "function" and method == nil then
		return resource
	end
	if method == nil then
		local kind = typeof(resource)
		if kind == "RBXScriptConnection" then
			method = "Disconnect"
		elseif kind == "Instance" then
			method = "Destroy"
		elseif type(resource) == "table" then
			method = type(resource.Destroy) == "function" and "Destroy" or "Disconnect"
		end
	end
	assert(type(method) == "string" and #method > 0, "Expected a cleanup callback or method")
	local fn = resource[method]
	assert(type(fn) == "function", "Resource has no cleanup method: " .. method)
	return function()
		fn(resource)
	end
end

local function execute(cleanup)
	local ok, err = pcall(cleanup)
	if ok then
		return nil
	end
	local printable, message = pcall(tostring, err)
	return printable and message or "Cleanup failed with an unprintable error"
end

function CleanupBag.new()
	return setmetatable(
		{ _entries = {}, _resources = {}, _cleaning = false, _destroyed = false },
		CleanupBag
	)
end

-- Returns the resource, plus an error only if immediate cleanup fails.
function CleanupBag:Add(resource, method)
	assert(resource ~= nil and resource ~= self, "Invalid cleanup resource")
	local cleanup = cleanupFor(resource, method)
	if self._destroyed or self._cleaning then
		local err = execute(cleanup)
		if err and self._errors then
			table.insert(self._errors, err)
		end
		return resource, err
	end
	assert(not self._resources[resource], "Resource is already registered")
	local entry = { Resource = resource, Cleanup = cleanup }
	self._resources[resource] = entry
	table.insert(self._entries, entry)
	return resource
end

function CleanupBag:Remove(resource)
	local entry = self._resources[resource]
	if not entry then
		return false
	end
	self._resources[resource] = nil
	for i, candidate in ipairs(self._entries) do
		if candidate == entry then
			table.remove(self._entries, i)
			break
		end
	end
	return true, execute(entry.Cleanup)
end

-- Reverse registration order. All callbacks run even if one fails.
function CleanupBag:Clean()
	if self._cleaning then
		return {}
	end
	local entries, errors = self._entries, {}
	self._entries, self._resources = {}, {}
	self._cleaning, self._errors = true, errors
	for i = #entries, 1, -1 do
		local err = execute(entries[i].Cleanup)
		if err then
			table.insert(errors, err)
		end
	end
	self._cleaning, self._errors = false, nil
	return errors
end

function CleanupBag:Destroy()
	self._destroyed = true
	return self:Clean()
end

return CleanupBag
