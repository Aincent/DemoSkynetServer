local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")

local TAG = 'MoneyClient'

local MoneyClient = class()

local SOCKET = {}

function MoneyClient:isConnected()
	if self.m_pSocketfd and self.m_pSocketfd > 0 then
		return true
	else
		self:connectToClient()
		return false
	end
end

function MoneyClient:init(conf)
	self.m_pSocketfd = nil
	self.m_pGate = nil

	self.m_pGate = skynet.newservice("bygate")
	self.m_pMoneyConfig = conf
	self:connectToClient()
end

function MoneyClient:connectToClient()
	local dataTable = {
		ip = self.m_pMoneyConfig.ip,
		port = self.m_pMoneyConfig.port,
		watchdog = skynet.self(),
		nodelay = true,
	}
	Log.dump(TAG, dataTable)
	skynet.call(self.m_pGate, "lua", "connect", dataTable)
end

function MoneyClient:onGetUserInfo(userId)
	if not userId or userId <= 0 then
		return nil
	end
	if not self:isConnected() then
		return nil
	end
	local cmd = socketCmd.CLIENT_CMD_GET_RECORD
	local info = {}
	info.iUserId = userId
	socketManager.send(self.m_pSocketfd, cmd, info)
	self.m_waitingCo = coroutine.running()
	skynet.wait(self.m_waitingCo)
	Log.d(TAG, "skynet wakeup")
	return self.m_waitingData
end

function MoneyClient:onSendToMoneyServer(cmd, info)
	if not self:isConnected() then
		return nil
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function MoneyClient:disconnect()
	-- skynet.exit()
end

function SOCKET.connected(socketfd)
	MoneyClient.m_pSocketfd = socketfd
	Log.d(TAG, "MoneyClient onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if MoneyClient.m_pSocketfd and socketfd == MoneyClient.m_pSocketfd then
		MoneyClient.m_pSocketfd = nil
		-- TODO : 重连机制
	end
end

function SOCKET.receiveData(socketfd, cmd, buffer)
	Log.d(TAG, "receiveData socketfd[%s] MoneyClient.m_pSocketfd[%s] cmd[0x%04x]", socketfd, MoneyClient.m_pSocketfd, cmd)
	if socketfd == MoneyClient.m_pSocketfd then
		if MoneyClient.m_waitingCo then
			local data = socketManager.receive(cmd, buffer)
			if MoneyClient.m_waitingCo then
				MoneyClient.m_waitingData = data
				skynet.wakeup(MoneyClient.m_waitingCo)
				MoneyClient.m_waitingCo = nil
			end
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
			if MoneyClient[cmd] then
				skynet.ret(skynet.pack(MoneyClient[cmd](MoneyClient, subcmd, ...)))
			else
				Log.e(TAG, "unknown cmd = %s", cmd)
			end
		end
	end)
end)
