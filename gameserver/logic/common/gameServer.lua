local defineType = require("logic/common/defineType")
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local mahjongDefine = require("logic/common/mahjongDefine")
local skynet = require "skynet"
local TAG = "GameServer"
local queue = require "skynet.queue"
local sharedata = require("sharedata")

local cs = queue()

local GameServer = class()

function GameServer:init(level, port)
	Log.d(TAG, "GameServer init")
	-- 数据初始化
	self.m_level = level
	assert(self.m_level)
	Log.d(TAG, "GameServer.m_level = %s", self.m_level)
	self.m_allConfig = require("config/gameServerConfig")
	assert(self.m_allConfig)
	self.m_gameRoomConfig = require("config/gameConfig")[self.m_level]
	assert(self.m_gameRoomConfig)
	-- 共享数据模块
	self:onInitShareData(level, port)

	self.m_totalUserCount = 0
	self.m_totalTableCount = 0
	-- 玩家对应tableId
	self.m_userIdToTableIdMap = {}  -- userId -> tableId
	-- tableId对应服务
	self.m_tableIdToGameTableMap = {} 	 -- tableId -> gameTable
	-- 桌子信息
	self.m_gameTableToGameTableInfoMap = {} -- gameTable -> gameTableInfo
	-- 玩家开房数目
	self.m_userIdToBattleRoomCountMap = {} -- userId -> battleRoomCount
	-- 离线列表
	self.m_pDisconnectUserList = {}

	-- 配置
	self.m_friendBattleConfig = {}
	self.m_trustLevelConfig = {}
	self.m_expConfig = {}

	-- self.m_gameTableData = require("logic/common/gameTableData")
	self.m_allocClient = nil
	self.m_moneyClients = {}
	self.m_diaMondClients = {}
	self.m_backendClients = {}
	self.m_filterClients = {}
	self.m_pRobotClients = {}
	self.m_lookbackClients = {}

	self.m_redisClientsManager = new(require("service/redisClientsMgr"))

	local config = self.m_allConfig

	--开启监听hallServer的端口,管理GameServer与hallServer的链接 
	local watchdog = skynet.newservice("hallWatchdog")
	skynet.call(watchdog, "lua", "start",{
		port      = self.m_gameRoomConfig.iListenPort,
		maxclient = self.m_gameRoomConfig.iMaxClient,
		nodelay   = true,
	})
	Log.e(TAG, "watchdog[%s] listen on port[%s]", watchdog, self.m_gameRoomConfig.iListenPort)

	-- 开启与allocserver链接
	self.m_allocClient = skynet.newservice("allocClient")
	local pAllocConfig = config.allocConfig[self.m_level]
	skynet.send(self.m_allocClient, "lua", "init")

	-- 开启与moneyServer链接
	local pMoneyConfig = config.moneyConfig
	assert(pMoneyConfig)
	Log.dump(TAG, pMoneyConfig, "pMoneyConfig")
	for k, v in pairs(pMoneyConfig) do
		local pIndex = tonumber(k)
		self.m_moneyClients[pIndex] = skynet.newservice("moneyClient")
		Log.d(TAG, "GameServer.m_moneyClients[%s] = %s", k, self.m_moneyClients[pIndex])
		local pRet = skynet.call(self.m_moneyClients[pIndex], "lua", "init", v)
	end

	-- mtkeyredis
	local pMtkeyRedisConfig = config.mtkeyRedisConfig
	assert(pMtkeyRedisConfig)
	if 1 == pMtkeyRedisConfig.open then
		self.m_redisClientsManager:addRedisClient("mtkeyRedis", {
			host = pMtkeyRedisConfig.ip,
			port = pMtkeyRedisConfig.port,
			db = 0,
		})
		-- 将自己的信息写入redis
		local pKey = "svidInfo_"..self.m_gameRoomConfig.iServerId
		local pRet = self:onExcuteRedisCmd("HMSet", "mtkeyRedis", pKey, "level", self.m_level, "ip", self.m_gameRoomConfig.iListenIp, 
			"port", self.m_gameRoomConfig.iListenPort, "basechip", self.m_gameRoomConfig.iBasePoint, 
			"name", self.m_gameRoomConfig.iTableName, "serverfee", self.m_gameRoomConfig.iServerFee, "gamecode", self.m_gameRoomConfig.iMJCode)
	end

	-- battlePayRedis
	local pBattlePayRedisConfig = config.battlePayRedisConfig
	assert(pBattlePayRedisConfig)
	if 1 == pBattlePayRedisConfig.open then
		-- self.m_redisClientsManager:addRedisClient("battlePayRedis", {
		-- 	host = pBattlePayRedisConfig.ip,
		-- 	port = pBattlePayRedisConfig.port,
		-- 	db = 0,
		-- })
	end

	-- battlePaiJuRedis
	local pBattlePaiJuRedisConfig = config.battlePaiJuRedisConfig
	assert(pBattlePaiJuRedisConfig)
	if 1 == pBattlePaiJuRedisConfig.open then
		self.m_redisClientsManager:addRedisClient("battlePaiJuRedis", {
			host = pBattlePaiJuRedisConfig.ip,
			port = pBattlePaiJuRedisConfig.port,
			db = 0,
		})
	end

	-- diamondServer
	local pDiamondConfig = config.diamondConfig
	assert(pDiamondConfig)
	for k, v in pairs(pDiamondConfig) do
		local pIndex = tonumber(k)
		self.m_diaMondClients[pIndex] = skynet.newservice("diamondClient")
		Log.d(TAG, "GameServer.m_diaMondClients[%s] = %s", k, self.m_diaMondClients[pIndex])
		local pRet = skynet.call(self.m_diaMondClients[pIndex], "lua", "init", v)
	end

	-- backendServer
	local pBackendConfig = config.backendConfig
	assert(pBackendConfig)
	for k, v in pairs(pBackendConfig) do
		local pIndex = tonumber(k)
		self.m_backendClients[pIndex] = skynet.newservice("backendClient")
		skynet.send(self.m_backendClients[pIndex], "lua", "init", v)
	end

	-- robotConfig
	local pRobotConfig = config.robotConfig
	for k, v in pairs(pRobotConfig) do
		local pIndex = tonumber(k)
		self.m_pRobotClients[pIndex] = skynet.newservice("robotClient")
		skynet.send(self.m_pRobotClients[pIndex], "lua", "init", v)
	end

  -- 开启与lookbackServer链接
  local pLookbackConfig = config.lookbackConfig
  assert(pLookbackConfig)
  Log.dump(TAG, pLookbackConfig, "pLookbackConfig")
  for k, v in pairs(pLookbackConfig) do
    local pIndex = tonumber(k)
    self.m_lookbackClients[pIndex] = skynet.newservice("lookbackClient")
    Log.d(TAG, "GameServer.m_lookbackClients[%s] = %s", k, self.m_lookbackClients[pIndex])
    local pRet = skynet.call(self.m_lookbackClients[pIndex], "lua", "init", v)
  end

	-- filterServer
	-- local pFilterConfig = config.filterConfig
	-- assert(pFilterConfig)
	-- for k, v in pairs(pFilterConfig) do
	-- 	local pIndex = tonumber(k)
	-- 	self.m_filterClients[pIndex] = skynet.newservice("filterClient")
	-- 	skynet.send(self.m_filterClients[pIndex], "lua", "init", v)
	-- end

	-- scheduleManager
	self.m_scheduleMgr = new(require('utils/schedulerMgr'))

	--SvrDep
	self.m_svrDep = new(require("logic/common/svrDeplyBase"), self)
	self.m_svrDep:init(config)

	-- 重启前去掉所有的在线信息
	self:onResetGameServerOnline()
end

function GameServer:onInitShareData(level, port)
	self.m_gameRoomConfig.iListenPort = port
	self.m_gameRoomConfig.iLevel = level
	-- 房间配置信息初始化
	sharedata.new("GameRoomConfig", self.m_gameRoomConfig)
	self.m_gameRoomConfig = sharedata.query("GameRoomConfig")
	local pPlaytypeConfig = require(mahjongDefine.MahjongPlayTypeMap[self.m_gameRoomConfig.iMJCode])
	sharedata.new("PlaytypeConfig", pPlaytypeConfig)
	Log.dump(TAG, pPlaytypeConfig, "pPlaytypeConfig")
	sharedata.new("FriendBattleConfig", {})
	self.m_friendBattleConfig = sharedata.query("FriendBattleConfig")
end

function GameServer:onResetGameServerOnline()
	local pKey = "svidOnline_"..self.m_gameRoomConfig.iServerId
	local pRetRedis = self:onExcuteRedisCmd("SMEMBERS", "mtkeyRedis", pKey)
	if pRetRedis and type(pRetRedis) == "table" then
		for k, v in pairs(pRetRedis) do
			local pVKey = "mt_"..v
			local pRet = self:onExcuteRedisCmd("HMSet", "mtkeyRedis", pVKey, "uid", 0, "tid", 0, "svid", 0, "port", 0, "from", 0,"gamecode", 0)
			local pRet = self:onExcuteRedisCmd("Expire", "mtkeyRedis", pVKey, 3600 * 3)
			local pRet = self:onExcuteRedisCmd("SREM", "mtkeyRedis", pKey, v)
		end
	end
end

-- 容错当alloc存在玩家桌子，而gameServer已经没有改桌子了
function GameServer:onUpdateRoomUserCount(data)
	local cmd = socketCmd.UPDATE_ROOM_USER_COUNT
	local info = {}
	info.iServerId = self.m_gameRoomConfig.iServerId
	info.iTableId = data.iTableId
	info.iLevel = self.m_level
	info.iUserCount = 3
	info.iServerUserCount = self:onGetGameServerUserCount()
	info.iUserId = data.iUserId
	info.iStatus = defineType.USER_LOGOUT
	info.iSwapCards = 1
	info.iPlayType = 1
	info.iWanFa = 1
	info.iMatchId = 1
	info.iRoomId = 0
	self:onSendToAllocServer(cmd, info)
end

-- GameUser相关的
function GameServer:onClientCmdLogin(data, socketfd)
	Log.d(TAG, "onClientCmdLogin uid[%s], tableId[%s] socketfd[%s]", data.iUserId, data.iTableId, socketfd)
	local pGameTable = self:onGetGameTableByTableId(data.iTableId)
	if not data.iUserId or not data.iTableId then
		Log.e(TAG, "onDealUserLogin failed, data.iUserId[%s], data.iTableId[%s], pGameTable[%s]", data.iUserId, data.iTableId, pGameTable)
		return -2
	end
	data.iIsRobot = 0
	Log.d(TAG, "pGameTable[%s], iIsBattleRoom[%s]", pGameTable, self:isBattleServer())
	-- 如果是对战场，且房间不存在，则失败
	if not self:onCheckGameTable(pGameTable) and self:isBattleServer() then
		self:onUpdateRoomUserCount(data)
        local cmd = socketCmd.SERVER_CMD_CLIENT_LOGIN_ERROR
        local info = {}
        info.iErrorType = defineType.ERROR_TABLE_MAX_COUNT
        socketManager.send(socketfd, cmd, info, true)
        return -1
    end
    -- 如果创建房间失败， 普通场的逻辑
	if not self:onDealCheckAndAddTable(data.iTableId) then
		self:onUpdateRoomUserCount(data)
		local cmd = socketCmd.SERVER_CMD_CLIENT_LOGIN_ERROR
        local info = {}
        info.iErrorType = defineType.ERROR_TABLE_NOT_EXIST
        socketManager.send(socketfd, cmd, info, true)
        return -1
	end
	pGameTable = self:onGetGameTableByTableId(data.iTableId)
	local pDiamondClient = self:onGetDiamondClient(data.iUserId)
	local pMoneyClient = self:onGetMoneyClient(data.iUserId)
	if pDiamondClient and pMoneyClient then
		local pRet = skynet.call(pGameTable, "lua", "onClientCmdLogin", data, data.iUserId, socketfd, pDiamondClient, pMoneyClient)
		return pRet
	end
	return 0
end

function GameServer:onCreatNewTableId()
	for k, v in pairs(self.m_tableIdToGameTableMap) do
		if not self.m_tableIdToGameTableMap[k + 1] then
			return k + 1
		end
	end
end

function GameServer:onCreatANewGameTable(data, socketfd)
	local pTableId = self:onCreatNewTableId()
	if not pTableId then return end
	-- 如果创建房间失败， 普通场的逻辑
	data.iTableId = pTableId
	self:onClientCmdLogin(data, socketfd)
end

function GameServer:onServerCmdRobotLogin(data, socketfd)
	data.iIsRobot = 1
	if data.iMJCode ~= self.m_gameRoomConfig.iMJCode then
		self:onSendRobotLoginError(data.iTableId, "gametype error")
		return -1
	end
	local pGameTable = self:onGetGameTableByTableId(data.iTableId)
	if not self:onCheckGameTable(pGameTable) then
		self:onSendRobotLoginError(data.iTableId, "table not found")
		return -1
	end
	local pDiamondClient = self:onGetDiamondClient(data.iUserId)
	local pMoneyClient = self:onGetMoneyClient(data.iUserId)
	if pDiamondClient and pMoneyClient then
		local pRet = skynet.call(pGameTable, "lua", "onClientCmdLogin", data, data.iUserId, socketfd, pDiamondClient, pMoneyClient)
		return pRet
	end
end

function GameServer:onSendRobotLoginError(tableId, reason)
	local cmd = socketCmd.SERVER_CMD_ROBOT_LOGIN
	local info = {}
	info.iRet = -1
	info.iReason = reason
	info.iIsTable = 0
	local pRobotClient = self:onGetRobotClient(tableId)
	if pRobotClient then
		skynet.send(pRobotClient, "lua", "onSendToRobotServer", cmd, info)
	end
end

function GameServer:onRemoveUser(userId)
	if not userId then
		return
	end
	self.m_userIdToTableIdMap[userId] = nil
	self.m_totalUserCount = self.m_totalUserCount - 1 
end

-- GameTable相关
-- GameTable将自己的数据传给GameServer,更新
function GameServer:onGameTableUpdateTableData(data, dismiss)
	if not data then
		Log.e(TAG, "GameServer onGameTableUpdateTableData is failed")
		return -1 
	end
	if not self.m_tableIdToGameTableMap[data.iTableId] then
		self.m_tableIdToGameTableMap[data.iTableId] = data.iGameTable
		self.m_gameTableToGameTableInfoMap[data.iGameTable] = data.iGameTableInfo
	end
	for k, v in pairs(data.iUserTable) do
		if not self.m_userIdToTableIdMap[v.iUserId] then
			self.m_totalUserCount = self.m_totalUserCount + 1
		end
		self.m_userIdToTableIdMap[v.iUserId] = data.iTableId
	end
end

function GameServer:onDealCheckAndAddTable(tableId, palyType)
	Log.d(TAG, "GameServer.onDealCheckAndAddTable tableId = %s", tableId)
	local pGameTable = self:onGetGameTableByTableId(tableId)
	if not pGameTable then
		pGameTable = skynet.newservice("gameTableService")
		local pRet = skynet.call(pGameTable, "lua", "init", tableId, self.m_level, self.m_gameRoomConfig.iServerId)
	end
	self.m_tableIdToGameTableMap[tableId] = pGameTable
	return true
end

function GameServer:onCheckDataValid(data)
	if not data.iUserId or data.iUserId <= 0 or not data.iRoomId or data.iRoomId <= 0 or 
		not data.iTableId or data.iTableId <= 0 or not data.iMJCode or data.iMJCode <= 0 or 
		not data.iRoundNum or data.iRoundNum <= 0 then
		return false
	end
	-- 检验玩法是否正确
	if data.iMJCode ~= self.m_gameRoomConfig.iMJCode then
		return false
	end
	-- 校验开房局数是否正确
	-- if not self.m_friendBattleConfig[data.iRoundNum] then
	-- 	return false
	-- end
	return true
end

function GameServer:onClientCmdCreateBattleRoom(data, socketfd)
	-- 检验参数的合法性
	if not self:onCheckDataValid(data) then
		Log.e(TAG, "GameServer onCheckDataValid is false")
		-- Log.dump(TAG, data, "data")
		return -1
	end
	-- 先确定一个房间
	if not self:onDealCheckAndAddTable(data.iTableId, data.iPlayType) then
		Log.e(TAG, "onClientCmdCreateBattleRoom uid[%s] not get tableId[%s], palyType[%s]", data.iUserId, data.iTableId, data.iPlayType)
		return -1
	end
	local pGameTable = self:onGetGameTableByTableId(data.iTableId)
	if not self:onCheckGameTable(pGameTable) then
		Log.d(TAG, "pGameTable is nil")
		return -1
	end
	local pRet = skynet.call(pGameTable, "lua", "onClientCmdCreateBattleRoom", data, data.iUserId, socketfd)
	return pRet
end

function GameServer:onSysResponseMasterBattleRoomCount(data, socketfd)
	if not data or not data.iUserId then
		Log.d(TAG, "onSysResponseMasterBattleRoomCount not data or not data.iUserId")
		return -1
	end
	Log.d(TAG, "GameServer onSysResponseMasterBattleRoomCount")
	self.m_userIdToBattleRoomCountMap[data.iUserId] = data.iCount
	return 0
end

function GameServer:onExcuteRedisCmd(redisCmd, ...)
	local pFmt = ""
	local arg = {...}
	for i = 1, #arg do
		pFmt = pFmt.."%s "
	end
	local pStr = string.format(pFmt, ...)
	Log.d(TAG, "onExcuteRedisCmd %s %s", redisCmd, pStr)
	if self.m_redisClientsManager[redisCmd] then
		local pRetRedis = self.m_redisClientsManager[redisCmd](self.m_redisClientsManager, ...)
		if type(pRetRedis) == "table" then
			Log.dump(TAG, pRetRedis, "pRetRedis")
		else
			Log.d(TAG, "pRetRedis[%s]", pRetRedis)
		end
		return pRetRedis
	else
		Log.e(TAG, "unknow redisCmd[%s]", redisCmd)
		return -1
	end
end

function GameServer:onAddOneUserDisconnect(userId)
	Log.i(TAG, "onAddOneUserDisconnect userId[%s]", userId)
	if userId then
		self.m_pDisconnectUserList[userId] = 1
	end
end

function GameServer:onClearOnUserDisconnect(userId)
	if userId then
		self.m_pDisconnectUserList[userId] = 0
	end
end

function GameServer:onIsDisconnectUser(userId)
	return userId and self.m_pDisconnectUserList[userId] or 0
end

function GameServer:onCheckGameTable(gameTable)
	if not gameTable or gameTable <= 0 then
		return false
	end
	return true
end

function GameServer:onGetTableIdByUserId(userId)
	return userId and self.m_userIdToTableIdMap[userId] or nil
end

function GameServer:onGetGameTableByTableId(tableId)
	return tableId and self.m_tableIdToGameTableMap[tableId] or nil
end

function GameServer:onGetGameTableByUserId(userId)
	local pTableId = self:onGetTableIdByUserId(userId)
	return self:onGetGameTableByTableId(pTableId)
end

function GameServer:onGetGameServerUserCount()
	return self.m_totalUserCount
end

function GameServer:onSendToAllocServer(cmd, info)
	if self.m_allocClient and self.m_allocClient > 0 then
		skynet.send(self.m_allocClient, "lua", "onSendToAllocServer", cmd, info)
	end
	return 0
end

function GameServer:onSendToBackendServer(cmd, info)
	if self.m_backendClients and #self.m_backendClients > 0 then
		skynet.send(self.m_backendClients[1], "lua", "onSendToBackendServer", cmd, info)
	end
	return 0
end

-- 获取服务标识
function GameServer:onGetDiamondClient(userId)
	if not userId then
		return nil
	end
	local pDiamondCount = #self.m_diaMondClients
	return pDiamondCount > 0 and self.m_diaMondClients[userId % pDiamondCount + 1] or nil
end

function GameServer:onGetMoneyClient(userId)
	if not userId then
		return nil
	end
	local pMoneyClient = #self.m_moneyClients
	return pMoneyClient > 0 and self.m_moneyClients[userId % pMoneyClient + 1] or nil
end

function GameServer:onGetRobotClient(tableId)
	if not tableId then
		return nil
	end
	local pRobotClient = #self.m_pRobotClients
	return pRobotClient > 0 and self.m_pRobotClients[tableId % pRobotClient + 1] or nil
end

function GameServer:onGetTrustLevelOpenNum(trustLevel)
	return trustLevel and self.m_trustLevelConfig[trustLevel] or 0
end

-- 获取某个id的开房数量
function GameServer:onGetUserBattleRoomCount(userId)
	return self.m_userIdToBattleRoomCountMap[userId] and self.m_userIdToBattleRoomCountMap[userId] or 0
end

-- 是否是对战场
function GameServer:isBattleServer()
	return 1 == self.m_gameRoomConfig.iIsBattleRoom
end

-- 获取所有对战房间信息,只有连上allocserver的时候才执行一次
function GameServer:onReportBattleData(socketfd)
	if not self:isBattleServer() then
		return -1
	end
	local cmd = socketCmd.REPORT_BATTLE_DATA
	local info = {}
	info.iServerId = self.m_gameRoomConfig.iServerId
	info.iLevel = self.m_level
	info.iAliveBattleRoom = 0
	info.iTableList = {}

	for k, v in pairs(self.m_tableIdToGameTableMap) do
		local pGameTableInfo = self.m_gameTableToGameTableInfoMap[v]
		if pGameTableInfo and pGameTableInfo.iBattleConfig and pGameTableInfo.iIsAlive then
			info.iAliveBattleRoom = info.iAliveBattleRoom + 1
			local pTemp = {}
			pTemp.iRoomId = pGameTableInfo.iBattleConfig.iRoomId
			pTemp.iUserId = pGameTableInfo.iBattleConfig.iUserId
			pTemp.iTableId = pGameTableInfo.iBattleConfig.iTableId
			pTemp.iPlayType = pGameTableInfo.iBattleConfig.iPlayType
			pTemp.iTableStatus = pGameTableInfo.iTableStatus
			info.iTableList[#info.iTableList + 1] = pTemp
		end
	end
	socketManager.send(socketfd, cmd, info)
end

function GameServer:onReportServerData(socketfd)
	local cmd = socketCmd.REPORT_SERVER_DATA
	local info = {}
	info.iAllocLevel = self.m_level
	info.iAllocServerId = self.m_gameRoomConfig.iServerId
	info.iRoomCount = 0
	info.iUserCount = self.m_totalUserCount
	for k, v in pairs(self.m_tableIdToGameTableMap) do
		local pGameTableInfo = self.m_gameTableToGameTableInfoMap[v]
		if pGameTableInfo and pGameTableInfo.iCommonConfig then
			info.iRoomCount = info.iRoomCount + 1
			local pTemp = {}
			pTemp.iTableId = pGameTableInfo.iCommonConfig.iTableId
			pTemp.iMJCode = pGameTableInfo.iCommonConfig.iMJCode
			pTemp.iUserCount = pGameTableInfo.iCommonConfig.iUserCount
			pTemp.iRoomId = pGameTableInfo.iCommonConfig.iRoomId
			info.iTableList[#info.iTableList + 1] = pTemp
		end
	end
	socketManager.send(socketfd, cmd, info)
end

function GameServer:onAllCmdRequestUserBattleData(data, socketfd)
	if not self:isBattleServer() or not data or not socketfd then
		return -1
	end
	local pGameTable = self:onGetGameTableByTableId(data.iTableId)
	if not self:onCheckGameTable(pGameTable) then
		return -1
	end
	local pGameTableInfo = self.m_gameTableToGameTableInfoMap[pGameTable]
	-- 如果这个房间没有使用，则上报删除该玩家下开房数目
	if pGameTableInfo and pGameTableInfo.iBattleConfig then
		if pGameTableInfo.iBattleConfig.iRoomId == data.iRoomId and 
			pGameTableInfo.iBattleConfig.iUserId == data.iUserId and 
			not pGameTableInfo.iIsAlive then
			local cmd = socketCmd.GAMECMD_RESPONSE_USER_BATTLE_DATA
			local info = {}
			info.iServerId = self.m_gameRoomConfig.iServerId
			info.iLevel = self.m_level
			info.iUserId = data.iUserId
			info.iRoomId = data.iRoomId
			info.iTableId = data.iTableId
			socketManager.send(socketfd, cmd, info)
		end
	end
	return 0
end

function GameServer:onReportRobotUserCount()
	local pRobotClient = self:onGetRobotClient()
	if not pRobotClient then
		Log.e(TAG, "onReportRobotUserCount failed --> pRobotClient is nil")
		return
	end
	local pRobotCountTable = {}
	for k, v in pairs(self.m_tableIdToGameTableMap) do
		local pRobotCount = skynet.call(v, "lua", "onGetRobotUserCount")
		if pRobotCount > 0 then
			pRobotCountTable[#pRobotCountTable + 1] = {
				iTableId = k,
				iRobotCount = pRobotCount,
			}
		end
	end
	local cmd = socketCmd.AUTOAICMD_ROBOT_PACKET
	local info = {}
	info.iSwitchCmd = socketCmd.ROBOT_INTRCMD_REPORT_ROBOTLIST
	info.iServerId = self.m_gameRoomConfig.iServerId
	info.iLevel = self.m_level
	info.iRobotTableCount = #pRobotCountTable
	info.iRobotCountTable = pRobotCountTable
	skynet.send(pRobotClient, "lua", "onSendToRobotServer", cmd, info)
end

-- decypt解密
function GameServer:receiveData(socketfd, cmd, buffer, decypt)
	if cmd and self.s_cmdFuncMap[cmd] then
		Log.d(TAG, "GameServer:receiveData socketfd=[%d], cmd=[0x%x]", socketfd, cmd)
		local data = socketManager.receive(cmd, buffer, decypt)
		return cs(self.s_cmdFuncMap[cmd], GameServer, data, socketfd)
	end
end


GameServer.s_cmdFuncMap = {
	-- hallServer
	[socketCmd.CLIENT_CMD_CREATE_BATTLE_ROOM] = GameServer.onClientCmdCreateBattleRoom,
	[socketCmd.CLIENT_CMD_LOGIN] = GameServer.onClientCmdLogin,

	-- allocServer
	[socketCmd.SYS_RESPONSE_MASTER_BATTLEROOM_COUNT] = GameServer.onSysResponseMasterBattleRoomCount,
	[socketCmd.ALLCMD_REQUEST_USER_BATTLE_DATA] = GameServer.onAllCmdRequestUserBattleData,

	-- robotServer
	[socketCmd.SERVER_CMD_ROBOT_LOGIN] = GameServer.onServerCmdRobotLogin,
}

return GameServer