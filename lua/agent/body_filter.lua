--[[
author: jie123108@163.com
date: 20151017
]]
local config = require("config")
local filter_ext = require("agent.filter_ext")

local login_url = "/nright/login"
local logout_url = "/nright/logout"
local change_pwd_url = "/nright/change_pwd"
local change_pwd_post_url = "/nright/change_pwd_post"
local login_post_url = "/nright/login_post"
local no_access_page = "/nright/no_access_page"
local right_check_url = "/nright/right_check"

local ignore_list = {login_url, login_post_url, right_check_url, change_pwd_url, change_pwd_post_url}

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

local topbar_style = [[
<style type="text/css">
<!--
.topbar {
	top: 0px;
	height:15px;
	background-color: #E5E5E5;
	font-size: 12px;
	background-position: top;
	border-top-width: thin;
	border-right-width: thin;
	border-bottom-width: thin;
	border-left-width: thin;
	border-top-style: none;
	border-right-style: solid;
	border-bottom-style: solid;
	border-left-style: none;
	border-top-color: #0033FF;
	border-right-color: #000000;
	border-bottom-color: #000000;
	border-left-color: #0033FF;
	padding: 5px;
	margin: 5px;
}
.pms-sysname {
	float:left;
	width:50%;
	text-align:left;
	padding-left:8px;
	padding-right:8px;
}

.pms-info { 
	float: right;
}

.pms-info div {
	float: left;
	text-align:right;
	padding-left:8px;
	padding-right:8px;
	white-space:nowrap;
	
}
-->
</style>
]]
local topbar_tpl = [[
<div id="topbar" class="topbar">
<div id="pms-sysname" class="pms-sysname">Nginx Permission System</div>
<div id="pms-info" class="pms-info"> 
    <div id="pms-username" class="pms-username">USER: %s</div>
    <div id="pms-password" class="pms-password"><a %s>Change Password</a></div>
    <div id="pms-logout" class="pms-logout"><a href="%s" target="_self">Logout</a></div>
</div>
</div>
]]

local function get_infobar()
	--template.caching(tmpl_caching)
	--local infobar = template.compile(topbar_tpl){username='liuxiaojie'}
	local username = "NONE"
	local userinfo = ngx.ctx.userinfo
	if userinfo then
		username = userinfo.username
	elseif ngx.var.arg_username then
		username = ngx.var.arg_username
	end
	local href = string.format([[href="%s"  target="_blank"]], change_pwd_url)
	if config.not_allow_change_pwd then
		href = string.format([[href="#" onclick="javascript:alert('have no permission to change password!');"]])
	end
	ngx.log(ngx.INFO, "user [", username, "] request...")
	local replace = topbar_style .. string.format(topbar_tpl, username, href, logout_url)
	return true, replace
end

local content_type = ngx.header["Content-Type"]
function split(s, delimiter)
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

if content_type == nil then 
   ngx.log(ngx.INFO, "---- ignore type: ", tostring(content_type));
   return 
end
local arr = split(content_type, ";")
content_type = arr[1]
if content_type == "text/plain" or content_type == "text/html" then
	local ok, infobar = get_infobar()
	if ok then
		local n = nil
		-- if ngx.var.uri == "/" then 
			ngx.arg[1], n =  ngx.re.sub(ngx.arg[1], "\\<body[^\\>]*\\>", "$0 " .. infobar , "jom")
		-- else
		-- 	ngx.arg[1] =  ngx.re.sub(ngx.arg[1], [[<div id="pms" style="display:none"></div>]], infobar , "jom")
		-- end
		ngx.ctx.topbar_added = (n==1)
		ngx.log(ngx.INFO, "### add infobar. ### n:", tostring(ngx.ctx.topbar_added))

		if filter_ext.filter and type(filter_ext.filter) == 'function' then 
			local body = filter_ext.filter(ngx.arg[1])
			if body then 
				ngx.arg[1] = body
			end
		end
	end
else
    ngx.log(ngx.INFO, "---- ignore type: ", content_type);
end