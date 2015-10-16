local config = require("config")
local util = require("util.util")
local ck = require('util.cookie')

local login_url = config.login_url or "/nright/login"
local logout_url = config.logout_url or "/nright/logout"
local login_post_url = "/nright/login_post"
local no_access_page = config.no_access_page or "/nright/no_access_page"
local right_check_url = config.right_check_url or "/nright/right_check"

local ignore_list = {login_url, login_post_url, right_check_url}

local function is_ignore_url(url)
	if ignore_list == nil then
		return false
	end
	local matched = false
	-- 精确匹配。
	if type(ignore_list)=='table' then
		for i, item in ipairs(ignore_list) do 
			--ngx.log(ngx.INFO, "### compare(", item, ",", url, ")...")
			if item == url then
				matched = true
				break
			end
		end
	end
	return matched
end

ngx.log(ngx.INFO, "url:", ngx.var.uri)
if is_ignore_url(ngx.var.uri) then
	ngx.log(ngx.INFO, "### body-filter ignore : ", ngx.var.uri)
	return
end

local topbar_tpl = [[
<table width="100%%" border="0" cellspacing="1" cellpadding="0" style="
	top: 0px;
	height:25px;
	background-color: #CED1FD;
	font-size: 12px;
	background-position: top;
	border: thin dashed #0033FF;">
  <tr>
  	<td align="left">&nbsp;&nbsp;NRight System</td>
    <td align="right">&nbsp;&nbsp;USER: <a href="#" target="_blank">%s</a> | <a href="%s" target="_self">Logout</a>&nbsp;&nbsp;&nbsp;&nbsp;</td>
  </tr>
</table>
]]

local function get_infobar()
	--template.caching(tmpl_caching)
	--local infobar = template.compile(topbar_tpl){username='liuxiaojie'}
	local username = "NONE"
	local cookie = ngx.ctx.cookie or ck.get_cookie()

	if cookie ~= nil and cookie ~= "" then
		local id, username = ck.parse_cookie(cookie)
		if id == nil then
			ngx.log(ngx.ERR, "parse cookie (", cookie, ") failed! err:", username)
			return false
		end
		return true, string.format(topbar_tpl, username, logout_url)
	else
		ngx.log(ngx.INFO, "do not show infobar, cookie missing!")
	end
	return false
end

local ok, body = get_infobar()
if ok then
	ngx.arg[1] =  ngx.re.sub(ngx.arg[1], "\\<body[^\\>]*\\>", "$0 " .. body , "jom")
	ngx.log(ngx.INFO, "### add infobar. ###")
end