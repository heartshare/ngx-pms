--[[
author: jie123108@163.com
date: 20150901
]]

local mysql_util = require("dao.mysql_util")
local util = require("util.util")
local config = require(config_name or "config")
local cjson = require "cjson"
local basedao = require "dao.basedao"
local error = require('dao.error')

local _M = {}
_M.db_inited = false

local user_dao = basedao:new("user", 
                   {id='number', 
                    username='string', 
                    email='string', 
                    tel='string', 
                    password='string', 
                    app='string', 
                    role_id='string', 
                    permission='string',
                    create_time='number',
                    update_time='number'})
local role_dao = basedao:new("role", 
                   {id='string', 
                    name='string', 
                    remark='string', 
                    app='string', 
                    permission='string',
                    create_time='number',
                    update_time='number'})
local url_perm_dao = basedao:new("url_perm", 
                   {id='number', 
                    app='string', 
                    type='string', 
                    url='string', 
                    url_len='number', 
                    permission='string',
                    create_time='number',
                    update_time='number'})

function _M.init_db()   
    _M.db_inited = true
    return true
end

function _M.role_get_by_id(id)
    if not _M.db_inited and not _M.init_db() then 
        ngx.log(ngx.ERR, "user_get failed! database not inited!")
        return false, error.err_dbuninit
    end
    id = ngx.quote_sql_str(id)
    local ok, obj = role_dao:select_by("where id=" .. tostring(id))
    if not ok then
        return  ok, obj
    end
    local permissions = {}
    if obj.permission then
        permissions = util.split(obj.permission, "|")
    end
    obj.permissions = permissions

    return ok, obj
end

function _M.url_perm_get(app, url)
    if not _M.db_inited and not _M.init_db() then 
        ngx.log(ngx.ERR, "url_perm_get failed! database not inited!")
        return false, error.err_dbuninit
    end

    app = ngx.quote_sql_str(app)
    url = ngx.quote_sql_str(url)

    local wheres = {}
    -- 优先查找精确匹配。
    table.insert(wheres, "where app=" .. app .. " and type='equal' and url = " .. url)
    -- 然后查找后缀匹配的。
    table.insert(wheres, "where app=" .. app .. " and type='suffix' and url = right(" .. url .. ", length(url)) order by url_len desc limit 1")
    -- 然后查找前缀匹配的。
    table.insert(wheres, "where app=" .. app .. " and type='prefix' and url = substr(" .. url .. ", 1, length(url)) order by url_len desc limit 1")

    local ok, obj, where_ = nil,nil
    for i, where in ipairs(wheres) do
        where_ = where
        ok, obj = url_perm_dao:select_by(where)
        if ok then
            return ok, obj
        elseif obj ~= error.err_data_not_exist then --出错
            ngx.log(ngx.ERR, "url_perm_dao.select_by(" .. tostring(where) .. ") failed! err:", tostring(obj))
            return ok, obj
        end
    end
    if not ok then
        ngx.log(ngx.ERR, "url_perm_dao.select_by(" .. tostring(where_) .. ") failed! err:", tostring(obj))
    end
    return ok, obj
end

return  _M

