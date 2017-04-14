local mahjongDefine = {}

mahjongDefine.MJCodeMap = {
	MJ_CODE_GY = 29,
	MJ_CODE_GD = 100,
}

mahjongDefine.UserCardCountMap = {
	[mahjongDefine.MJCodeMap.MJ_CODE_GY] = 13,
	[mahjongDefine.MJCodeMap.MJ_CODE_GD] = 13,
}

mahjongDefine.MahjongPlayTypeMap = {
	[mahjongDefine.MJCodeMap.MJ_CODE_GY] = "logic/gamegymj/playtypeConfigGY",
	[mahjongDefine.MJCodeMap.MJ_CODE_GD] = "logic/gamegdmj/playtypeConfigGD",
}

mahjongDefine.MahjongGameLogicMap = {
	[mahjongDefine.MJCodeMap.MJ_CODE_GY] = "logic/gamegymj/playtypeConfigGY",
	[mahjongDefine.MJCodeMap.MJ_CODE_GD] = "logic/gamegdmj/gameRoundLogicGD",
}

return mahjongDefine