local Tag = "gameRoundLogic"
local operationType = require("logic/common/operationType")
local gameRoundLogic = class()
----------------------------------------提供给 gameRound的接口(@require 必须实现)-----------------------

function gameRoundLogic:init(gameInterface)
	self.m_pGameInterface = gameInterface
end

function gameRoundLogic:onGameStart()
	-- 用户数据只有extendInfo可以修改
	self.m_pTableUserMap = self.m_pGameInterface:onGetTableUsers()
end



-- 判断函数
function gameRoundLogic:isCanChi(handCardMap, cardValue)
	
end

function gameRoundLogic:isCanPeng(handCardMap, cardValue)
	local pHandCount = 0
	for i = 1, #handCardMap do
		if handCardMap[i].iCardValue == cardValue then
			pHandCount = pHandCount + 1
		end
	end
	return pHandCount >= 2
end

function gameRoundLogic:isCanGang(handCardMap, cardValue)
	local pHandCount = 0
	for i = 1, #handCardMap do
		if handCardMap[i].iCardValue == cardValue then
			pHandCount = pHandCount + 1
		end
	end
	return pHandCount >= 3
end

function gameRoundLogic:isCanAnGang(handCardMap, cardValue)
	local pHandCount = 0
	for i = 1, #handCardMap do
		if handCardMap[i].iCardValue == cardValue then
			pHandCount = pHandCount + 1
		end
	end
	return pHandCount >= 4
end

function gameRoundLogic:isCanBuGang(handleCardMap, cardValue)
	for i = 1, #handleCardMap do
		if handleCardMap[i].iCardValue == cardValue and operationType:isPeng(handleCardMap[i].iOpValue) then
			return true
		end
	end
	return false
end

function gameRoundLogic:compute(handCards)
	local pHandCount = 0 
	for k, v in pairs(handCards) do
		pHandCount = pHandCount + handCards[k]
	end
	-- Log.dump(Tag, handCards, "handCards")
	if pHandCount == 0 then return true end
	local pIsOk = false
	-- 先去掉3个
	for k , v in pairs(handCards) do
		if handCards[k] >= 3 then 
			handCards[k] = handCards[k] - 3 
			pIsOk = self:compute(handCards)
			handCards[k] = handCards[k] + 3 
			if pIsOk then return true end
		end
	end
	-- 去掉顺子
	for k, v in pairs(handCards) do
		if handCards[k] and handCards[k] > 0 and 
			handCards[k+1] and handCards[k+1] > 0 and 
				handCards[k+2] and handCards[k+2] > 0 then

			handCards[k] = handCards[k] - 1
			handCards[k+1] = handCards[k+1] - 1
			handCards[k+2] = handCards[k+2] - 1
			pIsOk = self:compute(handCards)
			handCards[k] = handCards[k] + 1
			handCards[k+1] = handCards[k+1] + 1
			handCards[k+2] = handCards[k+2] + 1
			if pIsOk then return true end
		end
	end
	return false
end

return gameRoundLogic