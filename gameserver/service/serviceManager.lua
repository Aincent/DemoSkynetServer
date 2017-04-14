local skynet = require("skynet")
local queue = require("skynet.queue")

local TAG = "ServiceManager"

local cs = queue()

local ServiceManager = class()

function ServiceManager:init()
	-- agent --> socket
	self.m_pHallAgentToSocketfdMap = {}
	-- socketfd --> agent
	self.m_pSocketfdToHallAgentMap = {}
end

function ServiceManager:onSetHallAgentAndSocket(agent, socketfd)
	Log.d(TAG, "onSetHallAgentAndSocket agent[%s] socketfd[%s]", agent, socketfd)
	-- agent必须要有
	if agent then
		if socketfd then
			self.m_pSocketfdToHallAgentMap[socketfd] = agent
		else
			local pSocketfd = self.m_pHallAgentToSocketfdMap[agent]
			if pSocketfd then
				self.m_pSocketfdToHallAgentMap[pSocketfd] = nil
			end
		end	
		self.m_pHallAgentToSocketfdMap[agent] = socketfd
	end
end

function ServiceManager:onGetSocketfdByHallAgent(agent)
	return agent and self.m_pHallAgentToSocketfdMap[agent] or nil
end

function ServiceManager:onGetHallAgentBySocketfd(socketfd)
	return socketfd and self.m_pSocketfdToHallAgentMap[socketfd] or nil
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, command, ...)
		-- Log.d("ServiceManager", "command[%s]", command)
		local f = ServiceManager[command]
		skynet.ret(skynet.pack(cs(f, ServiceManager, ...)))
	end)
end)