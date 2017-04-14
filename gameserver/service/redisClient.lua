local skynet = require "skynet"
local redis = require "redis"
local TAG = 'RedisClient'

local RedisClient = {}

RedisClient.db = nil

local Handle = {}
function Handle.start( cfg )
	RedisClient.db = redis.connect(cfg)
	return true
end 

function Handle.disconnect()
	RedisClient.db:disconnect()
	RedisClient.db = nil 
	return true
end 

local function handleCMDs(cmd,subcmd, ...)
	--log.i(TAG, "handleCMDs cmd : %s subcmd : %s", cmd, subcmd)
	return RedisClient.db[cmd](RedisClient.db, subcmd, ...)
end

skynet.start(function(cfg)
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		--log.i(TAG, "cmd : %s subcmd : %s", cmd, subcmd)
		if Handle[cmd] then 
			skynet.ret(skynet.pack(Handle[cmd](subcmd, ...)))
		else 
			skynet.ret(skynet.pack(handleCMDs(cmd,subcmd, ...))) 
		end 

	end)
end)
