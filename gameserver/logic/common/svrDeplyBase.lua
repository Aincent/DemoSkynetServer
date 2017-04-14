
local TAG = 'svrDeplyBase'
local skynet = require "skynet"
local sharedata = require("sharedata")
local json = require "cjson"

local SvrDeplyBase = class()

SvrDeplyBase.RET_REDIS_NULLPTR      = 0 --没有配置Redis
SvrDeplyBase.RET_REDIS_SUCCESS      = 1 --从缓存中读取成功
SvrDeplyBase.RET_REDIS_ACCESS_MYSQL = 2 --这批进程中是本进程从mysql并同步数据
SvrDeplyBase.RET_REDIS_WAIT_SYN     = 3 --等待另一个进程同步数据中

SvrDeplyBase.RET_CHECKNEWCONFIG_NORMAL   = 0x1--正常
SvrDeplyBase.RET_CHECKNEWCONFIG_WAIT_SYN = 0x2--等待同步
SvrDeplyBase.RET_CHECKNEWCONFIG_MASTER   = 0x4--我是master


local DEF_DEPLY_TIMER = 0x10001
local DEPREDIS_SYN_SUCCESS_FLAG = 1000000
local DEPREDIS_KEY_ACCESS_FLAG_EXPIRE = 15

local function tableHasElement(t)
	for k,v in pairs(t) do
		return true 
	end
	return false
end 


function SvrDeplyBase:initConfigList()
	for k,v in pairs(self.m_pKeyFuncMap) do
		local argst = {}
		if self:getDeplyConfig(k, argst) then 
			self:onConfigUpdate(k, argst.json)
		end 
	end 
	return true 
end 

function SvrDeplyBase:onConfigUpdate(key,  jsonContent)
	Log.d(TAG, "onConfigUpdate key[%s]", key)
	local data = json.decode(jsonContent)
	if data then 
		local funcName = self.m_pKeyFuncMap[key]
		Log.d(TAG, "onConfigUpdate funcName[%s]", funcName)
		local func     = self[funcName]
		if func then 
			func(self, data)
		end 
		return true 
	end 
	return false
end 

function SvrDeplyBase:onRoomListConfigUpdate(cfg)
	local pUpdateConfig = {}
	for k, v in pairs(cfg) do
		local pLevel = tonumber(k)
		if pLevel == self.m_pGameServer.m_level then
			local pMJCode = tonumber(v.gametype) or 0
			if pMJCode == self.m_pGameRoomConfig.iMJCode then
				pUpdateConfig.iLocalGameType = tonumber(v.type)
				pUpdateConfig.iTableName = tostring(v.name)
				pUpdateConfig.iExtendInfo = {
					iHorse = tonumber(v.horse) or 0,
					iGuiPai = tonumber(v.ext) or 0
				}
				pUpdateConfig.iServerFee = tonumber(v.fee)
				pUpdateConfig.iBasePoint = tonumber(v.value)
				pUpdateConfig.iLevelNeedMoney = tonumber(v.require)
				pUpdateConfig.iLevelMinHoldMoney = tonumber(v.xzrequire)
				pUpdateConfig.iLevelMaxHoldMoney = tonumber(v.uppermost)
				pUpdateConfig.iOutCardTime = tonumber(v.time)
				pUpdateConfig.iOperationTime = tonumber(v.cztime)
				local pPlayTypes = 0
				for p, q in pairs(v.playtype) do
					local pPlayType = tonumber(p) or 0
					local pValue = tonumber(q) or 0
					if 1 == pValue then
						pPlayTypes = pPlayTypes | pPlayType
					end
				end
				pUpdateConfig.iPlayType = pPlayTypes
				table.merge(self.m_pGameRoomConfig, pUpdateConfig)
				sharedata.update("GameRoomConfig", self.m_pGameRoomConfig)
				Log.dump(TAG, self.m_pGameRoomConfig, "self.m_pGameRoomConfig")
			end
		end
	end
end

function SvrDeplyBase:onFriendBattleConfigUpdate(cfg)
	Log.d(TAG, "SvrDeplyBase onFriendBattleConfigUpdate")
	local pLevel = tonumber(cfg.level) or 0
	if self.m_pGameServer.m_level ~= pLevel then
		Log.e(TAG, "onFriendBattleConfigUpdate failed, m_level[%s], cfg.level[%s]", self.m_pGameServer.m_level, cfg.level)
		return -1
	end
	Log.dump(TAG, cfg, "cfg")
	local pUpdateConfig = {}
	for k, v in pairs(self.m_pPlaytypeConfig.LocalGameTypeMap) do
		for p, q in pairs(cfg.list) do
			if tonumber(p) == tonumber(v) then
				local pTemp = {}
				local pDiamonds = {}
				local pPlayTypes = 0
				for num, diamod in pairs(q.boyaacoins or {}) do
					pDiamonds[tonumber(num)] = tonumber(diamod)
				end
				for playType, value in pairs(q.playtype or {}) do
					if tonumber(value) == 1 then
						pPlayTypes = pPlayTypes | playType
					end
				end
				pTemp.iDiamondTable = pDiamonds
				pTemp.iPlayType = pPlayTypes
				pUpdateConfig[#pUpdateConfig + 1] = pTemp
			end
		end
	end
	Log.dump(TAG, pUpdateConfig, "pUpdateConfig")
	sharedata.update("FriendBattleConfig", pUpdateConfig)
end

function SvrDeplyBase:ctor(pGameServer)
	self.m_pGameServer = pGameServer
	self.m_redisKey    = nil 

	self.m_keyUpdateList = {}

	self.m_scheuleHandle = nil 
	self.m_bError = false
end 

function SvrDeplyBase:dtor()
	self.m_pGameServer = nil 
	self.m_redisKey    = nil
end 

function SvrDeplyBase:getSchedulerMgr()
	return self.m_pGameServer and self.m_pGameServer.m_scheduleMgr 
end 

function SvrDeplyBase:getRedisMgr()
	return self.m_pGameServer and self.m_pGameServer.m_redisClientsManager
end 

function SvrDeplyBase:init(config)
	--init db
	self.m_dbClient = skynet.newservice("dbClient")
	local pRet = skynet.call(self.m_dbClient, "lua", "init")
	if pRet < 0 then
		assert("m_dbClient init failed")
		return 
	end

	--init redis
	if config.deplyConfig.DEP_REDIS_OPEN == 1 then 
		self.m_redisKey = "deplyRedis"
		local rcm = self:getRedisMgr()
		rcm:addRedisClient(self.m_redisKey, {
			host = config.deplyConfig.DEP_REDIS_IP,
			port = config.deplyConfig.DEP_REDIS_PORT,
			db = 0,
		})
	end 

	self.m_checkExpire = config.deplyConfig.CHECK_TIME_EXPIRE
	self.m_dbname      = config.dbConfig.DB

	self.m_pPlaytypeConfig = sharedata.query("PlaytypeConfig")
	self.m_pGameRoomConfig = sharedata.query("GameRoomConfig")
	self.m_pPrefixName = "deply_access_count_"..self.m_dbname.."_"

	self.m_pKeyFuncMap = {
		[self.m_pGameRoomConfig.iMJCode.."|roomlist|config"] 		= "onRoomListConfigUpdate",
		-- [self.m_pGameRoomConfig.iMJCode.."|exp|config"] 			= "onExpConfigUpdate",
		-- [self.m_pGameRoomConfig.iMJCode.."|trustlevel|config"] 	= "onTrustLevelConfigUpdate",
		[self.m_pGameRoomConfig.iMJCode.."|friendbattle|config"] 	= "onFriendBattleConfigUpdate",
	}

	local ret = self:initConfigList()
	-- Log.d(TAG,"=====")
	-- Log.dump(TAG,self.m_keyUpdateList)
	if ret and tableHasElement(self.m_keyUpdateList) then 
		if self.m_scheuleHandle then 
			self:getSchedulerMgr():unregister(self.m_scheuleHandle)
			self.m_scheuleHandle = nil 
		end 
		self.m_scheuleHandle = self:getSchedulerMgr():registerOnceNow(SvrDeplyBase.processOnTimerOut, self:clacExpire()*1000, self)
	end 
end 

function SvrDeplyBase:checkNow()
	if self.m_scheuleHandle then 
		self:getSchedulerMgr():unregister(self.m_scheuleHandle)
		self.m_scheuleHandle = nil 
	end 

	self.m_scheuleHandle = self:getSchedulerMgr():registerOnceNow(SvrDeplyBase.processOnTimerOut, 100, self)
end 

function SvrDeplyBase:processOnTimerOut(timeId)
	-- Log.d(TAG,"processOnTimerOut....")
	local ret = self.RET_CHECKNEWCONFIG_NORMAL
	ret = self:checkNewConfig()

	-- Log.d(TAG, '1checkNewConfig ret:'..ret)
	local intr = self:clacExpire()*1000
	if (self.RET_CHECKNEWCONFIG_MASTER & ret) ~= self.RET_CHECKNEWCONFIG_MASTER then
		intr = intr + 200
	end
	-- Log.d(TAG, '2processOnTimerOut:int='..intr)
	if (self.RET_CHECKNEWCONFIG_WAIT_SYN & ret) ~= 0 then 
		intr = 1000
		if self.m_bError then 
			intr = 60000
		end 
	end 
	-- Log.d(TAG, '3processOnTimerOut:int='..intr)
	if self.m_scheuleHandle then 
		self:getSchedulerMgr():unregister(self.m_scheuleHandle)
		self.m_scheuleHandle = nil 
	end 

	self.m_scheuleHandle = self:getSchedulerMgr():registerOnceNow(SvrDeplyBase.processOnTimerOut, intr, self)
end 
function SvrDeplyBase:clacExpire()
	local current = os.time()-- s
	intr = self.m_checkExpire - current%self.m_checkExpire
	return intr + 1000
end 


function SvrDeplyBase:checkNewConfig()
	Log.d(TAG,"checkNewConfig")
	local wait_data_syn = self.RET_CHECKNEWCONFIG_NORMAL
	for k,v in pairs(self.m_keyUpdateList) do
		local over = false
		local argst = {}-- json,cur
		local ret_redis = self:proceRedis(k, v, argst)
		--log.d(TAG, 'proceRedis:ret_redis'..ret_redis)
		-- Log.d(TAG,"proceRedis ret_redis=[%d]",ret_redis)
		if ret_redis == self.RET_REDIS_WAIT_SYN then 
			wait_data_syn = wait_data_syn | self.RET_CHECKNEWCONFIG_WAIT_SYN
			over = true 
		elseif ret_redis == self.RET_REDIS_SUCCESS then 
			if argst.cur ~= v then 
				local ret = self:onConfigUpdate(k, argst.json)
				self.m_keyUpdateList[k] = argst.cur
			end 
			over = true 
		end 

		if not over then 
			wait_data_syn = wait_data_syn | self.RET_CHECKNEWCONFIG_MASTER
			if self:onMysqlGetKeyConfig(k, argst) then 
				-- Log.d(TAG,"onMysqlGetKeyConfig k=[%s]",k)
				-- Log.dump(TAG,argst)

				self:redisSetKeyConfig(k,argst)
				-- Log.d(TAG,"argst.cur=[%s], v=[%s]",argst.cur,v)
				if argst.cur ~= v then 
					local ret = self:onConfigUpdate(k, argst.json)
					self.m_keyUpdateList[k] = argst.cur
				end 
			end 
		end 
	end
	return wait_data_syn
end 


function SvrDeplyBase:proceRedis(key, last_cur, argst)--str_cur, cur
	Log.d(TAG, "proceRedis")
	-- Log.dump(TAG,self.m_keyUpdateList)
	--log.d(TAG, 'proceRedis:self.m_redisKey:'..tostring(self.m_redisKey)..",self:getRedisMgr():"..tostring(self:getRedisMgr()))
	if not self.m_redisKey or not self:getRedisMgr() then 
		return self.RET_REDIS_NULLPTR
	end 

	--local syn_success_flag = 0 
	local ret,syn_success_flag = self:redisCanIAccessMysql(key, last_cur) 
	if ret then
		return self.RET_REDIS_ACCESS_MYSQL
	end

	-- Log.d(TAG, "&&&&&&&&&&&&&&&&&&&&&&")
	-- Log.d(TAG, "ret = [%s],type(ret) = [%s]", syn_success_flag, type(syn_success_flag))
	-- Log.d(TAG, "ret = [%s],type(ret) = [%s]", DEPREDIS_SYN_SUCCESS_FLAG, type(DEPREDIS_SYN_SUCCESS_FLAG))
	if syn_success_flag < DEPREDIS_SYN_SUCCESS_FLAG then 
		return self.RET_REDIS_WAIT_SYN
	end 

	if not self:redisGetKeyConfig(key, argst) then 

		local name = self.m_pPrefixName..key
		-- Log.d(TAG, "proceRedis Del rediskey=[%s], name=[%s]", self.m_redisKey, name)
		-- Log.d(TAG, "proceRedis Incr rediskey=[%s], name=[%s]", self.m_redisKey, name)
		-- Log.d(TAG, "proceRedis Expire rediskey=[%s], name=[%s]", self.m_redisKey, name)
		self.m_pGameServer:onExcuteRedisCmd("Del", self.m_redisKey, name)
		self.m_pGameServer:onExcuteRedisCmd("Incr", self.m_redisKey, name)
		self.m_pGameServer:onExcuteRedisCmd("Expire", self.m_redisKey, name, DEPREDIS_KEY_ACCESS_FLAG_EXPIRE)
		return self.RET_REDIS_ACCESS_MYSQL
	end 

	return self.RET_REDIS_SUCCESS
end 



function SvrDeplyBase:getDeplyConfig(key, argst)
	--log.d(TAG, "getDeplyConfig:"..key)
	if not self.m_keyUpdateList[key] then 
		self.m_keyUpdateList[key] = 0
	end 
	if not self:onMysqlGetKeyConfig(key, argst) then 
		return false 
	end 

	self.m_keyUpdateList[key] = argst.cur 
	return true
end 






function SvrDeplyBase:getVersionByKey(key)
	for k,v in pairs(self.m_keyUpdateList) do
		if k == key then 
			return v
		end 
	end
	return 0
end 




--private
function SvrDeplyBase:redisCanIAccessMysql(key, last_cur)
	if not self.m_redisKey or not self:getRedisMgr() then 
		return false,0 
	end 

	local deply_access_count = 0
	local name = self.m_pPrefixName..key
	-- Log.d(TAG, "redisCanIAccessMysql Incr rediskey=[%s], name=[%s]", self.m_redisKey, name)
	deply_access_count = self.m_pGameServer:onExcuteRedisCmd("Incr", self.m_redisKey, name)
	if deply_access_count == nil or deply_access_count == 0 then
		self.m_bError = true 
		Log.e(TAG,"11111deply_access_count = [%d]",deply_access_count)
		return false,0
	end

	self.m_bError = false 
	--flag = 
	if deply_access_count > 1 then
		Log.e(TAG,"222deply_access_count = [%d]",deply_access_count)
		return false,deply_access_count
	end
	-- Log.d(TAG, "redisCanIAccessMysql Expire rediskey=[%s], name=[%s], v = [%d]", self.m_redisKey, name,DEPREDIS_KEY_ACCESS_FLAG_EXPIRE)
	self.m_pGameServer:onExcuteRedisCmd("Expire", self.m_redisKey, name, DEPREDIS_KEY_ACCESS_FLAG_EXPIRE)
	return true,deply_access_count
end 

function SvrDeplyBase:redisGetKeyConfig(key, argst)
	if not self.m_redisKey or not self:getRedisMgr() then 
		return false 
	end 

	--local mconfig = {}
	local mconfig = self.m_pGameServer:onExcuteRedisCmd("HGetAll", self.m_redisKey, "deply_config_"..self.m_dbname.."_"..key)
	if not mconfig or #mconfig  <= 0 then
		return false 
	end

	local jsonstr = nil 
	local time    = nil 
	for i=1,#mconfig,2 do
		if mconfig[i] == "v" then 
			jsonstr = mconfig[i+1]
		end 

		if mconfig[i] == "time" then 
			time = mconfig[i+1]
		end 
	end

	if not jsonstr or not not time then 
		return false 
	end 

	argst.json = jsonstr
	argst.cur  = tonumber(time)
	return true 
end 

function SvrDeplyBase:redisSetKeyConfig(key, argst)
	if not self.m_redisKey or not self:getRedisMgr() then 
		return false 
	end 
	local name = "deply_config_"..self.m_dbname.."_"..key
	-- Log.d(TAG, "redisSetKeyConfig HMSet rediskey=[%s], name=[%s] v=[%s], time=[%d]", self.m_redisKey, name, argst.json,argst.cur)
	local ret = self.m_pGameServer:onExcuteRedisCmd("HMSet", self.m_redisKey, name, "v", argst.json, "time", argst.cur)
	if not ret or ret ~= "OK" then 
		return false 
	end 

	return self:redisSetSynSuccess(key)
end 

function SvrDeplyBase:redisSetSynSuccess(key)
	if not self.m_redisKey or not self:getRedisMgr() then 
		return false 
	end 
	local name = self.m_pPrefixName..key
	-- Log.d(TAG, "redisSetSynSuccess IncrBy rediskey=[%s], name=[%s] v=[%d]", self.m_redisKey, name, DEPREDIS_SYN_SUCCESS_FLAG)
	local deply_access_count = self.m_pGameServer:onExcuteRedisCmd("IncrBy", self.m_redisKey, name, DEPREDIS_SYN_SUCCESS_FLAG)
	-- Log.d(TAG, "redisSetSynSuccess Expire rediskey=[%s], name=[%s] v=[%d]", self.m_redisKey, name, self.m_checkExpire*10)
	self.m_pGameServer:onExcuteRedisCmd("Expire", self.m_redisKey, name, self.m_checkExpire*10)
	return true 
end 

function SvrDeplyBase:onMysqlGetKeyConfig(key, argst)
	--log.d(TAG, "onMysqlGetKeyConfig:"..key)
	if not self.m_dbClient or not key or string.len(key) <= 0 then 
		return false 
	end 
	local ret = skynet.call(self.m_dbClient,"lua","getSvrDeply",key)
	if ret and tableHasElement(ret) then 
		if ret[1] and type(ret[1]) == "table" then 
			argst.cur = ret[1]["time"]
			argst.json = ret[1]["v"]
		end 
	end 

	if argst.cur and argst.json then
		-- Log.dump(TAG, argst, key)
		return true 
	end 	
	return false
end 



	
return SvrDeplyBase