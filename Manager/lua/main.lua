--[[
author: jie123108@163.com
date: 20151014
]]

local template = require "resty.template"
local config = require("config")
local app = require("Manager.lua.appview")
local user = require("Manager.lua.userview")
local perm = require("Manager.lua.permview")
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

local router = {
	["/"] = main_render,
	["/app/list"] = app.list_render,
	["/app/add"] = app.add_render,
	["/app/add_post"] = app.add_post,
	["/user/list"] = user.list_render,
	["/user/add"] = user.add_render,
	["/user/add_post"] = user.add_post,
	["/user/detail"] = user.detail_render,
	["/user/del"] = user.del_post,
	["/passport/login"] = login.login_render,
	["/passport/login_post"] = login.login_post,
	["/passport/logout"] = login.logout_post,
	["/passport/changepwd"] = login.changepwd_render,
	["/passport/changepwd_post"] = login.changepwd_post,
	["/perm/list"] = perm.list_render,
	["/perm/add"] = perm.add_render,
	["/perm/add_post"] = perm.add_post,
	["/perm/del"] = perm.del_post,

}

if router[uri] then
	router[uri]()
else 
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end
