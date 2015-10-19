--[[
author: jie123108@163.com
date: 20151017
]]

local mysql_util = require("dao.mysql_util")
local util = require("util.util")
local json = require("util.json")
local config = require("config")
local basedao = require "dao.basedao"
local error = require('dao.error')

local _M = {}


local mt = { __index = _M }



function _M.new(self, connection)
    local dao = basedao:new("user", 
                   {id='number', 
                    username='string', 
                    email='string', 
                    tel='string', 
                    password='string', 
                    app='string', 
                    role_id='string', 
                    permission='string',
                    create_time='number',
                    update_time='number'}, connection)

    return setmetatable({ dao = dao}, mt)
end

function _M.list(self, page, page_size)    
    page = page or 1
    page_size = page_size or 10
    local limit = page_size
    local offset = nil
    if page > 1 then
        offset = (page-1)*page_size
    end

    local ok, obj = self.dao:list_by(nil, limit, offset)
    if not ok then
        return  ok, obj
    end
    
    return ok, obj
end

function _M.count(self)
    local ok, obj = self.dao:count_by(nil)
    
    return ok, obj
end

function _M.save(self, values)
    return self.dao:save(values)
end

function _M:exist(field, value)
    return self.dao:exist(field, value)
end

function _user_get_internal(dao, id, username)
    local ok, obj 
    if id then
        id = tonumber(id)
        ok, obj = dao:select_by("where id=" .. tostring(id))
    elseif username then
        username = ngx.quote_sql_str(username)
        ok, obj = dao:select_by("where username=" .. username)
    else
        ngx.log(ngx.ERR, "_user_get_internal failed! args 'id','username' missing!")
        return false, error.err_data_not_exist
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
        --TODO: role_get_by_id 修改
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

function _M.get_by_name(self, username)
    return _user_get_internal(self.dao, nil, username)
end

function _M.get_by_id(self, userid)
   return _user_get_internal(self.dao, userid) 
end

return  _M
