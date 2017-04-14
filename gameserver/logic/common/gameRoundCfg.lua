--ex for gy
local gameRoundCfg = {
	process   = {"crap","banker","deal", "start_game"}, --牌局流程	 -按序
	isBattle    = true,
	op_time     = 8000,--ms
	max_op_time = 600000,--ms
	bt_time     = 6000,--报听处理时间
	out_time    = 8000,--出牌时间
	--playerNum = 4 
}
return gameRoundCfg