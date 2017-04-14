local skynet    = require "skynet.manager"
local TAG = 'main'

local function start_gameServer()
	
	-- local t = {}
	-- for i= 0x1, 0x9 do
	-- 	table.insert(t,i)
	-- end
	-- for i= 0x11, 0x19 do
	-- 	table.insert(t,i)
	-- end
	-- for i= 0x21, 0x29 do
	-- 	table.insert(t,i)
	-- end

	-- for i=1,#t do
	-- 	local r,c = getKeyByValue(t[i])
	-- 	Log.e(TAG, "[0x%x]:%d,%d",t[i],r,c)
	-- end
	-- local json = require "cjson"

	-- --json.encode
	-- --json.decode

	-- local testtable = {}
	-- testtable.name = "zain"
	-- testtable.password = '123456'
	-- testtable.sex = 1

	-- local js = json.encode(testtable)
	-- Log.e(TAG, "jsonencode test:"..js)

	-- local de = json.decode(js)
	-- Log.dump(TAG,de,"HAHA")

	-- 业务服务管理类
	local pServiceMgr = skynet.uniqueservice("serviceManager")
	skynet.name(".ServiceManager", pServiceMgr)
	Log.d(TAG, "pServiceMgr = %s", pServiceMgr)
	local pRet = skynet.call(pServiceMgr, "lua", "init")

	-- 整个server的控制层
	local pGameServer = skynet.newservice("gameServerService")
	skynet.name(".GameServer", pGameServer)
	Log.d(TAG, "pGameServer = %s", pGameServer)
	-- 获取等级和端口
	local level = tonumber(skynet.getenv("level"))
	local port = tonumber(skynet.getenv("port"))  -- 也用做serverId
	local pRet = skynet.call(pGameServer, "lua", "init", level, port)

	--
	-- skynet.name("GameServer", gameServer)

	-- 监测HallServer数据端口
	-- local config = require('config/gameconfig')
	-- Log.dump(TAG, config)
	-- for i = 1, #config do
		-- local allocwatchdog = skynet.newservice('gamewatchdog')
		-- skynet.call(allocwatchdog, 'lua', 'start', {
		-- 	port = 8900,
		-- 	nodelay = true,
		-- })
		-- Log.d(TAG, 'listen on port :%d', config[i].port)
	-- end
end

skynet.start(function()
    Log.e(TAG, "GameServer start")
    start_gameServer()
end)
