
local skynet = require "skynet"
local GameServer = require("logic/common/gameServer")

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.ret(skynet.pack(GameServer[command](GameServer,...)))
	end)
end)
