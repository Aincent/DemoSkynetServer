local config = {	
	[100] = {
		iListenIp = "172.30.204.160",
		iListenPort = 0,
		iMaxClient = 1024,
		iServerId = 1100,

		iMJCode = 100,
		iMaxPlayerCount = 4,
		iBasePoint = 1,
		iServerFee = 0,
		iMaxWaitOutTime = 240,
		iOutCardTime = 10,
		iOperationTime= 10,
		iPlayType = 1,

		iLevel = 0,

		iTableName = "好友对战",
		iIsBattleRoom = 1,
		iBattleDayFirstFree = 1,
		iBattlePayType = 1, -- 1是钻石 2是金币
	},

	[110] = {
		iListenIp = "172.30.204.160",
		iListenPort = 0,
		iMaxClient = 1024,
		iServerId = 1110,

		iMJCode = 100,
		iMaxPlayerCount = 4,
		iBasePoint = 200,
		iServerFee = 200,
		iMaxWaitOutTime = 240,
		iOutCardTime = 10,
		iOperationTime= 10,

		iLocalGameType = 1,
		iPlayType = 1,
		iExtendInfo = {},

		-- 金币场的配置
		iLevel = 0,
		iLevelNeedMoney = 1000,
		iLevelMinHoldMoney = 1000,
		iLevelMaxHoldMoney = 10000000,

		iTableName = "初级场",
		iIsBattleRoom = 0,
		iBattleDayFirstFree = 0,
		iBattlePayType = 0, -- 1是钻石 2是金币
	},
}

return config