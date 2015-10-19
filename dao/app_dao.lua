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
    local dao = basedao:new("application", 
        {app='string', appname='string', remark='string', 
        create_time='number', update_time='number'}, connection)

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

return  _M

--[[
local appdao = _M

ok, err  = appdao.save({app="KB01", appname="kuaibo 01 proj"})
ngx.say(ok, err)
ok, err  = appdao.save({app="KB002", appname="kuaibo 002 proj"})
ngx.say(ok, err)

local ok, values = appdao.count()
ngx.say("[", ok, ",", json.dumps(values), "]")

]]