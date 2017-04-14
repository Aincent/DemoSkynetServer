local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")

local TAG = 'FilterClinet'

local FilterClinet = class()

local SOCKET = {}

function SOCKET.connected(socketfd)
	FilterClinet.m_socketfd = socketfd
	Log.d(TAG, "FilterClinet onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if FilterClinet.m_socketfd and socketfd == FilterClinet.m_socketfd then
		FilterClinet.m_socketfd = nil
		-- TODO : 重连机制
	end
end

function FilterClinet:init(conf)
	self.m_socketfd = nil
	self.m_watchdog = nil
	self.m_gate = skynet.newservice("bygate")
	local dataTable = {
		ip = conf.ip,
		port = conf.port,
		watchdog = skynet.self(),
		nodelay = true,
	}
	Log.dump(TAG, dataTable)
	skynet.call(self.m_gate, "lua", "connect", dataTable)
end

function FilterClinet:isConnected()
	return self.m_socketfd and self.m_socketfd > 0
end

function FilterClinet:onSendToBackendServer(cmd, info)
	if not self:isConnected() then
		return -1
	end
	socketManager.send(self.m_socketfd, cmd, info)
end

function FilterClinet:disconnect()
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		Log.i(TAG, "session = %s source = %s cmd : %s subcmd : %s", session, source, cmd, subcmd)
		if cmd == "socket" then
			if SOCKET[subcmd] then
				SOCKET[subcmd](...)
			else
				Log.e(TAG, "unknown subcmd = %s", subcmd)
			end
		else
			if FilterClinet[cmd] then
				FilterClinet[cmd](FilterClinet, subcmd, ...)
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
