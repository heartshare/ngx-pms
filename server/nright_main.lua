local template = require "resty.template"
local util = require("util.util")
local ck = require('util.cookie')
local cookiedao = require("dao.cookie_dao")
local userdao = require('dao.user_dao')
local urldao = require("dao.url_dao")
local config = require("config")
local json = require("util.json")
local r = require "util.res"
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
	local dao = userdao:new()
	local ok, userinfo = dao:get_by_name(username)
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
		ck.set_cookie(cookie)
		cookiedao.cookie_set(cookie, userinfo)
		util.redirect(uri)
	end
end

local function logout_post()
	ck.set_cookie("logouted")
	local cookie_value = ck.get_cookie()
	if cookie_value then
		cookiedao.cookie_del(cookie_value)
	end
	util.redirect("/nright/login")
end

local function get_user_by_cookie(cookie_value)
	local cookie = ck.parse_cookie(cookie_value)

	local ok, userinfo = cookiedao.cookie_get(cookie)
	if ok then
		ngx.ctx.userinfo = userinfo
	else 
		userinfo = error.err_data_not_exist
	end

	return ok, userinfo
end

local function get_url_permission(app, url)
	local dao = urldao:new()
	local ok, url_perm = dao:url_perm_get(app, url)
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
			ngx.log(ngx.ERR, "cookie [", cookie, "] not exist in database!")
			ngx.status = ngx.HTTP_UNAUTHORIZED
			ngx.say("session-timeout")
			ngx.exit(0)
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
			ngx.status = ngx.HTTP_OK
			ngx.say(json.dumps(userinfo))
			ngx.exit(0)
		else --没有权限 
			ngx.log(ngx.ERR, "user [", username, "] have no [", url_permission, '] permission to access: ', uri)
			ngx.status = ngx.HTTP_UNAUTHORIZED
			ngx.say(json.dumps(userinfo))
			ngx.exit(0)
		end
	else 
		if url_permission == error.err_data_not_exist then
			ngx.log(ngx.INFO, "user [", username, "] check right for uri [", uri, "] ok, uri not exist!")
			ngx.status = ngx.HTTP_OK
			ngx.say(json.dumps(userinfo))
			ngx.exit(0)
		else
			ngx.log(ngx.ERR, "user [", username, "] check right for uri [", uri, "] failed, err:", tostring(url_permission))
			ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
			ngx.say(json.dumps(userinfo))
			ngx.exit(0)
		end
	end
	ngx.status = ngx.HTTP_UNAUTHORIZED
	ngx.say(json.dumps(userinfo))
	ngx.exit(0)
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