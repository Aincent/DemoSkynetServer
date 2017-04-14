local skynet = require("skynet")
local GameTable = require("logic/common/gameTable")

skynet.start(function()
	Log.d(TAG, "GameTableService start")
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if GameTable[cmd] then
			skynet.ret(skynet.pack(GameTable[cmd](GameTable, subcmd, ...)))
		else
			Log.e(TAG, "unknown cmd = %s", cmd)
		end
	end)
end)
