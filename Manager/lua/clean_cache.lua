local util = require("util.util")
local cookiedao = require("dao.cookie_dao")


local uri = ngx.var.uri
local clean_prefixs = {"/app", "/user", "/passport", "/perm", "/role", "/url"}
for _, prefix in ipairs(clean_prefixs) do 
	if util.startswith(uri, prefix) then 
		local ok, err = cookiedao.clean_userinfo()
		break
	end
end

