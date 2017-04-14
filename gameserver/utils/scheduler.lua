local TAG = 'scheduler'
local scheduler = class()

function scheduler:ctor(id, callback, intaval, times, delay,  target, ...) 
	self.name = id 
	self:updateSet(id, callback, intaval, times, delay,  target, ...)
end 

function scheduler:dtor()
end

function scheduler:updateSet(name, callback, intaval, times, delay,  target, ...)
	self.delay     = delay 
	self.intaval   = intaval 
	self.times     = times 
	self.callback  = callback 
	self.target    = target 
	self.otherArgs = ...
	self.name      = name

	self.ontimes    = 0
	self.curIntaval = intaval

	self.alive  = true
end 

function scheduler:isAlive()
	--local ret =  (not self.isDeath) and (self.ontimes < self.times  or self.times == -1)
	----log.d(TAG, "name:"..tostring(self.name)..",isDeath:"..tostring(self.isDeath)..',isAlive:'..tostring(ret)..","..tostring(self.ontimes).."/"..tostring(self.times))
	return self.alive
end 

function scheduler:onTriggle()
	if self:isAlive() then 
		self.ontimes    = self.ontimes + 1
		self.curIntaval = self.intaval

		if self.times ~= -1 and self.ontimes >= self.times then 
			self:death()
		end 
		--log.d(TAG, 'onTriggle times:'..self.ontimes)
		if self.callback then 
			self.callback(self.target, self.otherArgs)
		end 
	end 
end 

function scheduler:updateTime(dt)
	if not self:isAlive() then 
		return 
	end 

	if self.delay > 0 then 
		self.delay = self.delay - dt 
	else-- <= 0
		self.curIntaval = self.curIntaval - dt 
		if self.curIntaval <= 0 then 
			self:onTriggle()
		end 
	end 
end 

function scheduler:death()
	self.alive = false 
end 
 

return scheduler