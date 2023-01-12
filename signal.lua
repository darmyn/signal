local signal = {}
signal.interface = {}
signal.schema = {}
signal.metatable = {__index = signal.schema}

function signal.prototype(self)
	self._connections = {
		callbacks = {},
		yieldedThreads = {}
	}
	return self
end

function signal.interface.new()
	return setmetatable(signal.prototype({}), signal.metatable)
end

function signal.schema.connect(self: signal, callback: () -> any)
	table.insert(self._connections.callbacks, callback)
end

function signal.schema.fire(self: signal, ...)
	local connections = self._connections
	for _, callback in pairs(connections.callbacks) do
		callback(...)
	end
	local yieldedThreads = connections.yieldedThreads
	for _, thread in pairs(yieldedThreads) do
		coroutine.resume(thread, ...)
	end
	table.clear(yieldedThreads)
end

function signal.schema.wait(self: signal, timeout: number)
	timeout = timeout or 10
	local yieldedThreads = self._connections.yieldedThreads
	local result
	table.insert(yieldedThreads, coroutine.create(function(...)
		result = table.pack(...)
	end))
	local beganWaitingAt = os.clock()
	while not result do
		if os.clock() - beganWaitingAt >= timeout then
			warn("Signal timeout of "..timeout.." seconds was exceded.")
			break
		end
		task.wait()
	end
	return table.unpack(result)
end

type signal = typeof(signal.prototype(...)) & typeof(signal.schema)
export type Type = signal

return signal.interface