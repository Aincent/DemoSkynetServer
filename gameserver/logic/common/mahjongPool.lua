--[[
麻将编码如下:
0x01 ~ 0x09   [1~9]万
0x11 ~ 0x19   [1~9]筒
0x21 ~ 0x29   [1~9]条
0x31 ~ 0x34   [东,南,西,北]风
0x41 ~ 0x43   [红中,发财,白板]
0x51 ~ 0x58   [春,夏,秋,冬,梅,兰,菊,竹]
]]
local TAG = "mahjongPool"

local mahjongPool = class()

function mahjongPool:initMahjongPool(cardTypeTable)
	self.m_pMahjongPool = {}
	for k, v in pairs(cardTypeTable) do
		local cardType = tonumber(k) or -1
		if cardType >= 0 and cardType < 5 then
			for i = 1, #v do
				local cardValue = cardType * 16 + i
				self.m_pMahjongPool[#self.m_pMahjongPool + 1] = cardValue
				self.m_pMahjongPool[#self.m_pMahjongPool + 1] = cardValue
				self.m_pMahjongPool[#self.m_pMahjongPool + 1] = cardValue
				self.m_pMahjongPool[#self.m_pMahjongPool + 1] = cardValue
			end
		elseif cardType == 5 then
			for i = 1, #v do
				local cardValue = cardType * 16 + i
				self.m_pMahjongPool[#self.m_pMahjongPool + 1] = cardValue
			end
		end
	end
	self.m_pMaxCardCount = #self.m_pMahjongPool
	self:shuffleMahjongPool()
	self:onStackCard()
	return self
end

-- 做牌
function mahjongPool:onStackCard()
	local pDealCards = {
		{0x01, 0x01, 0x01, 0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x04, 0x04, 0x04, 0x05},
		{0x11, 0x11, 0x11, 0x12, 0x12, 0x12, 0x13, 0x13, 0x13, 0x14, 0x14, 0x14, 0x15},
		{0x21, 0x21, 0x21, 0x22, 0x22, 0x22, 0x23, 0x23, 0x23, 0x24, 0x24, 0x24, 0x25},
		{0x31, 0x31, 0x31, 0x32, 0x32, 0x32, 0x33, 0x33, 0x33, 0x34, 0x34, 0x04, 0x05},
	}
	local pDrawCards = {0x07, 0x03, 0x08, 0x08, 0x09, 0x09}
	local pCardCout = 0
	for k, v in pairs(pDealCards) do
		for p, q in pairs(v) do
			pCardCout = pCardCout + 1
			for i = pCardCout, #self.m_pMahjongPool do
				if q == self.m_pMahjongPool[i] then
					local pValue = self.m_pMahjongPool[pCardCout]
					self.m_pMahjongPool[pCardCout] = self.m_pMahjongPool[i]
					self.m_pMahjongPool[i] = pValue
					break
				end
			end
		end
	end
	for k, v in pairs(pDrawCards) do
		pCardCout = pCardCout + 1
		for i = pCardCout, #self.m_pMahjongPool do
			if v == self.m_pMahjongPool[i] then
				local pValue = self.m_pMahjongPool[pCardCout]
				self.m_pMahjongPool[pCardCout] = self.m_pMahjongPool[i]
				self.m_pMahjongPool[i] = pValue
				break
			end
		end
	end
end	

--洗牌
function mahjongPool:shuffleMahjongPool()
	local swapIndex1, swapIndex2 = 1, 1
	for i = 1, 200 do
		swapIndex1 = math.random(self.m_pMaxCardCount)
		swapIndex2 = math.random(self.m_pMaxCardCount)
		local pValue = self.m_pMahjongPool[swapIndex1]
		self.m_pMahjongPool[swapIndex1] = self.m_pMahjongPool[swapIndex2]
		self.m_pMahjongPool[swapIndex2] = pValue
	end
end 

--发牌
function mahjongPool:dealCards(playerNum, mahjongNum)
	local dealCardMap = {}
	for i = 1, playerNum do
		local handCards = {}
		for j = 1, mahjongNum or 1 do
			handCards[#handCards + 1] = self:pop()
		end
		dealCardMap[#dealCardMap + 1] = handCards
	end
	return dealCardMap
end 

-- 抓牌
function mahjongPool:drawCard()
	return self:pop()
end

function mahjongPool:pop()
	local popCard = table.remove(self.m_pMahjongPool, 1)
	return popCard
end 

function mahjongPool:top()
	return self.m_pMahjongPool[#self.m_pMahjongPool]
end 

--剩余张数
function mahjongPool:remainCard()
	return #self.m_pMahjongPool
end 

--马牌
function mahjongPool:getMa(num)
	local mas = {}
	while num > 0 and self:length() > 0 do
		table.insert(mas, self:pop())
		num = num - 1
	end
	return mas
end 

return mahjongPool