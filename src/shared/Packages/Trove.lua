--!strict
-- Trove: Cleanup-tracking utility (from sleitnick/trove)
-- Tracks objects (Instances, connections, functions, threads) and cleans them all at once.

local RunService = game:GetService("RunService")

local FN_MARKER = newproxy()
local THREAD_MARKER = newproxy()
local GENERIC_OBJECT_CLEANUP_METHODS = table.freeze({ "Destroy", "Disconnect", "destroy", "disconnect" })

local function GetObjectCleanupFunction(object, cleanupMethod)
	local t = typeof(object)
	if t == "function" then return FN_MARKER end
	if t == "thread" then return THREAD_MARKER end
	if cleanupMethod then return cleanupMethod end
	if t == "Instance" then return "Destroy" end
	if t == "RBXScriptConnection" then return "Disconnect" end
	if t == "table" then
		for _, m in GENERIC_OBJECT_CLEANUP_METHODS do
			if typeof(object[m]) == "function" then return m end
		end
	end
	error("failed to get cleanup function for object " .. t .. ": " .. tostring(object), 3)
end

local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _objects = {}, _cleaning = false }, Trove)
end

function Trove:Add(object, cleanupMethod)
	if self._cleaning then error("cannot call trove:Add() while cleaning", 2) end
	local cleanup = GetObjectCleanupFunction(object, cleanupMethod)
	table.insert(self._objects, { object, cleanup })
	return object
end

function Trove:Clone(instance)
	if self._cleaning then error("cannot call trove:Clone() while cleaning", 2) end
	return self:Add(instance:Clone())
end

function Trove:Construct(class, ...)
	if self._cleaning then error("cannot call trove:Construct() while cleaning", 2) end
	local object
	if type(class) == "table" then object = class.new(...)
	elseif type(class) == "function" then object = class(...)
	end
	return self:Add(object)
end

function Trove:Connect(signal, fn)
	if self._cleaning then error("cannot call trove:Connect() while cleaning", 2) end
	return self:Add(signal:Connect(fn))
end

function Trove:BindToRenderStep(name, priority, fn)
	if self._cleaning then error("cannot call trove:BindToRenderStep() while cleaning", 2) end
	RunService:BindToRenderStep(name, priority, fn)
	self:Add(function() RunService:UnbindFromRenderStep(name) end)
end

function Trove:AddPromise(promise)
	if self._cleaning then error("cannot call trove:AddPromise() while cleaning", 2) end
	if promise:getStatus() == "Started" then
		promise:finally(function()
			if self._cleaning then return end
			self:_findAndRemoveFromObjects(promise, false)
		end)
		self:Add(promise, "cancel")
	end
	return promise
end

function Trove:Remove(object)
	if self._cleaning then error("cannot call trove:Remove() while cleaning", 2) end
	return self:_findAndRemoveFromObjects(object, true)
end

function Trove:Extend()
	if self._cleaning then error("cannot call trove:Extend() while cleaning", 2) end
	return self:Construct(Trove)
end

function Trove:Clean()
	if self._cleaning then return end
	self._cleaning = true
	for _, obj in self._objects do
		self:_cleanupObject(obj[1], obj[2])
	end
	table.clear(self._objects)
	self._cleaning = false
end

function Trove:WrapClean()
	return function() self:Clean() end
end

function Trove:_findAndRemoveFromObjects(object, cleanup)
	local objects = self._objects
	for i, obj in objects do
		if obj[1] == object then
			local n = #objects
			objects[i] = objects[n]
			objects[n] = nil
			if cleanup then self:_cleanupObject(obj[1], obj[2]) end
			return true
		end
	end
	return false
end

function Trove:_cleanupObject(object, cleanupMethod)
	if cleanupMethod == FN_MARKER then
		task.spawn(object)
	elseif cleanupMethod == THREAD_MARKER then
		pcall(task.cancel, object)
	else
		object[cleanupMethod](object)
	end
end

function Trove:AttachToInstance(instance)
	if self._cleaning then error("cannot call trove:AttachToInstance() while cleaning", 2) end
	if not instance:IsDescendantOf(game) then error("instance is not a descendant of the game hierarchy", 2) end
	return self:Connect(instance.Destroying, function() self:Destroy() end)
end

function Trove:Destroy()
	self:Clean()
end

return { new = Trove.new }
