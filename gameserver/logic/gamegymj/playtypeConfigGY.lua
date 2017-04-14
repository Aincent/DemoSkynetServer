local playtypeConfig = {}

-- 地方游戏下的不同游戏，例如贵阳麻将下的贵阳麻将，三丁拐...
playtypeConfig.LocalGameTypeMap = {
	GYMJ_GAME_GYMJ = 0x0,
	GYMJ_GAME_SDGMJ = 0x1,
	GYMJ_GAME_ZYMJ = 0x2,
	GYMJ_GAME_TRMJ = 0x3,
	GYMJ_GAME_ASMJ = 0x4,
}

-- 某个游戏下的特定玩法，例如上下鸡,满堂鸡...
playtypeConfig.GamePlayTypeMap = {
	GYMJ_TYPE_MANTANGJI = 0x1,
	GYMJ_TYPE_SHOUSHANGJI = 0x2,
	GYMJ_TYPE_SHANGXIAJI = 0x4,
	GYMJ_TYPE_ZUOZHUANG = 0x8,
	GYMJ_TYPE_YANGYANGSAN = 0x10,
}

return playtypeConfig