--[[
author: jie123108@163.com
date: 20150914
]]

local config = require("config")
local util = require("util.util")
local ck = require("resty.cookie")   -- https://github.com/cloudflare/lua-resty-cookie

local _M = {}

function _M.make_cookie(userinfo)
	-- TODO: Cookie 编码，加密
	return string.format("%s:%s", tostring(userinfo["id"]), tostring(userinfo["username"]))
end

function _M.parse_cookie(cookie)
	-- TODO: Cookie 编码，加密
	local arr = util.split(cookie, ':')
	if #arr == 2 then
		return tonumber(arr[1]), arr[2]
	else 
		return nil, 'invalid cookie'
	end
end

function _M.get_cookie()
	local cookie, err = ck:new()
    if not cookie then
        ngx.log(ngx.ERR, "ck:new() failed!", err)
        return nil
    end

    local cookie_key = "nright"
    if config.cookie_config and config.cookie_config.key then
    	cookie_key = config.cookie_config.key
    end

	local cookie_value, err = cookie:get(cookie_key)
	return cookie_value
end

return _M