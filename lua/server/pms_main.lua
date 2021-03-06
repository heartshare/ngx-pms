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


local function get_user_by_cookie(cookie_value)
	local cookie = ck.parse_cookie(cookie_value)
	local ok, userinfo = cookiedao.cookie_get(cookie)
	if ok then
		ngx.ctx.userinfo = userinfo
	else 
		userinfo = nil
	end

	return ok, userinfo
end

local function login_render(args)
	ngx.header['Content-Type'] = "text/html"
	
	template.caching(tmpl_caching)
	template.render("agentlogin.html", args)
	ngx.exit(0)
end

local function login_page()
	-- set $template_root /path/to/templates;
	ngx.header['Content-Type'] = "text/html"
	ngx.log(ngx.INFO, "---- login page for agent ----")
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
	if not ok or userinfo == nil then
		if userinfo == nil then
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


local function change_pwd_render(args)
	ngx.header['Content-Type'] = "text/html"
	
	template.caching(tmpl_caching)
	template.render("change_pwd.html", args)
	ngx.exit(0)
end

local function change_pwd_page()
	-- set $template_root /path/to/templates;
	ngx.header['Content-Type'] = "text/html"	
	local args = ngx.req.get_uri_args()

	local cookie = ck.get_cookie()
	if not cookie then -- 没有登录，不能修改密码
		ngx.log(ngx.ERR, "change password failed！cookie not found!")
		util.redirect("/pms/login")
	end
	local ok, userinfo = get_user_by_cookie(cookie)
	if not ok or userinfo == nil then
		if userinfo == nil then
			ngx.log(ngx.ERR, "cookie [", cookie, "] not exist in database!")
			util.redirect("/pms/login")
		else
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
	args["username"] = userinfo.username

	if config.not_allow_change_pwd then
		args["error_info"] = r.ERR_NO_PERMISSION
	end
	change_pwd_render(args)
end


local function change_pwd_post()
	ngx.header['Content-Type'] = "text/html"
	ngx.req.read_body()
	local args = ngx.req.get_post_args()
	local cookie = ck.get_cookie()
	if not cookie then -- 没有登录，不能修改密码
		ngx.log(ngx.ERR, "change password failed！cookie not found!")
		util.redirect("/pms/login")
	end
	local ok, userinfo = get_user_by_cookie(cookie)
	if not ok or userinfo == nil then
		if userinfo == nil then
			ngx.log(ngx.ERR, "cookie [", cookie, "] not exist in database!")
			util.redirect("/pms/login")
		else
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
	args["username"] = userinfo.username

	if config.not_allow_change_pwd then
		args["error_info"] = r.ERR_NO_PERMISSION
		change_pwd_render(args)
	end

	local old_password = args.old_password
	local new_password = args.new_password
	local re_new_password = args.re_new_password
	if old_password == nil or old_password == "" then
		args["error_info"] = r.ERR_OLDPWD_MISSING
		change_pwd_render(args)
	end
	if new_password == nil or new_password == "" then
		args["error_info"] = r.ERR_NEWPWD_MISSING
		change_pwd_render(args)
	end
	if new_password ~= re_new_password then
		args["error_info"] = r.ERR_TOWPWD_NOT_EQUALS
		change_pwd_render(args)
	end

	-- Check the old password.
	old_password = util.make_pwd(old_password)
	if old_password ~= userinfo.password then
		args["error_info"] = r.ERR_OLDPWD_ERROR
		change_pwd_render(args)
	end

	local update_by = {id=userinfo.id}
	local values = {password=util.make_pwd(new_password), update_time=ngx.time()}
	local dao = userdao:new()
	local ok, err = dao:update(values, update_by)
	if not ok then
		ngx.log(ngx.ERR, "uerdao:update(", json.dumps(values), ",", 
					json.dumps(update_by), ") failed! err:", tostring(err))
		args["error_info"] = r.ERR_SYSTEM_ERROR
		change_pwd_render(args)
	else -- 密码修改成功。
		args["success_info"] = r.CHANGE_PWD_SUCC
		change_pwd_render(args)
	end
end

local function logout_post()
	local cookie_value = ck.get_cookie()
	if cookie_value then
		cookiedao.cookie_del(cookie_value)
	end
	ck.set_cookie("logouted")
	util.redirect("/pms/login")
end

local function get_url_permission(app, url)
	local dao = urldao:new()
	local ok, url_perm = dao:url_perm_get(app, url)
	if not ok or url_perm == nil then
		return ok, url_perm 
	end
	return ok, url_perm.permission, url_perm
end

local function http_resp(status, body, cookie)
	ngx.status = status
	ck.set_cookie(cookie)
	if body then
		ngx.say(body)
	end
	ngx.exit(0)
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
	if not ok or userinfo == nil then
		if userinfo == nil then
			ngx.log(ngx.ERR, "cookie [", cookie, "] not exist in database!")
			http_resp(ngx.HTTP_UNAUTHORIZED, "session-timeout", cookie)
		else
			ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
	end
	-- 隐藏密码。
	userinfo.password = nil 

	local username = userinfo.username
	local userinfo_json = json.dumps(userinfo)
	local ok, url_permission, url_perm = get_url_permission(app, uri)
	ngx.log(ngx.INFO, string.format("app [%s] url [%s] matched: {type: %s, url: %s, perm: %s}", 
				tostring(app),tostring(uri), 
				tostring(url_perm.type), tostring(url_perm.url),tostring(url_perm.permission)))
	if ok and url_permission then
		if url_permission == "ALLOW_ALL" then -- 所有人可访问
			ngx.log(ngx.INFO, "url [", app, ".", uri, "] permission is [", 
					url_permission, '], allow all user to access!')
			http_resp(ngx.HTTP_OK, userinfo_json, cookie)
		elseif url_permission == "DENY_ALL" then --所有人不可访问
			ngx.log(ngx.INFO, "url [", app, ".", uri, "] permission is [", 
					url_permission, '], not allow any user to access!')
			http_resp(ngx.HTTP_UNAUTHORIZED, userinfo_json, cookie)
		elseif userinfo.permissions[url_permission] then -- 有权限。
			ngx.log(ngx.INFO, "user [", username, "] have [", url_permission, '] permission to access: ', uri)
			http_resp(ngx.HTTP_OK, userinfo_json, cookie)
		else --没有权限 
			ngx.log(ngx.ERR, "user [", username, "] have no [", url_permission, '] permission to access: ', uri)
			http_resp(ngx.HTTP_UNAUTHORIZED, userinfo_json, cookie)
		end
	else 
		if url_permission == nil then
			ngx.log(ngx.INFO, "user [", username, "] check right for uri [", uri, "] ok, uri not exist!")
			http_resp(ngx.HTTP_OK, userinfo_json, cookie)
		else
			ngx.log(ngx.ERR, "user [", username, "] check right for uri [", uri, "] failed, err:", tostring(url_permission))
			http_resp(ngx.HTTP_INTERNAL_SERVER_ERROR, userinfo_json, cookie)
		end
	end

	http_resp(ngx.HTTP_UNAUTHORIZED, userinfo_json, cookie)
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
local router = {
	["/pms/right_check"] = right_check,
	["/pms/login"] = login_page,
	["/pms/login_post"] = login_post,
	["/pms/change_pwd"] = change_pwd_page,
	["/pms/change_pwd_post"] = change_pwd_post,
	["/pms/logout"] = logout_post,
	["/pms/no_access_page"] = no_access_page,
}

if router[uri] then
	router[uri]()
else
	ngx.log(ngx.ERR, "page [", uri, "] not found!")
	ngx.exit(404)
end