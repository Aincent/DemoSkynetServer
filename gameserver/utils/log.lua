local skynet = require("skynet")
local Log = class()

Log.LV_ERROR = 1
Log.LV_WARN = 2
Log.LV_INFO = 3
Log.LV_DEBUG = 4

local function format_msg(level, tag, fmt, ...)
    local time_info = os.date("%X",os.time())
    local debug_info = debug.getinfo(3)
    local msg = string.format(tostring(fmt), ...)
    return string.format("%s:%s[%d] lv%d %s [%s] --> %s",debug_info.source, debug_info.name, debug_info.currentline, level, tag, time_info, msg)
end

local function log_printfmsg(msg)
    skynet.error(msg)
end

local log_level = Log.LV_DEBUG

local function log_error(tag, fmt, ...)
	if log_level >= Log.LV_ERROR then
		local info = format_msg(Log.LV_ERROR, tag, fmt, ...)
		log_printfmsg(info)
	end
end

local function log_warn(tag, fmt, ...)
	if log_level >= Log.LV_WARN then
		local info = format_msg(Log.LV_WARN, tag, fmt, ...)
		log_printfmsg(info)
	end
end

local function log_info(tag, fmt, ...)
	if log_level >= Log.LV_INFO then
		local info = format_msg(Log.LV_INFO, tag, fmt, ...)
		log_printfmsg(info)
	end
end

local function log_debug(tag, fmt, ...)
	if log_level >= Log.LV_DEBUG then
		local info = format_msg(Log.LV_DEBUG, tag, fmt, ...)
		log_printfmsg(info)
	end
end

local function log_dump(tag, root, name)
	if log_level < Log.LV_DEBUG then return end
    local function _dump(t, space, name)
        local temp = {}
        table.insert(temp, (name or "table").." = {")
        for k, v in pairs(t) do
            local key = tostring(k)
            if type(v) == "table" then
                table.insert(temp, space..string.rep(" ", 4).._dump(v, space..(next(t, k) and "" or "" )..string.rep(" ", 4), key))
            else
                if type(v) == "number" or type(v) == "boolean" then
                    table.insert(temp, space..string.rep(" ", 4)..key.." = "..tostring(v)..",")
                else
                    table.insert(temp, space..string.rep(" ", 4)..key.." = \""..tostring(v).."\",")
                end
            end
        end
        table.insert(temp, space.."}")
        return table.concat(temp, "\n")
    end
    local fmt = "\n".._dump(root, "", name or "table")
    local info = format_msg(Log.LV_DEBUG, tag, fmt)
    log_printfmsg(info)
end

Log.e = log_error
Log.w = log_warn
Log.i = log_info
Log.d = log_debug
Log.dump = log_dump

return Log