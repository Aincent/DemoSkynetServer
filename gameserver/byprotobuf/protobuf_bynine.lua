
local Protobuf_bynine = class()

local TAG = 'Protobuf_bynine'

local PACKETHEADSIZE = {
	PACKET_BY_HEADER_SIZE = 9,
	PACKET_QE_HEADER_SIZE = 15
}

local PACKETVER = {
	SERVER_PACKET_DEFAULT_VER = 1,
	SERVER_PACKET_DEFAULT_SUBVER = 1
}

function Protobuf_bynine:ctor(data)
	-- Log.d(TAG, "Protobuf_bynine ctor")
	self.m_packetBuf = ''
	self.m_packetlen = PACKETHEADSIZE.PACKET_BY_HEADER_SIZE
	self.m_packetPos = PACKETHEADSIZE.PACKET_BY_HEADER_SIZE + 1
	self.m_cmd = -1
	-- 包头字段
	self.m_protobufname = 'BY'
	self.m_version = PACKETVER.SERVER_PACKET_DEFAULT_VER
	self.m_subversion = PACKETVER.SERVER_PACKET_DEFAULT_SUBVER
	self.m_code = 0
	-- 是否已经加过密
	self.m_ischeckcode = false
	-- 包头大小
	self.m_packetheadsize = PACKETHEADSIZE.PACKET_BY_HEADER_SIZE

	-- 如果是解包
	if data then
		self.m_packetBuf = data
		self:initPacketBegin()
	end
end

function Protobuf_bynine:read(len, fmt)
	if len <= 0 or self.m_packetlen <= 0 or self.m_packetPos + len - 1 > self.m_packetlen then
		return false
	end
	local value = string.unpack(fmt, self.m_packetBuf, self.m_packetPos)
	self.m_packetPos = self.m_packetPos + len
	return value
end

function Protobuf_bynine:readChar()
	local value = self:read(1, '!1>i1') or -1
	return string.char(value)
end

function Protobuf_bynine:readByte()
	local value = self:read(1, '!1>i1') or -1
	return value
end

function Protobuf_bynine:readShort()
	local value = self:read(2, '!1>i2') or -1
	return value
end

function Protobuf_bynine:readInt()
	local value = self:read(4, '!1>i4') or -1
	return value
end

function Protobuf_bynine:readInt64()
	local value = self:read(8, '!1>i8') or -1
	return value
end

function Protobuf_bynine:readString()
	local strlen = self:readInt()
	if strlen <= 0 or strlen + self.m_packetPos - 1 > self.m_packetlen then 
		return ""
	end
	local value = ""
	if strlen > 1 then
		value = string.sub(self.m_packetBuf, self.m_packetPos, self.m_packetPos + strlen - 2)
	end
	self.m_packetPos = self.m_packetPos + strlen
	return value
end

function Protobuf_bynine:readBinary()
	local binlen = self:readInt()
	Log.d(TAG, "binlen = %s", binlen)
	if binlen <= 0 then 
		return -1
	end
	local value = string.sub(self.m_packetBuf, self.m_packetPos, self.m_packetPos + binlen - 1)
	self.m_packetPos = self.m_packetPos + binlen
	return value
end

function Protobuf_bynine:write(value, len, fmt)
	local packstr = string.pack(fmt, value)
	self.m_packetBuf = self.m_packetBuf..packstr
	self.m_packetlen = self.m_packetlen + len
	-- Log.d(TAG, "self.m_packetlen[%s]", self.m_packetlen)
end

-- function Protobuf_bynine:writeChar(value)
-- 	assert(value and type(value) == 'string')
-- 	self:write(value, 1, '>s1')
-- end

function Protobuf_bynine:writeByte(value)
	assert(value and type(value) == 'number')
	value = value & 0xFF
	self:write(value, 1, '>i1')
end

function Protobuf_bynine:writeShort(value)
	assert(value and type(value) == 'number')
	value = value & 0xFFFF
	self:write(value, 2, '>i2')
end

function Protobuf_bynine:writeInt(value)
	assert(value and type(value) == 'number')
	self:write(value, 4, '>i4')
end

function Protobuf_bynine:writeInt64(value)
	assert(value and type(value) == 'number')
	self:write(value, 8, '>i8')
end

function Protobuf_bynine:writeString(value)
	if not value then return end
	local strlen = string.len(value..'\0') + 4
	self:write(value..'\0', strlen, '>s4')
end

function Protobuf_bynine:writeBinary(value)
	if not value then return end
	local strlen = string.len(value) + 4
	self:write(value, strlen, ">s4")
end

function Protobuf_bynine:writeBegin(cmd)
	assert(cmd >= 0)
	self.m_cmd = cmd
end

function Protobuf_bynine:writeEnd()
	assert(self.m_cmd >= 0)
	-- Log.d(TAG, "writeEnd, m_packetlen = %s", self:getPacketLen())
	local packstr = string.pack(">i2", self:getPacketLen() - 2)
	packstr = packstr..self.m_protobufname
	packstr = packstr..string.pack(">i1", self.m_version)
	packstr = packstr..string.pack(">i1", self.m_subversion)
	packstr = packstr..string.pack(">i2", self.m_cmd)
	packstr = packstr..string.pack(">i1", self.m_code)
	self.m_packetBuf = packstr..self.m_packetBuf
end

function Protobuf_bynine:getPacketLen()
	return self.m_packetlen
end

function Protobuf_bynine:getBeginCmd()
	assert(self.m_cmd >= 0)
	return self.m_cmd
end

function Protobuf_bynine:getBeginCode()
	return self.m_code
end

function Protobuf_bynine:initPacketBegin()
	self.m_packetlen = string.unpack(">i2", self.m_packetBuf, 1) + 2
	-- Log.d(TAG, "self.m_packetlen = %s", self.m_packetlen)
	self.m_version = string.unpack(">i1", self.m_packetBuf, 5)
	-- Log.d(TAG, "self.m_version = %s", self.m_version)
	self.m_subversion = string.unpack(">i1", self.m_packetBuf, 6)
	-- Log.d(TAG, "self.m_subversion = %s", self.m_subversion)
	self.m_cmd = string.unpack(">i2", self.m_packetBuf, 7)
	-- Log.d(TAG, "self.m_cmd = 0x%x", self.m_cmd)
	self.m_code = string.unpack(">i1", self.m_packetBuf, 9)
	-- Log.d(TAG, "self.m_code = %s", self.m_code)
end

return Protobuf_bynine
