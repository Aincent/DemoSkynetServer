
local socketManager = require("byprotobuf/socketManager")
local socketCmd = require("logic/common/socketCmd")
local operationType = require("logic/common/operationType")
local mahjongDefine = require("logic/common/mahjongDefine")
local GR_cfg = require("logic/common/gameRoundCfg")
local sharedata = require("sharedata")
local json = require("cjson")

local Tag = "GameRound"
--[[
tableStatus:
"GAME_STATUS_PLAYING"----------------- 打牌状态
"GAME_STATUS_WAIT_OPERATE"------------ 等待用户操作状态
"GAME_STATUS_WAIT_OUT"--------------- 游戏准备停止状态 stopRound 与 stopGame之间

]]
local GameRound = class()

GameRound.m_pRoundStatusMap = {
	ROUND_STATUS_NONE = 0,
	ROUND_STATUS_DRAWCARD = 1,
	ROUND_STATUS_OUTCARD = 2,
	ROUND_STATUS_OPOUTCARD = 3,
	ROUND_STATUS_OPDRAWCARD = 4,
	ROUND_STATUS_OPBUGANGCARD = 5,
	ROUND_STATUS_STOP = 6,
}
----------------------------------------public----------------------------------------
function GameRound:init(gameTable, scheduleMgr)
	self.m_pGameTable = gameTable
	self.m_scheduleMgr   = scheduleMgr
	-- 游戏配置
	self.m_pGameRoomConfig = sharedata.query("GameRoomConfig")
	-- 游戏逻辑类
	self.m_pGameInterface = require("logic/common/gameInterface")
	self.m_pGameInterface:init(self)

	self.m_logic = require(mahjongDefine.MahjongGameLogicMap[self.m_pGameRoomConfig.iMJCode])
	self.m_logic:init(self.m_pGameInterface)
	self.m_pool = require("logic/common/mahjongPool")

	-- 上一局的信息
	self.m_pPreRoundInfo = {
		iBankerSeatId     = -1,    --庄家位置
		iLianZhuangNum  = 0,      --连庄数 
		iHuSeatId        = -1,     --胡牌玩家
		iBeiHuSeatId      = -1,     --被胡玩家
		iIsQiangGangHu  = -1,      --是否是抢杠胡
	}

	self.m_pBankerSeatId = -1
	self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_NONE
	self.m_pOutCardNum = 0

	self.m_pCurOpUserTable = {}
	self.m_pPlayerMoneyTable = {}

	self.m_pTurnMoneyInfoTable = {}
end 

function GameRound:onReset()
	self:clearAllRoundTimer()
	self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_NONE
	self.m_pCurOpUserTable = {}
	self.m_pPlayerMoneyTable = {}
	self.m_pBankerSeatId = -1
	self.m_pOutCardNum = 0
	self.m_pTurnMoneyInfoTable = {}
	self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable = {}
	self.m_pTurnMoneyInfoTable.iHuTurnMoneyTable = {}

	-- 抓牌和打牌玩家
	self.m_iCurOutCardSeatId = -1
end

function GameRound:onClearUserOp()
	for i = 1, self:onGetPlayerCount() do
		self.m_pCurOpUserTable[i] = {
			iOpValue = 0,
			iOpTable = nil,
			iSelectOp = 0,
		}
	end
end

--游戏开始
function GameRound:onGameStart(info)
	Log.i(Tag, "GameRound onGameStart")
	self:onReset()
	self:initRoundInfo()
	self:initCards() --初始化牌墙
	self.m_logic:onGameStart()
	
	self.m_progress      = clone(GR_cfg.process)
	self.m_progressIndex = 1

	self:procNextProgress()--按配置顺序处理 可配流程
end

function GameRound:procNextProgress()
	-- Log.i(Tag, "procNextProgress  11111 self.m_progressIndex[%s]", self.m_progressIndex)
	local progress = self.ProcessMap[self.m_progressIndex]
	if progress then
		progress.iFunc(self, progress)
	else 
		---------!!!!!可配流程全部走完 正式开始 抓牌
		self.m_iCurOutCardSeatId = 1
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
	    self:startTimer("drawCard", 3000, self.onDrawCardTimerCallback)
	end 
	-- Log.i(Tag, "procNextProgress  22222 self.m_progressIndex[%s]", self.m_progressIndex)
	self.m_progressIndex = self.m_progressIndex + 1
end 

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--接受到客户端消息 处理
--客户端 选择出牌
function GameRound:onClientCmdOutCard(data, userId)
	local outCard = data.iCardValue 
	Log.d(Tag, "onClientCmdOutCard userId[%s] card[%s]", userId, outCard)
	local player  = self:onGetPlayerByUserId(userId)
	if not player then
		Log.e(Tag, "onClientCmdOutCard not player[%s]", userId)
		return 
	end
	-- 校验牌是否合法
	if not self:onCheckOutCardIsValid(player:onGetSeatId(), outCard) then
		Log.e(Tag, "onClientCmdOutCard cardValue[%s] is not valid", outCard)
		return 
	end
	if not self:isRoundStatusOutCard() and not self:isRoundStatusOpDrawCard() then
		return 
	end
	if self.m_iCurOutCardSeatId ~= player:onGetSeatId() then
		return
	end
	local pHandCardMap = player:onGetHandCardMap()
	local pOutCardMap = player:onGetOutCardMap()
	local pCard = nil
	for i = 1, #pHandCardMap do
		if pHandCardMap[i].iCardValue == outCard then
			pCard = table.remove(pHandCardMap, i)
			break
		end
	end
	if not pCard then return end

	self:stopTimer("outCard")

	self.m_pOutCardNum = self.m_pOutCardNum + 1
	pCard.iRank = self.m_pOutCardNum
	pOutCardMap[#pOutCardMap + 1] = pCard

	self:onClearUserOp()
	local pHasOp = false
	for i = 1, self:onGetPlayerCount() do
		local iPlayer = self.m_players[i]
		local cmd = socketCmd.SERVER_CMD_BROADCAST_USER_OUT_CARD
		local info = {}
		info.iUserId = player:onGetUserId()
		info.iCardValue = pCard.iCardValue
		info.iOpValue = 0
		info.iOpNum = 0
		info.iOpTable = {}
		if player:onGetSeatId() ~= i then
			local pOpValue, pOpTable = self.m_logic:onGetUserOpValueWhenOutCard(i, pCard.iCardValue)
			info.iOpValue = pOpValue
			info.iOpNum = #pOpTable
			info.iOpTable = pOpTable
			
			if pOpValue > 0 then
				pHasOp = true
				self.m_pCurOpUserTable[i] = {
					iOpValue = pOpValue,
					iOpTable = pOpTable,
					iSelectOp = nil,
				}
			end
		end
		self:onSendToGameUser(iPlayer, cmd, info)
	end
	if pHasOp then
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OPOUTCARD
		self:startTimer("opOutCard", self.m_pGameRoomConfig.iOperationTime * 1000, self.onOpOutCardTimerTimeOut)
	else
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
		local pSeatId = self:onGetNextSeat(self.m_iCurOutCardSeatId)
		self.m_iCurOutCardSeatId = 0
		Log.i(Tag, "onOutCardTimerTimeOut pSeatId[%s]", pSeatId)
		self:drawCard(self.m_players[pSeatId])
	end
end 

-- 客户端 选择操作
function GameRound:onClientCmdTakeOpreation(data, userId) 
	Log.d(Tag, "userId[%s]", userId)
	if not self:isRoundStatusOpOutCard() and not self:isRoundStatusOpDrawCard() and not self:isRoundStatusOpBuGangCard() then
		return 
	end 
	local player  = self:onGetPlayerByUserId(userId)
	if not player then 
		Log.e(Tag, "onClientCmdTakeOpreation not player[%s]", userId)
		return 
	end 
	local pSeatId = player:onGetSeatId()
	local pTemp = self.m_pCurOpUserTable[pSeatId]
	local pMatch = false
	if pTemp.iOpValue > 0 and not pTemp.iSelectOp then
		for k, v in pairs(pTemp.iOpTable) do
			if (v.iOpValue == data.iOpValue and v.iCardValue == data.iCardValue) then
				pTemp.iSelectOp = v
				pMatch = true
				break
			end
		end
	end
	if not pMatch or operationType:isGuo(data.iOpValue) then
		pTemp.iOpValue = 0
	else
		for i = 1, self:onGetPlayerCount() do
			local pCurOpTable = self.m_pCurOpUserTable[i]
			if pCurOpTable.iOpValue > 0 and i ~= pSeatId then
				if not operationType:isHu(pCurOpTable.iOpValue) then
					pCurOpTable.iOpValue = 0
				end
				if pCurOpTable.iSelectOp and not operationType:isHu(pCurOpTable.iSelectOp.iOpValue) then
					pCurOpTable.iOpValue = 0
				end
			end
		end
	end
	local pIsDone = true
	-- 校验是否所有的玩家都已经操作
	for i = 1, self:onGetPlayerCount() do
		if self.m_pCurOpUserTable[i].iOpValue > 0 and not self.m_pCurOpUserTable[i].iSelectOp then
			pIsDone = false
		end
	end
	if pIsDone then
		self:onClientUserHasAllOp()
	end
end 

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--牌局流程
--初始化牌堆 各个子类实现 自己的初始牌堆
--基类默认处理是只有万筒条(1~9)*4 共108张
function GameRound:initCards()--固定流程-- 初始化牌池
	self.m_pool:initMahjongPool(self.m_logic:onGetCardTypeTable())
end

--定庄
function GameRound:process_makeBanker(conf)
	--当局庄家位置 和 骰子
	local pSeatId, pDices = self.m_logic:onMakeBanker(self.m_pPreRoundInfo)
	self.m_pBankerSeatId = pSeatId
	--前一操作玩家 位置
	self.m_iPreOutCardSeatId = -1
	--当前操作玩家 位置
	self.m_iCurOutCardSeatId = self.m_pBankerSeatId
	-- 这里发给客户端游戏开始
	local cmd = socketCmd.SERVER_BROADCAST_READY_START
	local info = {}
	info.iBankerSeatId = self.m_pBankerSeatId
	info.iDiceNum = #pDices
	info.iDiceTable = pDices
	if self.m_pGameTable:isBattleRoom() then
		info.iCurRound = self.m_pGameTable.m_battleConfig.iCurRound
	end 
	self.m_pGameTable:onBroadcastTableUsers(cmd, info)

	self:startTimer("makeBanker", conf.iTime, self.onMakeBankerTimerCallback)
end

function GameRound:onMakeBankerTimerCallback()
	self:procNextProgress()
end

function GameRound:onDealCardsTimerCallback()
	self:procNextProgress()
end

function GameRound:onSetCard(value)
	local pCard = {}
	pCard.iCardValue = value
	pCard.iStatus = 0
	pCard.iRank = -1
	return pCard
end

--可配流程--发牌 0x3001
function GameRound:process_dealCards(conf)
	--获取庄家uid
	local bankerUid = self.m_players[self.m_pBankerSeatId ]:onGetUserId()
	--发牌
	local dealCardMap = self.m_pool:dealCards(self:onGetPlayerCount(), self.m_pGameTable:onGetDealCardCount())
	for i = 1, self:onGetPlayerCount() do
		local pHandCardMap = self.m_players[i]:onGetHandCardMap()
		for j = 1, #dealCardMap[i] do
			pHandCardMap[#pHandCardMap + 1] = self:onSetCard(dealCardMap[i][j])
		end
	end	
	local info = {}
	info.iBankerSeatId   = self.m_pBankerSeatId 
	info.iDiceTable = self.m_logic:onDealCardDice()
	info.iDiceNum   = #info.iDiceTable
	info.iUserCount = self:onGetPlayerCount()
	for i = 1, self:onGetPlayerCount() do
		self:onSendGameUserDealCard(self.m_players[i], info)
	end
	self:startTimer("dealCards", conf.iTime, self.onDealCardsTimerCallback)
end 

function GameRound:onSendGameUserDealCard(player, info)
	--通知发牌内容 给客户端
	local cmd = socketCmd.SERVER_CMD_DEAL_CARD
	info.iHandCardMap = {}
	for i = 1, self:onGetPlayerCount() do
		local pHandCardMap = self.m_players[i]:onGetHandCardMap()
		info.iHandCardMap[i] = {}
		info.iHandCardMap[i].iSeatId = i
		info.iHandCardMap[i].iHandCardCount = #pHandCardMap
		info.iHandCardMap[i].iHandCards = {}
		for j = 1, #pHandCardMap do
			if self.m_players[i] == player then
				info.iHandCardMap[i].iHandCards[j] = pHandCardMap[j].iCardValue
			else
				info.iHandCardMap[i].iHandCards[j] = 0
			end
		end
	end
	self:onSendToGameUser(player, cmd, info)
end

function GameRound:onSendToGameUser(user, cmd, info)
	socketManager.send(user.m_socketfd, cmd, info, true)
end

--------------------------------------------------------------------------------------------------------------------

--抓牌
function GameRound:drawCard(player, isGangDraw)
	Log.i(Tag, "drawCard")
	if not self:isRoundStatusDrawCard() then
		return
	end
	if self:onGetRemainCardCount() <= 0 then 
		self:onGameStopRound(0)
		return
	end 
	local cardValue = self.m_pool:drawCard()
	Log.i(Tag, "drawCard cardValue[0x%2x]", cardValue)
	-- 将牌加进玩家的手牌
	local pHandCardMap = player:onGetHandCardMap()
	pHandCardMap[#pHandCardMap + 1] = self:onSetCard(cardValue)
	--广播当前用户抓牌--0x4006
	local cmd = socketCmd.SERVER_CMD_BROADCAST_CURRENT_PLAYER
	local info = {}
	info.iUserId = player:onGetUserId()
	info.iBuHuaNum = 0
	info.iBuHuaTable = {}
	self.m_pGameTable:onBroadcastTableUsers(cmd, info, info.iUserId)
	--单播给当前抓牌用户 抓牌信息0x3002
	local cmd = socketCmd.SERVER_CMD_GRAB_CARD
	local info = {}
	info.iBuHuaNum = 0
	info.iBuHuaTable = {}
	info.iCardValue = cardValue
	local pOpValue, pOpTable = self.m_logic:onGetUserOpValueWhenDrawCard(player:onGetSeatId(), cardValue)
	info.iOpValue = pOpValue
	info.iOpNum = #pOpTable
	info.iOpTable = pOpTable
	self:onSendToGameUser(player, cmd, info)

	self:onClearUserOp()
	self.m_iCurOutCardSeatId = player:onGetSeatId()
	if pOpValue > 0 then
		self.m_pCurOpUserTable[player:onGetSeatId()] = {
			iOpValue = pOpValue,
			iOpTable = pOpTable,
			iSelectOp = nil,
		}
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OPDRAWCARD
		self:startTimer("opDarwCard", self.m_pGameRoomConfig.iOperationTime * 1000, self.onOpDarwCardTimerTimeOut)
	else
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OUTCARD
		self:startTimer("outCard", self:onGetOutCardTime(self.m_iCurOutCardSeatId), self.onOutCardTimerTimeOut)
	end
end 

function GameRound:onOpDarwCardTimerTimeOut()
	self:onClientUserHasAllOp()
end

function GameRound:onOpOutCardTimerTimeOut()
	self:onClientUserHasAllOp()
end

function GameRound:onClientUserHasAllOp()
	Log.d(Tag, "onClientUserHasAllOp")
	self:stopTimer("opOutCard")
	self:stopTimer("opDarwCard")
	self:stopTimer("opBuGangCard")
	for i = 1, self:onGetPlayerCount() do
		local pTemp = self.m_pCurOpUserTable[i]
		if pTemp.iOpValue > 0 and pTemp.iSelectOp then
			local pOp = {
				iOpValue = pTemp.iSelectOp.iOpValue,
				iCardValue = pTemp.iSelectOp.iCardValue,
			}
			if operationType:isHu(pOp.iOpValue) or operationType:isZiMo(pOp.iOpValue) or
				operationType:isQiangGangHu(pOp.iOpValue) or operationType:isGangShangKaiHua(pOp.iOpValue) or 
				operationType:isGangShangPao(pOp.iOpValue) then
				self:onDealClientUserHu(i, pOp)
				self:onGameStopRound(1)
				return
			else
				self:onDealClientUserTakeOp(i, pOp)
				return
			end
		end
	end
	self:onClearUserOp()
	if self:isRoundStatusOpOutCard() then
		local pSeatId = self:onGetNextSeat(self.m_iCurOutCardSeatId)
		local player = self.m_players[pSeatId]
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
		self:drawCard(player)
	elseif self:isRoundStatusOpDrawCard() then
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OUTCARD
		self:startTimer("outCard", self:onGetOutCardTime(self.m_iCurOutCardSeatId), self.onOutCardTimerTimeOut)
	elseif self:isRoundStatusOpBuGangCard() then
		-- 补杠别的玩家不胡
		self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable[#self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable].iIsDone = true
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
		self:drawCard(self.m_players[self.m_iCurOutCardSeatId])
	end
end

function GameRound:onDealGangTurnMoney(seatId, op)
	-- 先算钱
	if operationType:isBuGang(op.iOpValue) or operationType:isBuGang(op.iOpValue) 
		or operationType:isAnGang(op.iOpValue) then
		local pTemp = {}
		pTemp.iSeatId = seatId
		pTemp.iTSeatId = self.m_iCurOutCardSeatId
		pTemp.iOpValue = op.iOpValue
		pTemp.iCardValue = op.iCardValue
		pTemp.iIsDone = true
		pTemp.iGSPSeatIds = {}
		pTemp.iGangTurnMoney = {}
		self.m_logic:onSetGangTurnMonyInfo(pTemp, self.m_pGameRoomConfig.iBasePoint)
		self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable[#self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable + 1] = pTemp
	end
end

function GameRound:onDealClientUserHu(seatId, op)
	Log.d(Tag, "onDealClientUserHu seatId[%s] iOpValue[%s] iCardValue[%s]", seatId, op.iOpValue, op.iCardValue)
	local player = self.m_players[seatId]
	local pHandCardMap = player:onGetHandCardMap()
	local pHandleCardMap = player:onGetHandleCardMap()
	-- 先判断是不是抢杠胡
	local pTseatId = self.m_iCurOutCardSeatId
	if operationType:isQiangGangHu(op.iOpValue) then
		-- 找到被抢杠胡的玩家
		for k, v in pairs(self.m_players) do
			local pHandleCardMap = v:onGetHandleCardMap()
			for p, q in pairs(pHandleCardMap) do
				if operationType:isBuGang(q.iOpValue) and q.iCardValue == op.iCardValue then
					q.iOpValue = operationType.PENG
					pTseatId = k
					break
				end
			end
		end
		-- 去掉抢杠胡的杠钱
		table.remove(self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable, #self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable)
	end
	-- 先算钱
	local pTemp = {}
	pTemp.iSeatId = seatId
	pTemp.iTSeatId = pTseatId
	pTemp.iOpValue = op.iOpValue
	pTemp.iCardValue = op.iCardValue
	pTemp.iHandCardMap = {}
	for i = 1, #pHandCardMap do
		pTemp.iHandCardMap[#pTemp.iHandCardMap + 1] = pHandCardMap[i].iCardValue
	end
	pTemp.iHuTurnMoney = {}
	self.m_logic:onSetHuTurnMonyInfo(pTemp, self.m_pGameRoomConfig.iBasePoint)
	self.m_pTurnMoneyInfoTable.iHuTurnMoneyTable[#self.m_pTurnMoneyInfoTable.iHuTurnMoneyTable + 1] = pTemp
end

function GameRound:onDealClientUserTakeOp(seatId, op)
	-- 玩家牌
	Log.d(Tag, "onDealClientUserTakeOp seatId[%s] iOpValue[%s] iCardValue[%s]", seatId, op.iOpValue, op.iCardValue)
	local player = self.m_players[seatId]
	local pHandCardMap = player:onGetHandCardMap()
	local pHandleCardMap = player:onGetHandleCardMap()
	if operationType:isBuGang(op.iOpValue) then
		for k, v in pairs(pHandleCardMap) do
			if operationType:isPeng(v.iOpValue) and v.iCardValue == op.iCardValue then
				v.iOpValue = operationType.BU_GANG
				v.iCardValue = op.iCardValue
				break
			end
		end
	else
		pHandleCardMap[#pHandleCardMap + 1] = {
			iOpValue = op.iOpValue,
			iCardValue = op.iCardValue,
		}
	end
	local pCardCount = 0
	if operationType:isPeng(op.iOpValue) then
		pCardCount = 2
	elseif operationType:isGang(op.iOpValue) then
		pCardCount = 3
	elseif operationType:isBuGang(op.iOpValue) then
		pCardCount = 1
	elseif operationType:isAnGang(op.iOpValue) then
		pCardCount = 4
	end
	for i = 1, pCardCount do
		for k, v in pairs(pHandCardMap) do
			if v.iCardValue == op.iCardValue then
				table.remove(pHandCardMap, k)
				break
			end
		end
	end
	self:onDealGangTurnMoney(seatId, op)
	local cmd = socketCmd.SERVER_CMD_BROADCAST_TAKE_OPERATION
	local info = {}
	info.iUserId = player:onGetUserId()
	info.iOpValue = op.iOpValue
	info.iCardValue = op.iCardValue
	info.iTargetSeatId = self.m_iCurOutCardSeatId
	local pHasOp = false
	self:onClearUserOp()
	for i = 1, self:onGetPlayerCount() do
		info.iOpNum = 0
		info.iOpTable = {}
		if operationType:isBuGang(op.iOpValue) then
			if i ~= seatId then
				local pOpValue, pOpTable = self.m_logic:onGetUserOpValueWhenBuGang(i, op.iCardValue)
				info.iOpNum = #pOpTable
				info.iOpTable = pOpTable
				
				if pOpValue > 0 then
					pHasOp = true
					self.m_pCurOpUserTable[i] = {
						iOpValue = pOpValue,
						iOpTable = pOpTable,
						iSelectOp = nil,
					}
				end
			end
		end
		self:onSendToGameUser(self.m_players[i], cmd, info)
	end
	if pHasOp then
		-- 杠钱还没到手
		self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable[#self.m_pTurnMoneyInfoTable.iGangTurnMoneyTable].iIsDone = false
		self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OPBUGANGCARD
		self:startTimer("opBuGangCard", self.m_pGameRoomConfig.iOperationTime * 1000, self.onOpBuGangCardTimerTimeOut)
	else
		if operationType:isGang(op.iOpValue) or operationType:isBuGang(op.iOpValue) or operationType:isAnGang(op.iOpValue) then
			self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
			self.m_iCurOutCardSeatId = 0
			self:drawCard(self.m_players[seatId])
		else
			self.m_pRoundStatus = self.m_pRoundStatusMap.ROUND_STATUS_OUTCARD
			self.m_iCurOutCardSeatId = seatId
			self:startTimer("outCard", self:onGetOutCardTime(self.m_iCurOutCardSeatId), self.onOutCardTimerTimeOut)
		end
	end
end

function GameRound:onOpBuGangCardTimerTimeOut()
	self:onClientUserHasAllOp()
end

function GameRound:onClientCmdRequestAI(data, userId)
	local player = self:onGetPlayerByUserId(userId)
	if player then
		self:onUserSetTuoGuan(player, data.iAiType == 1 and true or false)
	end
end

function GameRound:onUserSetTuoGuan(player, isTuoGuan)
	player:onSetTuoGuan(isTuoGuan)
	local cmd = socketCmd.SERVER_CMD_BROADCAST_USER_AI
	local info = {}
	info.iUserId = player:onGetUserId()
	info.iAiType = isTuoGuan and 1 or 0
	self.m_pGameTable:onBroadcastTableUsers(cmd, info)
end

function GameRound:onOutCardTimerTimeOut()
	Log.i(Tag, "onOutCardTimerTimeOut")
	local player = self.m_players[self.m_iCurOutCardSeatId]
	local pHandCardMap = player:onGetHandCardMap()
	local pCard = pHandCardMap[#pHandCardMap]
	local data = {
		iCardValue = pCard.iCardValue,
	}
	-- 设置当前玩家托管
	self:onUserSetTuoGuan(player, true)
	self:onClientCmdOutCard(data, player:onGetUserId())
end

--抓牌
function GameRound:onDrawCardTimerCallback()
	self:drawCard(self.m_players[self.m_iCurOutCardSeatId]) 
end 

function GameRound:onCheckOutCardIsValid(seatId, cardValue)
	local isValid = false
	-- 是否在在玩家手牌中
	local pHandCardMap = self.m_players[seatId]:onGetHandCardMap()
	-- Log.dump(Tag, pHandCardMap, "pHandCardMap["..seatId.."]")
	for i = 1, #pHandCardMap do
		if pHandCardMap[i].iCardValue == cardValue then
			isValid = true
		end
	end
	return isValid
end

--[[
resultType: 0流局 1非流局 
huInfos = {
	iHuSeatId,
	iHuCard,
	iHuType,
	iHuHandCardMap,
}
]]
function GameRound:onGameStopRound(resultType)
	self:clearAllRoundTimer()
	
	self.m_pUserGameStopHuInfoTable = self.m_logic:onGetGameStopHuInfo(self.m_pTurnMoneyInfoTable)
	local cmd = socketCmd.SERVER_CMD_BROADCAST_STOP_ROUND
	local info = {}
	info.iResultType = resultType
	info.iServerFee = self.m_pGameRoomConfig.iServerFee
	info.iBasePoint = self.m_pGameRoomConfig.iBasePoint
	info.iRoundTime = 0
	info.iUserCount = self:onGetPlayerCount()
	info.iExtendInfo = json.encode(self.m_logic:onGetGameLogicExtendInfo())
	info.iUserInfoTable = {}
	for i = 1, info.iUserCount do
		local player = self.m_players[i]
		if player then
			local pMoney = player.m_money - self.m_pUserGameStopHuInfoTable[i].iTotalTurnMoney
			player.m_money = pMoney > 0 and pMoney or 0
			player:onSetTurnMoney(self.m_pUserGameStopHuInfoTable[i].iTotalTurnMoney)
			info.iUserInfoTable[i] = {}
			local pUserInfo = info.iUserInfoTable[i]
			pUserInfo.iSeatId = player:onGetSeatId()
			pUserInfo.iUserId = player:onGetUserId()
			pUserInfo.iMoney = player.m_money
			pUserInfo.iTurnMoney = player:onGetTurnMoney()
			local pHandCardMap = player:onGetHandCardMap()
			local pHandleCardMap = player:onGetHandleCardMap()
			local pOutCardMap = player:onGetOutCardMap()
			pUserInfo.iHandCardCount = #pHandCardMap
			pUserInfo.iHandCardMap = {}
			for k, v in pairs(pHandCardMap) do
				pUserInfo.iHandCardMap[#pUserInfo.iHandCardMap + 1] = v.iCardValue
			end
			pUserInfo.iHandleCardCount = #pHandleCardMap
			pUserInfo.iHandleCardMap = {}
			for k, v in pairs(pHandleCardMap) do
				local pTemp = {
					iOpValue = v.iOpValue,
					iCardValue = v.iCardValue,
				}
				pUserInfo.iHandleCardMap[#pUserInfo.iHandleCardMap + 1] = pTemp
			end
			pUserInfo.iOutCardCount = #pOutCardMap
			pUserInfo.iOutCardMap = pOutCardMap
			pUserInfo.iGameStopHuInfo = json.encode(self.m_pUserGameStopHuInfoTable[i])
		end
	end
	self.m_pGameTable:onBroadcastTableUsers(cmd, info)

	self.m_pGameTable:onGameStopRound()
end

function GameRound:onGetNextSeat(seatId)
	return seatId == self:onGetPlayerCount() and 1 or seatId + 1
end 
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--初始化
function GameRound:initRoundInfo()
	self:initPlayerInfo()

	self.m_pBankerSeatId = -1

	self.m_pRoundStatus   = self.m_pRoundStatusMap.ROUND_STATUS_NONE
end 

function GameRound:initPlayerInfo()
	self.m_players = self.m_pGameTable.m_tableUserMap
	for k, v in pairs(self.m_players) do
		v:onResetRoundUserInfo()
	end
end 
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--网络消息

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--定时器 框架部分
local function getFullNameByKey(key)
	return 'GameRound_timer_'..key
end 

function GameRound:getTimerHandlerByKey(key)
	return self[getFullNameByKey(key)]
end 

function GameRound:setTimerHandler(key , value)
	self[getFullNameByKey(key)] = value
end 

function GameRound:startTimer(key, time, callback)
	self:stopTimer(key)
	Log.d(Tag, "startTimer key[%s] time[%s]", key, time)
	if not self:getTimerHandlerByKey(key) then
		self:setTimerHandler(key, self.m_scheduleMgr:registerOnceNow(callback, time, self) )
	end 
end 

function GameRound:stopTimer(key)
	local h = self:getTimerHandlerByKey(key)
	if h then 
		self.m_scheduleMgr:unregister(h)
		self:setTimerHandler(key, nil)
	end 
end 

function GameRound:clearAllRoundTimer()
	self:stopTimer("drawCard")
	self:stopTimer("dealCards") 
	self:stopTimer("outCard") 
	self:stopTimer("opOutCard")
	self:stopTimer("opDarwCard")
	self:stopTimer("makeBanker")
end

function GameRound:onGetPlayerByUserId(userId)
	for seatId, player in ipairs(self.m_players) do
		if player.m_userId == userId then
			return player
		end
	end
end

function GameRound:onGetPlayerCount()
	return #self.m_players
end

function GameRound:isRoundStatusNone()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_NONE
end

function GameRound:isRoundStatusDrawCard()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_DRAWCARD
end

function GameRound:isRoundStatusOutCard()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_OUTCARD
end

function GameRound:isRoundStatusOpDrawCard()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_OPDRAWCARD
end

function GameRound:isRoundStatusOpOutCard()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_OPOUTCARD
end

function GameRound:isRoundStatusOpBuGangCard()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_OPBUGANGCARD
end

function GameRound:isRoundStatusStop()
	return self.m_pRoundStatus == self.m_pRoundStatusMap.ROUND_STATUS_STOP
end

function GameRound:onGetOutCardTime(seatId)
	local player = self.m_players[seatId]
	local pTime = self.m_pGameRoomConfig.iOutCardTime
	return player:onGetTuoGuan() and 1000 or pTime * 1000
end

function GameRound:onGetOpCardTime(seatId)
	local player = self.m_players[seatId]
	local pTime = self.m_pGameRoomConfig.iOperationTime
	return player:onGetTuoGuan() and 1000 or pTime * 1000
end

function GameRound:onGetRemainCardCount()
	return self.m_pool:remainCard()
end

function GameRound:onGetUserReconnectGameInfo(seatId)
	local player = self.m_players[seatId]
	if not player then return end
	local pHandCardMap = player:onGetHandCardMap()
	local pHandleCardMap = player:onGetHandleCardMap()
	local pOutCardMap = player:onGetOutCardMap()
	local pUserInfo = {}
	pUserInfo.iIsAI = 1
	pUserInfo.iHandCardCount = #pHandCardMap
	pUserInfo.iHandCardMap = {}
	for k, v in pairs(pHandCardMap) do
		pUserInfo.iHandCardMap[#pUserInfo.iHandCardMap + 1] = v.iCardValue
	end
	pUserInfo.iHandleCardCount = #pHandleCardMap
	pUserInfo.iHandleCardMap = {}
	for k, v in pairs(pHandleCardMap) do
		local pTemp = {
			iOpValue = v.iOpValue,
			iCardValue = v.iCardValue,
		}
		pUserInfo.iHandleCardMap[#pUserInfo.iHandleCardMap + 1] = pTemp
	end
	pUserInfo.iOutCardCount = #pOutCardMap
	pUserInfo.iOutCardMap = pOutCardMap

	pUserInfo.iCurGradCard = 0
	pUserInfo.iExtendInfo = ""

	return pUserInfo
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--流程
GameRound.ProcessMap = {
	-- 摇骰子
	[1] = {
		iFunc = GameRound.process_makeBanker,
		iTime = 2000,
	},
	-- 发牌 广播发牌 0x3001
	[2] = {
		iFunc = GameRound.process_dealCards,
		iTime = 2000,
	},
	-- ["exchange"]     = GameRound.process_exchangeCards,---------换三张
	-- ["bao_ting"]     = GameRound.process_procBaoTing,-----------报听
	-- ["ding_que"]     = GameRound.process_procDingQue,-----------定缺
	-- ["piao"]         = GameRound.process_procPiao,--------------漂  卡五星 特有
}
return GameRound