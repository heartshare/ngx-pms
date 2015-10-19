local template = require "resty.template"
local config = require("config")
local app = require("Manager.lua.appview")
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

if uri == "/" then
	main_render()
elseif uri == "/app/list" then
	app.list_render()
elseif uri == "/app/add" then
	app.add_render()
elseif uri == "/app/add_post" then
	app.add_post()
else
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end