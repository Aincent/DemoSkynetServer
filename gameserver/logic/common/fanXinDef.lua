local FanXinDef = {}
local DEF       = {}
local VALUE     = {}
FanXinDef.def   = DEF
FanXinDef.value = VALUE

DEF.TIAN_HU_GY        = 0x1--天胡
DEF.DI_HU_GY          = 0x2--地胡
DEF.QING_LONG_BEI_GY  = 0x3--青龙背
DEF.QING_QI_DUI_GY    = 0x4--清七对
DEF.LONG_QI_DUI_GY    = 0x5--龙七对
DEF.QING_DA_DUI_GY    = 0x6--清大对
DEF.QING_YI_SE_GY     = 0x7--清一色
DEF.QI_DUI_GY         = 0x8--七对
DEF.DA_DUI_ZI_GY      = 0x9--大对子
DEF.PING_HU_GY        = 0xA--平胡
DEF.BAO_TING_GY       = 0xB--报听
DEF.SHA_BAO_GY        = 0xC--杀报
----------------------------------------------
DEF.TIAN_HU_GY_THREE        = 0x21--天胡 
DEF.DI_HU_GY_THREE          = 0x22--地胡 
DEF.QING_LONG_BEI_GY_THREE  = 0x23--青龙背
DEF.QING_QI_DUI_GY_THREE    = 0x24--清七对
DEF.LONG_QI_DUI_GY_THREE    = 0x25--龙七对
DEF.QING_DA_DUI_GY_THREE    = 0x26--清大对
DEF.QING_YI_SE_GY_THREE     = 0x27--清一色
DEF.QI_DUI_GY_THREE         = 0x28--七对 
DEF.DA_DUI_ZI_GY_THREE      = 0x29--大对子
DEF.PING_HU_GY_THREE        = 0x2A--平胡
DEF.YUAN_QUE_GY_THREE       = 0x2B--原缺 
DEF.BAO_TING_GY_THREE       = 0x2C--报听 
DEF.SHA_BAO_GY_THREE        = 0x2D--杀报 
----------------------------------------
DEF.TIAN_HU_GY_ZUNYI        = 0x41--天胡 
DEF.DI_HU_GY_ZUNYI          = 0x42--地胡 
DEF.QING_LONG_BEI_GY_ZUNYI  = 0x43--青龙背
DEF.QING_QI_DUI_GY_ZUNYI    = 0x44--清七对
DEF.LONG_QI_DUI_GY_ZUNYI    = 0x45--龙七对
DEF.QING_DA_DUI_GY_ZUNYI    = 0x46--清大对
DEF.QING_YI_SE_GY_ZUNYI     = 0x47--清一色
DEF.QI_DUI_GY_ZUNYI         = 0x48--七对 
DEF.DA_DUI_ZI_GY_ZUNYI      = 0x49--大对子
DEF.PING_HU_GY_ZUNYI        = 0x4A--平胡
DEF.BIAN_KA_DIAO_GY_ZUNYI   = 0x4B--边卡吊
DEF.DA_KUAN_ZHANG_GY_ZUNYI  = 0x4C--大宽张
DEF.YUAN_QUE_GY_ZUNYI       = 0x4D--原缺 
DEF.BAO_TING_GY_ZUNYI       = 0x4E--报听 
DEF.SHA_BAO_GY_ZUNYI        = 0x4F--杀报 


----------------------------------------
VALUE[DEF.TIAN_HU_GY]           = {30,"天胡"}
VALUE[DEF.DI_HU_GY]             = {30,"地胡"}
VALUE[DEF.QING_LONG_BEI_GY]     = {30,"清龙背"}
VALUE[DEF.QING_QI_DUI_GY]       = {20,"清七对"}
VALUE[DEF.LONG_QI_DUI_GY]       = {20,"龙七对"}
VALUE[DEF.QING_DA_DUI_GY]       = {15,"清大对"}
VALUE[DEF.QING_YI_SE_GY]        = {10,"清一色"}
VALUE[DEF.QI_DUI_GY]            = {10,"七对"}
VALUE[DEF.DA_DUI_ZI_GY]         = {5,"对对胡"}
VALUE[DEF.PING_HU_GY]           = {1,"平胡"}
VALUE[DEF.BAO_TING_GY]          = {10,"报听"}
VALUE[DEF.SHA_BAO_GY]           = {10,"杀报"}


----------------------------------------三丁拐
VALUE[DEF.TIAN_HU_GY_THREE]           = {10,"天胡"}
VALUE[DEF.DI_HU_GY_THREE]             = {10,"地胡"}
VALUE[DEF.QING_LONG_BEI_GY_THREE]     = {30,"清龙背"}
VALUE[DEF.QING_QI_DUI_GY_THREE]       = {20,"清七对"}
VALUE[DEF.LONG_QI_DUI_GY_THREE]       = {20,"龙七对"}
VALUE[DEF.QING_DA_DUI_GY_THREE]       = {15,"清大对"}
VALUE[DEF.QING_YI_SE_GY_THREE]        = {10,"清一色"}
VALUE[DEF.QI_DUI_GY_THREE]            = {10,"七对"}
VALUE[DEF.DA_DUI_ZI_GY_THREE]         = {5,"对对胡"}
VALUE[DEF.PING_HU_GY_THREE]           = {1,"平胡"}
VALUE[DEF.YUAN_QUE_GY_THREE]          = {2,"原缺"}
VALUE[DEF.BAO_TING_GY_THREE]          = {10,"报听"}
VALUE[DEF.SHA_BAO_GY_THREE]           = {10,"杀报"}


----------------------------------------遵义
VALUE[DEF.TIAN_HU_GY_ZUNYI]           = {10,"天胡"}
VALUE[DEF.DI_HU_GY_ZUNYI]             = {10,"地胡"}
VALUE[DEF.QING_LONG_BEI_GY_ZUNYI]     = {20,"清龙背"}
VALUE[DEF.QING_QI_DUI_GY_ZUNYI]       = {14,"清七对"}
VALUE[DEF.LONG_QI_DUI_GY_ZUNYI]       = {10,"龙七对"}
VALUE[DEF.QING_DA_DUI_GY_ZUNYI]       = {14,"清大对"}
VALUE[DEF.QING_YI_SE_GY_ZUNYI]        = {10,"清一色"}
VALUE[DEF.QI_DUI_GY_ZUNYI]            = {4,"暗七对"}
VALUE[DEF.DA_DUI_ZI_GY_ZUNYI]         = {4,"对对胡"}
VALUE[DEF.PING_HU_GY_ZUNYI]           = {2,"平胡"}
VALUE[DEF.BIAN_KA_DIAO_GY_ZUNYI]      = {3,"边卡吊"}
VALUE[DEF.DA_KUAN_ZHANG_GY_ZUNYI]     = {4,"大宽张"}
VALUE[DEF.YUAN_QUE_GY_ZUNYI]          = {2,"原缺"}
VALUE[DEF.BAO_TING_GY_ZUNYI]          = {10,"报听"}
VALUE[DEF.SHA_BAO_GY_ZUNYI]           = {10,"杀报"}

return FanXinDef