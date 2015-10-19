
local _M = {}

--[[ 忽略列表,列表中的项不进行检查，节省时间。
格式：
	ignore_list = {
	equals={"/test", "/login"},
	suffix={".doc", ".jpg"},
	prefix={"/demo", "/error"},
	regex={""}
	}
]]
_M.ignore_list = {
	equals={"/test", "/login", "/favicon.ico"},
	suffix={".doc", ".jpg"},
	prefix={"/error"},
	regex={}
}

--[[
-- 登录URL。
_M.login_url =  "/nright/login"
-- 权限检查URL
_M.right_check_url = "/nright/right_check"
-- 没权限时，显示的页面
_M.no_access_page = "/nright/no_access_page"
-- 信息栏地址。
_M.infobar_page = "/nright/infobar"

]]
-- Cookie 设置相关参数。
_M.cookie_config = {key="nright", path="/", expires=3600*24*10}

-- 数据库配置。
_M.db = {host="192.168.1.111", port=3306,user="root", password="123456",
		database="nright",DEFAULT_CHARSET="utf8"}

-- 列表显示时，默认分页大小
_M.defNumPerPage = 10
return _M