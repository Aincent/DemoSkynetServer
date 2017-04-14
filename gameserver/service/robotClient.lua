local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")

local TAG = 'RobotClient'

local RobotClient = class()

local SOCKET = {}

function SOCKET.connected(socketfd)
	RobotClient.m_socketfd = socketfd
	Log.d(TAG, "RobotClient onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if RobotClient.m_socketfd and socketfd == RobotClient.m_socketfd then
		RobotClient.m_socketfd = nil
		-- TODO : 重连机制
	end
end

function RobotClient:init(conf)
	self.m_socketfd = nil
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

function RobotClient:isConnected()
	return self.m_socketfd and self.m_socketfd > 0
end

function RobotClient:onSendToRobotServer(cmd, info)
	if not self:isConnected() then
		Log.e(TAG, "onSendToRobotServer failed --> socket is disconnect")
		return -1
	end
	socketManager.send(self.m_socketfd, cmd, info)
end

function RobotClient:disconnect()
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			if SOCKET[subcmd] then
				SOCKET[subcmd](...)
			else
				Log.e(TAG, "unknown subcmd = %s", subcmd)
			end
		else
			if RobotClient[cmd] then
				RobotClient[cmd](RobotClient, subcmd, ...)
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
