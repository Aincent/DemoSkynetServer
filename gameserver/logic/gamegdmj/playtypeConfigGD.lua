local playtypeConfigGD = {}

-- 地方游戏下的不同游戏
playtypeConfigGD.LocalGameTypeMap = {
	GUANGDONGMJ_GAME_TDHMJ = 0x1,      	-- 推倒胡
	GUANGDONGMJ_GAME_TDHGPMJ = 0x2,		-- 推倒胡(鬼牌)
	GUANGDONGMJ_GAME_ZPTDHMJ = 0x3,		-- 做牌推倒胡
}

-- 大玩法下的牌配置
playtypeConfigGD.LocalGameCardMap = {
	[playtypeConfigGD.LocalGameTypeMap.GUANGDONGMJ_GAME_TDHMJ] = {
		iMaxUserCount = 4,
		iMaxCardCount = 136,
		iDealCardCount = 13,
	},
	[playtypeConfigGD.LocalGameTypeMap.GUANGDONGMJ_GAME_TDHGPMJ] = {
		iMaxUserCount = 4,
		iMaxCardCount = 136,
		iDealCardCount = 13,
	},
	[playtypeConfigGD.LocalGameTypeMap.GUANGDONGMJ_GAME_ZPTDHMJ] = {
		iMaxUserCount = 4,
		iMaxCardCount = 136,
		iDealCardCount = 13,
	},
}

-- 某个游戏下的特定玩法
playtypeConfigGD.GamePlayTypeMap = {
	GUANGDONGMJ_TYPE_KEHUQIDUI = 0x1,					-- 可胡七对
	GUANGDONGMJ_TYPE_BAOGANGKAI = 0x2,					-- 包杠开
	GUANGDONGMJ_TYPE_MAGENGANG = 0x4,					-- 马跟杠
	GUANGDONGMJ_TYPE_HUANGPAIBUHUANGZHUANG = 0x8,		-- 荒牌不荒庄
	GUANGDONGMJ_TYPE_LIANZHUANGJIAMA = 0x10,			-- 连庄加马
	GUANGDONGMJ_TYPE_JIEJIEGAO = 0x20,					-- 节节高
	GUANGDONGMJ_TYPE_MAGUIHU = 0x40,					-- 满鬼和
	GUANGDONGMJ_TYPE_MAGENDIFEN = 0x80,					-- 马跟底分
	GUANGDONGMJ_TYPE_WUGUIJIABEI = 0x100,				-- 无鬼加倍
	GUANGDONGMJ_TYPE_GUIPAI = 0x200,					-- 鬼牌
	GUANGDONGMJ_TYPE_MAIMA = 0x400,						-- 买马
}

-- 玩法下的扩展信息
playtypeConfigGD.ExtendInfoMap = {
	[playtypeConfigGD.GamePlayTypeMap.GUANGDONGMJ_TYPE_GUIPAI] = {
		GUANGDONGMJ_TYPE_GUIPAI_EXTEND_GUANBI = 0x1,	-- 关闭
		GUANGDONGMJ_TYPE_GUIPAI_EXTEND_BAIBAN = 0x2,	-- 白板
		GUANGDONGMJ_TYPE_GUIPAI_EXTEND_FANGUI = 0x3,	-- 番鬼
		GUANGDONGMJ_TYPE_GUIPAI_EXTEND_SHUANGGUI = 0x4,	-- 双鬼
	},
}

return playtypeConfigGD