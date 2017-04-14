
local skynet = require("skynet")
local socketdriver = require("socketdriver")
local queue = require "skynet.queue"

local socketfd

local TAG = 'BYGATESERVER'

local BYGateServer = {}

local socket_pool = setmetatable(
	{},
	{ 
		__gc = function(p)
			for id, v in pairs(p) do
				socketdriver.close(id)
				-- don't need clear v.buffer, because buffer pool will be free at the end
				p[id] = nil
			end
		end
	}
)

local function wakeup(s)
	local co = s.co
	if co then
		s.co = nil
		skynet.wakeup(co)
	end
end

local function suspend(s)
	assert(not s.co)
	s.co = coroutine.running()
	skynet.wait(s.co)
	-- wakeup closing corouting every time suspend,
	-- because socket.close() will wait last socket buffer operation before clear the buffer.
	if s.closing then
		skynet.wakeup(s.closing)
	end
end

local function funcqueen( cs, func )
	cs(func)
end

local function connect(id, func)
	local s = {
		id = id,
		buffer = "",
		connected = false,
		connecting = true,
		co = false,
		callback = func,
		protocol = "TCP",
		cs = queue(),
	}
	assert(not socket_pool[id], "socket is not closed")
	socket_pool[id] = s
	suspend(s)
	local err = s.connecting
	s.connecting = nil
	if s.connected then
		return id
	else
		socket_pool[id] = nil
		return nil, err
	end
end

function BYGateServer.openclient(fd, func)
	-- Log.i(TAG, "openclient fd = %s, func = %s", fd, func)
	socketdriver.start(fd)
	return connect(fd, func)
end

function BYGateServer.closelient(fd, func)
	-- Log.i(TAG, "closelient fd = %s, func = %s", fd, func)
	local s = socket_pool[fd]
	if s then
		if s.connected then
			func(fd)
		end
	end
end

local function close_fd(fd, func)
	-- Log.i(TAG, "close_fd fd = %s, func = %s", fd, func)
	local s = socket_pool[fd]
	if s then
		if s.connected then
			func(fd)
		end
	end
end

function BYGateServer.shutdown(id)
	close_fd(id, socketdriver.shutdown)
end

function BYGateServer.close_fd(id)
	assert(socket_pool[id] == nil,"Use socket.close instead")
	socketdriver.close(id)
end

function BYGateServer.close(id)
	local s = socket_pool[id]
	if s == nil then
		return
	end
	if s.connected then
		socketdriver.close(id)
		-- notice: call socket.close in __gc should be carefully,
		-- because skynet.wait never return in __gc, so driver.clear may not be called
		if s.co then
			-- reading this socket on another coroutine, so don't shutdown (clear the buffer) immediately
			-- wait reading coroutine read the buffer.
			assert(not s.closing)
			s.closing = coroutine.running()
			skynet.wait(s.closing)
		else
			suspend(s)
		end
		s.connected = false
	end
	close_fd(id)	-- clear the buffer (already close fd)
	assert(s.lock == nil or next(s.lock) == nil)
	socket_pool[id] = nil
end

function BYGateServer.start(handler)
	assert(handler.message)
	assert(handler.connect)

	local CMD = {}
	function CMD.open(source, conf)
		assert(not socketfd)
		local ip = conf.ip or '0.0.0.0'
		local port = assert(conf.port)
		maxclient = conf.maxclient or 1024
		nodelay = conf.nodelay
		if handler.open then
			handler.open(source, conf, false)
		end
		Log.i(TAG, string.format('listen on %s:%s', ip, port))
		socketfd = socketdriver.listen(ip, port)
		socketdriver.start(socketfd)
		connect(socketfd, handler.connect)
	end

	-- 主动链接一个端口
	function CMD.connect(source, conf)
		-- Log.i(TAG, "connect source = %s, ip = %s, port = %s", source, conf.ip, conf.port)
		socketfd = socketdriver.connect(conf.ip, conf.port)
		if handler.open then
			handler.open(source, conf, true)
		end
		assert(socketfd)
		connect(socketfd)
	end

	function CMD.close()
		-- Log.i(TAG, 'CMD close')
		assert(socketfd)
		socketdriver.close(socketfd)
	end

	local function unpack_package( fd, info)
		-- Log.d(TAG, "fd = %s", fd)
		local s = socket_pool[fd]
		if s == nil then
			return
		end
		s.buffer = s.buffer .. info
		while(true) 
		do
			local size = string.len(s.buffer)
			-- Log.d(TAG, "buffer size = %s", size)
			if size < 2 then
				Log.d(TAG, string.format("fd [%d] data size[%d] less than 2",fd,size));
				return 
			end
			local pack_len = string.unpack(">I2", s.buffer)
			-- Log.d(TAG, "pack_len = %s", pack_len)
			if size < pack_len + 2 then
				Log.d(TAG, string.format("fd[%d] data size[%d] < pack_len[%d] + 2",fd,size, pack_len));
				return
			end
			local data = s.buffer:sub(1, pack_len + 2)
			local cmd = string.unpack(">I2", data, 7)
			s.buffer = s.buffer:sub(3 + pack_len)
			handler.message(fd, cmd, data)
			local size = string.len(s.buffer)
			if size < 2 then
				break
			end
		end
	end
	local MSG = {}
	-- read skynet_socket.h for these macro
	-- SKYNET_SOCKET_TYPE_DATA = 1
	MSG[1] = function(id, size, data)
		-- Log.d(TAG, "id = %s, size = %s", id, size)
		local s = socket_pool[id]
		if not s then
			Log.e(TAG, "socket drop packet for id %s", id)
			socketdriver.drop(data, size)
		end
		local info = skynet.tostring(data, size)
		socketdriver.drop(data, size)
		s.cs(unpack_package, id, info)
	end

	-- SKYNET_SOCKET_TYPE_CONNECT = 2
	MSG[2] = function(id, xx, address)
		-- Log.d(TAG, "id = %s, xx = %s, address = %s", id, xx, address)
		local s = socket_pool[id]
		if not s then return end
		s.connected = true
		wakeup(s)
		if handler.connected then
			handler.connected(id, address)
		end
	end

	-- SKYNET_SOCKET_TYPE_CLOSE = 3
	MSG[3] = function(id)
		-- Log.d(TAG, "msgType = %s, id = %s", 3, id)
		local s = socket_pool[id]
		if s == nil then return end
		s.connected = false
		wakeup(s)
		if handler.disconnect then
			handler.disconnect(id)
		end
	end

	-- SKYNET_SOCKET_TYPE_ACCEPT = 4
	MSG[4] = function(id, newid, addr)
		-- Log.d(TAG, "msgType = %s, id = %s, newid = %s, addr = %s", 4, id, newid, addr)
		local s = socket_pool[id]
		if s == nil then
			socketdriver.close(newid)
			return
		end
		s.callback(newid, addr)
	end

	-- SKYNET_SOCKET_TYPE_ERROR = 5
	MSG[5] = function(id, _, err)
		-- Log.d(TAG, "msgType = %s, id = %s, _ = %s, err = %s", 5, id, _, err)
		local s = socket_pool[id]
		if s == nil then
			Log.e(TAG, "socket: error on unknown id = %s, err = %s", id, err)
			return
		end
		if s.connected then
			Log.e(TAG, "socket: error on id = %s, err = %s", id, err)
		elseif s.connecting then
			s.connecting = err
		end
		s.connected = false
		socketdriver.shutdown(id)
		wakeup(s)
	end

	-- SKYNET_SOCKET_TYPE_UDP = 6
	MSG[6] = function(id, size, data, address)
		-- udp , now don't need
		Log.d(TAG, "msgType = %s, id = %s, size = %s, data = %s, address", 6, id, size, data, address)
	end

	-- SKYNET_SOCKET_TYPE_WARNING = 7
	MSG[7] = function(id, size)
		Log.d(TAG, "msgType = %s, id = %s, size = %s", 7, id, size);
		local s = socket_pool[id]
		if s then
			-- local warning = s.warning or default_warning
			-- warning(id, size)
		end
	end

	skynet.register_protocol {
		name = "socket",
		id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
		unpack = socketdriver.unpack,
		dispatch = function (_, _, t, ...)
			Log.d(TAG, "msgType = [%s], socketfd = [%s]", t, tostring(...));
			MSG[t](...)
		end
	}

	skynet.start(function()
		skynet.dispatch("lua", function (_, address, cmd, ...)
			-- Log.d(TAG, 'address = %s, cmd = %s', address, cmd)
			local f = CMD[cmd]
			if f then
				skynet.ret(skynet.pack(f(address, ...)))
			else
				skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
			end
		end)
	end)
end

return BYGateServer
