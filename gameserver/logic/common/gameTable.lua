local defineType = require("logic/common/defineType")
local skynet = require("skynet")
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local json = require("cjson")
local sharedata = require("sharedata")
local queue = require("skynet.queue")

local cs = queue()

local TAG = "GameTable"

local GameTable = class()

function GameTable:init(...)
	self:initCmdFunction()
	self.m_tableUserMap = {}
	self.m_battleConfig = {
		iUserId = 0,
		iRoomId = 0,
		iFrom = 0, -- 房主的API
		iTableId = 0,
		iMJCode = 0,
		iRoundNum = 0,
		iCurRound = 0,
		iPlayType = 0,
		iExtendInfo = {},
		-- iKwxBei = 0,
		-- iSwapCards = 0,
		-- iIsPiao = 0,
		iCreateTime = 0, -- 房间开启时间
		iBattleId = "",
		iBattlePayNum = 0,

		iBattlePayMode = defineType.BATTLE_PAY_OWNER,
	}
	self.m_battleFreeOpenRoom = 0

	self.m_tableId, self.m_level, self.m_serverId = ...
	-- 将GameServer标识保存起来
	self.m_gameServer = skynet.localname(".GameServer")
	self.m_tableId = tonumber(self.m_tableId)
	self.m_level = tonumber(self.m_level)
	self.m_serverId = tonumber(self.m_serverId)
	Log.d(TAG, "GameTable.init m_tableId[%s], m_level[%s], m_serverId[%s]", self.m_tableId, self.m_level, self.m_serverId)
	self.m_commonConfig = {
		iRoomId = -1,
		iMJCode = 0,
		iPlayType = 0,
		iSwapCards = 0,
		iBasePoint = 0,
		iTableId = 0,
		iMatchId = "",
		iIsBattleRoom = 0,
		iBankSeatId = 0,
		iWanFa = 0,
		iBattleLocalGameType = 1, -- 地方游戏下的不同游戏
	}
	local pGameConfig = sharedata.query("GameRoomConfig")
	table.merge(self.m_commonConfig, pGameConfig)
	self.m_commonConfig.iTableId = self.m_tableId

	self.m_tableStatus = defineType.GAME_STATUS_STOP

	self.m_scheduleMgr = new(require('utils/schedulerMgr'))
	self.m_gameRound = require("logic/common/gameRound")
	self.m_gameRound:init(self, self.m_scheduleMgr)
	Log.dump(TAG, self.m_commonConfig, "self.m_commonConfig")

	self.m_pPlaytypeConfig = sharedata.query("PlaytypeConfig")
end

-- 重置table的信息
function GameTable:onResetTable()
	self.m_gameRound:onReset()
	self.m_tableUserMap = {}
	self.m_tableStatus = defineType.GAME_STATUS_STOP
end

function GameTable:onSetBattleRoomConfig(data)
	self.m_battleConfig.iUserId = data.iUserId
	self.m_battleConfig.iRoomId = data.iRoomId
	self.m_battleConfig.iTableId = data.iTableId
	self.m_battleConfig.iMJCode = data.iMJCode
	self.m_battleConfig.iRoundNum = data.iRoundNum
	self.m_battleConfig.iPlayType = data.iPlayType
	self.m_battleConfig.iBattlePayMode = data.iBattlePayMode
	self.m_battleConfig.iExtendInfo = data.iExtendInfo
	-- self.m_battleConfig.iKwxBei = data.iKwxBei
	-- self.m_battleConfig.iSwapCards = data.iSwapCards
	-- self.m_battleConfig.iIsPiao = data.iIsPiao
	self.m_battleConfig.iCreateTime = os.time()
	local pTempStr = string.format("%x-%x", self.m_battleConfig.iCreateTime, self.m_battleConfig.iTableId)
	self.m_battleConfig.iBattleId = pTempStr
	-- 获取开房条件
	self.m_battleConfig.iBattlePayNum = self:onGetBattlePayNum()
	-- 设置房间创建完成
	self.m_tableStatus = defineType.BATTLE_STATUS_CREATED

	-- 把一些数据写进commonConfig
	self.m_commonConfig.iPlayType = data.iPlayType
	self.m_commonConfig.iRoomId = self.m_battleConfig.iRoomId

	Log.dump(TAG, self.m_battleConfig, "self.m_battleConfig")
	return true
end

function GameTable:onCheckUserSameIp(data, userId)
	return false
end

function GameTable:onCheckUserDeviceID(data, userId)
	return false
end

function GameTable:onCheckUserMTkey(data, userId)
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "HMGet", "mtkeyRedis", "mt_"..data.iUserId, "tid", "mtkey") 
	data.iLastTableId = 0
	if type(pRedisRet) == "table" then
		if tonumber(pRedisRet[1]) and tonumber(pRedisRet[1]) > 0 then
			-- skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "HMSet", "mtkeyRedis", "mt_"..data.iUserId, "tid", 0)
			data.iLastTableId = tonumber(pRedisRet[1])
		end
		if data.iMtKey and data.iMtKey == "009bf200de3a132b9b063022abb525d7" then
			-- 万能mtkey  随便进
			return true
		end
		if not pRedisRet[2] or pRedisRet[2] ~= data.iMtKey then
			return false
		end
		return true
	end 
	return false
end

function GameTable:onGetUserInfo(data, userId, moneyClient)
	local pRet = skynet.call(moneyClient, "lua", "onGetUserInfo", data.iUserId)
	if pRet and type(pRet) == "table" then
		if data.iUserId ~= pRet.iUserId then
			Log.e(TAG, "moneyClient onGetUserInfo data.iUserId[%s], pRet.iUserId[%s]", data.iUserId, pRet.iUserId)
			return false
		end
		data.iMoney = pRet.iMoney
		data.iExp = pRet.iExp
		data.iLevel = pRet.iLevel
		data.iWinTimes = pRet.iWinTimes
		data.iLoseTimes = pRet.iLoseTimes
		data.iDrawTimes = pRet.iDrawTimes
		data.iChips = pRet.iChips
		return true
	end
	return false
end

function GameTable:onCheckTableStatus(data)
	if not self:isBattleRoom() then
		return true
	end
	if self.m_tableStatus == defineType.BATTLE_STATUS_CREATED or self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
		return true
	end
	Log.e(TAG, "onCheckTableStatus failed self.m_tableStatus[%s]", self.m_tableStatus)
	return false
end

function GameTable:onCheckUserCertification(data)
	if not self:isBattleRoom() or not self:isBattleOwner(data.iUserId) or self.m_battleFeePaid then
		return true
	end
	local pCount = skynet.call(self.m_gameServer, "lua", "onGetUserBattleRoomCount", data.iUserId)
	local pOpenNum = skynet.call(self.m_gameServer, "lua", "onGetTrustLevelOpenNum", data.iTrustLevel)
	Log.d(TAG, "onCheckUserCertification pCount[%s] pOpenNum[%s]", pCount, pOpenNum)
	if pOpenNum > 0 and pOpenNum >= pCount then
		return true
	end
	return true
end

function GameTable:onCheckUserEnoughMoney(data)
	Log.d(TAG, "GameTable onCheckUserEnoughMoney")
	if self:isBattleRoom() then
		return true
	end
	data.iMoney = data.iMoney or 0
	if data.iMoney < self.m_commonConfig.iLevelNeedMoney then
		return false
	end
	return true
end

function GameTable:onCheckUserTodayFirstOpenRoom(userId)
	if not userId or userId <= 0 then
		return false
	end
	if self:isBattleDayFirstFree() then
		-- TODO 开发服没有这个redis
		-- local pRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Get", "get gy:fre:"..userId)
		local pRet = 0
		if type(pRet) == "table" then
			Log.d(TAG, "pRet is table")
		else
			Log.d(TAG, "pRet is not table")
		end
		if pRet == 1 then
			pRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Del", "get gy:fre:"..userId)
			return pRet >= 0
		end
	end
	return false
end

function GameTable:onCheckUserBattlePay(data)
	if not self:isBattleRoom() then
		return true
	end
	-- 如果已经付过了
	if self.m_battleFeePaid then
		return true
	end
	-- 如果是第一次免费
	if self:isBattleOwner(data.iUserId) and self:isBattleDayFirstFree() then
		if self:onCheckUserTodayFirstOpenRoom(data.iUserId) then
			self.m_battleFeePaid = true
			self.m_battleFreeOpenRoom = 1
			return true
		end
	end
	-- 如果是用钻石支付
	if self:isBattlePayDiamond() then
		local pDiamond = self:onGetBattlePayNum()
		Log.d(TAG, "isWinerPay[%s] pDiamond[%s] data.iDiamond[%s]", tostring(self:isWinerPay()), pDiamond, data.iDiamond)
		if self:isWinerPay() then
			if pDiamond <= data.iDiamond then
				return true
			end
		elseif self:isBattleOwner(data.iUserId) then
			if pDiamond <= data.iDiamond then
				Log.d(TAG, "扣除钻石")
				-- 扣除钻石
				local pUpdateTable = {
					{
						iUserId = data.iUserId,
						iType = 0,
						iUpdateDiamond = -pDiamond,
						iFrom = data.iFrom,
					},
				}
				if not self:onUpdateUserDiamond(pUpdateTable, data.iUserId, defineType.ActId_Diamond_fee) then
					return false
				end
				self.m_battleFeePaid = true
				return true
			end
		end
	elseif self:isBattlePayMoney() then

	end
	return false
end

function GameTable:onCheckGameTableStartGame()
	if self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
		return
	end
	-- 检测人数，是否可以开始游戏
	if self:onGetReadyUserCount() == self:onGetMaxUserCount() then
		local info = {}
		info.iBankSeatId = self.m_commonConfig.iBankSeatId -- 座位号
		info.iRoundNum = self.m_battleConfig.iRoundNum
		info.iCurRound = self.m_battleConfig.iCurRound
		info.iMJCode = self.m_commonConfig.iMJCode
		info.iUserCount = self:onGetReadyUserCount()
		self.m_gameRound:onGameStart(info)
		self.m_tableStatus = defineType.GAME_STATUS_PLAYING
		self:onReportGameUsers()
		if not self:isBattleRoom() then
			for i = 1, self:onGetReadyUserCount() do
				local pUser = self.m_tableUserMap[i]
				if pUser then
					local pMoney = pUser.m_money - self.m_commonConfig.iServerFee
					pUser.m_money = pMoney > 0 and pMoney or 0
					self:onUpdateUserMoney(pUser, -self.m_commonConfig.iServerFee, defineType.ActId_SERVICE_FEE)
				end
			end
		end
	end
end

function GameTable:onReportGameUsers()
	local cmd = socketCmd.REPORT_GAME_USERS
	local info = {}
	info.iServerId = self.m_commonConfig.iServerId
	info.iTableId = self.m_commonConfig.iTableId
	info.iLevel = self.m_commonConfig.iLevel
	info.iUserCount = self:onGetUserCount()
	info.iUserIdTable = {}
	for i = 1, self:onGetUserCount() do
		if self.m_tableUserMap[i] then
			info.iUserIdTable[#info.iUserIdTable + 1] = self.m_tableUserMap[i]:onGetUserId()
		end
	end
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToAllocServer", cmd, info)
end

function GameTable:onGameStopRound()
	if not self:isBattleRoom() then
		-- 将标志置为一局结束
		self.m_tableStatus = defineType.GAME_STATUS_STOP
		-- 更新用户金币
		self:onUpdateMoneyExpAndLogEx()
		-- 如果金币场玩家已经掉线，则清除
		for i = 1, self:onGetMaxUserCount() do
			local pUser = self.m_tableUserMap[i]
			-- 清空玩家的信息
			pUser.m_ready = 0
			if pUser and pUser.m_socketfd <= 0 then
				self:onDisconnect(pUser:onGetUserId())
			end
		end
	else 
		if self.m_battleConfig.iRoundNum == self.m_battleConfig.iCurRound then
			self.m_tableStatus = defineType.GAME_STATUS_STOP
		else
			self.m_tableStatus = defineType.GAME_STATUS_PLAYING
			self.m_battleConfig.iCurRound = self.m_battleConfig.iCurRound + 1
		end
	end
	-- gameround全部重置
	self.m_gameRound:onReset()
end

function GameTable:onUpdateMoneyExpAndLogEx()
	if self:isBattleRoom() then
		return 
	end
	local pUpdateMoneyTable = {}
	for i = 1, self:onGetMaxUserCount() do
		local pUser = self.m_tableUserMap[i]
		if pUser and not pUser:isRobot() then
			local pTurnMoney = pUser:onGetTurnMoney()
			local pAction = pTurnMoney >= 0 and defineType.ActId_GAME_WIN or defineType.ActId_GAME_LOSE
			self:onUpdateUserMoney(pUser, pTurnMoney, pAction)
		end
	end
end 

function GameTable:onUpdateUserMoney(user, money, action)
	local cmd = socketCmd.SERVRE_CMD_MONEY_UPDATE_REQ
	local info = {}
	info.iMJCode = self.m_commonConfig.iMJCode
	info.iUserCount = 1
	info.iUserId = user:onGetUserId()
	info.iFrom = user.m_from
	info.iTurnMoney = money
	info.iAction = action

	local pMoneyClient = skynet.call(self.m_gameServer, "lua", "onGetMoneyClient", user:onGetUserId())
	local pRet = skynet.call(pMoneyClient, "lua", "onSendToMoneyServer", cmd, info)
end

function GameTable:onUpdateUserDiamond(data, userId, action)
	if not data or type(data) ~= "table" or not userId or not action then
		Log.e(TAG, "onUpdateUserDiamond data error")
		return false
	end
	local cmd = socketCmd.DAOJU_SERVER_MAIN_CMD
	local info = {}
	info.iSwitchCmd = socketCmd.SERVER_UPDATE_DIAM_NUM
	info.iMJCode = self.m_commonConfig.iMJCode
	info.iAction = action
	info.iUpdateCount = #data
	info.iUpdateTable = data
	local pDiamondClient = skynet.call(self.m_gameServer, "lua", "onGetDiamondClient", userId)
	if pDiamondClient then
		local pRet = skynet.call(pDiamondClient, "lua", "onUpdateUserDiamond", cmd, info)
		return pRet >= 0
	end
	return false
end

function GameTable:onAddOneRobotUser()
	if self:onGetUserCount() >= self:onGetMaxUserCount() then
		Log.e(TAG, "onAddOneRobotUser failed --> table is full")
		return 
	end

	local pRobotCount = 0
	local pRobotUserTable = {}
	for i = 1, self:onGetMaxUserCount() do
		local pUser = self.m_tableUserMap[i]
		if pUser and pUser:isRobot() then
			pRobotCount = pRobotCount + 1
			pRobotUserTable[#pRobotUserTable + 1] = pUser.m_userId
		end
	end
	local cmd = socketCmd.AUTOAICMD_ROBOT_PACKET
	local info = {}

	local cmdInner = socketCmd.ROBOT_INTRCMD_REQUEST_AI
	local infoInner = {}
	infoInner.iServerId = self.m_serverId
	infoInner.iListenIp = self.m_commonConfig.iListenIp
	infoInner.iListenPort = self.m_commonConfig.iListenPort
	infoInner.iTableId = self.m_commonConfig.iTableId
	infoInner.iLevel = self.m_level
	infoInner.iMJCode = self.m_commonConfig.iMJCode
	infoInner.iCurRobotCount = pRobotCount + 1
	infoInner.iRobotCount = pRobotCount
	infoInner.iRobotUserTable = pRobotUserTable

	local packetLen, packetBuf = socketManager.onGetPacket(cmdInner, infoInner)
	if packetLen > 0 and packetBuf then
		info.iInnerPacket = packetBuf
		local pRobotClient = skynet.call(self.m_gameServer, "lua", "onGetRobotClient", self.m_commonConfig.iTableId)
		if pRobotClient then
			skynet.send(pRobotClient, "lua", "onSendToRobotServer", cmd, info)
		end
	end
end

function GameTable:onCheckUserStatus(data, userId, diamondClent, moneyClient)
	data.iUserId = userId
	-- 获取玩家的钻石
	local pRetDiamond = {}
	if diamondClent then
		pRetDiamond = skynet.call(diamondClent, "lua", "onGetUserDiamond", {data.iUserId})
		if type(pRetDiamond) ~= "table" then 
			pRetDiamond = {} 
		end
	end
	data.iDiamond = tonumber(pRetDiamond[data.iUserId]) and  tonumber(pRetDiamond[data.iUserId]) or 0
	-- 判断房间的状态
	if not self:onCheckTableStatus(data) then
		return defineType.ERROR_BATTLE_NOT_CREATEED
	end
	-- 验证玩家是否还有开房的能力
	if not self:onCheckUserCertification(data) then
		return defineType.ERROR_BATTLE_CERTIFICATION
	end
	-- TODO 同ip
	if self:onCheckUserSameIp(data, data.iUserId) then
		return defineType.ERROR_SAME_IP
	end
	-- TODO 同设备
	if self:onCheckUserDeviceID(data, data.iUserId) then
		return defineType.ERROR_DEVICEID_CONFICE
	end
	-- mtkey 验证
	if not self:onCheckUserMTkey(data, data.iUserId) then
		return defineType.ERROR_USERKEY
	end
	-- 是否重连验证
	Log.d(TAG, "data.iLastTableId[%s] , self.m_tableId[%s]", data.iLastTableId, self.m_tableId)
	if data.iLastTableId > 0 then
		if self.m_tableId ~= data.iLastTableId then
			return defineType.ERROR_USERLOGINTABLE
		end
		local pIsDiConnect = skynet.call(self.m_gameServer, "lua", "onIsDisconnectUser", data.iUserId)
		if pIsDiConnect > 0 then
			return defineType.SUCCESS_RECONNECT
		end
	end
	-- 获取用户信息
	if not self:onGetUserInfo(data, data.iUserId, moneyClient) then
		return defineType.ERROR_USERKEY
	end
	-- TODO 先不处理防沉迷
	-- 判断玩家是不是已经在里面了
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] then 
			if self.m_tableUserMap[i]:onGetUserId() == data.iUserId then
				Log.d(TAG, "判断玩家是不是已经在里面了")
				return defineType.ERROR_TABLE_MAX_COUNT
			end
		end 
	end
	-- 如果桌子满了
	if self:onGetUserCount() >= self:onGetMaxUserCount() then
		Log.d(TAG, "如果桌子满了")
		return defineType.ERROR_TABLE_MAX_COUNT
	end
	-- 判断是否有足够的money
	if not self:onCheckUserEnoughMoney(data) then
		return defineType.ERROR_BATTLE_NOT_ENOUGH_FEE
	end
	-- 判断是否有进入对战场的能力
	if not self:onCheckUserBattlePay(data) then
		return defineType.ERROR_BATTLE_NOT_ENOUGH_FEE
	end

	return defineType.SUCCESS_NEWCONNECT
end

function GameTable:onDealUserLoginTableSuccess(data, userId, socketfd)
	local pUser = self:onAddNewUser(data, userId, socketfd)
	if not pUser then
		self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
		self:onSendUserLoginError(socketfd, defineType.ERROR_MYSQL)
        return -1
	end
	self:onUpdateRoomUserCount(userId, defineType.USER_LOGIN)
	-- redis处理
	self:onDealUserLoginTableRedis(pUser)
	pUser.m_userStatus = defineType.STATUS_LOGIN
	pUser.m_isOnline = true
	-- 更新GameServer的信息
	self:onGameTableUpdateTableData()
	-- 返回玩家成功进入房间的包
	self:onSendUserLoginSuccess(pUser)
	-- 上报给backendServer对战场的状态
	self:onSendBackendBattleRoomInfo()
	-- 将房间的命令和等级给用户
	self:onSendUserTableLevelAndName(pUser)
	-- 广播房间内的玩家有玩家进入
	self:onBroadcastUserEnterTable(pUser)
	-- 通知agent登录成功
	self:onSetUserdAndGameTable(userId, socketfd)
	-- 如果已经准备则广播准备并检查是否可以开始游戏
	if pUser:isReady() then
		self:onServerBroadcastUserReady(pUser)
		self:onCheckGameTableStartGame()
	end
	return 0
end

function GameTable:onCheckTableIsAlive()
	if self:onGetUserCount() > 0 then
		return true
	end
	if defineType.BATTLE_STATUS_STOP ~= self.m_tableStatus then
		return true
	end
	return false
end

function GameTable:onClientCmdLogin(data, userId, socketfd, diamondClent, moneyClient)
	Log.d(TAG, "userId[%s] socketfd[%s] diamondClent[%s]", userId, socketfd, diamondClent)
	-- 校验玩家的状态
	local pStatus = self:onCheckUserStatus(data, userId, diamondClent, moneyClient)
	Log.d(TAG, "GameTable onClientCmdLogin pStatus[%s]", pStatus)
	if pStatus == defineType.SUCCESS_NEWCONNECT then
		-- 桌子接纳这个玩家了
		local pRet = self:onDealUserLoginTableSuccess(data, userId, socketfd)
		if pRet >= 0 then
			return 0
		end
	elseif pStatus == defineType.SUCCESS_RECONNECT then
		self:onDealUserReconnectTableSuccess(data, userId, socketfd)
	else
		self:onDealUserLoginError(data, userId, socketfd, pStatus)
		-- 如果是房主进入失败，则销毁房间，退回钻石
		if self:isBattleOwner(userId) then
			self:onDismissBattleRoom(defineType.BATTLE_DISSMISS_MASTER_LEAVE)
		end
	end
	return -1
end

function GameTable:onDealUserReconnectTableSuccess(data, userId, socketfd)
	Log.d(TAG, "GameTable onDealUserReconnectTableSuccess userId[%s]", userId)
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then
		Log.d(TAG, "onDealUserReconnectTableSuccess not pUser")
		return -1
	end
	-- 将玩家的socketfd更新
	pUser.m_socketfd = socketfd
	-- 发送重连信息
	self:onSendUserReconnetSucccess(userId)
	-- 重连成功则标识为在线
	pUser.m_isOnline = true
	-- 更新
	self:onUpdateRoomUserCount(userId, defineType.USER_LOGIN)
	-- 发送房间信息
	self:onSendUserTableLevelAndName(pUser)
	-- 从离线列表中去掉
	local pRet = skynet.call(self.m_gameServer, "lua", "onClearOnUserDisconnect", userId)
	-- 通知agent重连成功
	self:onSetUserdAndGameTable(userId, socketfd)
end

function GameTable:onDealUserLoginError(data, userId, socketfd, status)
	if not userId or not socketfd or not status then
		return -1
	end
	Log.d(TAG, "GameTable onDealUserLoginError userId[%s] socketfd[%s] status[%s]", userId, socketfd, status)
	if 1 == data.iIsRobot then
		self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
		-- self:onSendRobotUserLoginError(socketfd, status)
	else
		if defineType.ERROR_TABLE_MAX_COUNT == status or defineType.ERROR_TABLE_NOT_EXIST == status then
			if self:isBattleRoom() then
				self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
				self:onSendUserLoginError(socketfd, status)
			else
				local pRet = skynet.call(self.m_gameServer, "lua", "onCreatANewGameTable", data, socketfd)
			end
		elseif defineType.ERROR_USERLOGINTABLE == status then
			self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
			self:onSendUserLoginError(socketfd, status)
		else
			self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
			self:onSendUserLoginError(socketfd, status)
		end
	end
end

function GameTable:onRemoveUser(user)
	Log.d(TAG, "GameTable onRemoveUser")
	if not user then
		return -1
	end
	-- 去掉gameserver上的键值对
	local pRet = skynet.call(self.m_gameServer, "lua", "onRemoveUser", user.m_userId)
	-- 如果当前玩家确实存在，则移除该玩家
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] and self.m_tableUserMap[i] == user then
			self.m_tableUserMap[i] = nil
			break
		end
	end
	delete(user)
	return 0
end

function GameTable:onUserCanLogoutTable(user)
	Log.d(TAG, "GameTable onUserCanLogoutTable userId[%s], self.m_tableStatus[%s]", user.m_userId, self.m_tableStatus)
	if self:isBattleRoom() then
		if self.m_tableStatus == defineType.BATTLE_STATUS_STOP or self.m_tableStatus == defineType.BATTLE_STATUS_CREATED then
			return true
		end
		return false
	else
		if self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
			return false
		end
		return true
	end
	return true
end


function GameTable:onCheckSameIpAndShowTips()
	local pUserTable = {}
	for i = 1, self:onGetMaxUserCount() do
		for j = i + 1, self:onGetMaxUserCount() do
			if self.m_tableUserMap[i].m_clientIp == self.m_tableUserMap[j].m_clientIp then
				pUserTable[#pUserTable + 1] = {}
			end
		end
	end
end

function GameTable:onDismissBattleRoom(disType)
	Log.d(TAG, "GameTable onDismissBattleRoom disType[%s]", disType)
	if not self:isBattleRoom() then
		return -1
	end
	-- 退回开房消耗
	self:onRefundBattlePay()
	-- 踢掉所有人
	for i = 1, self:onGetMaxUserCount() do
		local pUser = self.m_tableUserMap[i]
		if pUser then
			Log.d(TAG, "ssssssssssssssssssssssssssssssssss")
			-- 退出房间
			self:onSendUserLogoutSuccess(pUser, disType)
			-- 处理玩家退出
			self:onDealUserLogoutTableSuccess(pUser.m_userId)
		end
	end
	-- 通知allocServer桌子解散
	self:onUpdateBattleRoomData(defineType.BATTLE_RELEASE)
	-- 桌子状态重置
	self:onResetTable()
	self:onClearUserTableInfo()
	return 0
end

function GameTable:onClearUserTableInfo()
	Log.d(TAG, "GameTable onClearUserTableInfo")
	local pHashKey = string.format("%s:bb_run:%d", self.m_commonConfig.iMJCode, self.m_battleConfig.iUserId)
	local pHashBattleId = self.m_battleConfig.iBattleId
	local cmd = socketCmd.BACKEND_CMD_EXCUTE_REDIS
	local info = {}
	info.iCmdType = 1
	info.iCmdStr1 = pHashKey
	info.iCmdStr2 = pHashBattleId
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToBackendServer", cmd, info)
	-- 从系统保存的列表中删除对战的信息
	local pHashKey = string.format("%s:bb_run:list:%d", self.m_commonConfig.iMJCode, self.m_serverId)
	local pListTable = {}
	pListTable.uid = self.m_battleConfig.iUserId
	pListTable.battleid = self.m_battleConfig.iBattleId
	local pListJson = json.encode(pListTable)
	local cmd = socketCmd.BACKEND_CMD_EXCUTE_REDIS
	local info = {}
	info.iCmdType = 2
	info.iCmdStr1 = pHashKey
	info.iCmdStr2 = pListJson
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToBackendServer", cmd, info)
end

function GameTable:onClientCmdCreateBattleRoom(data, userId, socketfd)
	Log.d(TAG, "GameTable onClientCmdCreateBattleRoom")
	self:onSetBattleRoomConfig(data)
	Log.d(TAG, "m_tableId[%s], m_level[%s], m_serverId[%s]", self.m_tableId, self.m_level, self.m_serverId)
	-- 将对战场的信息保存到redis
	local pHashKey = string.format("%s:bb_run:list:%d", self.m_commonConfig.iMJCode, self.m_serverId)
	local pListTable = {}
	pListTable.uid = self.m_battleConfig.iUserId
	pListTable.battleid = self.m_battleConfig.iBattleId
	local pListJson = json.encode(pListTable)
	local cmd = socketCmd.BACKEND_CMD_EXCUTE_REDIS
	local info = {}
	info.iCmdType = 3
	info.iCmdStr1 = pHashKey
	info.iCmdStr2 = pListJson
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToBackendServer", cmd, info)
	self:onGameTableUpdateTableData()
	return 0
end

function GameTable:onDealUserLogoutTableSuccess(userId)
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then
		return -1
	end
	-- 广播用户退出房间
	self:onBroadcastUserLogoutTable(pUser)
	-- 处理redis
	self:onDealUserLogoutTableRedis(pUser)
	-- 移除这个玩家
	self:onRemoveUser(pUser)
	-- 上报用户退出
	self:onUpdateRoomUserCount(userId, defineType.USER_LOGOUT)
	-- 上报给backendServer对战场的状态
	self:onSendBackendBattleRoomInfo()
end

function GameTable:onRefundBattlePay()
	if not self:isBattleRoom() then
		return
	end 
	if not self.m_battleFeePaid or self:isWinerPay() or defineType.BATTLE_STATUS_CREATED ~= self.m_tableStatus then
		return
	end
	if self:isBattlePayDiamond() then
		-- 返回钻石
		local pDiamond = self:onGetBattlePayNum()
		local pUpdateTable = {
			{
				iUserId = self.m_battleConfig.iUserId,
				iType = 0,
				iUpdateDiamond = pDiamond,
				iFrom = self.m_battleConfig.iFrom,
			},
		}
		self:onUpdateUserDiamond(pUpdateTable, self.m_battleConfig.iUserId, defineType.ActId_Diamond_back)
	elseif self:isBattlePayMoney() then

	end
end

function GameTable:onAddNewUser(data, userId, socketfd)
	-- 先分配座位号
	local pSeatId = self:onAutoSeat()
	if pSeatId <= 0 or pSeatId > self:onGetMaxUserCount() then
		return nil
	end
	local pNewUser = new(require("logic/common/gameUser"), userId, pSeatId, socketfd)
	pNewUser:onSetUserInfo(data)
	self.m_tableUserMap[pSeatId] = pNewUser
	return pNewUser
end

function GameTable:onAutoSeat()
	for i = 1, self:onGetMaxUserCount() do
		if not self.m_tableUserMap[i] then
			return i
		end
	end
	return -1
end

--------------------------------------- gameServer ------------------------------
function GameTable:onGameTableUpdateTableData()
	local data = {}
	data.iTableId = self.m_tableId
	data.iGameTable = skynet.self()
	data.iGameTableInfo = {}
	data.iGameTableInfo.iTableStatus = self.m_tableStatus
	data.iGameTableInfo.iIsAlive = self:onCheckTableIsAlive()
	data.iGameTableInfo.iCommonConfig = {
		iRoomId = self.m_commonConfig.iRoomId,
		iTableId = self.m_commonConfig.iTableId,
		iUserCount = self:onGetUserCount(),
		iMJCode = self.m_commonConfig.iMJCode,
	}
	if self:isBattleRoom() then
		data.iGameTableInfo.iBattleConfig = {
			iRoomId = self.m_battleConfig.iRoomId,
			iUserId = self.m_battleConfig.iUserId,
			iTableId = self.m_battleConfig.iTableId,
			iPlayType = self.m_battleConfig.iPlayType,
		}
	end
	data.iUserTable = {}
	for i = 1, self:onGetMaxUserCount() do
		local pTtemp = {}
		if self.m_tableUserMap[i] then
			-- Log.d(TAG, "[%s] is not nil [%s] [%s]", i, self.m_tableUserMap[i].m_userId, self.m_tableUserMap[i].m_socketfd)
			pTtemp.iUserId = self.m_tableUserMap[i].m_userId
			pTtemp.iSocketFd = self.m_tableUserMap[i].m_socketfd
			data.iUserTable[#data.iUserTable + 1] = pTtemp
		end
	end
	local pRet = skynet.call(self.m_gameServer, "lua", "onGameTableUpdateTableData", data)
end

--------------------------------------- redis -----------------------------------
function GameTable:onDealUserLoginTableRedis(pUser)
	if not pUser then
		return -1
	end
	local key = "mt_"..pUser.m_userId
	local pPort = self.m_commonConfig.iListenPort
	local pMjCode = self.m_commonConfig.iMJCode
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "HMSet", "mtkeyRedis", key, "uid", pUser.m_userId, "tid", self.m_tableId, "svid", self.m_serverId, "from", pUser.m_from, "port", pPort, "gamecode", pMjCode)
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Expire", "mtkeyRedis", key, 3600 * 3)
	local key = "svidOnline_"..self.m_serverId
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "SAdd", "mtkeyRedis", key, pUser.m_userId)
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Expire", "mtkeyRedis", key, 3600 * 3)
end

function GameTable:onDealUserLogoutTableRedis(pUser)
	if not pUser then
		return -1
	end
	local key = "mt_"..pUser.m_userId
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "HMSet", "mtkeyRedis", key, "uid", 0, "tid", 0, "svid", 0, "gamecode", 0)
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Expire", "mtkeyRedis", key, 3600 * 3)
	local key = "svidOnline_"..self.m_serverId
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "SREM", "mtkeyRedis", key, pUser.m_userId)
	local pRedisRet = skynet.call(self.m_gameServer, "lua", "onExcuteRedisCmd", "Expire", "mtkeyRedis", key, 3600 * 3)
end

--------------------------------------- 网络包组装函数 -----------------------------
-- 如果userId有值，则不包括该userId
function GameTable:onBroadcastTableUsers(cmd, info, userId)
	userId = userId or -1
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] and self.m_tableUserMap[i].m_userId ~= userId then
			socketManager.send(self.m_tableUserMap[i].m_socketfd, cmd, info, true)
		end
	end
end

function GameTable:onUpdateRoomUserCount(userId, userStatus)
	Log.d(TAG, "onUpdateRoomUserCount userId[%s], userStatus[%s]", userId, userStatus)
	if not userId or not userStatus then
		return
	end
	local pServerUserCount = skynet.call(self.m_gameServer, "lua", "onGetGameServerUserCount")
	local cmd = socketCmd.UPDATE_ROOM_USER_COUNT
	local info = {}
	info.iServerId = self.m_serverId
	info.iTableId = self.m_tableId
	info.iLevel = self.m_level
	info.iUserCount = self:onGetUserCount()
	info.iServerUserCount = pServerUserCount
	info.iUserId = userId
	info.iStatus = userStatus
	info.iSwapCards = self.m_commonConfig.iSwapCards
	info.iPlayType = self.m_commonConfig.iPlayType
	info.iWanFa = self.m_commonConfig.iWanFa
	info.iMatchId = self.m_commonConfig.iMatchId
	info.iRoomId = self.m_commonConfig.iRoomId
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToAllocServer", cmd, info)
end

function GameTable:onUpdateBattleRoomData(status)
	Log.d(TAG, "GameTable onUpdateBattleRoomData status[%s]", status)
	local cmd = socketCmd.UPDATE_BATTLE_ROOM_DATA
	local info = {}
	info.iStatus = status
	info.iRoomId = self.m_battleConfig.iRoomId
	info.iTableId = self.m_battleConfig.iTableId
	info.iUserId = self.m_battleConfig.iUserId
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToAllocServer", cmd, info)
end

function GameTable:onSendUserLogoutSuccess(user, logoutType)
	Log.d(TAG, "GameTable onSendUserLogoutSuccess")
	local cmd = socketCmd.SERVER_CMD_CLIENT_LOGOUT_SUCCESS
	local info = {}
	info.iLogoutType = logoutType or defineType.USER_REQUEST_BACK_TO_HALL
	socketManager.send(user.m_socketfd, cmd, info, true)
end

function GameTable:onBroadcastUserLogoutTable(user)
	Log.d(TAG, "GameTable onBroadcastUserLogoutTable")
	local cmd = socketCmd.SERVER_BROADCAST_USER_LOGOUT
	local info = {}
	info.iUserId = user.m_userId
	self:onBroadcastTableUsers(cmd, info, user.m_userId)
end

function GameTable:onServerBroadcastUserReady(user)
	local cmd = socketCmd.SERVER_BROADCAST_USER_READY
	local info = {}
	info.iUserId = user.m_userId
	self:onBroadcastTableUsers(cmd, info)
end

function GameTable:onSendUserTableLevelAndName(user)
	local cmd = socketCmd.SERVER_CMD_CLINET_TABLE_LEVEL_AND_NAME
	local info = {}
	info.iMJCode = self.m_commonConfig.iMJCode
	info.iLevel = self.m_level
	info.iTableId = self.m_tableId
	info.iName = self.m_commonConfig.iTableName
	socketManager.send(user.m_socketfd, cmd, info, true)
end

function GameTable:onSendUserLoginSuccess(user)
	local pUser = user
	if not pUser then
		return -1
	end
	local cmd = socketCmd.SERCER_CMD_CLIENT_LOGIN_SUCCESS
	local info = {}
	info.iMJCode = self.m_commonConfig.iMJCode
	info.iPlayType = self.m_commonConfig.iPlayType
	info.iBasePoint = self.m_commonConfig.iBasePoint
	info.iServerFee = self.m_commonConfig.iServerFee
	info.iRoundNum = 1 -- 这个是圈风的标识，贵阳没用，先写死
	info.iSeatId = pUser:onGetSeatId()
	info.iMoney = pUser.m_money
	if self:isBattleRoom() then
		info.iMoney = pUser:onGetTurnMoney()
	end
	info.iMaxUserCount = self:onGetMaxUserCount()
	info.iMaxCardCount = self:onGetMaxCardCount()
	info.iUserCount = self:onGetUserCount() - 1
	info.iUserTable = {}
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] and pUser ~= self.m_tableUserMap[i] then
			local pTemp = {}
			pTemp.iUserId = self.m_tableUserMap[i].m_userId
			pTemp.iSeatId = self.m_tableUserMap[i].m_seatId
			pTemp.iReady = self.m_tableUserMap[i].m_ready
			pTemp.iUserInfoStr = self.m_tableUserMap[i].m_userInfoStr
			pTemp.iMoney = self.m_tableUserMap[i].m_money
			info.iUserTable[#info.iUserTable + 1] = pTemp
		end
	end
	info.iOutCardTime = self.m_commonConfig.iOutCardTime - 1
	info.iOperationTime = self.m_commonConfig.iOperationTime - 1
	info.iIsBattleRoom = 0
	if self:isBattleRoom() then
		info.iIsBattleRoom = 1
		info.iBattleConfig = {}
		info.iBattleConfig.iRoomId = self.m_battleConfig.iRoomId
		info.iBattleConfig.iTableId = self.m_battleConfig.iTableId
		info.iBattleConfig.iUserId = self.m_battleConfig.iUserId
		info.iBattleConfig.iMJCode = self.m_battleConfig.iMJCode
		info.iBattleConfig.iRoundNum = self.m_battleConfig.iRoundNum
		info.iBattleConfig.iPlayType = self.m_battleConfig.iPlayType
		info.iBattleConfig.iBasePoint = self.m_commonConfig.iBasePoint
		info.iBattleConfig.iExtendInfo = ""
	end
	socketManager.send(user.m_socketfd, cmd, info, true)
end

function GameTable:onBroadcastUserEnterTable(user)
	local cmd = socketCmd.SERVER_BROADCAST_USER_LOGIN
	local info = {}
	info.iUserId = user.m_userId
	info.iSeatId = user.m_seatId
	info.iReady = user.m_ready
	info.iMoney = user.m_money
	info.iUserInfoStr = user.m_userInfoStr
	info.iFrom = user.m_from
	self:onBroadcastTableUsers(cmd, info, user.m_userId)
end

function GameTable:onSendBackendTableInfo(userInfoMap)
	if not userInfoMap then
		return
	end
	local pUsersInfoTable = {}
	for k, v in pairs(userInfoMap) do

	end
	local cmd = socketCmd.BACKEND_CMD_WRITE_LOG
	local info = {}
	info.iMJCode = self.m_commonConfig.iMJCode
	info.iTableId = self.m_commonConfig.iTableId
	info.iLevel = self.m_level
	info.iBasePoint = self.m_commonConfig.iBasePoint
	info.iServerFee = self.m_commonConfig.iServerFee
	info.iServerId = self.m_serverId
	info.iGameStartTime = self.m_commonConfig.iGameStartTime
	info.iGameEndTime = self.m_commonConfig.iGameEndTime
	info.iUserCount = self:onGetUserCount()
	info.iUserInfoTable = userInfoMap
	for i = 1, #userInfoMap do
		local pCardsInfoStr = "["
		-- 手牌
		for j = 1, #userInfoMap[i].iHandCardTable do
			local pMahjong = userInfoMap[i].iHandCardTable[j]
			pCardsInfoStr = pCardsInfoStr..string.format("%s[%s]", (1 == j and "" or ","), pMahjong.iValue)
		end
		-- 吃碰杠的牌
		for j = 1, #userInfoMap[i].iChiTable do
			local pMahjong = userInfoMap[i].iHandCardTable[j]
			pCardsInfoStr = pCardsInfoStr..string.format("%s[%s]", (1 == j and "" or ","), pMahjong.iValue)
		end
	end
end

function GameTable:onSendBackendBattleRoomInfo()
	if not self:isBattleRoom() or not self:onCheckTableIsAlive() then
		Log.d(TAG, "GameTable onSendBackendBattleRoomInfo failed isBattleRoom onCheckTableIsAlive false")
		return -1
	end
	local pStatus = 1
	if defineType.BATTLE_STATUS_CREATED == self.m_tableStatus then
		pStatus = 0  -- 创建没进行
	elseif defineType.BATTLE_STATUS_STOP == self.m_tableStatus then
		pStatus = 2
	end
	local pInnerLog = {}
	for i = 1, self:onGetMaxUserCount() do
		local pUser = self.m_tableUserMap[i] 
		if pUser then
			pInnerLog[""..pUser.m_userId] = pUser.m_money
		end
	end
	-- Log.dump(TAG, pInnerLog, "pInnerLog")
	local pJsonTable = {
		battleid = self.m_battleConfig.iBattleId,
		timestamp = self.m_battleConfig.iCreateTime,
		status = pStatus,
		owner = self.m_battleConfig.iUserId,
		playround = self.m_battleConfig.iRoundNum,
		currentround = self.m_battleConfig.iCurRound,
		fid = self.m_battleConfig.iRoomId,
		basechip = self.m_battleConfig.iBasePoint,
		playtype = self.m_battleConfig.iPlayType,
		bei = 0,
		svid = self.m_serverId,
		from = self.m_battleConfig.iFrom,
		free = self.m_battleFreeOpenRoom,
		player = json.encode(pInnerLog)
	}
	local pKey = string.format("%s:bb_run:%d", self.m_commonConfig.iMJCode, self.m_battleConfig.iUserId)
	local cmd = socketCmd.BACKEND_CMD_BATTLE_LOG_GY
	local info = {}
	info.iBattleKey = pKey
	info.iBattleId = self.m_battleConfig.iBattleId
	info.iBattleInfo = json.encode(pJsonTable)
	local pRet = skynet.call(self.m_gameServer, "lua", "onSendToBackendServer", cmd, info)
end

function GameTable:onSendUserLoginError(socketfd, errorType)
	local cmd = socketCmd.SERVER_CMD_CLIENT_LOGIN_ERROR
	local info = {}
    info.iErrorType = errorType or defineType.ERROR_MYSQL
    socketManager.send(socketfd, cmd, info, true)
end

function GameTable:onSendUserReconnetSucccess(userId)
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then
		return -1
	end
	-- if self.m_tableStatus == defineType.BATTLE_STATUS_PAUSE or not pUser.m_isOnline then
		local cmd = socketCmd.SERVER_CMD_CLIENT_RECONNECT_SUCCESS
		local info = {}
		info.iMJCode = self.m_commonConfig.iMJCode
		info.iPlayType = self.m_commonConfig.iPlayType
		info.iServerFee = self.m_commonConfig.iServerFee
		info.iBasePoint = self.m_commonConfig.iBasePoint
		info.iOutCardTime = self.m_commonConfig.iOutCardTime - 1
		info.iOperationTime = self.m_commonConfig.iOperationTime - 1
		info.iUserId = userId
		info.iMaxUserCount = self:onGetMaxUserCount()
		info.iMaxCardCount = self:onGetMaxCardCount()
		info.iIsInGame = self.m_tableStatus == defineType.GAME_STATUS_PLAYING and 1 or 0
		info.iBankSeatId = 0
		info.iRemainCard = 0
		if 1 == info.iIsInGame then
			info.iBankSeatId = self.m_gameRound.m_pBankerSeatId
			info.iBankSeatId = self.m_gameRound:onGetRemainCardCount()
		end
		info.iUserCount = self:onGetUserCount()
		info.iPlayerTable = {}
		for i = 1, self:onGetUserCount() do
			local tpUser = self.m_tableUserMap[i]
			if tpUser then
				local temp = {}
				if 1 == info.iIsInGame then
					temp = self.m_gameRound:onGetUserReconnectGameInfo(i)
				else
					temp.iIsAI = 0
					temp.iHandCardCount = 0
					temp.iHandleCardCount = 0
					temp.iOutCardCount = 0
					temp.iCurGradCard = 0
					temp.iExtendInfo = ""
				end
				temp.iUserId = tpUser:onGetUserId()
				temp.iSeatId = tpUser:onGetSeatId()
				temp.iUserInfoStr = tpUser.m_userInfoStr
				temp.iMoney = tpUser.m_money
				info.iPlayerTable[#info.iPlayerTable + 1] = temp
			end
		end
		if self:isBattleRoom() then
			info.iIsBattleRoom = 1
			info.iBattleConfig = {}
			info.iBattleConfig.iRoomId = self.m_battleConfig.iRoomId
			info.iBattleConfig.iTableId = self.m_battleConfig.iTableId
			info.iBattleConfig.iUserId = self.m_battleConfig.iUserId
			info.iBattleConfig.iMJCode = self.m_battleConfig.iMJCode
			info.iBattleConfig.iRoundNum = self.m_battleConfig.iRoundNum
			info.iBattleConfig.iPlayType = self.m_battleConfig.iPlayType
			info.iBattleConfig.iBasePoint = self.m_battleConfig.iBasePoint
			info.iBattleConfig.iCurRound = self.m_battleConfig.iCurRound
			info.iBattleConfig.iExtendInfo = ""
			info.iBattleConfig.iUserCount = self:onGetUserCount()
			info.iBattleConfig.iPlayerMoneyTable = {}
			for i = 1, self:onGetMaxUserCount() do
				local tpUser = self.m_tableUserMap[i]
				if tpUser then
					local temp = {}
					temp.iUserId = tpUser:onGetUserId()
					temp.iSeatId = tpUser:onGetSeatId()
					temp.iReady = tpUser:isReady() and 1 or 0
					temp.iMoneyTable = {}
					for j = 1, self.m_battleConfig.iCurRound - 1 do
						temp.iMoneyTable[j] = 0
					end
					info.iBattleConfig.iPlayerMoneyTable[#info.iBattleConfig.iPlayerMoneyTable + 1] = temp
				end
			end
		else
			info.iIsBattleRoom = 0
		end
		socketManager.send(pUser.m_socketfd, cmd, info, true)
	-- end
end

--------------------------------------- 网络事件 ----------------------------------
-- 玩家掉线
function GameTable:onDisconnect(userId)
	Log.d(TAG, "onDisconnect userId[%s]", userId)
	-- 非正常关闭
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then
		Log.e(TAG, "GameTable onDisconnect pUser is nil")
		return - 1
	end
	-- 将该玩家的socketfd置空
	local pRet = skynet.call(self.m_gameServer, "lua", "onAddOneUserDisconnect", userId)
	pUser.m_isOnline = false
	-- 这里处理玩家应不应该保存桌子信息下来登录重连
	if not self:isBattleRoom() and self.m_tableStatus ~= defineType.GAME_STATUS_PLAYING then
		local data = {}
		self:onClientCmdLogout(data, userId, pUser.m_socketfd)
	end
end

-------------------------------------- cmd函数 ------------------------------
function GameTable:onClientCmdReady(data, userId, socketfd)
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then return end
	if 1 ~= pUser.m_ready then
		pUser.m_ready = 1
		self:onServerBroadcastUserReady(pUser)
	end
	self:onCheckGameTableStartGame()
end

function GameTable:onClientCmdLogout(data, userId, socketfd)
	Log.d(TAG, "GameTable onClientCmdLogout userId[%s] isBattleRoom[%s], isBattleOwner[%s]", userId, self:isBattleRoom(), self:isBattleOwner(userId))
	local pUser = self:onGetUserByUserId(userId)
	if not pUser then 
		Log.e(TAG, "onClientCmdLogout pUser is nil")
		return -1 
	end
	if not self:onUserCanLogoutTable(pUser) then
		return -1
	end
	-- 如果是房主离开房间
	if self:isBattleRoom() and self:isBattleOwner(userId) then
		if 1 == data.iLeave then -- 不解散房间
			-- 返回房主退出房间
			self:onSendUserLogoutSuccess(pUser, defineType.BATTLE_MASTER_LEAVE_AND_RESERVE)
			-- 处理玩家退出房间
			self:onDealUserLogoutTableSuccess(userId)
		else -- 解散房间
			self:onDismissBattleRoom(defineType.BATTLE_DISSMISS_MASTER_LEAVE)
		end
	elseif self:isBattleRoom() then
		-- 返回退出房间
		self:onSendUserLogoutSuccess(pUser, defineType.USER_REQUEST_BACK_TO_HALL)
		-- 处理玩家退出房间
		self:onDealUserLogoutTableSuccess(userId)
		-- 判断一下  如果该房间已经打完，且玩家全部退出
		if self:onGetUserCount() == 0 and self.m_tableStatus == defineType.BATTLE_STATUS_STOP then
			self:onDismissBattleRoom(defineType.BATTLE_DISSMISS_MASTER_LEAVE)
		end
	else
		-- 返回退出房间
		self:onSendUserLogoutSuccess(pUser, defineType.USER_REQUEST_BACK_TO_HALL)
		-- 处理玩家退出房间
		self:onDealUserLogoutTableSuccess(userId)
	end
	return 0
end

function GameTable:onClientCmdChat(data, userId, socketfd)
	local cmd = socketCmd.CLIENT_CMD_CHAT
	local info = {}
	info.iUserId = userId
	info.iMsg = data.iMsg
	self:onBroadcastTableUsers(cmd, info)
end

function GameTable:onClientCmdFace(data, userId, socketfd)
	local cmd = socketCmd.CLIENT_CMD_FACE
	local info = {}
	info.iUserId = userId
	info.iFaceType = data.iFaceType
	self:onBroadcastTableUsers(cmd, info)
	-- 这里添加机器人
	if 1 == data.iFaceType then
		self:onAddOneRobotUser()
	end
end

function GameTable:onClientCmdOutCard(data, userId, socketfd)
	if self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
		self.m_gameRound:onClientCmdOutCard(data, userId)
	end
end

function GameTable:onClientCmdTakeOpreation(data, userId, socketfd)
	if self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
		self.m_gameRound:onClientCmdTakeOpreation(data, userId)
	end
end

function GameTable:onClientCmdRequestAI(data, userId, socketfd)
	if self.m_tableStatus == defineType.GAME_STATUS_PLAYING then
		self.m_gameRound:onClientCmdRequestAI(data, userId)
	end
end

-------------------------------------- set数据 ------------------------------
function GameTable:onSetUserdAndGameTable(userId, socketfd)
	local pAgent = self:onGetHallAgentBySocketfd(socketfd)
	if pAgent then
		skynet.send(pAgent, "lua", "onSetUserdAndGameTable", userId, skynet.self())
	else
		Log.e(TAG, "pAgent is nil")
	end
end

-------------------------------------- get数据 ------------------------------
function GameTable:onGetUserBySeatId(seatId)
	return seatId and self.m_tableUserMap[seatId] or nil
end

function GameTable:onGetUserByUserId(userId)
	if not userId then return end
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] and self.m_tableUserMap[i].m_userId == userId then
			return self.m_tableUserMap[i]
		end
	end
end

function GameTable:onGetUserCount()
	local pUserCount = 0
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] then
			pUserCount = pUserCount + 1
		end
	end
	return pUserCount
end

function GameTable:onGetRobotUserCount()
	local pUserCount = 0
	for i = 1, self:onGetMaxUserCount() do
		local pUser = self.m_tableUserMap[i]
		if pUser and pUser:isRobot() then
			pUserCount = pUserCount + 1
		end
	end
	return pUserCount
end

function GameTable:onGetReadyUserCount()
	local pUserCount = 0
	for i = 1, self:onGetMaxUserCount() do
		if self.m_tableUserMap[i] and 1 == self.m_tableUserMap[i].m_ready then
			pUserCount = pUserCount + 1
		end
	end
	return pUserCount
end

function GameTable:onGetMaxUserCount()
	return self.m_pPlaytypeConfig.LocalGameCardMap[self.m_commonConfig.iBattleLocalGameType].iMaxUserCount
end

function GameTable:onGetMaxCardCount()
	return self.m_pPlaytypeConfig.LocalGameCardMap[self.m_commonConfig.iBattleLocalGameType].iMaxCardCount
end

function GameTable:onGetDealCardCount()
	return self.m_pPlaytypeConfig.LocalGameCardMap[self.m_commonConfig.iBattleLocalGameType].iDealCardCount
end

function GameTable:onGetHallAgentBySocketfd(socketfd)
	local pServiceMgr = skynet.localname(".ServiceManager")
	if pServiceMgr then
		return skynet.call(pServiceMgr, "lua", "onGetHallAgentBySocketfd", socketfd)
	end
end

function GameTable:onGetBattlePayNum()
	local pPayNum = 0
	if not self:isBattleRoom() then
		return pPayNum
	end
	local pCfg = sharedata.query("FriendBattleConfig")
	if pCfg[self.m_commonConfig.iBattleLocalGameType] then
		pPayNum = pCfg[self.m_commonConfig.iBattleLocalGameType].iDiamondTable[self.m_battleConfig.iRoundNum]
		pPayNum = pPayNum and pPayNum or 1
	end
	return pPayNum
end

-------------------------------------- 判断数据 ------------------------------
function GameTable:isBattleDayFirstFree()
	return 1 == self.m_battleConfig.iBattleDayFirstFree
end

function GameTable:isBattlePayDiamond()
	return 1 == self.m_commonConfig.iBattlePayType
end

function GameTable:isBattlePayMoney()
	return 2 == self.m_commonConfig.iBattlePayType
end

function GameTable:isBattleRoom()
	return 1 == self.m_commonConfig.iIsBattleRoom
end

-- 是否是房主
function GameTable:isBattleOwner(userId)
	return 1 == self.m_commonConfig.iIsBattleRoom and userId == self.m_battleConfig.iUserId
end

-- 玩法相关函数
function GameTable:isWinerPay()
	return self:isBattleRoom() and defineType.BATTLE_PAY_WINER == self.m_battleConfig.iBattlePayMode
end

----------------------------------- cmd网络数据处理 ------------------------------
-- decypt解密
function GameTable:onReceiveData(socketfd, userId, cmd, buffer, decypt)
	-- 首先判断该玩家在不在，去掉极端情况下的错误
	if not self:onGetUserByUserId(userId) then
		-- 判断如果返回这个，agent直接关闭
		return -1111
	end
	if cmd and self.s_cmdFuncMap[cmd] then
		Log.d(TAG, "receiveData socketfd=[%d], cmd=[0x%04x] decypt[%s]", socketfd, cmd, decypt or false)
		local data = socketManager.receive(cmd, buffer, decypt)
		return cs(self.s_cmdFuncMap[cmd], self, data, userId, socketfd)
	end
end

function GameTable:initCmdFunction()
	self.s_cmdFuncMap = {
		-- hallServer
		[socketCmd.CLIENT_CMD_READY] = self.onClientCmdReady,
		[socketCmd.CLIENT_CMD_LOGOUT] = self.onClientCmdLogout,
		[socketCmd.CLIENT_CMD_CHAT]	= self.onClientCmdChat,
		[socketCmd.CLIENT_CMD_FACE]	= self.onClientCmdFace,


		[socketCmd.CLIENT_CMD_OUT_CARD] = self.onClientCmdOutCard,
		[socketCmd.CLIENT_CMD_TAKE_OPERATION] = self.onClientCmdTakeOpreation,
		[socketCmd.CLIENT_CMD_REQUEST_AI] = self.onClientCmdRequestAI,
	}
end

return GameTable
