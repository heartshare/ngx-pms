--[[
author: jie123108@163.com
date: 20151014
]]

local template = require "resty.template"
local config = require("config")
local app = require("appview")
local user = require("userview")
local perm = require("permview")
local role = require("roleview")
local url = require("urlview")
local login = require("login")
local dwz = require("dwzutil")
local util = require("util.util")
local apputil = require("apputil")

local tmpl_caching = config.tmpl_caching
if tmpl_caching == nil then
	tmpl_caching = false
end


local function main_render()
	template.caching(tmpl_caching)
    local sel_app = apputil.sel_app_get(ngx.ctx.userinfo.id)
	template.render("dwz_base.html", {userinfo=ngx.ctx.userinfo, sel_app=sel_app})
	ngx.exit(0)
end

local uri = ngx.var.uri
ngx.header['Content-Type'] = "text/html"

if not util.startswith(uri, "/passport/login") then
	login.check()
end

local router = {
	["/"] = main_render,
	-- ["/perm_apply"] = permission_apply,
	["/app/list"] = app.list_render,
	["/app/add"] = app.add_render,
	["/app/add_post"] = app.add_post,
	["/app/change_current"] = app.sel_app_render, 
	["/app/change_current_post"] = app.sel_app_post, 
	["/user/list"] = user.list_render,
	["/user/add"] = user.add_render,
	["/user/add_post"] = user.add_post,
	["/user/detail"] = user.detail_render,
	["/user/del"] = user.del_post,
	["/user/app_change"] = user.app_change_render,
	["/user/app_change_post"] = user.app_change_post,

	["/passport/login"] = login.login_render,
	["/passport/login_post"] = login.login_post,
	["/passport/logout"] = login.logout_post,
	["/passport/changepwd"] = login.changepwd_render,
	["/passport/changepwd_post"] = login.changepwd_post,
	["/perm/list"] = perm.list_render,
	["/perm/add"] = perm.add_render,
	["/perm/add_post"] = perm.add_post,
	["/perm/del"] = perm.del_post,
	["/role/list"] = role.list_render,
	["/role/add"] = role.add_render,
	["/role/add_post"] = role.add_post,
	["/role/del"] = role.del_post,
	["/url/list"] = url.list_render,
	["/url/add"] = url.add_render,
	["/url/add_post"] = url.add_post,
	["/url/del"] = url.del_post,
}

if router[uri] then
	router[uri]()
else 
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end
