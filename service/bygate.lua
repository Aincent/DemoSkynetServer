local skynet = require "skynet"
local gateserver = require "bygateserver"

local TAG = 'BYGATE'

local watchdog
--local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
--local forwarding = {}   -- hallagent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local SOCKET = {}

local localInfo = {
	isclient = false,
	watchdog = nil,
	connection = {},
    forwarding = {},---- hallagent -> connection
}

function SOCKET.open(source, conf, isclient)
	-- Log.dump(TAG, conf)
	-- Log.d(TAG, 'source = %s', source)
	localInfo.watchdog = conf.watchdog or source
	localInfo.isclient = isclient
end

--接受到网络数据
function SOCKET.message(fd, cmd, buffer)
	-- Log.d(TAG, "message fd = %s, cmd = 0x%x", fd, cmd)
	local client = localInfo.connection[fd]
	assert(client)
	-- Log.dump(TAG, client)
	if client.agent then
		skynet.send(client.agent, 'lua','receiveData', fd, cmd, buffer)
	else
		skynet.send(localInfo.watchdog, "lua", "socket", "receiveData", fd, cmd, buffer)
	end
end

function SOCKET.connect(fd, addr)
	-- Log.d(TAG, 'fd = %s, addr = %s', fd, addr)
	local client = {
		fd = fd,
		ip = addr,
	}
	localInfo.connection[fd] = client
	skynet.call(localInfo.watchdog, "lua", "socket", "connect", fd, addr)
end

function SOCKET.connected(fd, addr)
	-- Log.d(TAG, 'fd = %s, addr = %s', fd, addr) 
	if not localInfo.isclient then return end
	local client = {
		fd = fd,
		ip = addr,
	}
	localInfo.connection[fd] = client
	-- Log.d(TAG, "localInfo.watchdog = %s", localInfo.watchdog)
	skynet.call(localInfo.watchdog, "lua", "socket", "connected", fd, addr)
end

local function close_fd(fd)
	Log.d(TAG, "close_fd localInfo.connection[%s] is %s", fd, localInfo.connection[fd] and true or false)
	if localInfo.connection[fd] then
		localInfo.connection[fd] = nil
		gateserver.close(fd)
	end
end

function SOCKET.disconnect(fd)
	Log.d(TAG, 'disconnect = %s', fd)
	close_fd(fd)
	skynet.send(localInfo.watchdog, "lua", "socket", "disconnect", fd)
end

function SOCKET.error(fd, msg)
	-- Log.d(TAG, 'error = %s, msg = %s', fd, msg)
	close_fd(fd)
	skynet.send(localInfo.watchdog, "lua", "socket", "error", fd, msg)
end

function SOCKET.warning(fd, size)
	Log.d(TAG, 'warning = %s, size = %s', fd, size)
	skynet.send(localInfo.watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

function CMD.closeclient(source, fd)
	Log.d(TAG, "closeclient fd = %s", fd)
	close_fd(fd)
end

function CMD.forward(source, fd, client, address)
	-- Log.d(TAG, "forward source = %s, fd = %s, client = %s, address = %s", source, fd, client, address)
	local client = localInfo.connection[fd]
	if client then
		-- Log.dump(TAG, client)
		client.agent = source
		gateserver.openclient(fd)
	end
end

function SOCKET.command(cmd, source, ...)
	-- Log.d(TAG, 'cmd = %s, source = %s', cmd, source)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(SOCKET)
