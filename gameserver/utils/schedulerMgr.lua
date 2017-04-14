--------skynet的单位时间为0.01s
--------该schedulerMgr支持的最大精度为0.1s
local skynet = require "skynet"
local TAG = 'schedulerMgr'

local scheduler = require("utils/scheduler")
local schedulerMgr = class()
--[[
example:
	local tmgr = new(require('utils/schedulerMgr'))
	local rrrrr = 1
	local handler = nil 
	handler = tmgr:register(function()
		--log.d(TAG, 'add redisClient '..rrrrr)
		rrrrr = rrrrr + 1
		if rrrrr >= 10 then 
			tmgr:unregister(handler)
		end 
	end,1000,-1,0 )//  times=-1需手动unregister

]]--
--------------------------------------public----------------------------------------------------
--注册定时器时间
--callback:定时回调函数
--intaval:定时器的间隔时间[单位:毫秒  必须为100的整数倍  该定时器框架最大精度支持为0.1s]
--times:定时器触发的次数 
--[必须为-1  或者 正整数, 
--      -1表示无穷次                     需手动调用unregister取消
--      正整数表示触发次数,当触发次数达到时,自动销毁]
--delay:首次定时器触发的延迟时间[单位:毫秒  必须为100的整数倍  该定时器框架最大精度支持为0.1s]
--target, ...  传入的参数,作为callback的入参   可不传

--返回值:name  [移除定时器的key值]
------------------------------------------------------------------------------------------------
function schedulerMgr:register( callback, intaval, times, delay,  target, ...)
	assert((intaval % 100 == 0) and ( delay % 100 == 0),"时间必须是100的倍数!单位为毫秒")
	local name = self:gernerateUniqueId()
	--log.d(TAG, '注册name=[%s]间隔=[%d]次数=[%d]延迟=[%d]',name,intaval,times,delay)
	if not self.m_schedulers[name] then
		local s = new(scheduler, name, callback, intaval, times, delay, target, ...)
		self.m_schedulers[name] = s 
	else 
		self.m_schedulers[name]:updateSet(name,callback, intaval, times, delay,  target, ...)
	end

	if not self.m_isRunTime and self:isNeedTimer() then 
		self:startRunTimer()
	end 
	return name
end 

function schedulerMgr:registerOnce(callback, intaval, delay, target, ...)
	--log.d(TAG,"registerOnce")
	return self:register(callback, intaval, 1, delay, target, ...)
end 

function schedulerMgr:registerOnceNow(callback, intaval, target, ...)
	--log.d(TAG,"registerOnceNow")
	return self:register(callback, intaval, 1, 0, target, ...)
end 

--移除定时器  通过name作为键值
function schedulerMgr:unregister(name)
	local s = self.m_schedulers[name]
	if s then 
		--log.d(TAG, '销毁name=[%s]',name)
		s:death()
	end 

--	if self.m_isRunTime and not self:isNeedTimer() then 
--		self:stopRunTimer()
--	end 
end 

--移除该管理器中的所有已注册的定时器
function schedulerMgr:unregisterAllschedule()
	self:stopRunTimer()
		
end 

function schedulerMgr:ctor()
	self.m_schedulers   = {}

	self.m_isRunTime    = false --当前是否已经启用定时器 skynet.timeout
	self.m_curTimeUnit  = 100   --单位毫秒

	self.m_pCurTimerId       = 0
end 

--------------------------------------private  不建议外部访问--------------------------------------

function schedulerMgr:dtor()
	self:stopRunTimer()
	self:unregisterAllschedule()
end 

function schedulerMgr:isNeedTimer()
	local needTime = false 
	for name, s in pairs(self.m_schedulers) do
		if s:isAlive() then 
			needTime = true 
			break
		end 
	end
	----log.d(TAG, 'isNeedTimer:'..tostring(needTime))
	return needTime
end 

local instance = nil 
local function skynet_timeout_callback()
	----log.d(TAG, 'skynet_timeout_callback:')
	if instance then 
		instance.update(instance)
	end 
end 

function schedulerMgr:update()
	if not self.m_isRunTime then 
		----log.d(TAG, 'update over return: self.m_isRunTime = '..tostring(self.m_isRunTime))
		return 
	end 
	--
	local deathIds = {}
	for name,s in pairs(self.m_schedulers) do
		if s:isAlive() then 
			s:updateTime(self.m_curTimeUnit)
		--标记需要销毁的定时器
		else
			table.insert(deathIds,name)
		end 
	end
	if #deathIds > 0 then 
		self:destroySchedulers(deathIds)
	end 

	-- if not self:isNeedTimer() then 
	-- 	self:stopRunTimer()
	-- 	return 
	-- end 

	self:startRunTimer()
end 

function schedulerMgr:destroySchedulers(ids)
	for i=1,#ids do
		local name = ids[i]
		local s    = self.m_schedulers[name]
		delete(s)
		self.m_schedulers[name] = nil
	end
end 

function schedulerMgr:getSchedulerByHandler(h)
	return self.m_schedulers[h]
end 

function schedulerMgr:startRunTimer()
	----log.d(TAG, 'startRunTimer:')
	self.m_isRunTime = true
	instance = self
	--单服务内的to唯一
	self.to = skynet.timeout(self.m_curTimeUnit/10, skynet_timeout_callback)
end 

function schedulerMgr:stopRunTimer()
	self.m_isRunTime = false
	instance = nil 

	local deathIds = {}
	for name,s in pairs(self.m_schedulers) do
		table.insert(deathIds,name)
	end
	if #deathIds > 0 then 
		self:destroySchedulers(deathIds)
	end 
	self.m_schedulers = {}

	if self.to then 
		skynet.remove_timeout(self.to)
		self.to = nil 
	end 
	--self.m_pCurTimerId     = 0
end 

function schedulerMgr:gernerateUniqueId()
	local id = self.m_pCurTimerId + 1
	while(self.m_schedulers[id]) do 
		id   = id + 1
		if id >=  0xffffffff then 
			id = 1
		end 
	end 
	self.m_pCurTimerId = id 
	return id 
end 

return schedulerMgr