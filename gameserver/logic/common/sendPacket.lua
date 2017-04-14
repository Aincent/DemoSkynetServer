local skynet = require("skynet")
local socketCmd = require("logic/common/socketCmd")

local TAG = "sendPacket"

local sendPacket = {}

function sendPacket.onServerCmdClientLoginError(packet, info)
	packet:writeInt(info.iErrorType)
end

function sendPacket.onRegisterAllocClient(packet, info)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iAllocLevel)
	packet:writeInt(info.iIsGamaServer)
	packet:writeInt(info.iAllocServerId)
	packet:writeInt(info.iBaseChips)
	packet:writeInt(info.iOutCardTime)
	packet:writeInt(info.iDingQue)
	packet:writeInt(info.iSwapCards)
	packet:writeInt(info.iPlayType)
end

function sendPacket.onReportServerData(packet, info)
	packet:writeShort(info.iAllocServerId)
	packet:writeShort(info.iAllocLevel)
	packet:writeInt(info.iRoomCount)
	packet:writeInt(info.iUserCount)
	for i = 1, info.iRoomCount do
		packet:writeInt(info.iTableList[i].iTableId)
		packet:writeInt(info.iTableList[i].iMJCode)
		packet:writeShort(info.iTableList[i].iUserCount)
		packet:writeInt(info.iTableList[i].iRoomId)
	end
end

function sendPacket.onReportServerIpPort(packet, info)
	packet:writeShort(info.iAllocServerId)
	packet:writeInt(info.iListenPort)
	packet:writeString(info.iListenIp)
	packet:writeInt(info.iIsRetire)
end

function sendPacket.onReportBattleData(packet, info)
	packet:writeShort(info.iServerId)
	packet:writeShort(info.iLevel)
	packet:writeInt(info.iAliveBattleRoom)
	for i = 1, info.iAliveBattleRoom do
		packet:writeInt(info.iTableList[i].iRoomId)
		packet:writeInt(info.iTableList[i].iUserId)
		packet:writeInt(info.iTableList[i].iTableId)
		packet:writeInt(info.iTableList[i].iPlayType)
		packet:writeInt(info.iTableList[i].iTableStatus)
	end
end 

function sendPacket.onDaoJuServerMainCmd(packet, info)
	packet:writeInt(info.iSwitchCmd)
	if info.iSwitchCmd == socketCmd.SERVER_GET_DIAM_NUM then
		packet:writeInt(info.iUserCount)
		for k, v in pairs(info.iUserIdTable) do
			packet:writeInt(v)
		end
	elseif info.iSwitchCmd == socketCmd.SERVER_UPDATE_DIAM_NUM then
		packet:writeInt(info.iMJCode)
		packet:writeInt(info.iAction)
		packet:writeInt(info.iUpdateCount)
		for k, v in pairs(info.iUpdateTable) do
			packet:writeInt(v.iUserId)
			packet:writeInt(v.iType)
			packet:writeInt(v.iUpdateDiamond)
			packet:writeInt(v.iFrom)
		end
	end
end

function sendPacket.onServerCmdClientLoginSuccess(packet, info)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iPlayType)
	packet:writeInt(info.iBasePoint)
	packet:writeInt(info.iServerFee)
	packet:writeShort(info.iRoundNum)
	packet:writeInt(info.iSeatId)
	packet:writeInt64(info.iMoney)
	packet:writeByte(info.iMaxUserCount)
	packet:writeInt(info.iMaxCardCount)
	packet:writeInt(info.iUserCount)
	for i = 1, info.iUserCount do
		packet:writeInt(info.iUserTable[i].iUserId)
		packet:writeInt(info.iUserTable[i].iSeatId)
		packet:writeInt(info.iUserTable[i].iReady)
		packet:writeString(info.iUserTable[i].iUserInfoStr)
		packet:writeInt64(info.iUserTable[i].iMoney)
	end
	packet:writeShort(info.iOutCardTime)
	packet:writeShort(info.iOperationTime)
	if 1 == info.iIsBattleRoom then
		packet:writeByte(1)
		packet:writeInt(info.iBattleConfig.iRoomId)
		packet:writeInt(info.iBattleConfig.iTableId)
		packet:writeInt(info.iBattleConfig.iUserId)
		packet:writeInt(info.iBattleConfig.iMJCode)
		packet:writeInt(info.iBattleConfig.iRoundNum)
		packet:writeInt(info.iBattleConfig.iPlayType)
		packet:writeInt(info.iBattleConfig.iBasePoint)
		packet:writeString(info.iBattleConfig.iExtendInfo)
	else
		packet:writeByte(0)
	end
end

function sendPacket.onServerCmdClientTableLevelAndName(packet, info)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iLevel)
	packet:writeInt(info.iTableId)
	packet:writeString(info.iName)
end

-- TODO 这个是非对战场
function sendPacket.onServerCmdClientReayCountDown(packet, info)
	-- packet:
end

function sendPacket.onServerBroadcastUserLogin(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeInt(info.iSeatId)
	packet:writeInt(info.iReady)
	packet:writeString(info.iUserInfoStr)
	packet:writeInt(info.iMoney)
	packet:writeInt(info.iFrom)
end

function sendPacket.onServerBroadcastUserReady(packet, info)
	packet:writeInt(info.iUserId)
end

function sendPacket.onServerCmdLogoutSuccess(packet, info)
	packet:writeInt(info.iLogoutType)
end

function sendPacket.onServerBroadcastUserLogout(packet, info)
	packet:writeInt(info.iUserId)
end

function sendPacket.onUpdateBattleRoomData(packet, info)
	packet:writeInt(info.iStatus)
	packet:writeInt(info.iRoomId)
	packet:writeInt(info.iTableId)
	packet:writeInt(info.iUserId)
end

function sendPacket.onReportGameUsers(packet, info)
	packet:writeShort(info.iServerId)
	packet:writeInt(info.iTableId)
	packet:writeShort(info.iLevel)
	packet:writeInt(info.iUserCount)
	for i = 1, #info.iUserIdTable do
		packet:writeInt(info.iUserIdTable[i])
	end
end 

function sendPacket.onBackendCmdExcuteRedis(packet, info)
	packet:writeShort(info.iCmdType)
	packet:writeString(info.iCmdStr1)
	packet:writeString(info.iCmdStr2)
end

function sendPacket.onServerDealCard(packet, info)
	packet:writeByte(info.iBankerSeatId)
	packet:writeByte(info.iDiceNum)
	for i = 1, info.iDiceNum do
		packet:writeByte(info.iDiceTable[i])
	end
	packet:writeByte(info.iUserCount)
	for i = 1, info.iUserCount do
		packet:writeByte(info.iHandCardMap[i].iSeatId)
		packet:writeByte(info.iHandCardMap[i].iHandCardCount)
		for j = 1, info.iHandCardMap[i].iHandCardCount do
			packet:writeByte(info.iHandCardMap[i].iHandCards[j])
		end
	end
end

function sendPacket.onServerBroadcastStartGame(packet, info)
	packet:writeInt(info.iUid)
	packet:writeInt(info.iHuaCard)
	for i=1,info.iHuaCard do
		packet:writeByte(info.bHuaCards[i])
	end
end 

function sendPacket.onServerUserSelectQue(packet, info)
	packet:writeInt(info.iSelectedTime)
	packet:writeInt(#info.iRecommendQues)
	for i=1,#info.iRecommendQues do
		packet:writeInt(info.iRecommendQues[i])
	end
end 

function sendPacket.onServerUserBaoTingRet(packet, info)
	packet:writeInt(#info)
	for i=1,#info do
		packet:writeInt(info[i].iUid)
		packet:writeInt(info[i].iBaoTing)
	end
end 

function sendPacket.onServerUserBaoTing(packet, info)
	packet:writeInt(info.iTime)
	packet:writeInt(#info.bTingCards)
	for i=1,#info.bTingCards do
		packet:writeByte(info.bTingCards[i])
	end
end 

function sendPacket.onServerBroadcastSelectPai(packet, info)
	packet:writeByte(#info)
	for i=1,#info do
		packet:writeInt(info[i].iUid)
		packet:writeByte(info[i].bQue)
	end
end 

function sendPacket.onServerCurrentPlayer(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeByte(info.iBuHuaNum)
	for i = 1, info.iBuHuaNum do
		packet:writeByte(info.iBuHuaTable[i])
	end
end 

function sendPacket.onServerGrabCard(packet, info)
	packet:writeByte(info.iBuHuaNum)
	for i = 1, info.iBuHuaNum do
		packet:writeByte(info.iBuHuaTable[i])
	end
	packet:writeByte(info.iCardValue)
	packet:writeByte(info.iOpNum)
	for i = 1, info.iOpNum do
		packet:writeInt(info.iOpTable[i].iOpValue)
		packet:writeByte(info.iOpTable[i].iCardValue)
	end
end 

function sendPacket.onServerInvalidOpt(packet, info)
--empty
end 

function sendPacket.onServerBroadcastTakeOpt(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeInt(info.iOpValue)
	packet:writeByte(info.iCardValue)
	packet:writeByte(info.iTargetSeatId)
	packet:writeByte(info.iOpNum)
	for i = 1, info.iOpNum do
		packet:writeInt(info.iOpTable[i].iOpValue)
		packet:writeByte(info.iOpTable[i].iCardValue)
	end
end 

function sendPacket.onServerBroadcastGFXY(packet, info)
	packet:writeInt(info.iUid)
	packet:writeInt(info.iMoney)
	packet:writeInt64(info.i64CurMoney)
	packet:writeShort(info.sType)
	packet:writeByte(info.bIsPengGang)
	packet:writeByte(#info.tMoneyInfo)
	for i=1,#info.tMoneyInfo do
		packet:writeInt(info.tMoneyInfo[i].iUid)
		packet:writeInt(info.tMoneyInfo[i].iMoney)
		packet:writeInt64(info.tMoneyInfo[i].i64CurMoney)
	end
	packet:writeByte(info.bEnd)
end 

function sendPacket.onServerOptHint(packet, info)
	packet:writeShort(info.sOperType)
	packet:writeByte(info.bCard)
	packet:writeByte(info.bSeatId)
	if info.bByFan then 
		packet:writeByte(info.bByFan)
	end 
end 

function sendPacket.onBroadcastOpTimer(packet, info)
	packet:writeInt(info.iUid)
	packet:writeInt(info.iSeatId)
	packet:writeShort(info.sOutTime)
end 

function sendPacket.onServerBroadcastUserOutcard(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeByte(info.iCardValue)
	packet:writeByte(info.iOpNum)
	for i = 1, info.iOpNum do
		packet:writeInt(info.iOpTable[i].iOpValue)
		packet:writeByte(info.iOpTable[i].iCardValue)
	end
end 

function sendPacket.onServerCmdBroadcastStopRound(packet, info)
	packet:writeByte(info.iResultType) 
	packet:writeInt(info.iServerFee)
	packet:writeInt(info.iBasePoint)
	packet:writeInt(info.iRoundTime)
	packet:writeString(info.iExtendInfo)
	packet:writeByte(info.iUserCount)--玩家数量
	for k, v in pairs(info.iUserInfoTable) do
		packet:writeInt(v.iUserId)
		packet:writeByte(v.iSeatId)
		packet:writeInt64(v.iMoney)
		packet:writeInt64(v.iTurnMoney)
		packet:writeByte(v.iHandCardCount)
		for i = 1, v.iHandCardCount do
			packet:writeByte(v.iHandCardMap[i])
		end
		packet:writeByte(v.iHandleCardCount)
		for i = 1, v.iHandleCardCount do
			packet:writeInt(v.iHandleCardMap[i].iOpValue)
			packet:writeByte(v.iHandleCardMap[i].iCardValue)
		end
		packet:writeByte(v.iOutCardCount)
		for i = 1, v.iOutCardCount do
			packet:writeByte(v.iOutCardMap[i].iCardValue)
			packet:writeByte(v.iOutCardMap[i].iStatus)
			packet:writeByte(v.iOutCardMap[i].iRank)
		end
		packet:writeString(v.iGameStopHuInfo)
	end
end 

function sendPacket.onBackendCmdBattleLogGY(packet, info)
	packet:writeString(info.iBattleKey)
	packet:writeString(info.iBattleId)
	packet:writeString(info.iBattleInfo)
end

function sendPacket.onClientCmdGetRecord(packet, info)
	packet:writeInt(info.iUserId)
end

function sendPacket.onUpdateRoomUserCount(packet, info)
	packet:writeShort(info.iServerId)
	packet:writeInt(info.iTableId)
	packet:writeShort(info.iLevel)
	packet:writeShort(info.iUserCount)
	packet:writeInt(info.iServerUserCount)
	packet:writeInt(info.iUserId)
	packet:writeInt(info.iStatus)
	packet:writeInt(info.iSwapCards)
	packet:writeInt(info.iPlayType)
	packet:writeInt(info.iWanFa)
	packet:writeString(info.iMatchId)
	packet:writeInt(info.iRoomId)
end

function sendPacket.onServerCmdClientReconnectSuccess(packet, info)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iPlayType)
	packet:writeInt(info.iServerFee)
	packet:writeInt(info.iBasePoint)
	packet:writeShort(info.iOutCardTime)
	packet:writeShort(info.iOperationTime)
	packet:writeInt(info.iUserId)
	packet:writeByte(info.iBankSeatId)
	packet:writeByte(info.iMaxUserCount)
	packet:writeInt(info.iMaxCardCount)
	packet:writeInt(info.iRemainCard)
	packet:writeByte(info.iIsInGame)
	packet:writeShort(info.iUserCount)
	for k, v in pairs(info.iPlayerTable) do
		packet:writeInt(v.iUserId)
		packet:writeByte(v.iSeatId)
		packet:writeString(v.iUserInfoStr)
		packet:writeInt64(v.iMoney)
		packet:writeByte(v.iIsAI)
		packet:writeByte(v.iHandCardCount)
		for i = 1, v.iHandCardCount do
			packet:writeByte(v.iHandCardMap[i])
		end
		packet:writeByte(v.iHandleCardCount)
		for i = 1, v.iHandleCardCount do
			packet:writeInt(v.iHandleCardMap[i].iOpValue)
			packet:writeByte(v.iHandleCardMap[i].iCardValue)
		end
		packet:writeByte(v.iOutCardCount)
		for i = 1, v.iOutCardCount do
			packet:writeByte(v.iOutCardMap[i].iCardValue)
			packet:writeByte(v.iOutCardMap[i].iStatus)
			packet:writeInt(v.iOutCardMap[i].iRank)
		end
		packet:writeByte(v.iCurGradCard)
		packet:writeString(v.iExtendInfo)
	end
	packet:writeByte(info.iIsBattleRoom)
	if 1 == info.iIsBattleRoom then
		packet:writeInt(info.iBattleConfig.iRoomId)
		packet:writeInt(info.iBattleConfig.iTableId)
		packet:writeInt(info.iBattleConfig.iUserId)
		packet:writeInt(info.iBattleConfig.iMJCode)
		packet:writeInt(info.iBattleConfig.iRoundNum)
		packet:writeInt(info.iBattleConfig.iPlayType)
		packet:writeInt(info.iBattleConfig.iBasePoint)
		packet:writeInt(info.iBattleConfig.iCurRound)
		packet:writeString(info.iBattleConfig.iExtendInfo)
		packet:writeInt(info.iBattleConfig.iUserCount)
		for k, v in pairs(info.iBattleConfig.iPlayerMoneyTable) do
			packet:writeInt(v.iUserId)
			packet:writeByte(v.iSeatId)
			packet:writeByte(v.iReady)
			for i = 1, info.iBattleConfig.iCurRound - 1 do
				packet:writeInt(v.iMoneyTable[i])
			end
		end
	end
end

function sendPacket.onClientCmdChat(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeString(info.iMsg)
end

function sendPacket.onClientCmdFace(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeInt(info.iFaceType)
end

function sendPacket.onRobotIntrcmdRequestAI(packet, info)
	packet:writeInt(info.iServerId)
	packet:writeString(info.iListenIp)
	packet:writeInt(info.iListenPort)
	packet:writeInt(info.iTableId)
	packet:writeInt(info.iLevel)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iCurRobotCount)
	packet:writeInt(info.iRobotCount)
	for i = 1, info.iRobotCount do
		packet:writeInt(info.iRobotUserTable[i])
	end
end

function sendPacket.onRobotIntrcmdReportRobotlist(packet, info)
	packet:writeInt(info.iServerId)
	packet:writeInt(info.iLevel)
	packet:writeInt(info.iRobotTableCount)
	for i = 1, info.iRobotTableCount do
		packet:writeInt(info.iRobotCountTable[i].iTableId)
		packet:writeInt(info.iRobotCountTable[i].iRobotCount)
	end
end

function sendPacket.onAutoAICmdRobotPacket(packet, info)
	packet:writeBinary(info.iInnerPacket)
end

function sendPacket.onServerCmdRobotLogin(packet, info)
	info.iRet = -1
	info.iReason = reason
	info.iIsTable = 0
	packet:writeInt(info.iRet)
	packet:writeString(info.iReason)
	packet:writeInt(info.iIsTable)
	if 1 == info.iIsTable then
		packet:writeInt(info.iTableId)
		packet:writeInt(info.iUserCount)
		packet:writeInt(info.iCurRobotCount)
	end
end

function sendPacket.onServerBroadcastReadyStart(packet, info)
	packet:writeInt(info.iBankerSeatId)
	packet:writeShort(info.iDiceNum)
	for i = 1, info.iDiceNum do
		packet:writeShort(info.iDiceTable[i])
	end
	if info.iCurRound then
		packet:writeShort(info.iCurRound)
	end
end

function sendPacket.onServerCmdBroadcastUserAI(packet, info)
	packet:writeInt(info.iUserId)
	packet:writeByte(info.iAiType)  -- 0取消， 1托管
end

function sendPacket.onServerCmdMoneyUpdateReq(packet, info)
	packet:writeInt(info.iMJCode)
	packet:writeInt(info.iUserCount)
	for i = 1, info.iUserCount do
		packet:writeInt(info.iUserId)
		packet:writeInt(info.iFrom)
		packet:writeInt(info.iTurnMoney)
		packet:writeString(info.iAction)
	end
end

-- 分发函数
function sendPacket.send(packet, cmd, info)
	if not packet or not cmd then
		return
	end
	if sendPacket.s_cmdFuncMap[cmd] then
		Log.d(TAG, "--- sendPacket cmd[0x%04x] ---", cmd)
		Log.dump(TAG, info, "info")
		Log.d(TAG, "------------------------------")
		packet:writeBegin(cmd)
		sendPacket.s_cmdFuncMap[cmd](packet, info)
		packet:writeEnd()
		return true
	else
		Log.e(TAG, "sendPacket cmd[0x%04x] not deal", cmd)
		return false
	end
end

sendPacket.s_cmdFuncMap = {
	-- allocServer
	[socketCmd.REGISTER_ALLOC_CLIENT] = sendPacket.onRegisterAllocClient,
	[socketCmd.REPORT_SERVER_IP_PORT] = sendPacket.onReportServerIpPort,
	[socketCmd.REPORT_SERVER_DATA] = sendPacket.onReportServerData,
	[socketCmd.REPORT_BATTLE_DATA]    = sendPacket.onReportBattleData,
	[socketCmd.UPDATE_BATTLE_ROOM_DATA] = sendPacket.onUpdateBattleRoomData,
	[socketCmd.REPORT_GAME_USERS]       = sendPacket.onReportGameUsers,
	[socketCmd.UPDATE_ROOM_USER_COUNT] = sendPacket.onUpdateRoomUserCount,

	-- diamond
	[socketCmd.DAOJU_SERVER_MAIN_CMD] = sendPacket.onDaoJuServerMainCmd,

	-- hallServer
	[socketCmd.SERCER_CMD_CLIENT_LOGIN_SUCCESS] = sendPacket.onServerCmdClientLoginSuccess,
	[socketCmd.SERVER_CMD_CLIENT_LOGIN_ERROR] = sendPacket.onServerCmdClientLoginError,
	[socketCmd.SERVER_CMD_CLINET_TABLE_LEVEL_AND_NAME] = sendPacket.onServerCmdClientTableLevelAndName,
	[socketCmd.SERVER_CMD_CLIENT_READY_COUNT_DOWN] = sendPacket.onServerCmdClientReayCountDown,
	[socketCmd.SERVER_BROADCAST_USER_LOGIN]	= sendPacket.onServerBroadcastUserLogin,
	[socketCmd.SERVER_CMD_CLIENT_LOGOUT_SUCCESS] = sendPacket.onServerCmdLogoutSuccess,
	[socketCmd.SERVER_CMD_CLIENT_RECONNECT_SUCCESS] = sendPacket.onServerCmdClientReconnectSuccess,
	[socketCmd.SERVER_BROADCAST_USER_READY]	= sendPacket.onServerBroadcastUserReady,
	[socketCmd.SERVER_BROADCAST_USER_LOGOUT] = sendPacket.onServerBroadcastUserLogout,
	[socketCmd.CLIENT_CMD_CHAT] = sendPacket.onClientCmdChat,
	[socketCmd.CLIENT_CMD_FACE] = sendPacket.onClientCmdFace,

	[socketCmd.SERVER_CMD_DEAL_CARD]  		= sendPacket.onServerDealCard,
	[socketCmd.SERVER_CMD_START_GAME] 		= sendPacket.onServerBroadcastStartGame,
	[socketCmd.SERVER_CMD_USER_SELECT_QUE]  = sendPacket.onServerUserSelectQue,
	[socketCmd.SERVER_CMD_USER_BAO_TING]	= sendPacket.onServerUserBaoTing,
	[socketCmd.CLIENT_CMD_SELECT_PAI]       = sendPacket.onServerBroadcastSelectPai,
	[socketCmd.SERVER_CMD_USER_BAO_TING_RET]= sendPacket.onServerUserBaoTingRet,
	[socketCmd.SERVER_CMD_BROADCAST_CURRENT_PLAYER] = sendPacket.onServerCurrentPlayer,
	[socketCmd.SERVER_CMD_GRAB_CARD]        = sendPacket.onServerGrabCard,
	[socketCmd.SERVER_CMD_INVALID_OPT]      = sendPacket.onServerInvalidOpt,
	[socketCmd.SERVER_CMD_BROADCAST_TAKE_OPERATION] = sendPacket.onServerBroadcastTakeOpt,
	[socketCmd.SERVER_CMD_OPT_HINT]         = sendPacket.onServerOptHint,
	[socketCmd.SERVER_CMD_BROADCAST_USER_OUT_CARD] = sendPacket.onServerBroadcastUserOutcard,

	[socketCmd.SERVER_CMD_BROADCAST_OP_TIME]= sendPacket.onBroadcastOpTimer,
	[socketCmd.SERVER_CMD_BROADCAST_STOP_ROUND] = sendPacket.onServerCmdBroadcastStopRound,
	[socketCmd.SERVER_CMD_BROADCAST_GFXY]   = sendPacket.onServerBroadcastGFXY,
	[socketCmd.SERVER_BROADCAST_READY_START] = sendPacket.onServerBroadcastReadyStart,
	[socketCmd.SERVER_CMD_BROADCAST_USER_AI] = sendPacket.onServerCmdBroadcastUserAI,

	-- backendServer
	[socketCmd.BACKEND_CMD_EXCUTE_REDIS] = sendPacket.onBackendCmdExcuteRedis,
	[socketCmd.BACKEND_CMD_BATTLE_LOG_GY] = sendPacket.onBackendCmdBattleLogGY,

	-- moneyserver
	[socketCmd.CLIENT_CMD_GET_RECORD] = sendPacket.onClientCmdGetRecord,
	[socketCmd.SERVRE_CMD_MONEY_UPDATE_REQ] = sendPacket.onServerCmdMoneyUpdateReq,

	-- robotServer
	[socketCmd.AUTOAICMD_ROBOT_PACKET] = sendPacket.onAutoAICmdRobotPacket,
	[socketCmd.ROBOT_INTRCMD_REPORT_ROBOTLIST] = sendPacket.onRobotIntrcmdReportRobotlist,
	[socketCmd.ROBOT_INTRCMD_REQUEST_AI] = sendPacket.onRobotIntrcmdRequestAI,
	[socketCmd.SERVER_CMD_ROBOT_LOGIN] = sendPacket.onServerCmdRobotLogin,
}

return sendPacket