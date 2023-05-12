local connection = {}
connection.interface = {}
connection.behavior = {}
connection.meta = {__index = connection.behavior}

function connection.interface.new(
	callback: callback, 
	maxCalls: number
)
    local self = setmetatable({}, connection.meta)
    self.calls = 0 -- number of times the connection was fired
	self.maxCalls = maxCalls or 0 -- the max number of times the connection can be fired (0 = infinity)
	self.callback = callback
	self.alive = true -- can the connection be fired?
	return self
end

function connection.behavior.fire(self: connection, ...)
	if self.alive then
		self.calls += 1
		self.callback(...)
		if self.calls >= self.maxCalls and self.maxCalls ~= 0 then
			self:destroy()
		end
	end
end

function connection.behavior.destroy(self: connection)
	self.alive = false
	setmetatable(self, nil)
end

type connection = typeof(connection.interface.new(table.unpack(...)))

local signal = {}
signal.interface = {} --> public distributable of the module
signal.behavior = {} --> methods of class
signal.meta = {__index = signal.behavior} --> object metatable

function signal.interface.new() --> creates a new signal
    local self = setmetatable({}, signal.meta)
    self._connections = {}
    return self
end

function signal.interface.wrap(scriptSignal: RBXScriptSignal) --> creates a new signal and connects it to an existing RBXScriptConnection
	local newSignal = signal.interface.new()
	return scriptSignal:Connect(function(...)
		newSignal:fire(...)
	end)
end

type callback = (...any) -> (...any | nil)

function signal.behavior.connect(self: signal, callback: callback, itterations: number?)
	local connections = self._connections
	local connection = connection.interface.new(callback, itterations)
	table.insert(connections, connection)
	return connection
end

function signal.behavior.connectMethod(self: signal, obj, method, itterations: number?)
	return self:connect(function(...)
		return method(obj, ...)
	end, itterations)
end

function signal.behavior.wait(self: signal, itterations: number, timeout: number)
	timeout = timeout or 10
	local results = {}
	local connection = self:connect(function(...)
		return table.insert(results, table.pack(...))
	end, itterations)
	local beganWaitingAt = os.clock()
	while connection.calls ~= itterations do
		if os.clock() - beganWaitingAt >= timeout then
			warn("Signal timeout of "..timeout.." seconds was exceded.")
			break
		end
		task.wait()
	end
	return results
end

function signal.behavior.disconnectAll(self: signal)
	for _, connection in ipairs(self._connections) do
		connection:destroy()
	end
	table.clear(self._connections)
end

function signal.behavior.fire(self: signal, ...)
	local connections = self._connections
	for i, connection: connection in pairs(connections) do
		connection:fire()
		if not connection.alive then
			table.remove(connections, i)
		end
	end
end

function signal.behavior.destroy(self: signal)
	self:disconnectAll()
	setmetatable(self :: any, nil)
	table.clear(self :: any)
end

local test = signal.interface.new()
test:fire()
print("fired initial test")
task.spawn(function()
	local result = test:wait(2)
	print("2 itterations have passed, here is the result: ", result)
end)
test:connect(function()
	print("Connection 1 fired")
end)
test:connect(function()
	print("Connection 2 fired")
end, 3)
task.spawn(function()
	local result = test:wait(2)
	print("other wait is fired, here is the result: ", result)
end)

for i = 1, 3 do
	test:fire()
end

type signal = typeof(signal.interface.new(table.unpack(...)))
export type Type = signal

return signal.interface