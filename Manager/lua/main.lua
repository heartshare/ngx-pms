local template = require "resty.template"
local config = require("config")
local tmpl_caching = config.tmpl_caching
if tmpl_caching == nil then
	tmpl_caching = false
end


local function main_render(args)
	ngx.header['Content-Type'] = "text/html"
	
	template.caching(tmpl_caching)
	template.render("dwz_base.html", args)
	ngx.exit(0)
end

local uri = ngx.var.uri

if uri == "/" then
	main_render()
elseif uri == "/" then

else
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end