local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local socketchannel = require "socketchannel"

local TAG = 'LookBackClient'

local LookBackClient = class();

local SOCKET = {}

function  LookBackClient:isConnected()
	if self.m_pSocketfd and self.m_pSocketfd > 0 then
		return  true
	else
		self:connectToClient()
		return false
	end
end

function LookBackClient:connectToClient()
	-- todo: learnothers
	local dataTable = {
	ip = self.pLookbackConfig.ip,
	port = self.pLookbackConfig.port,
	watchdog = skynet.self(),
	nodelay = true,
	}
	Log.dump(TAG, dataTable)

	skynet.call(self.m_pGate, "lua", "connect", dataTable)
end

function LookBackClient:init(conf)
	self.m_pSocketfd = nil
	self.m_pGate = nil
	
  	self.m_pGate = skynet.newservice("bygate")
	self.pLookbackConfig = conf
	self:connectToClient()
end

function onSendTolookbackServer(cmd,info)
	-- body
	if not self:isConnected() then
		return -1
	end
	socketManager.send(self.m_pSocketfd, cmd, info)
end

function SOCKET.connected(socketfd)
	LookBackClient.socketfd = socketfd
	Log.d(TAG, "LookBackClient onconnected socketfd = %s", socketfd)
end

function SOCKET.disconnect(socketfd)
	Log.d(TAG, "disconnect socketfd = %s", socketfd)
	if LookBackClient.m_pSocketfd and socketfd == LookBackClient.m_pSocketfd then
		LookBackClient.m_pSocketfd = nil
		-- TODO : 重连机制
	end
end

function SOCKET.receiveData(socketfd, cmd, buffer)
	Log.d(TAG, "receiveData socketfd[%s] MoneyClient.m_pSocketfd[%s] cmd[0x%04x]", socketfd, LookBackClient.m_pSocketfd, cmd)
	if socketfd == LookBackClient.m_pSocketfd then
		if LookBackClient.m_waitingCo then
			local data = socketManager.receive(cmd, buffer)
			if LookBackClient.m_waitingCo then
				LookBackClient.m_waitingData = data
				skynet.wakeup(LookBackClient.m_waitingCo)
				LookBackClient.m_waitingCo = nil
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
      if LookBackClient[cmd] then
        skynet.ret(skynet.pack(LookBackClient[cmd](LookBackClient, subcmd, ...)))
      else
        Log.e(TAG, "unknown cmd = %s", cmd)
      end
    end
  end)
end)
