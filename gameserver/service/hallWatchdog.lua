local skynet = require "skynet"
local TAG = 'hallwatchdog'

local CMD = {}
local SOCKET = {}

local clients = {}  --保存fd --> agent的映射

local bygate

function SOCKET.connect(fd, addr)
	Log.d(TAG, "New hallclient from : " .. addr)
	-- 这里启动业务逻辑处理文件,俗称agent
	clients[fd] = skynet.newservice("hallAgent")
	local ret = skynet.call(clients[fd], "lua", "start", {
		fd = fd,
		addr = addr,
		gate = bygate,
		watchdog = skynet.self(),
	})
end

function SOCKET.close(fd)
	Log.d(TAG, "socket close "..fd)
	clients[fd] = nil
end

function SOCKET.error(fd, msg)
	Log.e(TAG, "socket error "..fd.."  "..msg)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	Log.w(TAG, "socket warning "..fd.." "..size)
end

function SOCKET.disconnect(fd)
	Log.d(TAG, 'disconnect = %s', fd)
	if clients[fd] then
		skynet.send(clients[fd], "lua", "disconnect")
		clients[fd] = nil
	end
end

function CMD.start(conf)
	skynet.call(bygate, "lua", "open" , conf)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		-- Log.i(TAG, "cmd : %s subcmd : %s", cmd, subcmd)
		if type(subcmd) == 'table' then
			Log.dump(TAG, subcmd)
		end
		
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	bygate = skynet.newservice("bygate")
end)
