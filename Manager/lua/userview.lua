--[[
author: jie123108@163.com
date: 20151019
]]

local template = require "resty.template"
local config = require("config")
local userdao = require('dao.user_dao')
local permdao = require('dao.perm_dao')
local viewpub = require("Manager.lua.viewpub")
local roledao = require("dao.role_dao")
local mysql = require("dao.mysql_util")
local json = require("util.json")
local dwz = require("Manager.lua.dwzutil")
local util = require("util.util")
local error = require('dao.error')
local tmpl_caching = config.tmpl_caching
if tmpl_caching == nil then
	tmpl_caching = false
end

local _M = {}

function _M.list_render()
	local errmsg = nil
	local totals = 0
	ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
    if args.username == "" then
        args.username = nil
    end
    if args.email == "" then
        args.email = nil
    end
    if args.tel == "" then
        args.tel = nil
    end

	local dao = userdao:new()
	local pageNum = tonumber(args.pageNum) or 1
	local numPerPage = tonumber(args.numPerPage) or config.defNumPerPage
	local ok, users = dao:list(args, pageNum, numPerPage)
	if not ok then
		if users == error.err_data_not_exist then
			totals = 0
			users = {}
		else
			errmsg = users
			users = nil
		end
	else 
		ok, totals = dao:count(args)
		if not ok then
			totals = 0
		end
	end
	
	template.caching(tmpl_caching)
	template.render("user_list.html", {errmsg=errmsg, users=users, 
                    username=args.username, email=args.email, tel=args.tel,
                    pageNum=pageNum, numPerPage=numPerPage, totals=totals})
	ngx.exit(0)
end

function _M.add_render()
	local args = ngx.req.get_uri_args()
    local id = tonumber(args.id)
	
    local ok, userinfo = nil
    if id then
        local dao = userdao:new()
        ok, userinfo = dao:get_by_id(id)
        if not ok then
            ngx.log(ngx.ERR, "userdao:get_by_id(", id, ") failed! err:", tostring(userinfo))
            ngx.say(dwz.cons_resp(300, "修改用户信息时出错：" .. tostring(userinfo)))
            ngx.exit(0)
        end
    end
    

    
    local app, apps = viewpub.get_app_and_apps()
	local dao = permdao:new()
    local perm_ok, permissions = dao:list(app, 1, 1024)
    if not perm_ok then
        if perm_ok == error.err_data_not_exist then

        else
            ngx.log(ngx.ERR, "permdao:list(", tostring(app), ") failed! err:", tostring(permissions))
        end
        permissions = {}
    end

    local dao = roledao:new()
    local role_ok, roles = dao:list(app, 1, 1024)
    if not role_ok then
        if role_ok == error.err_data_not_exist then

        else
            ngx.log(ngx.ERR, "roledao:list(", tostring(roles), ") failed! err:", tostring(roles))
        end
        roles = {{id="", name="无", remark=""}}
    else
        table.insert(roles, 1, {id="", name="无", remark=""})
    end


    if userinfo then
        ngx.log(ngx.INFO, "------------------------------")
        permissions = viewpub.perm_sub(permissions, userinfo.user_permissions)
    end

	template.caching(tmpl_caching)
	template.render("user_add.html", {permission_others=permissions, apps=apps, roles=roles, userinfo=userinfo})
	ngx.exit(0)
end

function _M.add_post()
	ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
    local id = tonumber(args.id)
    local username = args.username
    local email = args.email
    local tel = args.tel 
    local app = args.app
    local manager = args.manager or ""
    local role_id = args.role_id or ""
    local permission = args.permission or {}
    local create_time = ngx.time()
    local update_time = ngx.time()

    --ngx.log(ngx.ERR, "---[", json.dumps(args), "]---")
    if type(permission) == 'table' then
        permission = table.concat(permission, "|")
    end
    local userinfo = {username=username, email=email, tel=tel,
    					app=app,manager=manager,role_id=role_id,permission=permission,
    					create_time=create_time,update_time=update_time}
    
    -- 检查用户是否存在
    local dao = userdao:new()
    if id then
        local ok, exist = dao:exist_exclude("username", username, id)
        if ok and exist then
            ngx.say(dwz.cons_resp(300, "修改用户信息时出错了, 用户名[" .. username .. "]已经存在!"))
            ngx.exit(0)
        end
        local ok, exist = dao:exist_exclude("email", email, id)
        if ok and exist then
            ngx.say(dwz.cons_resp(300, "修改用户信息时出错了, EMAIL[" .. email .. "]已经存在!"))
            ngx.exit(0)
        end
        if tel and string.len(tel) > 0 then
            local ok, exist = dao:exist_exclude("tel", tel, id)
            if ok and exist then
                ngx.say(dwz.cons_resp(300, "修改用户信息时出错了, TEL[" .. tel .. "]已经存在!"))
                ngx.exit(0)
            end
        else 
            userinfo["tel"] = nil
        end
        userinfo["create_time"] = nil
        local ok, err = dao:update(userinfo, {id=id})
        if not ok then
            ngx.log(ngx.ERR, "userdao:update(", json.dumps(userinfo, ") failed! err:", tostring(err)))
            
            if err == error.err_data_exist then
                ngx.say(dwz.cons_resp(300, "修改用户信息时出错了: 数据重复"))
            else
               ngx.say(dwz.cons_resp(300, "修改用户信息时出错了:" .. tostring(err)))
            end     
            ngx.exit(0)
        end
        ngx.say(dwz.cons_resp(200, "用户【" .. username .. "】修改成功", {navTabId="user_list"}))
    else
        local ok, exist = dao:exist("username", username)
        if ok and exist then
            ngx.say(dwz.cons_resp(300, "保存用户信息时出错了, 用户名[" .. username .. "]已经存在!"))
            ngx.exit(0)
        end
        local ok, exist = dao:exist("email", email)
        if ok and exist then
            ngx.say(dwz.cons_resp(300, "保存用户信息时出错了, EMAIL[" .. email .. "]已经存在!"))
            ngx.exit(0)
        end
        if tel and string.len(tel) > 0 then
            local ok, exist = dao:exist("tel", tel)
            if ok and exist then
                ngx.say(dwz.cons_resp(300, "保存用户信息时出错了, TEL[" .. tel .. "]已经存在!"))
                ngx.exit(0)
            end
        else 
            userinfo["tel"] = nil
        end
        local password = util.random_pwd(16)
        userinfo["password"] = util.make_pwd(password)
        local ok, err = dao:save(userinfo)
        if not ok then
            ngx.log(ngx.ERR, "userdao:save(", json.dumps(userinfo, ") failed! err:", tostring(err)))
            
            if err == error.err_data_exist then
                ngx.say(dwz.cons_resp(300, "保存用户信息时出错了: 数据重复"))
            else
               ngx.say(dwz.cons_resp(300, "保存用户信息时出错了:" .. tostring(err)))
            end     
            ngx.exit(0)
        end
         --TODO: 密码提示框会小时问题修改。
        ngx.say(dwz.cons_resp(200, "用户【" .. username .. "】添加成功: \n用户名：" 
                    .. username .. "\n密码：" .. password, {navTabId="user_list"}))
    end
end

function _M.del_post()
    local args = ngx.req.get_uri_args()
    local id = tonumber(args.id)
    if not id then
        ngx.say(dwz.cons_resp(300, "删除用户信息时出错了, 缺少用户ID!"))
        ngx.exit(0)
    end
    -- 检查用户是否存在
    local dao = userdao:new()
    local ok, userinfo = dao:get_by_id(id)
    if not ok then
        ngx.say(dwz.cons_resp(300, "删除用户信息时出错了，错误：" .. tostring(userinfo)))
        ngx.exit(0)
    end 
    if userinfo.manager == "super" then
        ngx.say(dwz.cons_resp(300, "超级管理员不能删除！"))
        ngx.exit(0)
    elseif userinfo.manager == "admin" then
        ngx.say(dwz.cons_resp(300, "管理员用户不能删除！"))
        ngx.exit(0)
    end

    local ok, err = dao:delete_by_id(id)
    if not ok then
        ngx.log(ngx.ERR, "dao:delete_by_id(", tostring(id), ") failed! err:", tostring(err))
        
        if err == error.err_data_exist then
            ngx.say(dwz.cons_resp(300, "删除用户信息时出错了，用户不存在"))
        else
           ngx.say(dwz.cons_resp(300, "删除用户信息时出错了:" .. tostring(err)))
        end     
        ngx.exit(0)
    end
   
    --TODO: 密码提示框会小时问题修改。
    ngx.say(dwz.cons_resp(200, "用户【" .. userinfo.username .. "】删除成功！", {navTabId="user_list"}))
end

function _M.detail_render()
    local method_name = ngx.req.get_method()
    local args, err = nil
    if method_name == "POST" then
        ngx.req.read_body()
        args, err = ngx.req.get_post_args()
    else
        args = ngx.req.get_uri_args()
    end
    local id = tonumber(args.id)
    if not id then
        ngx.log(ngx.ERR, "args [id] missing!")
        ngx.say(dwz.cons_resp(300, "缺少必要的参数"))
        ngx.exit(0)
    end

    local dao = userdao:new()
    local ok, userinfo = dao:get_by_id(id)    

    if ok then
        --ngx.log(ngx.INFO, "---[", json.dumps(userinfo), "]---")
        template.caching(tmpl_caching)
        template.render("user_detail.html", {userinfo=userinfo})
        ngx.exit(0)
    else
        ngx.log(ngx.ERR, "dao:get_by_id(", tostring(id), ") failed err:", tostring(userinfo))
        ngx.say(dwz.cons_resp(300, "系统错误，查询用户信息时出错！"))
        ngx.exit(0)
    end

end

return _M
