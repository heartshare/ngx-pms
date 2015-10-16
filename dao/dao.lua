--[[
author: jie123108@163.com
date: 20150901
]]

local mysql_util = require("dao.mysql_util")
local util = require("util.util")
local config = require(config_name or "config")
local cjson = require "cjson"
local basedao = require "dao.basedao"

local _M = {}
_M.db_inited = false
_M.err_dblock = "ERR.DATABASE_LOCKED"
_M.err_dbuninit = "ERR.DATABASE_NOT_INITED"
_M.err_sql = "ERR.SQL_EXEC_ERR"

local user_dao = basedao:new("user", {'id', 'username', 'email', 'password', 'role_id', 'permission'})
local role_dao = basedao:new("role", {'id', 'name', 'remark', 'permission'})
local url_perm_dao = basedao:new("url_perm", {'id', 'app', 'type', 'url', 'url_len', 'permission'})

function _M.init_db()   
    _M.db_inited = true
    return true
end

function _M.role_get_by_id(id)
    if not _M.db_inited and not _M.init_db() then 
        ngx.log(ngx.ERR, "user_get failed! database not inited!")
        return false, _M.err_dbuninit
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

local function _user_get_internal(id, username)
    if not _M.db_inited and not _M.init_db() then 
        ngx.log(ngx.ERR, "user_get failed! database not inited!")
        return false, _M.err_dbuninit
    end
    local ok, obj 
    if id then
        id = tonumber(id)
        ok, obj = user_dao:select_by("where id=" .. tostring(id))
    elseif username then
        username = ngx.quote_sql_str(username)
        ok, obj = user_dao:select_by("where username=" .. username)
    else
        ngx.log(ngx.ERR, "_user_get_internal failed! args 'id','username' missing!")
        return false, "not-exist"
    end
    
    if not ok then
        return  ok, obj
    end

    local permissions = nil
    ngx.log(ngx.INFO, "user.permission: ", tostring(obj.permission))

    if obj.permission then
        permissions = util.split(obj.permission, "|")
    end

    local role_permissions = nil
    if obj.role_id then
        local ok, role = _M.role_get_by_id(obj.role_id)
        if not ok then
            ngx.log(ngx.ERR, "role_get_by_id(", obj.role_id, ") failed! err:", tostring(role))
        else 
            if role.permissions and type(role.permissions) == 'table' then
                role_permissions = role.permissions
            end
        end
    end
    obj.permissions = util.merge_array_as_map(permissions, role_permissions)
    --[[
    ngx.log(ngx.INFO, "------------------------------------")
    for k, v in pairs(obj.permissions) do
        ngx.log(ngx.INFO, "---- ", k)
    end
    ]]
    return  ok, obj
end

function _M.user_get_by_username(username)
    return _user_get_internal(nil, username)
end

function _M.user_get_by_id(userid)
   return _user_get_internal(userid) 
end

function _M.url_perm_get(app, url)
    if not _M.db_inited and not _M.init_db() then 
        ngx.log(ngx.ERR, "url_perm_get failed! database not inited!")
        return false, _M.err_dbuninit
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
        elseif obj ~= "not-exist" then --出错
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

