local skynet = require "skynet"
local mysql = require "mysql"
local json = require "cjson"

local TAG = "DBClient"

local MAX_SQL_BUF_LEN = 2048

local DBClient = class()

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

function DBClient:isConnected()
	if self.m_pSocketfd then
        return true
    else
        self:connectToClient()
        return false
    end
end

function DBClient:connectToClient()
    self.m_pSocketfd = mysql.connect({
        host = self.m_dbConfig.HOST,
        user = self.m_dbConfig.USER,
        password = self.m_dbConfig.PARSSWORD,
        database = self.m_dbConfig.DB,
        port = self.m_dbConfig.PORT,
        max_packet_size = 1024 * 1024,
        on_connect = on_connect,
    })
    if not self.m_pSocketfd then 
        Log.d(TAG, "DBClient.client_fd is nil, db failed!")
        return -1
    end
    Log.d(TAG, "DBClient[%s] success to connect to mysql server", self.m_pSocketfd)
    return 0
end

function DBClient:init()
	local function on_connect(db)
		db:query("set charset utf8")
	end
	self.m_dbConfig = require("config/gameServerConfig").dbConfig
	assert(self.m_dbConfig)
	Log.dump(TAG, self.m_dbConfig, "m_dbConfig")
	return self:connectToClient()
end

function DBClient:disconnect()
    Log.e(TAG, "DBClient disconnect")
	self.m_pSocketfd = nil
end

function DBClient:getSvrDeply(key)
    if not self:isConnected() then
        return
    end
    local sqlStr = string.format("select v,time from mahjong_svr_deploy where `k`='%s'", key)
    local res = self.m_pSocketfd:query(sqlStr)
    return res
end 

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        -- Log.i(TAG, "cmd : %s subcmd : %s", cmd, subcmd)
        local f = assert(DBClient[cmd])
        skynet.ret(skynet.pack(f(DBClient, subcmd, ...)))
    end)
end)
