
local gameInterface = class()

function gameInterface:init(gameRound)
	self.m_pGameRound = gameRound
end

--------------------gameRound  >>  gameRoundLogic--------------------
function gameInterface:onGetTableUsers()
	return self.m_pGameRound.m_players
end

-- 获取牌池中的前cardNum张牌,如不够，则有多少张返回多少
function gameInterface:onGetMahjongPoolCard(cardNum)
	local pCardTable = {}
	for i = 1, cardNum do
		pCardTable[#pCardTable + 1] = self.m_pGameRound.m_pool:drawCard()
	end
	return pCardTable
end

function gameInterface:onGetBankerSeatId()
	return self.m_pGameRound.m_pBankerSeatId
end

function gameInterface:onGetPreRoundInfo()
	return self.m_pGameRound.m_pPreRoundInfo
end

function gameInterface:onGetPlayType()
	return self.m_pGameRound.m_pGameRoomConfig.iPlayType
end

return gameInterface
