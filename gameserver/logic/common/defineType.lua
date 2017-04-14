
local DefineType = {}

-- login errorType
DefineType.SUCCESS_NEWCONNECT = 0
DefineType.SUCCESS_RECONNECT = 1
DefineType.SUCCESS_KICK_OTHER_USER = 2
DefineType.ERROR_USERKEY = 3
DefineType.ERROR_MYSQL = 4
DefineType.ERROR_TABLE_NOT_EXIST = 5
DefineType.ERROR_USERLOGINTABLE = 6
DefineType.ERROR_TABLE_MAX_COUNT = 7
DefineType.ERROR_NO_EMPTY_SEAT = 8
DefineType.ERROR_NOT_ENOUGH_MONEY = 9	-- 金币不足
DefineType.ERROR_UNKOWN = 10
DefineType.ERROR_NO_THIS_MAHJONG_TYPE = 11
DefineType.ERROR_MTKEY = 12
DefineType.ERROR_MATCH_ROOM_NOT_EXIST = 13
DefineType.ERROR_SAME_IP = 14
DefineType.ERROR_TOO_MUCH_MONEY = 15
DefineType.ERROR_FCM = 16
DefineType.ERROR_NEWER_PROGRESS = 17       -- 新手教学进度不对
DefineType.ERROR_ZB = 18                   -- 可能作弊
DefineType.ERROR_MAX_CODE = 19
DefineType.ERROR_SHENHE = 20					-- 审核需求，条件不满足审核，弹错误
DefineType.ERROR_DEVICEID_CONFICE = 21		-- 和桌上玩家的设备ID冲突
DefineType.SUCCESS_LOGIN_MATCH = 22			-- 
DefineType.SUCCESS_USER_WAIT = 23				-- 用户正在等待配桌
DefineType.ERROR_DUIJIA_POCHANG = 24			-- 对家破产，二人不给配这样的桌子
DefineType.ERROR_NEED_CHONGXINPEIZHUO = 25	-- 需要重新配桌，防止2人由于上局还没结算完，换桌换回原来的桌子
DefineType.ERROR_ROOM_VIP_LIMIT = 26			-- 房间对VIP等级进行限制
DefineType.ERROR_ROOM_FROM_DIFF_PROJECT = 27  -- 从不同的客户端进入
DefineType.ERROR_BATTLE_NOT_CREATEED = 28		-- 对战房间没有被创建
DefineType.ERROR_BATTLE_CERTIFICATION = 29	-- 认证等级无法通过(现在用于验证开的房间太多了)
DefineType.ERROR_BATTLE_NOT_ENOUGH_FEE = 30	-- 对战包厢房费不够
DefineType.ERROR_BATTLE_ROOM_NUM_LIMIT = 31	-- 对战包厢开房数量达到上限
DefineType.ERROR_CLIENT_VERSION = 32			-- 客户端版本过低

--游戏停止状态
DefineType.GAME_STATUS_STOP = 0
--中间停止状态
DefineType.GAME_STATUS_PAUSE = 1
--打牌状态
DefineType.GAME_STATUS_PLAYING = 2
--等待用户操作状态
DefineType.GAME_STATUS_WAIT_OPERATE = 3
--游戏准备停止状态,stopRound与stopGame之间
DefineType.GAME_STATUS_WAIT_STOP = 4
--桌子处于刚刚创建对战的状态
DefineType.BATTLE_STATUS_CREATED = 5
--对战的状态,一局游戏结束了,但是对战还是没有结束
DefineType.BATTLE_STATUS_PAUSE = 6
--对战结束了,已经完成了预设的牌局
DefineType.BATTLE_STATUS_STOP = 7
--对战等待玩家出牌
DefineType.BATTLE_STATUS_TIMEOUT_OUTCARD = 8
--对战等待玩家操作,这里有个问题，1。就是要不要等待所有玩家操作完，2.多个玩家有操作的时候怎么提示？,3.操作可以放弃，但是出牌不可以放弃啊
DefineType.BATTLE_STATUS_TIMEOUT_OPRERATION = 9

DefineType.STATUS_DISCONNECT = 0	--未连进来
DefineType.STATUS_LOGIN = 1		--已登录
DefineType.STATUS_SIT = 2			--坐下来

--battle解散的原因
DefineType.BATTLE_DISSMISS_MASTER_LEAVE = 0	--房主离开房间（客户端提示房主俩开）
DefineType.BATTLE_DISSMISS_AGREEMENT = 1		--所有玩家同意解散（客户端提示玩家同意解散）
DefineType.BATTLE_DISSMISS_FULL_ROUND = 2		--已经打满了盘数
DefineType.BATTLE_MASTER_LEAVE_AND_RESERVE = 3	--房主离开保留房间
DefineType.BATTLE_START_GAME_TIMER_OUT = 4		--开局超时
DefineType.USER_REQUEST_BACK_TO_HALL = 5		--客户端主动申请返回大厅（该子命令客户端回到大厅不做任何提示）

--给大厅上报人数
DefineType.USER_LOGIN   = 0
DefineType.USER_LOGOUT  = 1
DefineType.ROBOT_LOGIN  = 2
DefineType.ROBOT_LOGOUT = 3
DefineType.SOME_ERROR   = 4
DefineType.BATTLE_CREATE = 5
DefineType.BATTLE_RELEASE = 6

--更新钻石的action
DefineType.ActId_Diamond_fee = 153			--扣钻石台费
DefineType.ActId_Diamond_back = 154		--返还钻石台费
DefineType.ActId_Diamond_donate = 179		--打赏钻石扣钻石
DefineType.ActId_Diamond_donate_add = 180	--打赏钻石加钻石

--更新金币的action
DefineType.ActId_SERVICE_FEE = "1"  --扣除台费
DefineType.ActId_GAME_LOSE = "3"    --玩牌输钱
DefineType.ActId_GAME_WIN = "4"     --玩牌赢钱
DefineType.ActId_PROP_USE = "123"     --道具消耗
DefineType.ActId_EXP_UPLEVEL = "39"     --经验等级升级奖励
DefineType.ActId_GAME_SYSGIVE = "444"     --玩家牌局破产，系统补助不足金币
DefineType.ActId_BACK_FEE = "174"		--退回台费
DefineType.ActId_Baltter_FEE = "230"		--好友对战开房扣费

--开房支付方式
DefineType.BATTLE_PAY_OWNER = 0x0
DefineType.BATTLE_PAY_WINER = 0x1

--贵阳麻将，玩法类型
DefineType.GYWANFA_NORMAL = 0x0		--正常玩法 房主支付
DefineType.GYWANFA_SHANGXIA_JI = 0x1		--上下鸡
DefineType.GYWANFA_ZUOZHUANGT = 0x2		--坐庄
DefineType.GYWANFA_MANTANG_JI = 0x4		--满堂鸡
DefineType.GYWANFA_SHOUSHANG_JI = 0x8		--手上鸡
DefineType.GYWANFA_OWERPAY = 0x10		--房主支付
DefineType.GYWANFA_WINPAY = 0x20		--赢家支付
DefineType.GYWANFA_DINGQUE = 0x40		--定缺

DefineType.GYWANFA_GY = 0x1000                --贵阳麻将，原玩法, 为了兼容以前版本，如果不是三丁拐，不是遵义麻将则为贵阳麻将
DefineType.GYWANFA_THREE = 0x2000             --三丁拐
DefineType.GYWANFA_ZY = 0x4000                --遵义麻将
	
return DefineType

