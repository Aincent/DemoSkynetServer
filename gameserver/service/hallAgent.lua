local skynet = require "skynet"
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local queue = require("skynet.queue")

local cs = queue()

local TAG = "HallAgent"

HallAgent = class()

function HallAgent:start(conf)
	self.m_pUserId = nil
	self.m_gamebale = nil
	Log.dump(TAG, conf)
	local fd   = conf.fd
	self.m_gate = conf.gate
	self.m_watchdog  = conf.watchdog
	self.m_socketfd = fd
	-- 链接成功，上报给serviceManager
	local pServiceMgr = skynet.localname(".ServiceManager")
	local pRet = skynet.call(pServiceMgr, "lua", "onSetHallAgentAndSocket", skynet.self(), self.m_socketfd)
	-- 通知gate  来自fd链接的网络消息直接转发  不再走watchdog
	local pRet = skynet.call(self.m_gate, "lua", "forward", self.m_socketfd)
end

function HallAgent:receiveData(socketfd, cmd, buffer)
	Log.d(TAG,'recv socket data socketfd[%s] cmd[0x%x]', socketfd, cmd)
	
	local pGameServer = skynet.localname(".GameServer")
	cs(function() 
		local pRet = 0
		if self.m_pGameTable and self.m_pUserId then
			pRet = skynet.call(self.m_pGameTable, "lua", "onReceiveData", socketfd, self.m_pUserId, cmd, buffer, true)
		else
			pRet = skynet.call(pGameServer, "lua", "receiveData", socketfd, cmd, buffer, true)
		end
		Log.d(TAG, "pRet[%s]", pRet)
	end)
end 

function HallAgent:disconnect()
	cs(function()
		self.m_socketfd = nil
		Log.d(TAG, "HallAgent is disconnect")
		-- todo: do something before exit
		-- 首先从serviceManager中清除
		local pServiceMgr = skynet.localname(".ServiceManager")
		local pRet = skynet.call(pServiceMgr, "lua", "onSetHallAgentAndSocket", skynet.self())
		-- 告诉gameTable, 老子掉线了
		if self.m_pGameTable and self.m_pUserId then
			Log.d(TAG, "disconnect userId[%s] gameTable[%s]", self.m_pUserId, self.m_pGameTable)
			local pRet = skynet.call(self.m_pGameTable, "lua", "onDisconnect", self.m_pUserId)
		end
		skynet.exit()
	end)
end

function HallAgent:onSetUserdAndGameTable(userId, gameTable)
	Log.d(TAG, "onSetUserdAndGameTable userId[%s] gameTable[%s]", userId, gameTable)
	if userId and gameTable then
		self.m_pUserId = userId
		self.m_pGameTable = gameTable
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, command, ...)
		local f = HallAgent[command]
		-- skynet.ret(skynet.pack(f(...)))
		f(HallAgent, ...)
	end)
end)
