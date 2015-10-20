--[[
author: jie123108@163.com
date: 20151014
]]

local template = require "resty.template"
local config = require("config")
local app = require("Manager.lua.appview")
local user = require("Manager.lua.userview")
local login = require("Manager.lua.login")
local util = require("util.util")
local tmpl_caching = config.tmpl_caching
if tmpl_caching == nil then
	tmpl_caching = false
end


local function main_render()
	template.caching(tmpl_caching)
	template.render("dwz_base.html", args)
	ngx.exit(0)
end


local uri = ngx.var.uri
ngx.header['Content-Type'] = "text/html"

if not util.startswith(uri, "/passport/login") then
	login.check()
end

if uri == "/" then
	main_render()
elseif uri == "/app/list" then
	app.list_render()
elseif uri == "/app/add" then
	app.add_render()
elseif uri == "/app/add_post" then
	app.add_post()

elseif uri == "/user/list" then
	user.list_render()
elseif uri == "/user/add" then
	user.add_render()
elseif uri == "/user/detail" then
	user.detail_render()
elseif uri == "/passport/login" then
	login.login_render()
elseif uri == "/passport/login_post" then
	login.login_post()
elseif uri == "/passport/logout" then
	login.logout_post()
elseif uri == "/passport/changepwd" then
	login.changepwd_render()
elseif uri == "/passport/changepwd_post" then
	login.changepwd_post()

else
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end