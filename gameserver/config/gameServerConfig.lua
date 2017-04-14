
local dbip_dev = "192.168.200.144"
local dbip_test = "192.168.200.19"

local dbip = dbip_test

local ip_dev  = "192.168.96.156"
local ip_test = "192.168.201.90"
local ip_formal = "192.168.96.156"

local ip = ip_test

local config = {
    allocConfig = {
        [100] = {
            ip = ip,
            port = 8000,
        },
        [110] = {
            ip = ip,
            port = 8001,
        },
    },
    backendConfig = {
    	{
    		ip = ip,
    		port = 8750,
    	},
	},
    filterConfig = {
        {
            ip = ip,
            port = 6230,
        },
    },
    diamondConfig = {
        {
            ip = ip,
            port = 9800,
        },
        {
            ip = ip,
            port = 9801,
        },
    },
    moneyConfig = {
    	{
    		ip = ip,
    		port = 9500,
    	},
    	{
    		ip = ip,
    		port = 9501,
    	},
	},
    robotConfig = {
        {
            ip = ip,
            port = 8910,
        },
    },

    dbConfig = {
        SOCKET = "",
        PORT = 3388,
        PARSSWORD = "mwQraxraF54NYXns",
        HOST = dbip,
        DB = "mahjongdgd",
        USER = "mahjong",
    },
    deplyConfig = {
        CHECK_TIME_EXPIRE = 300,
        DEP_REDIS_OPEN  = 1,
        DEP_REDIS_IP = dbip,
        DEP_REDIS_PORT = 4530,
    },
	mtkeyRedisConfig = {
		open = 1,
		ip = dbip,
		port = 4544,
	},
    battlePaiJuRedisConfig = {
        open = 1,
        ip = dbip,
        port = 4546,
    },
    battlePayRedisConfig = {
        open = 1,
        ip = dbip,
        port = 4578,
    },
    lookbackConfig = {
        {
            open = 1,
            ip = ip,
            port = 8850,
            svrid = 0,
        },
    },
}

return config
