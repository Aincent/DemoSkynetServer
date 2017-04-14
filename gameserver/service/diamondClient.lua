local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local socketchannel = require "socketchannel"

local TAG = 'DiamondClient'

local DiamondClient = class()

function DiamondClient:isConnected()
	if self.m_pSocketfd and self.m_pSocketfd > 0 then
		return true
	else
		self:connectToClient()
		return false
	end
end

function DiamondClient:init(conf)
	Log.d(TAG, "DiamondClient init")
	-- 数据初始化
	self.m_pSocketfd = nil
	self.m_pDiamondConfig = conf

	self.m_pGate = skynet.newservice("bygate")
	self:connectToClient()
end

function DiamondClient:connectToClient()
	local dataTable = {
		ip = self.m_pDiamondConfig.ip,
		port = self.m_pDiamondConfig.port,
		watchdog = skynet.self(),
		nodelay = true,
	}
	Log.dump(TAG, dataTable)
	skynet.call(self.m_pGate, "lua", "connect", dataTable)
end

function DiamondClient:onGetUserDiamond(userIdTable)
	if not userIdTable or #userIdTable <= 0 then
		Log.e(TAG, "DiamondClient onGetUserDiamond userIdTable is nil")
		return -1
	end
	if not self:isConnected() then
		Log.e(TAG, "DiamondClient isConnected false")
		return -1
	end
	local cmd = socketCmd.DAOJU_SERVER_MAIN_CMD
	local info = {}
	info.iSwitchCmd = socketCmd.SERVER_GET_DIAM_NUM
	info.iUserCount = #userIdTable
	info.iUserIdTable = {}
	for k, v in pairs(userIdTable) do
		info.iUserIdTable[k] = v
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
	if self.m_waitingCo then
		skynet.wakeup(self.m_waitingCo)
		self.m_waitingCo = nil
	end
	self.m_waitingCo = coroutine.running()
	skynet.wait(self.m_waitingCo)
	Log.d(TAG, "skynet wakeup")
	local data = {}
	if self.m_waitingData and self.m_waitingData.iUserTable then
		-- Log.dump(TAG, self.m_waitingData, "self.m_waitingData")
		for p, q in pairs(self.m_waitingData.iUserTable) do
			for k, v in pairs(userIdTable) do
				if v == q.iUserId then
					data[v] = q.iDiamond
				end
			end
		end
		self.m_waitingData = nil
		-- Log.dump(TAG, data , "data")
		return data
	end
	self.m_waitingData = nil
	return -1
end

function DiamondClient:onUpdateUserDiamond(cmd, info)
	if not info or not cmd then
		Log.e(TAG, "onUpdateUserDiamond data error")
		return -1
	end
	if not self:isConnected() then
		Log.e(TAG, "DiamondClient isConnected false")
		return -1
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
	return 0
end

function DiamondClient:disconnect()
	-- skynet.exit()
end


local SOCKET = {}

function SOCKET.connected(socketfd)
	DiamondClient.m_pSocketfd = socketfd
	Log.d(TAG, "DiamondClient onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if DiamondClient.m_pSocketfd and socketfd == DiamondClient.m_pSocketfd then
		DiamondClient.m_pSocketfd = nil
		-- TODO : 重连机制
	end
end

function SOCKET.receiveData(socketfd, cmd, buffer)
	Log.d(TAG, "receiveData socketfd[%s] cmd[0x%x]", socketfd, cmd)
	if socketfd == DiamondClient.m_pSocketfd then
		local data = socketManager.receive(cmd, buffer)
		if DiamondClient.m_waitingCo then
			DiamondClient.m_waitingData = data
			skynet.wakeup(DiamondClient.m_waitingCo)
			DiamondClient.m_waitingCo = nil
		else
			Log.e(TAG, "receiveData socketfd[%s] cmd[0x%x] not deal", socketfd, cmd)
		end
	end
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
			if DiamondClient[cmd] then
				skynet.ret(skynet.pack(DiamondClient[cmd](DiamondClient, subcmd, ...)))
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
