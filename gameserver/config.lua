----------------------------------
-- 自定义参数
----------------------------------
local root = './'
local serverpath = root.."gameserver/"

thread = 4
cpath = root.."cservice/?.so"
harbor = 0
launchd = "./skynet.pid"
--daemon = "./skynet.pid"
--logger = "./GameServer/log_"
logger = nil

lua_path = root.."lualib/?.lua;"..serverpath.."/?.lua;"..root.."service/?.lua"
lua_cpath = root.."luaclib/?.so;"..serverpath.."/?.so"
lualoader = root.."lualib/loader.lua"
luaservice = root.."service/?.lua;"..serverpath.."/?.lua;"..serverpath.."service/?.lua"
preload = serverpath.."init.lua"	-- run preload.lua before every lua service run

-- 采用snlua bootstrap启动hello-world模块
bootstrap = "snlua bootstrap"
start = "main"

-- root = "./"
-- thread = 8
-- logger = nil
-- logpath = "."
-- harbor = 3
-- address = "127.0.0.1:2526"
-- master = "127.0.0.1:2013"
-- start = "main"	-- main script  nothing ?!
-- bootstrap = "snlua bootstrap"	-- The service for bootstrap
-- standalone = "0.0.0.0:2013"
-- luaservice = root.."service/?.lua;"..root.."test/?.lua;"..root.."examples/?.lua"
-- lualoader = root .. "lualib/loader.lua"
-- lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua"
-- lua_cpath = root .. "luaclib/?.so"
-- -- preload = "./examples/preload.lua"	-- run preload.lua before every lua service run
-- snax = root.."examples/?.lua;"..root.."test/?.lua"
-- -- snax_interface_g = "snax_g"
-- cpath = root.."cservice/?.so"
-- daemon = "./skynet.pid"
