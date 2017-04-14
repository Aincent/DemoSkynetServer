local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local sharedata = require("sharedata")

local TAG = 'AllocClient'

local AllocClient = class()

local SOCKET = {}

function SOCKET.connected(socketfd)
	AllocClient.m_pSocketfd = socketfd
	Log.d(TAG, "AllocClient onconnected socketfd = %s", socketfd)
	-- 发包给allocServer，告知gameserver启动
	AllocClient:registerClient()

	AllocClient:reportServerData()
	AllocClient:reportBattleData()
	-- 上报大厅IP端口
	AllocClient:reportServerIpPort()
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if AllocClient.m_pSocketfd and socketfd == AllocClient.m_pSocketfd then
		AllocClient.m_pSocketfd = nil
	end
end

function SOCKET.receiveData(socketfd, cmd, buffer)
	Log.d(TAG, "receiveData socketfd[%s] cmd[0x%x] AllocClient.m_pSocketfd[%s]", socketfd, cmd, AllocClient.m_pSocketfd)
	if socketfd == AllocClient.m_pSocketfd then
		local pGameServer = skynet.localname(".GameServer")
		if pGameServer then
			local pRet = skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, buffer)
			Log.d(TAG, "pRet[%s]", pRet)
		end
	end
end

function AllocClient:registerClient()
	if not self:isConnected() then 
		return 
	end
	local cmd = socketCmd.REGISTER_ALLOC_CLIENT
	local info = {}
	info.iMJCode = self.m_pGameRoomConfig.iMJCode
	info.iAllocLevel = self.m_pGameRoomConfig.iLevel --当前gameserver的level
	info.iIsGamaServer = 0x02
	info.iAllocServerId = self.m_pGameRoomConfig.iServerId--当前gameserver的serverId
	info.iBaseChips = self.m_pGameRoomConfig.iBasePoint
	info.iOutCardTime = self.m_pGameRoomConfig.iOutCardTime
	info.iDingQue = 0
	info.iSwapCards = 0
	info.iPlayType = self.m_pGameRoomConfig.iPlayType
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function AllocClient:reportServerIpPort()
	if not self:isConnected() then 
		return 
	end
	local cmd = socketCmd.REPORT_SERVER_IP_PORT
	local info = {}
	info.iAllocServerId = self.m_pGameRoomConfig.iServerId--当前gameserver的serverId
	info.iListenPort = self.m_pGameRoomConfig.iListenPort--当前gameserver监听的端口
	info.iListenIp = self.m_pGameRoomConfig.iListenIp--当前gameserve的ip
	info.iIsRetire = 0
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function AllocClient:reportServerData()
	if not self:isConnected() then 
		return 
	end
	local pGameServer = skynet.localname(".GameServer")
	local pRet = skynet.call(pGameServer, "lua", "onReportServerData", self.m_pSocketfd)
end

function AllocClient:reportBattleData()
	if not self:isConnected() then 
		return 
	end
	-- 这里上报是防止有可能和alloc的重连
	local pGameServer = skynet.localname(".GameServer")
	local pRet = skynet.call(pGameServer, "lua", "onReportBattleData", self.m_pSocketfd)
end

function AllocClient:onSendToAllocServer(cmd, info)
	Log.d(TAG, "AllocClient onSendToAllocServer cmd[0x%04x] self.m_pSocketfd[%s]", cmd, self.m_pSocketfd)
	if not self:isConnected() then
		return
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function AllocClient:isConnected()
	if self.m_pSocketfd and self.m_pSocketfd > 0 then
		return true
	else
		self:connectToClient()
		return false
	end
end

function AllocClient:init()
	self.m_pSocketfd = nil
	self.m_pGate = nil

	self.m_pGameRoomConfig = sharedata.query("GameRoomConfig")
	assert(self.m_pGameRoomConfig)
	self.m_pAllocConfig = require("config/gameServerConfig").allocConfig[self.m_pGameRoomConfig.iLevel]

	self.m_pGate = skynet.newservice("bygate")
	self:connectToClient()
end

function AllocClient:connectToClient()
	local dataTable = {
		ip = self.m_pAllocConfig.ip,
		port = self.m_pAllocConfig.port,
		watchdog = skynet.self(),
		nodelay = true,
	}
	Log.dump(TAG, dataTable)
	skynet.call(self.m_pGate, "lua", "connect", dataTable)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		-- Log.i(TAG, "session = %s source = %s cmd : %s subcmd : %s", session, source, cmd, subcmd)
		if cmd == "socket" then
			if SOCKET[subcmd] then
				SOCKET[subcmd](...)
			else
				Log.e(TAG, "unknown subcmd = %s", subcmd)
			end
		else
			if AllocClient[cmd] then
				AllocClient[cmd](AllocClient, subcmd, ...)
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
