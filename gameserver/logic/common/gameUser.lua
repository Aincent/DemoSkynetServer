local gameRoundUserInfo = require("logic/common/gameRoundUserInfo")

local TAG = "GameUser"
local GameUser = class()

function GameUser:ctor(userId, seatId, socketfd)
	self.m_userId = userId
	self.m_seatId = seatId
	self.m_socketfd = socketfd

	self.m_pIsRobot = 0

	self.m_ready = 0

	self.m_from = 0
	self.m_version = 0
	self.m_money = 0
	self.m_exp = 0
	self.m_level = 0
	self.m_winTimes = 0
	self.m_loseTimes = 0
	self.m_drawTimes = 0
	self.m_adultAuth = 0
	self.m_fcmPlayTime = 0
	self.m_vipLevel = 0
	self.m_clientIp = ""
	self.m_clientVersion = 0
	self.m_chips = 0
	self.m_mtkey = ""
	self.m_trustLevel = 0
	self.m_diamond = 0
	self.m_userInfo = {}
	self.m_userInfoStr = ""

	-- 玩牌
	self.m_pGameRoundUserInfo = new(gameRoundUserInfo, self.m_userId, self.m_seatId)
end

function GameUser:dtor()
	delete(self.m_pGameRoundUserInfo)
	self.m_pGameRoundUserInfo = nil
end

function GameUser:onResetUser()
	self.m_userId = 0
	self.m_userInfo = {}
	self.m_userInfoStr = ""
	self.m_socketfd = 0
	self.m_seatId = -1
	self.m_ready = 0
	self.m_pIsRobot = 0
end

function GameUser:onSetUserInfo(data)
	-- Log.dump(TAG, data, "data")
	self.m_from = data.iFrom or 0
	self.m_version = data.iVersion or 0
	self.m_money = data.iMoney or 0
	self.m_exp = data.iExp or 0
	self.m_level = data.iLevel or 0
	self.m_winTimes = data.iWinTimes or 0
	self.m_loseTimes = data.iLoseTimes or 0
	self.m_drawTimes = data.iDrawTimes or 0
	self.m_adultAuth = data.iAdultAuth or 0
	self.m_fcmPlayTime = data.iFcmPlayTime or 0
	self.m_vipLevel = data.iVipLevel or 0
	self.m_clientIp = data.iClientIp or ""
	self.m_clientVersion = data.iClientVersion or ""
	self.m_chips = data.iChips or 0
	self.m_mtkey = data.iMtkey or ""
	self.m_trustLevel = data.iTrustLevel or 0
	self.m_diamond = data.iDiamond or 0
	self.m_userInfo = data.iUserInfo or {}
	self.m_userInfoStr = data.iUserInfoStr or ""
	self.m_pIsRobot = data.iIsRobot or 0
	self.m_ready = data.iReady or 0
end

function GameUser:isRobot()
	return 1 == self.m_pIsRobot
end

function GameUser:isReady()
	return 1 == self.m_ready
end

function GameUser:onGetUserId()
	return self.m_userId
end

function GameUser:onGetSeatId()
	return self.m_seatId
end

function GameUser:onSetTuoGuan(isTuoGuan)
	self.m_pGameRoundUserInfo.m_pIsTuoGuan = isTuoGuan
end

function GameUser:onGetTuoGuan()
	return self.m_pGameRoundUserInfo.m_pIsTuoGuan
end

function GameUser:onGetHandCardMap()
	return self.m_pGameRoundUserInfo.m_pHandCardMap
end

function GameUser:onGetOutCardMap()
	return self.m_pGameRoundUserInfo.m_pOutCardMap
end

function GameUser:onGetHandleCardMap()
	return self.m_pGameRoundUserInfo.m_pHandleCardMap
end

function GameUser:onResetRoundUserInfo()
	self.m_pGameRoundUserInfo:onReset()
end

function GameUser:onSetTurnMoney(money)
	self.m_pGameRoundUserInfo.m_pTurnMoney = money
end

function GameUser:onGetTurnMoney()
	return self.m_pGameRoundUserInfo.m_pTurnMoney
end

return GameUser