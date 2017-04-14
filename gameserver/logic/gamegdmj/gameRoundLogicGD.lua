local operationType = require("logic/common/operationType")
local gameRoundLogic = require("logic/common/gameRoundLogic")

local TAG = "gameRoundLogicGD"

local gameRoundLogicGD = class(gameRoundLogic)

function gameRoundLogicGD:onReset()
	
end

-- 012345 分别对应 万筒条风字花
function gameRoundLogicGD:onGetCardTypeTable()
	return {
		[0] = {1, 2, 3, 4, 5, 6, 7, 8, 9},
		[1] = {1, 2, 3, 4, 5, 6, 7, 8, 9},
		[2] = {1, 2, 3, 4, 5, 6, 7, 8, 9},
		[3] = {1, 2, 3, 4},
		[4] = {1, 2, 3},
	}
end

function gameRoundLogicGD:isNeedDingQue()
	return false
end

--[[
	des : 确定庄家
	ret : 庄家庄家号, 色子列表 {1, 6}
]]
function gameRoundLogicGD:onMakeBanker(preRoundInfo)
	return 1, {}
end

--[[
	des : 确定抓牌打色子
	ret : 色子列表 {1, 6}
]]
function gameRoundLogicGD:onDealCardDice(preRoundInfo)
	local pDiceNum = 2
	local pDiceTable = {}
	for i = 1, pDiceNum do
		pDiceTable[i] = math.random(6)
	end
	return pDiceTable
end

function gameRoundLogicGD:isGangTurnMoney()
	return true
end

function gameRoundLogicGD:onGetUserOpValueWhenDrawCard(seatId, cardValue)
	local pHandCards = self.m_pTableUserMap[seatId]:onGetHandCardMap()
	local pHandleCards = self.m_pTableUserMap[seatId]:onGetHandleCardMap()
	local pOpValue = 0
	local pOpTable = {}
	for i = 1, #pHandCards do
		if self:isCanAnGang(pHandCards, pHandCards[i].iCardValue) then
			local pOpType = operationType.AN_GANG
			local pHasCard = false
			for k, v in pairs(pOpTable) do
				if v.iCardValue == pHandCards[i].iCardValue then
					pHasCard = true
					break
				end
			end
			if not pHasCard then
				pOpTable[#pOpTable + 1] = {
					iOpValue = pOpType,
					iCardValue = pHandCards[i].iCardValue,
				}
				pOpValue = pOpValue | pOpType 
			end
		end
	end	
	for i = 1, #pHandCards do
		if self:isCanBuGang(pHandleCards, pHandCards[i].iCardValue) then
			local pOpType = operationType.BU_GANG
			pOpTable[#pOpTable + 1] = {
				iOpValue = pOpType,
				iCardValue = pHandCards[i].iCardValue,
			}
			pOpValue = pOpValue | pOpType
		end
	end	
	if self:isCanHu(pHandCards, 0) then
		local pOpType = operationType.ZIMO
		pOpTable[#pOpTable + 1] = {
			iOpValue = pOpType,
			iCardValue = cardValue,
		}
		pOpValue = pOpValue | pOpType
	end
	return pOpValue, pOpTable
end

function gameRoundLogicGD:onGetUserOpValueWhenOutCard(seatId, cardValue)
	local pHandCards = self.m_pTableUserMap[seatId]:onGetHandCardMap()
	local pHandleCards = self.m_pTableUserMap[seatId]:onGetHandleCardMap()
	local pOpValue = 0
	local pOpTable = {}
	if self:isCanGang(pHandCards, cardValue) then
		local pOpType = operationType.GANG
		pOpTable[#pOpTable + 1] = {
			iOpValue = pOpType,
			iCardValue =cardValue,
		}
		pOpValue = pOpValue | pOpType
	end	
	if self:isCanPeng(pHandCards, cardValue) then
		local pOpType = operationType.PENG
		pOpTable[#pOpTable + 1] = {
			iOpValue = pOpType,
			iCardValue = cardValue,
		}
		pOpValue = pOpValue | pOpType
	end	
	return pOpValue, pOpTable
end

function gameRoundLogicGD:onGetUserOpValueWhenBuGang(seatId, cardValue)
	local pHandCards = self.m_pTableUserMap[seatId]:onGetHandCardMap()
	local pHandleCards = self.m_pTableUserMap[seatId]:onGetHandleCardMap()
	local pOpValue = 0
	local pOpTable = {}
	if self:isCanHu(pHandCards, cardValue) then
		local pOpType = operationType.QIANGGANGHU
		pOpTable[#pOpTable + 1] = {
			iOpValue = pOpType,
			iCardValue = cardValue,
		}
		pOpValue = pOpValue | pOpType
	end
	return pOpValue, pOpTable
end

--[[
	des : 获取不同麻将的扩展信息
]]
function gameRoundLogicGD:onGetGameLogicExtendInfo()
	local pExtendInfo = {}
	local pBankerSeatId = self.m_pGameInterface:onGetBankerSeatId()
	local pPreRoundInfo = self.m_pGameInterface:onGetPreRoundInfo()
	local pMaCount = 4 + pPreRoundInfo.iLianZhuangNum
	if pMaCount < 4 then pMaCount = 4 end
	if pMaCount > 8 then pMaCount = 8 end
	pExtendInfo.iMaCardMap = self.m_pGameInterface:onGetMahjongPoolCard(pMaCount)

	return pExtendInfo
end

--[[
	pTurnMoneyTable = {
		iGangTurnMoneyTable = {
	
		},
		iHuTurnMoneyTable = {
	
		}
	}
]]
function gameRoundLogicGD:onGetGameStopHuInfo(pTurnMoneyTable)
	Log.dump(TAG, pTurnMoneyTable, "pTurnMoneyTable")
	local pHuTable = {}
	for k, v in pairs(self.m_pTableUserMap) do
		pHuTable[k] = {
			iTotalTurnMoney = 0,
			iFanNameDeatail = {},
			iFanName = "",
			iTotalLostMoney = 0,
			iLostDeatail = {},
		}
		for p, q in pairs(self.m_pTableUserMap) do
			pHuTable[k].iLostDeatail[p] = {}
		end
	end
	local pBankerSeatId = self.m_pGameInterface:onGetBankerSeatId()
	for k, v in pairs(pTurnMoneyTable.iGangTurnMoneyTable) do
		if #v.iQGHSeatIds == 0 then
			for p, q in pairs(self.m_pTableUserMap) do
				pHuTable[p].iTotalTurnMoney = pHuTable[p].iTotalTurnMoney + v.iGangTurnMoney[p]
				if v.iGangTurnMoney[p] < 0 then
					pHuTable[p].iTotalLostMoney = pHuTable[p].iTotalLostMoney + v.iGangTurnMoney[p]
					local pTemp = {
						iOpValue = v.iOpValue,
						iMoney = v.iGangTurnMoney[p],
						iCount = 1,
						iDesName = self:onGetGangName(v.iOpValue),
					}
					local pIsHas = false
					local pLostDeatail = pHuTable[p].iLostDeatail[v.iSeatId]
					for _, lost in pairs(pLostDeatail) do
						if lost.iOpValue == pTemp.iOpValue then
							lost.iMoney = lost.iMoney + pTemp.iMoney
							lost.iCount = lost.iCount + 1
							pIsHas = true
							break
						end
					end
					if not pIsHas then
						pLostDeatail[#pLostDeatail + 1] = pTemp
					end
				elseif v.iGangTurnMoney[p] > 0 then
					local pTemp = {
						iOpValue = v.iOpValue,
						iMoney = v.iGangTurnMoney[p],
						iCount = 1,
						iDesName = self:onGetGangName(v.iOpValue),
					}
					local pIsHas = false
					local iFanNameDeatail = pHuTable[p].iFanNameDeatail
					for _, win in pairs(iFanNameDeatail) do
						if win.iOpValue == pTemp.iOpValue then
							win.iMoney = win.iMoney + pTemp.iMoney
							win.iCount = win.iCount + 1
							pIsHas = true
							break
						end
					end
					if not pIsHas then
						iFanNameDeatail[#iFanNameDeatail + 1] = pTemp
					end
				end
			end
		end
	end
	-- 将描述写明
	for k, v in pairs(self.m_pTableUserMap) do
		local iFanNameDeatail = pHuTable[k].iFanNameDeatail
		for p, q in pairs(iFanNameDeatail) do
			pHuTable[k].iFanName = pHuTable[k].iFanName..string.format(" %s%s+%s", q.iCount, q.iDesName, q.iMoney)
		end
	end
	--[[
		{
			iSeatId,
			iTSeatId,
			iOpValue,
			iCardValue,
			iHuTurnMoney = {},
		}
	]]
	for k, v in pairs(pTurnMoneyTable.iHuTurnMoneyTable) do
		for p, q in pairs(self.m_pTableUserMap) do
			pHuTable[p].iTotalTurnMoney = pHuTable[p].iTotalTurnMoney + v.iHuTurnMoney[p]
			if v.iHuTurnMoney[p] < 0 then
				pHuTable[p].iTotalLostMoney = pHuTable[p].iTotalLostMoney + v.iHuTurnMoney[p]
				local pTemp = {
					iOpValue = v.iOpValue,
					iMoney = v.iHuTurnMoney[p],
					iDesName = operationType:isZiMo(v.iOpValue) and "自摸" or "抢杠胡",
				}
				local pLostDeatail = pHuTable[p].iLostDeatail[v.iSeatId]
				pLostDeatail[#pLostDeatail + 1] = pTemp
			elseif v.iHuTurnMoney[p] > 0 then
				local pTemp = {
					iOpValue = v.iOpValue,
					iMoney = v.iHuTurnMoney[p],
					iCardValue = v.iCardValue,
					iDesName = operationType:isZiMo(v.iOpValue) and "自摸" or "抢杠胡",
				}
				local iFanNameDeatail = pHuTable[p].iFanNameDeatail
				iFanNameDeatail[#iFanNameDeatail + 1] = pTemp
			end
		end
	end
	-- 合并番型
	for k, v in pairs(self.m_pTableUserMap) do
		local iFanNameDeatail = pHuTable[k].iFanNameDeatail
		for p, q in pairs(iFanNameDeatail) do
			pHuTable[k].iFanName = pHuTable[k].iFanName..q.iDesName.." "
		end
	end
	Log.dump(TAG, pHuTable, "pHuTable")
	return pHuTable
end

function gameRoundLogicGD:onSetHuTurnMonyInfo(huInfo, basePoint)
	local pHuInfo = huInfo
	local pSeatId = pHuInfo.iSeatId
	local pTSeatId = pHuInfo.iTSeatId
	local pOpValue = pHuInfo.iOpValue
	for k, v in pairs(self.m_pTableUserMap) do
		pHuInfo.iHuTurnMoney[k] = 0
	end
	if operationType:isZiMo(pOpValue) then
		for k, v in pairs(self.m_pTableUserMap) do
			if k ~= pSeatId then
				pHuInfo.iHuTurnMoney[pSeatId] = pHuInfo.iHuTurnMoney[pSeatId] + 2 * basePoint
				pHuInfo.iHuTurnMoney[k] = -2 * basePoint
			end
		end
	elseif operationType:isQiangGangHu(pOpValue) then
		for k, v in pairs(self.m_pTableUserMap) do
			pHuInfo.iHuTurnMoney[pSeatId] = 6 * basePoint
			pHuInfo.iHuTurnMoney[pTSeatId] = -6 * basePoint
		end
	end
end

function gameRoundLogicGD:onGetGangName(opValue)
	if operationType:isGang(opValue) then
		return "明杠"
	elseif operationType:isAnGang(opValue) then
		return "暗杠"
	elseif operationType:isBuGang(opValue) then
		return "补杠"
	else
		return "明杠"
	end
end

function gameRoundLogicGD:onSetGangTurnMonyInfo(gangInfo, basePoint)
	-- 杠是否算钱
	if not self:isGangTurnMoney() then
		return
	end
	local pGangInfo = gangInfo
	local pSeatId = pGangInfo.iSeatId
	local pTSeatId = pGangInfo.iTSeatId
	local pOpValue = pGangInfo.iOpValue
	for k, v in pairs(self.m_pTableUserMap) do
		pGangInfo.iGangTurnMoney[k] = 0
	end
	if operationType:isGang(pOpValue) then
		pGangInfo.iGangTurnMoney[pSeatId] = 3 * basePoint
		pGangInfo.iGangTurnMoney[pTSeatId] = -3 * basePoint
	elseif operationType:isBuGang(pOpValue) then
		for k, v in pairs(self.m_pTableUserMap) do
			if k ~= pSeatId then
				pGangInfo.iGangTurnMoney[pSeatId] = pGangInfo.iGangTurnMoney[pSeatId] + 1 * basePoint
				pGangInfo.iGangTurnMoney[k] = -1 * basePoint
			end
		end
	elseif operationType:isBAnGang(pOpValue) then
		for k, v in pairs(self.m_pTableUserMap) do
			if k ~= pSeatId then
				pGangInfo.iGangTurnMoney[pSeatId] = pGangInfo.iGangTurnMoney[pSeatId] + 2 * basePoint
				pGangInfo.iGangTurnMoney[k] = -2 * basePoint
			end
		end
	end
end

---------- 内部函数 ---------------
function gameRoundLogicGD:isCanHu(handCardMap, cardValue)
	local pPlayType = self.m_pGameInterface:onGetPlayType()
	-- Log.dump(TAG, handCardMap, "handCardMap")
	local pHandCards = {}
	for i = 1, #handCardMap do
		local pCardValue = handCardMap[i].iCardValue
		if not pHandCards[pCardValue] then
			pHandCards[pCardValue] = 0
		end
		pHandCards[pCardValue] = pHandCards[pCardValue] + 1
	end
	if cardValue > 0 then 
		if not pHandCards[cardValue] then
			pHandCards[cardValue] = 0
		end
		pHandCards[cardValue] = pHandCards[cardValue] + 1
	end
	-- Log.dump(TAG, pHandCards, "pHandCards")
	-- 递归计算是否能胡牌
	local pIsHu = self:isNormalHu(pHandCards)

	return pIsHu
end

function gameRoundLogicGD:isNormalHu(handCards)
	-- 先去掉一对将牌
	for k, v in pairs(handCards) do
		if handCards[k] >= 2 then
			handCards[k] = handCards[k] - 2
			if self:compute(handCards) then
				return true
			end
			handCards[k] = handCards[k] + 2
		end
	end
	return false
end

return gameRoundLogicGD