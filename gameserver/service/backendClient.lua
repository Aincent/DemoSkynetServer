local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")

local TAG = 'BackendClient'

local BackendClient = class()

local SOCKET = {}

function SOCKET.connected(socketfd)
	BackendClient.m_pSocketfd = socketfd
	Log.d(TAG, "BackendClient onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if BackendClient.m_pSocketfd and socketfd == BackendClient.m_pSocketfd then
		BackendClient.m_pSocketfd = nil
		-- TODO : 重连机制
	end
end

function BackendClient:init(conf)
	self.m_pSocketfd = nil
	self.MatchState = nil
	self.m_pBackendConfig = conf
	self.m_pGate = skynet.newservice("bygate")
	self:connectToClient()
end

function BackendClient:connectToClient()
	local dataTable = {
		ip = self.m_pBackendConfig.ip,
		port = self.m_pBackendConfig.port,
		watchdog = skynet.self(),
		nodelay = true,
	}
	Log.dump(TAG, dataTable)
	skynet.call(self.m_pGate, "lua", "connect", dataTable)
end

function BackendClient:isConnected()
	if self.m_pSocketfd and self.m_pSocketfd > 0 then
		return true
	else
		self:connectToClient()
		return false
	end
end

function BackendClient:onSendToBackendServer(cmd, info)
	if not self:isConnected() then
		return -1
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function BackendClient:disconnect()
	skynet.exit()
end

function BackendClient:onProcUserRank(data, socketfd)
--	local cmd = socketCmd.CORESERVER_COMMAND_USER_WIN
--	local pGameServer = skynet.localname(".GameServer")
--	skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, data, true)
end



function BackendClient:onProcGameInfo(data, socketfd)
	local cmd = socketCmd.CORESERVER_GAME_INFO
	local pGameServer = skynet.localname(".GameServer")
	skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, data, true)
end

function BackendClient:onProcGameState(data, socketfd)
	if 0 == data.state then
		self.MatchState = false
	else
		self.MatchState = true
	end
end

function BackendClient:onProcUserKey(data, socketfd)
	local cmd = socketCmd.CORESERVER_USER_KEY
	local pGameServer = skynet.localname(".GameServer")
	skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, data, true)
end

function BackendClient:onProcSendUserTask(data, socketfd)
	local cmd = socketCmd.CORESERVER_USER_COMP_TASK
	local pGameServer = skynet.localname(".GameServer")
	skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, data, true)
end

-- decypt解密
function BackendClient:receiveData(socketfd, cmd, buffer, decypt)
	if cmd and self.s_cmdFuncMap[cmd] then
		Log.d(TAG, "BackendClient:receiveData socketfd=[%d], cmd=[0x%x]", socketfd, cmd)
		local data = socketManager.receive(cmd, buffer, decypt)
		return cs(self.s_cmdFuncMap[cmd], BackendClient, data, socketfd)
	end
end


BackendClient.s_cmdFuncMap = {
	-- GameServer
--	[socketCmd.CORESERVER_COMMAND_USER_WIN] = BackendClient.onProcUserRank,
--	[socketCmd.CORESERVER_GAME_INFO] = BackendClient.onProcGameInfo,
--	[socketCmd.CORESERVER_MATCH_STATE] = BackendClient.onProcGameState,
--	[socketCmd.CORESERVER_USER_KEY] = BackendClient.onProcUserKey,
--	[socketCmd.CORESERVER_USER_COMP_TASK] = BackendClient.onProcSendUserTask,
}


skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			if SOCKET[subcmd] then
				SOCKET[subcmd](...)
			else
				Log.e(TAG, "unknown subcmd = %s", subcmd)
			end
		else
			if BackendClient[cmd] then
				BackendClient[cmd](BackendClient, subcmd, ...)
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
