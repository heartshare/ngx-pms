--[[
author: jie123108@163.com
date: 20151014
]]
local template = require "resty.template"
local config = require("config")
local appdao = require("dao.app_dao")
local userdao = require('dao.user_dao')
local mysql = require("dao.mysql_util").get_mysql_mgr()
local json = require("util.json")
local dwz = require("dwzutil")
local util = require("util.util")
local error = require('dao.error')
local cookiedao = require("dao.cookie_dao")
local apputil = require("apputil")

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
	local dao = appdao:new()
	local pageNum = tonumber(args.pageNum) or 1
	local numPerPage = tonumber(args.numPerPage) or config.defNumPerPage
	local ok, apps = dao:list_all(pageNum, numPerPage)
	if not ok then
		errmsg = apps
		apps = nil
	else 
		ok, totals = dao:count()
		if not ok then
			totals = 0
		end
	end
	
	template.caching(tmpl_caching)
	template.render("app_list.html", {errmsg=errmsg, apps=apps, pageNum=pageNum, numPerPage=numPerPage, totals=totals})
	ngx.exit(0)
end

function _M.add_render()
	ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
	local app = args.app or ""
	local appname = args.appname or ""
	local remark = args.remark or ""
    
	local dao = userdao:new()
	local pageNum = 1
	local numPerPage = 1024
	local ok, users = dao:list_by_args(args, pageNum, numPerPage)
	if not ok then
	if users == error.err_data_not_exist then
	    totals = 0
	    users = {}
	else
	    users = nil
	end
	end

	template.caching(tmpl_caching)
	template.render("app_add.html", {app=app,appname=appname,remark=remark, users=users})
	ngx.exit(0)
end

function _M.add_post()
	ngx.req.read_body()
    local args, err = ngx.req.get_post_args()

    local app = args.app 
    local appname = args.appname
    local remark = args.remark
    local create_time = ngx.time()
    local update_time = ngx.time()
    local appinfo = {app=app,appname=appname,remark=remark, 
    				create_time=create_time,update_time=update_time}

    local userid = args.user
    local manager = args.manager or "admin"

    -- 检查应用是否存在。
    local dao = appdao:new()
    local ok, exist = dao:exist("app", app)
    if ok and exist then
        ngx.say(dwz.cons_resp(300, "保存应用信息时出错了, 应用ID[" .. app .. "]已经存在!"))
        ngx.exit(0)
    end
    local ok, exist = dao:exist("appname", appname)
    if ok and exist then
        ngx.say(dwz.cons_resp(300, "保存应用信息时出错了, 应用名称[" .. appname .. "]已经存在!"))
        ngx.exit(0)
    end
    
    local ok, connection = mysql:connection_get()
    if not ok then
        ngx.log(ngx.ERR, "mysql:connection_get failed! err:", tostring(connection))
        ngx.say(dwz.cons_resp(300, "获取数据库链接出错了:" .. tostring(connection)))
        ngx.exit(0)
    end
    local tx_ok, tx_err = mysql:tx_begin(connection)
    if not tx_ok then
    	ngx.log(ngx.ERR, "mysql:tx_begin failed! err:", tostring(tx_err))
    end

    local dao = appdao:new(connection)
    local ok, err = dao:save(appinfo)
    if not ok then
    	ngx.log(ngx.ERR, "appdao:save(", json.dumps(appinfo), ") failed! err:", tostring(err))
    	if tx_ok then 
    		tx_ok, tx_err = mysql:tx_rollback(connection)
    	end
        mysql:connection_put(connection)
        if err == error.err_data_exist then
            ngx.say(dwz.cons_resp(300, "保存应用信息时出错了: 数据重复"))
        else
    	   ngx.say(dwz.cons_resp(300, "保存应用信息时出错了:" .. tostring(err)))
        end
    	ngx.exit(0)
    end
    local dao = userdao:new(connection)
    local ok, userinfo = dao:get_by_id(userid)
    if not ok or userinfo == nil then 
        if userinfo == nil then 
            userinfo = "用户不存在"
        end
        ngx.log(ngx.ERR, "userdao:get_by_id(", userid, ") failed! err:", tostring(userinfo))
        if tx_ok then 
            tx_ok, tx_err = mysql:tx_rollback(connection)
        end
        mysql:connection_put(connection)
        ngx.say(dwz.cons_resp(300, "保存应用管理员信息时出错了:" .. tostring(userinfo)))
        ngx.exit(0)
    end
    if userinfo.apps == nil then 
        userinfo.apps = {}
    end
    local app_exist = false
    for i, xapp in ipairs(userinfo.apps) do 
        if xapp == app then 
            app_exist = true
            break
        end
    end
    if not app_exist then 
        table.insert(userinfo.apps, app)
    end
    userinfo.app = table.concat(userinfo.apps, '|')
    userinfo.manager = 'admin'
    local ok, err = dao:upsert(userinfo)
    if not ok then
    	ngx.log(ngx.ERR, "userdao:upsert(", json.dumps(userinfo), ") failed! err:", tostring(err))
    	if tx_ok then 
    		tx_ok, tx_err = mysql:tx_rollback(connection)
    	end
        mysql:connection_put(connection)
    	if err == error.err_data_exist then
            ngx.say(dwz.cons_resp(300, "保存应用信息时出错了: 数据重复"))
        else
           ngx.say(dwz.cons_resp(300, "保存应用管理员信息时出错了:" .. tostring(err)))
        end
    	ngx.exit(0)
    end
    tx_ok, tx_err = mysql:tx_commit(connection)
    mysql:connection_put(connection)
    cookiedao.userinfo_del(userid)
    --TODO: 密码提示框会小时问题修改。
	ngx.say(dwz.cons_resp(200, string.format([[应用【%s】添加成功，管理员：%s<br/>&nbsp;&nbsp;<br/>
请记住以上信息！]], app, userinfo.username), {navTabId="app_list", callbackType="closeCurrent"}))
end

function _M.sel_app_render()
    template.caching(tmpl_caching)
    local sel_app = apputil.sel_app_get(ngx.ctx.userinfo.id)
    template.render("app_sel.html", {sel_app=sel_app})
    ngx.exit(0)
end

function _M.sel_app_post()
    ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
    local app = args.app
    apputil.sel_app_set(ngx.ctx.userinfo.id, app)

    -- navTabId="url_list", 
    ngx.say(dwz.cons_resp(200, app, {callbackType="closeCurrent"}))
end
return _M
