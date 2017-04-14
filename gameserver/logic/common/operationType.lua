local operationType = {}

operationType.RIGHT_CHI = 0x0001--右吃
operationType.MID_CHI   = 0x0002--中吃
operationType.LEFT_CHI  = 0x0004--左吃
operationType.PENG      = 0x0008--碰
operationType.GANG      = 0x0010--碰杠
operationType.AN_GANG   = 0x0020--暗杠
operationType.BU_GANG   = 0x0040--补杠
operationType.TING      = 0x0080--听牌
operationType.HU        = 0x0100--胡
operationType.ZIMO      = 0x0200--自摸
operationType.QIANGGANGHU        = 0x0400--抢杠胡
operationType.GANGSHANGKAIHUA    = 0x0800--杠上开花
operationType.GANGSHANGPAO       = 0x1000--杠上炮
operationType.GUO       = 0x8000--过

function operationType:isRightChi(operateValue)
	return self.RIGHT_CHI == (operateValue & self.RIGHT_CHI)
end

function operationType:isMidChi(operateValue)
	return self.MID_CHI == (operateValue & self.MID_CHI)
end

function operationType:isLeftChi(operateValue)
	return self.LEFT_CHI == (operateValue & self.LEFT_CHI)
end

function operationType:isPeng(operateValue)
	return self.PENG == (operateValue & self.PENG)
end

function operationType:isGang(operateValue)
	return self.GANG == (operateValue & self.GANG)
end

function operationType:isZiMo(operateValue)
	return self.ZIMO == (operateValue & self.ZIMO)
end

function operationType:isHu(operateValue)
	return self.HU == (operateValue & self.HU)
end

function operationType:isAnGang(operateValue)
	return self.AN_GANG == (operateValue & self.AN_GANG)
end

function operationType:isBuGang(operateValue)
	return self.BU_GANG == (operateValue & self.BU_GANG)
end

function operationType:isTing(operateValue)
	return self.TING == (operateValue & self.TING)
end

function operationType:isGuo(operateValue)
	return self.GUO == (operateValue & self.GUO)
end

function operationType:isQiangGangHu(operateValue)
	return self.QIANGGANGHU == (operateValue & self.QIANGGANGHU)
end

function operationType:isGangShangKaiHua(operateValue)
	return self.GANGSHANGKAIHUA == (operateValue & self.GANGSHANGKAIHUA)
end

function operationType:isGangShangPao(operateValue)
	return self.GANGSHANGPAO == (operateValue & self.GANGSHANGPAO)
end

return operationType