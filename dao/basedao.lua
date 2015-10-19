--[[
author: jie123108@163.com
date: 20151017
]]

local mysql_util = require("dao.mysql_util")
local util = require("util.util")
local config = require("config")
local json = require('util.json')
local error = require('dao.error')

local _M = {}

local function get_select_sql(tablename, table_meta)
    local sql_select = {}

    table.insert(sql_select, "select ")

    for k,v in pairs(table_meta) do
        table.insert(sql_select, k)
        table.insert(sql_select, ",")
    end
    table.remove(sql_select)
    table.insert(sql_select, " from " .. tablename)
    return table.concat(sql_select);
end

local function get_insert_or_replace_sql(tablename, table_meta, obj, operate)
    local sql_insert = {}
    local sql_values = {}
    table.insert(sql_insert, operate .. " into " .. tablename .. "(")
    table.insert(sql_values, "values(")
    for k,v in pairs(obj) do
        table.insert(sql_insert, k)
        table.insert(sql_insert, ",")
        if table_meta == nil or table_meta[k] == nil then
            if type(v) == 'string' then
                table.insert(sql_values, "'" .. v .. "'")
            else
                if type(v) == 'boolean' then
                    if v then 
                        v = 1
                    else 
                        v = 0 
                    end
                end
                table.insert(sql_values, v)
            end
        else
            if table_meta[k] == 'string' then
                table.insert(sql_values, "'" .. v .. "'")
            elseif table_meta[k] == 'datetime' then
                table.insert(sql_values, "from_unixtime(" .. v .. ")")
            else
                if type(v) == 'boolean' then
                    if v then 
                        v = 1
                    else 
                        v = 0 
                    end
                end
                table.insert(sql_values, v)
            end
        end
        table.insert(sql_values, ",")
    end
    table.remove(sql_insert)
    table.insert(sql_insert, ") ")
    table.remove(sql_values)
    table.insert(sql_values, ")")
    return table.concat(sql_insert) .. table.concat(sql_values)
end

local function get_insert_sql(tablename, table_meta, obj)
    return get_insert_or_replace_sql(tablename, table_meta, obj, "insert")
end

local function get_replace_sql(tablename, table_meta, obj)
    return get_insert_or_replace_sql(tablename, table_meta, obj, "replace")
end


local mt = { __index = _M }

function _M:new(tablename, table_meta, connection)
    --local sql_select = "SELECT " .. table.concat(table_meta, ",") .. " FROM " .. tablename
    --local sql_insert = "insert into " .. tablename .. "(" .. table.concat(table_meta, ",") .. ")"
    local sql_select = get_select_sql(tablename, table_meta)
    local sql_count = "SELECT COUNT(*) as c FROM " .. tablename
    return setmetatable({ tablename = tablename, table_meta = table_meta, connection=connection, 
                sql_select=sql_select, sql_count=sql_count}, mt)
end

function _M:select_by(where)
    local sql = self.sql_select
    if where then
        sql = sql .. " " .. where
    end
   
    ngx.log(ngx.INFO, "sql is:", sql)
    local res, err = mysql_util.query(sql, self.connection)
    if not res then
        return  false, err
    end
    local result = res[#res]

    if util.tableIsNull(result) then
        return  false, error.err_data_not_exist
    end

    return  true, result
end

function _M:list_by(where, limit, offset)
    local sql = self.sql_select
    if where then
        sql = sql .. " " .. where
    end
    if limit then
        sql = sql .. " limit " .. tonumber(limit)
    end
    if offset then
        sql = sql .. " offset " .. tonumber(offset)
    end
    
    ngx.log(ngx.INFO, "sql is:", sql)
    local res, err = mysql_util.query(sql, self.connection)
    if not res then
        return  false, err
    end

    if util.tableIsNull(res) then
        return  false, error.err_data_not_exist
    end

    return  true, res
end

function _M:count_by(where)
    local sql = self.sql_count
    if where then
        sql = sql .. " " .. where
    end
    
    ngx.log(ngx.INFO, "sql is:", sql)
    local res, err = mysql_util.query(sql, self.connection)
    if not res then
        return  false, err
    end

    if util.tableIsNull(res) then
        return  false, error.err_data_not_exist
    end
    res = res[#res]
    return  true, tonumber(res.c)
end

function _M:exist(field, value)
    if type(value) == 'string' then
        value = ngx.quote_sql_str(value)
    end
    local where = "where " .. field .. "=" .. value
    local ok, count = _M.count_by(self, where)
    if ok then
        return ok, count>0
    else
        return ok, count 
    end
end

function _M:save(values)
    local sql = get_insert_sql(self.tablename, self.table_meta, values)
    local effects, err, errno = mysql_util.execute(sql, self.connection)
    if effects == -1 then
        ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(err))
        if errno == 1062 then
            return false, error.err_data_exist
        else
            return false, err
        end
    end
    return true
end

function _M:saveOrUpdate(values)
    local sql = get_replace_sql(self.tablename, self.table_meta, values)
    local effects, err = mysql_util.execute(sql, self.connection)
    if effects == -1 then
        ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(err))
        return false
    end
    return true
end

return _M