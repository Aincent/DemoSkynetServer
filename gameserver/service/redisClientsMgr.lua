--[[
example:
	local redisClientsMgr = require("service/redisClientsMgr")
	local rcm = new(redisClientsMgr)
	local bSucc = rcm:addRedisClient("phpJushuRedis",{
		host = "192.168.200.144" ,
		port = 4590 ,
		db = 0
	})
	--log.d(TAG, 'add redisClient '..tostring(bSucc))
	if bSucc then --db:exists "A"
		local out = rcm:exists("phpJushuRedis","ABBBB")
		--log.d(TAG, 'phpJushuRedis redis: exists A:'..tostring(bSucc))
	end 


	--log.d(TAG, 'phpJushuRedis redis: set A:'..tostring(rcm:set("phpJushuRedis","A", "bbbbb")))
	--log.d(TAG, 'phpJushuRedis redis: get A:'..tostring(rcm:get("phpJushuRedis","A")))

	--redisClientsMgr:[command]([name], args,...)
--]]---

local skynet    = require "skynet"
local redisClientsMgr = class()
local TAG = 'redisClientsMgr'

function redisClientsMgr:ctor()
	self.m_map = {}
	setmetatable(redisClientsMgr, { __index = function( t, k )
			local cmd = k 
			local f = function (self, v, ...)
				local name = v 
				local rc   = self.m_map[name]
				if rc then 
					return skynet.call(rc, 'lua', cmd, ...)
				else 
					--log.e(TAG, "[error] not found redisclient's name = ["..name.."] ")
				end 
				return false
			end
			t[k] = f
			return f			
		end})
end 

function redisClientsMgr:dtor()
	for k,v in pairs(self.m_map) do
		self:delRedisClient(k)
	end
end 


function redisClientsMgr:addRedisClient(name, cfg)
	local rc   = skynet.newservice("redisClient")
	local succ = skynet.call(rc, 'lua', 'start', cfg)
	self.m_map[name] = rc
	return succ
end 

function redisClientsMgr:delRedisClient(name)
	local rc = self.m_map[name]
	if not rc then 
		return false
	end 
	local result = skynet.call(rc,'lua','disconnect')
	if result then
		self.m_map[name] = nil 
	end
	return result
end 

return redisClientsMgr
