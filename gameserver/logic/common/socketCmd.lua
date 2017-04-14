
local SocketCMD = {
	-- allocServer
	REGISTER_ALLOC_CLIENT					= 0x0007,   -- gameServer注册到allocServer
	REPORT_SERVER_IP_PORT            		= 0x0504,	-- gameServer上报大厅IP，port
	REPORT_SERVER_DATA               		= 0x0501,	-- gameServer上报server数据
	UPDATE_ROOM_USER_COUNT           		= 0x0502,   -- 更新房间玩家的个数
	REPORT_BATTLE_DATA                      = 0x0522,
	UPDATE_BATTLE_ROOM_DATA          		= 0x0512,
	SYS_RESPONSE_MASTER_BATTLEROOM_COUNT	= 0x0514,
	ALLCMD_REQUEST_USER_BATTLE_DATA  		= 0x0523,
	GAMECMD_RESPONSE_USER_BATTLE_DATA		= 0x0524,

	REPORT_GAME_USERS                       = 0x0530,--上报给alloc ,该牌局中一起玩牌的玩家

	-- hallServer
	CLIENT_CMD_LOGIN                    	= 0x1001,
	CLIENT_CMD_LOGOUT						= 0x1002,
	CLIENT_CMD_CHAT                     	= 0x1003, --用户私聊
    CLIENT_CMD_FACE                			= 0x1004, --发送表情

	CLIENT_CMD_READY						= 0x2001, --用户准备
	SERVER_BROADCAST_USER_READY             = 0x4001, --广播用户准备
	SERVER_CMD_CLIENT_LOGIN_ERROR           = 0x1005,
	SERCER_CMD_CLIENT_LOGIN_SUCCESS         = 0x1110,
	SERVER_CMD_CLIENT_RECONNECT_SUCCESS		= 0x1111, --新的断线重连命令字，加多GameType
	SERVER_BROADCAST_USER_LOGIN             = 0x100D, --广播用户进入
	SERVER_BROADCAST_USER_LOGOUT            = 0x100E, --广播用户退出
	SERVER_CMD_CLIENT_LOGOUT_SUCCESS        = 0x1008, --退出成功 

	SERVER_CMD_CLINET_TABLE_LEVEL_AND_NAME  = 0x1112,
	SERVER_CMD_CLIENT_READY_COUNT_DOWN      = 0x3008, --告诉客户端准备倒计时

	CLIENT_CMD_SELECT_PAI                   = 0x200C,--给客户端广播各玩家的选缺信息
	CLIENT_CMD_SELECT_PAI2                  = 0x200D,--客户端定缺
	CLIENT_CMD_CREATE_BATTLE_ROOM			= 0x0130,
	CLIENT_CMD_OUT_CARD						= 0x2002,
	CLIENT_CMD_TAKE_OPERATION           	= 0x2004, --用户执行操作
	CLIENT_CMD_REQUEST_AI                   = 0x2005, --用户托管或取消托管

	SERVER_BROADCAST_READY_START            = 0x4002,--广播游戏开始
	SERVER_CMD_DEAL_CARD                    = 0x3001,--发牌
	SERVER_CMD_GRAB_CARD					= 0x3002,--抓牌
	SERVER_CMD_INVALID_OPT                  = 0x3003,--无效操作
	SERVER_CMD_KICK_OUT						= 0x3004,--踢掉用户
	SERVER_CMD_OPT_HINT						= 0x3005,--服务器通知客户端可以操作
	SERVER_CMD_USER_SELECT_QUE              = 0x3006,--通知客户端选择定缺
	SERVER_CMD_TELL_LEVEL_AND_NAME          = 0x3007,

	SERVER_CMD_USER_BAO_TING                = 0x3026,--服务器给用户广播选择报听
	CLIENT_CMD_BAO_TING                     = 0x3027,--客户端返回报听结果
	SERVER_CMD_USER_BAO_TING_RET            = 0x3028,--server给用户广播选择报听结果
	
	SERVER_CMD_START_GAME                   = 0x4003,--服务器广播游戏开始
	SERVER_CMD_BROADCAST_USER_OUT_CARD      = 0x4004,--广播用户出牌
	SERVER_CMD_BROADCAST_TAKE_OPERATION     = 0x4005,--广播用户进行了什么操作
	SERVER_CMD_BROADCAST_CURRENT_PLAYER     = 0x4006,--广播当前玩家ID
	SERVER_CMD_BROADCAST_USER_AI            = 0x4007, --广播用户托管

	SERVER_CMD_BROADCAST_GFXY               = 0x4012,--广播刮风下雨
	SERVER_CMD_BROADCAST_HU                 = 0x4013,
	SERVER_CMD_BROADCAST_HU2                = 0x4020,
	SERVER_CMD_BROADCAST_STOP_ROUND         = 0x4021,--广播一局游戏结束
	SERVER_CMD_NOTIFY_USER_MONEYINFO        = 0x4022,--通知客户端实时数据变化
	SERVER_CMD_BROADCAST_OP_TIME            = 0x4023,--广播桌子操作时间

	-- 道具(包括钻石)Server
	DAOJU_SERVER_MAIN_CMD                   = 0x7070,
		-- 二级命令字
    	SERVER_GET_DIAM_NUM 				= 0x1001, -- 获取玩家钻石数量
    	SERVER_UPDATE_DIAM_NUM 				= 0x1005, -- 更新用户钻石数量
    	SERVER_GET_DIAM_RES 				= 0x2001, -- Server返回玩家钻石数量
    	SERVER_UPDATE_DIAM_RES 				= 0x2002, -- Server返回更新用户钻石结果

    -- backendServer
    BACKEND_CMD_EXCUTE_REDIS         		= 0x7501, -- 执行Redis命令
    BACKEND_CMD_BATTLE_LOG_GY        		= 0x7219, -- 写贵阳麻将的战报
    BACKEND_CMD_WRITE_LOG	                = 0x7218, -- 写麻将的牌局上报

    -- moneyserver
    CLIENT_CMD_GET_RECORD               	= 0x1105, -- 取用户钱数,经验值
    SERVER_CMD_GET_RECORD               	= 0x1109, -- 服务器回应取用户信息
    SERVRE_CMD_MONEY_UPDATE_REQ             = 0x1100, -- 更新金币请求
    SERVER_CMD_MONEY_UPDATE_RES             = 0x1101, -- 更新金币返回


    -- robotServer
    AUTOAICMD_ROBOT_PACKET                  = 0x1116,
    -- 包中包命令字
    ROBOT_INTRCMD_REPORT_ROBOTLIST			= 0x0101, -- 上报机器人
    ROBOT_INTRCMD_REQUEST_AI				= 0x0102, -- 添加机器人
    SERVER_CMD_ROBOT_LOGIN 					= 0x1115, -- 机器人登陆
}

return SocketCMD
