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

function _M:new(connection)
    local dao = basedao:new("application", 
        {app='string', appname='string', remark='string', 
        create_time='number', update_time='number'}, connection)

    return basedao.extends(_M, dao)
end

function _M:list_all(page, page_size)
    return self:list(nil, page, page_size)
end

function _M:count()
    return self:count_by()
end

function _M:get_by_app(app)
    return self:get_by("where app=" .. ngx.quote_sql_str(app))
end

return  _M