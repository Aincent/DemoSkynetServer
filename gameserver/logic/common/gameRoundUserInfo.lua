
local gameRoundUserInfo = class()

function gameRoundUserInfo:ctor(userId, seatId)
	self.m_pUserId = userId
	self.m_pSeatId = seatId

	self.m_pHandCardMap = {}
	self.m_pOutCardMap = {}
	self.m_pHandleCardMap = {}

	self.m_pIsHu = false
	self.m_pIsTing = false
	self.m_pIsTuoGuan = false
	self.m_pTurnMoney = 0

	-- 给不同业务进行扩展
	self.m_pExtendInfo = {}
end

function gameRoundUserInfo:dtor()
	
end

function gameRoundUserInfo:onReset()
	self.m_pHandCardMap = {}
	self.m_pOutCardMap = {}
	self.m_pHandleCardMap = {}

	self.m_pIsHu = false
	self.m_pIsTing = false
	self.m_pIsTuoGuan = false
	self.m_pTurnMoney = 0

	-- 给不同业务进行扩展
	self.m_pExtendInfo = {}
end

return gameRoundUserInfo