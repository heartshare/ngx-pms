local template = require "resty.template"
local util = require("util.util")
local ck = require('util.cookie')
local dao = require("dao.dao")
local config = require("config")
local r = require "server.res"
local error = require('dao.error')

local tmpl_caching = config.tmpl_caching
if tmpl_caching == nil then
	tmpl_caching = false
end

local function login_render(args)
	ngx.header['Content-Type'] = "text/html"
	
	template.caching(tmpl_caching)
	template.render("login.html", args)
	ngx.exit(0)
end

local function login_page()
	-- set $template_root /path/to/templates;
	ngx.header['Content-Type'] = "text/html"
	local args = ngx.req.get_uri_args()
	login_render(args)
end

local function set_cookie(key, value, domain, path, expires)
	--"%s=%s;domain=%s;path=%s;expires=%s"
	local cookie_value = tostring(key) .. "=" .. tostring(value)
	if domain then
		cookie_value = cookie_value .. ";domain=" .. domain
	end
	if path == nil then
		path = "/"
	end
	cookie_value = cookie_value .. ";path=" .. path
	
	if expires then
		local expires_time = ngx.cookie_time(ngx.time() + expires)
		cookie_value = cookie_value .. ";expires=" .. expires_time
	end
	ngx.header['Set-Cookie'] = cookie_value
	ngx.log(ngx.INFO, "******* Set-Cookie:", cookie_value)
end

local function login_post()
	ngx.header['Content-Type'] = "text/html"
	ngx.req.read_body()
	local args = ngx.req.get_post_args()

	local uri = args["uri"]
	if uri == nil or uri == "" then
		uri = "/"
	end

	local username = args["username"]
	local password = args["password"]
	if username == nil or username == "" then
		args["error_info"] = r.ERR_USERNAME_MISSING
		login_render(args)
	end
	if password == nil or password == "" then
		args["error_info"] = r.ERR_PASSWORD_MISSING
		login_render(args)
	end

	local ok, userinfo = dao.user_get_by_username(username)
	if not ok then
		if userinfo == error.err_data_not_exist then
			args["error_info"] = r.ERR_USER_NOT_EXIST
			login_render(args)
		else 
			ngx.log(ngx.INFO, "query user from database failed! err:", tostring(userinfo))
			args["error_info"] = r.ERR_SYSTEM_ERROR
			login_render(args)			
		end
	else
		--用户存在。
		local pwd_md5 = util.make_pwd(password)
		if userinfo["password"] ~= pwd_md5 then
			args["error_info"] = r.ERR_PASSWORD_ERROR
			login_render(args)
		end

		local cookie = ck.make_cookie(userinfo)
		local cookie_config = config.cookie_config
		if cookie_config then
			set_cookie(cookie_config.key, cookie, cookie_config.domain, cookie_config.path, cookie_config.expires)
		end
		util.redirect(uri)
	end
end

local function logout_post()
	local cookie_config = config.cookie_config
	if cookie_config then
		set_cookie(cookie_config.key, "logouted", cookie_config.domain, cookie_config.path, 1)
	end
	util.redirect("/nright/login")
end

local function get_user_by_cookie(cookie)
	local id, username = ck.parse_cookie(cookie)
	if id == nil then
		ngx.log(ngx.ERR, "parse cookie (", cookie, ") failed! err:", username)
		return false, username
	end
	local ok, userinfo = dao.user_get_by_id(id)
	if not ok then
		if userinfo == error.err_data_not_exist then
			ngx.log(ngx.WARN, "dao.user_get_by_id(", id, ",", username, ") failed! err:", tostring(userinfo))
		else
			ngx.log(ngx.ERR, "dao.user_get_by_id(", id, ",", username, ") failed! err:", tostring(userinfo))
		end
	end
	return ok, userinfo
end

local function get_url_permission(app, url)
	local ok, url_perm = dao.url_perm_get(app, url)
	if not ok then
		return ok, url_perm 
	end
	return ok, url_perm.permission 
end

local function right_check()
	local args = ngx.req.get_uri_args()
	local app = args.app
	local uri = args.uri
	local cookie = args.cookie

	if app == nil then
		ngx.log(ngx.ERR, "right_check failed! args 'app' missing!")
		ngx.exit(ngx.HTTP_BAD_REQUEST)
	end
	if uri == nil then
		ngx.log(ngx.ERR, "right_check failed! args 'uri' missing!")
		ngx.exit(ngx.HTTP_BAD_REQUEST)
	end
	if cookie == nil then
		ngx.log(ngx.ERR, "right_check failed! args 'cookie' missing!")
		ngx.exit(ngx.HTTP_BAD_REQUEST)
	end

	local ok, userinfo = get_user_by_cookie(cookie)
	if not ok then
		if userinfo == error.err_data_not_exist then
			ngx.exit(ngx.HTTP_BAD_REQUEST)
		else
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
	local username = userinfo.username

	local ok, url_permission = get_url_permission(app, uri)
	ngx.log(ngx.INFO, "app [",tostring(app),"] url [", tostring(uri), "] permission: ", tostring(url_permission))
	if ok then
		-- 有权限。
		if userinfo.permissions[url_permission] then
			ngx.log(ngx.INFO, "user [", username, "] have [", url_permission, '] permission to access: ', uri)
			ngx.exit(ngx.HTTP_OK)
		else --没有权限 
			ngx.log(ngx.ERR, "user [", username, "] have no [", url_permission, '] permission to access: ', uri)
			ngx.exit(ngx.HTTP_UNAUTHORIZED)
		end
	else 
		if url_permission == error.err_data_not_exist then
			ngx.log(ngx.INFO, "user [", username, "] check right for uri [", uri, "] ok, uri not exist!")
			ngx.exit(ngx.HTTP_OK)
		else
			ngx.log(ngx.ERR, "user [", username, "] check right for uri [", uri, "] failed, err:", tostring(url_permission))
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
	ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local function no_access_page()
	local args = ngx.req.get_uri_args()
	ngx.header['Content-Type'] = "text/html"
	
	template.caching(tmpl_caching)
	template.render("no_access.html", args)
	ngx.exit(0)
end


ngx.header['Content-Type'] = "text/html"
local uri = ngx.var.uri
if uri == "/nright/right_check" then
    right_check()
elseif uri == "/nright/login" then
    login_page()
elseif uri == "/nright/login_post" then
    login_post()
elseif uri == "/nright/logout" then
	logout_post()
elseif uri == "/nright/no_access_page" then
	no_access_page()
else
	ngx.exit(404)
end