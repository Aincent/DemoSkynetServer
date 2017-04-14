local skynet = require("skynet")
local socketCmd = require("logic/common/socketCmd")
local json = require "cjson"
local TAG = "receivePacket"

local receivePacket = {}

function receivePacket.onClientCmdCreateBattleRoom(packet)
	local data = {}
	data.iUserId = packet:readInt()
	data.iRoomId = packet:readInt()
	data.iTableId = packet:readInt()
	data.iMJCode = packet:readShort()
	data.iRoundNum = packet:readShort()
	data.iPlayType = packet:readInt()
	data.iLocalGameType = packet:readInt()
	data.iBattlePayMode = packet:readInt()
	data.iExtendInfo = packet:readString()
	data.iExtendInfo = json.decode(data.iExtendInfo)
	return data
end

function receivePacket.onClientCmdLogin(packet)
	local data = {}
	data.iTableId = packet:readInt()
	data.iUserId = packet:readInt()
	data.iMtKey = packet:readString()
	data.iUserInfoStr = packet:readString()
	if data.iUserInfoStr and #data.iUserInfoStr > 1 then
		data.iUserInfo = json.decode(data.iUserInfoStr)
	end
	data.iFrom = packet:readInt()
	data.iVersion = packet:readInt()
	data.iClientVersion = packet:readString()
	data.iClientIp = packet:readString()
	data.iReady = packet:readShort()
	-- 将数据扩展出来
	if data.iUserInfo and type(data.iUserInfo) == "table" then
		data.iTrustLevel = tonumber(data.iUserInfo.trustlevel)
	end
	return data
end

function receivePacket.onServerCmdRobotLogin(packet)
	local data = {}
	data.iMJCode = packet:readInt()
	data.iServerIp = packet:readString()
	data.iServerPort = packet:readInt()
	data.iTableId = packet:readInt()
	data.iUserId = packet:readInt()
	data.iMtKey = packet:readString()
	data.iUserInfoStr = packet:readString()
	if data.iUserInfoStr and #data.iUserInfoStr > 1 then
		data.iUserInfo = json.decode(data.iUserInfoStr)
	end
	data.iFrom = packet:readInt()
	data.iVersion = packet:readString()
	data.iReady = packet:readInt()
	return data
end

function receivePacket.onClientCmdLogout(packet)
	local data = {}
	data.iLeave = packet:readInt()
	return data
end

function receivePacket.onDaoJuServerMainCmd(packet)
	local data = {}
	data.iSwitchCmd = packet:readInt()
	if socketCmd.SERVER_GET_DIAM_RES == data.iSwitchCmd then
		data.iUserCount = packet:readInt()
		data.iUserTable = {}
		for i = 1, data.iUserCount do
			data.iUserTable[i] = {}
			data.iUserTable[i].iUserId = packet:readInt()
			data.iUserTable[i].iDiamond = packet:readInt()
		end
	elseif socketCmd.SERVER_UPDATE_DIAM_RES == data.iSwitchCmd then
		
	end
	return data
end

function receivePacket.onClientCmdReady(packet)
	local data = {}
	return data
end

function receivePacket.onSysResponseMasterBattleRoomCount(packet)
	local data = {}
	data.iUserId = packet:readInt()
	data.iCount = packet:readInt()
	return data
end

function receivePacket.onAllCmdRequestUserBattleData(packet)
	local data = {}
	data.iUserId = packet:readInt()
	data.iRoomId = packet:readInt()
	data.iTableId = packet:readInt()
	return data
end

function receivePacket.onServerCmdGetRecord(packet)
	local data = {}
	data.iValue = packet:readInt()
	if 0 == data.iValue then
		data.iUserId = packet:readInt()
		data.iMoney = packet:readInt()
		data.iExp = packet:readInt()
		data.iLevel = packet:readInt()
		data.iWinTimes = packet:readInt()
		data.iLoseTimes = packet:readInt()
		data.iDrawTimes = packet:readInt()
		data.iChips = packet:readInt()
	end
	return data
end

function receivePacket.onClientCmdChat(packet)
	local data = {}
	data.iMsg = packet:readString()
	return data
end

function receivePacket.onClientCmdFace(packet)
	local data = {}
	data.iFaceType = packet:readInt()
	return data
end

function receivePacket.onClientCmdOutCard(packet)
	local data = {}
	data.iCardValue = packet:readByte()
	return data
end

function receivePacket.onClientCmdTakeOpreation(packet)
	local data = {}
	data.iOpValue = packet:readInt()
	data.iCardValue = packet:readByte()
	return data
end

function receivePacket.onClientCmdRequestAI(packet)
	local data = {}
	data.iAiType = packet:readByte()
	return data
end

function receivePacket.receive(packet)
	if not packet then 
		return 
	end
	local cmd = packet:getBeginCmd()
	if cmd and receivePacket.s_cmdFuncMap[cmd] then
		local data = receivePacket.s_cmdFuncMap[cmd](packet)
		Log.d(TAG, "---- receivePacket cmd[0x%04x] ----", cmd)
		Log.dump(TAG, data)
		Log.d(TAG, "-----------------------------------", cmd)
		return data
	end
end

receivePacket.s_cmdFuncMap = {
	-- hallServer
	[socketCmd.CLIENT_CMD_LOGIN] = receivePacket.onClientCmdLogin,
	[socketCmd.CLIENT_CMD_LOGOUT] = receivePacket.onClientCmdLogout,
	[socketCmd.CLIENT_CMD_READY] = receivePacket.onClientCmdReady,
	[socketCmd.CLIENT_CMD_CREATE_BATTLE_ROOM] = receivePacket.onClientCmdCreateBattleRoom,
	[socketCmd.CLIENT_CMD_CHAT]	= receivePacket.onClientCmdChat,
	[socketCmd.CLIENT_CMD_FACE]	= receivePacket.onClientCmdFace,
	[socketCmd.CLIENT_CMD_OUT_CARD] = receivePacket.onClientCmdOutCard,
	[socketCmd.CLIENT_CMD_TAKE_OPERATION] = receivePacket.onClientCmdTakeOpreation,
	[socketCmd.CLIENT_CMD_REQUEST_AI] = receivePacket.onClientCmdRequestAI,

	-- diamond
	[socketCmd.DAOJU_SERVER_MAIN_CMD] = receivePacket.onDaoJuServerMainCmd,

	-- allocServer 
	[socketCmd.SYS_RESPONSE_MASTER_BATTLEROOM_COUNT] = receivePacket.onSysResponseMasterBattleRoomCount,
	[socketCmd.ALLCMD_REQUEST_USER_BATTLE_DATA] = receivePacket.onAllCmdRequestUserBattleData,

	-- moneyServer
	[socketCmd.SERVER_CMD_GET_RECORD] = receivePacket.onServerCmdGetRecord,

	-- robotServer
	[socketCmd.SERVER_CMD_ROBOT_LOGIN] = receivePacket.onServerCmdRobotLogin,
}

return receivePacket