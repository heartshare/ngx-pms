--[[
author: jie123108@163.com
date: 20151017
]]

local cjson = require("cjson")
local error = require('dao.error')
local string_format = string.format
local def_mysql_util = require("dao.mysql_util").get_mysql_mgr()
local sql_debug = false
local ok, config = pcall(require, 'config')
if ok then 
    sql_debug = config.sql_debug or false
end

local _M = {}

local function tableIsNull(res)
    local ret = true
    if type(res) == "table" then
        for key, val in pairs(res) do
            if key then
                ret = false
                break
            end
        end
    end 
    return  ret
end

local function E(key)
    return "`" .. key .. "`"
end

--[[
table_meta: {id='number', user_id='string'}
excludes: {content=true, exclude_field=true}
]]
local function get_select_sql(tablename, table_meta, excludes)
    local sql_select = {}

    table.insert(sql_select, "SELECT ")

    for k,v in pairs(table_meta) do
        if excludes and excludes[k] then 
            -- continue
        else
            table.insert(sql_select, string_format('`%s`',k))
            table.insert(sql_select, ",")
        end
    end
    table.remove(sql_select)
    table.insert(sql_select, " FROM " .. E(tablename))
    return table.concat(sql_select);
end

local function get_sql_value(v, type_)
    if type_ == 'string' then
        return ngx.quote_sql_str(v)
    elseif type_ == 'datetime' then
        return "from_unixtime(" .. v .. ")"
    else
        if type(v) == 'boolean' then
            if v then 
                v = 1
            else 
                v = 0 
            end
        elseif type(v) == 'string' then
            v = ngx.quote_sql_str(v)
        end
        return v
    end
end

local function get_insert_or_replace_sql(tablename, table_meta, obj, operate)
    local sql_insert = {}
    local sql_values = {}
    table.insert(sql_insert, operate .. " into " .. E(tablename) .. "(")
    table.insert(sql_values, "values(")
    for k,v in pairs(obj) do
        if table_meta[k] then 
            table.insert(sql_insert, string_format('`%s`',k))
            table.insert(sql_insert, ",")
            
            table.insert(sql_values, get_sql_value(v, table_meta[k]))       
            table.insert(sql_values, ",")
        end
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

local function get_update_sql(tablename, table_meta, obj, update_by)
    local sql_update = {}
    table.insert(sql_update, "UPDATE " .. E(tablename) .. " ")
    table.insert(sql_update, "SET ")
    for k,v in pairs(obj) do
        if table_meta[k] then 
            table.insert(sql_update, string_format('`%s`',k))
            table.insert(sql_update, "=")
            
            table.insert(sql_update, get_sql_value(v, table_meta[k]))
            table.insert(sql_update, ",")
        end
    end
    table.remove(sql_update)

    table.insert(sql_update, " WHERE ")
    for k,v in pairs(update_by) do
        table.insert(sql_update, string_format('`%s`',k))
        table.insert(sql_update, "=")
        
        table.insert(sql_update, get_sql_value(v, table_meta[k])) 
        table.insert(sql_update, " and ")
    end
    table.remove(sql_update)

    return table.concat(sql_update) 
end

function _M.extends(this_module, super_obj)
    local super_mt = getmetatable(super_obj)
    -- 当方法在子类中查询不到时，再去父类中去查找。
    setmetatable(this_module, super_mt)
    -- 这样设置后，可以通过self.super.method(self, ...) 调用父类的已被覆盖的方法。
    super_obj.super = setmetatable({}, super_mt)
    return setmetatable(super_obj, { __index = this_module })
end

local mt = { __index = _M }

function _M:new(tablename, table_meta,  connection, mysql_util)
    local sql_select = get_select_sql(tablename, table_meta)
    local sql_count = "SELECT COUNT(*) as c FROM " .. E(tablename)
    local sql_delete = "DELETE FROM " .. E(tablename)
    if mysql_util == nil then 
        mysql_util = def_mysql_util
    end
    return setmetatable(
        { 
            mysql_util = mysql_util,
            tablename = tablename, 
            table_meta = table_meta, 
            connection=connection, 
            sql_select=sql_select, 
            sql_count=sql_count, 
            sql_delete=sql_delete
        },
        mt)
end

-- 设置列表时，要排除的字段。
function _M:set_list_excludes(excludes)
    self.excludes = excludes 
    self.sql_select_list = get_select_sql(self.tablename, self.table_meta, excludes)
end

function _M:get_one(sql)
    if sql_debug then 
        ngx.log(ngx.INFO, "sql is:", sql)
    end
    local res, err = self.mysql_util:query(sql, self.connection)
    if not res then
        return  false, err
    end
    local result = res[#res]

    if tableIsNull(result) then
        return  true, nil
    end
    for key, value in pairs(result) do 
        if value == cjson.null then
            result[key] = nil
        end
    end

    return  true, result
end


function _M:get_by(where)
    local sql = self.sql_select
    if where then
        sql = sql .. " " .. where
    end
   
    return self.get_one(self, sql)
end

function _M:list_internal(sql)
    if sql_debug then 
        ngx.log(ngx.INFO, "list sql is:", sql)
    end
    local res, err = self.mysql_util:query(sql, self.connection)
    if not res then
        return  false, err
    end

    if tableIsNull(res) then
        return  true, {}
    end
    if type(res) == 'table' then 
        local lst = {}
        for _, item in ipairs(res) do 
            for key, value in pairs(item) do 
                if value == cjson.null then
                    item[key] = nil
                end
            end
            table.insert(lst, item)
        end
        res = lst
    end

    return  true, res
end

function _M:list_by(where, limit, offset)
    local sql = self.sql_select_list or self.sql_select

    if where then
        sql = sql .. " " .. where
    end
    if limit then
        sql = sql .. " limit " .. tonumber(limit)
    end
    if offset then
        sql = sql .. " offset " .. tonumber(offset)
    end
    
    return _M.list_internal(self, sql)
end


function _M:list(where, page, page_size)
    local limit = page_size
    local offset = nil
    if page and page > 1 then
        page_size = page_size or 100
        offset = (page-1)*page_size
    end
    return _M.list_by(self, where, limit, offset)
end

function _M:query_int(sql, fieldname)
    if sql_debug then 
        ngx.log(ngx.INFO, "sql is:", sql)
    end
    local res, err = self.mysql_util:query(sql, self.connection)
    if not res then
        return  false, err
    end

    if tableIsNull(res) then
        return  true, nil
    end
    res = res[#res]
    return  true, tonumber(res[fieldname])
end

function _M:count_by(where)
    local sql = self.sql_count
    if where then
        sql = sql .. " " .. where
    end
    
    if sql_debug then 
        ngx.log(ngx.INFO, "sql is:", sql)
    end
    local res, err = self.mysql_util:query(sql, self.connection)
    if not res then
        return  false, err
    end

    if tableIsNull(res) then
        return  true, 0
    end
    res = res[#res]
    return  true, tonumber(res.c)
end

function _M:exist(field, value)
    if type(value) == 'string' then
        value = ngx.quote_sql_str(value)
    end
    local where = "WHERE " .. field .. "=" .. value
    local ok, count = _M.count_by(self, where)
    if ok then
        return ok, count>0
    else
        return ok, count 
    end
end

function _M:exist_exclude(field, value, id)
    if type(value) == 'string' then
        value = ngx.quote_sql_str(value)
    end
    if type(id) == 'number' then
        id = tostring(id)
    elseif type(id) == 'string' then
        id = ngx.quote_sql_str(id)
    end

    local where = "WHERE id!=" .. id .. " AND " .. field .. "=" .. value
    local ok, count = self:count_by(where)
    if ok then
        return ok, count>0
    else
        return ok, count 
    end
end

function _M:save(values)
    local sql = get_insert_sql(self.tablename, self.table_meta, values)
    if sql_debug then 
        ngx.log(ngx.INFO, "insert sql:", tostring(sql))
    end
    local effects, insert_id, errno, errmsg = self.mysql_util:execute(sql, self.connection)
    if effects == -1 then
        if errno == 1062 then
            ngx.log(ngx.INFO, "execute [", sql, "] failed! err:", tostring(insert_id))
            return false, error.err_data_exist, errmsg
        else
            ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(insert_id))
            return false, insert_id
        end
    end
    return true, insert_id
end

-- 存在就删除，再插入，不存在就直接插入。
function _M:replace(values)
    local sql = get_replace_sql(self.tablename, self.table_meta, values)
    if sql_debug then 
        ngx.log(ngx.INFO, "replace sql:", tostring(sql))
    end
    local effects, err = self.mysql_util:execute(sql, self.connection)
    if effects == -1 then
        ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(err))
        return false
    end
    return true
end

local function def_check_update_cb(ok, err, errmsg)
    -- ngx.log(ngx.INFO, "ok:", ok, ", err:", err, " errmsg:", errmsg, " matched:", ngx.re.match(errmsg or '', "Duplicate entry '.*' for key 'PRIMARY'"))
    return not ok and err == error.err_data_exist
end

function _M:upsert_by(values, id_field, not_update_fields, check_update_cb)
    local ok, err, errmsg = self:save(values)
    local operate = "save"
    check_update_cb = check_update_cb or def_check_update_cb
    local need_update = check_update_cb(ok, err, errmsg)
    ngx.log(ngx.INFO, "check_update(ok:", ok, ",err:", tostring(err), ", errmsg:", tostring(errmsg), "): ", need_update)
    
    if need_update then 
        local update = {}
        local select = {}
        for k, v in pairs(values) do 
            update[k] = v
        end
        if type(id_field) == 'table' then 
            for _, field in ipairs(id_field) do 
                select[field] = update[field]
                update[field] = nil
            end
        else
            select[id_field] = update[id_field]
            update[id_field] = nil
        end
        if not_update_fields and type(not_update_fields) == 'table' then 
            for _, field in ipairs(not_update_fields) do 
                update[field] = nil
            end
        end
        ok, err = self:update(update, select)
        operate = "update"
    end

    return ok, err, operate
end

function _M:update(values, select)
    if not values then
        ngx.log(ngx.ERR, "param values is missing")
        return false, error.err_args_invalid
    end
    if not select then
        ngx.log(ngx.ERR, "param select is missing")
        return false, error.err_args_invalid
    end

    local sql = get_update_sql(self.tablename, self.table_meta, values, select)
    if sql_debug then 
        ngx.log(ngx.INFO, "update sql:", tostring(sql))
    end
    local effects, err, errno = self.mysql_util:execute(sql, self.connection)
    -- ngx.log(ngx.ERR, "effects:", effects, ", err:", err, ", errno:", errno)

    if effects == -1 then
        ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(err))
        if errno == 1062 then
            return false, error.err_data_exist
        else
            return false, err
        end
    end
    return true, effects
end

function _M:delete_by(where)
    local sql = self.sql_delete
    if where then
        sql = sql .. " " .. where
    end
    
    if sql_debug then 
        ngx.log(ngx.INFO, "sql is:", sql)
    end
    local res, err = self.mysql_util:query(sql, self.connection)
    if not res then
        return  false, err
    end

    return true, tonumber(res.affected_rows)
end

-- 支持批量插入
function _M:multi_save(values)
  local sql_insert = {}
  local sql_values = {}
  for k, v in pairs(values) do
    local val = {}
    local insert = {}
    for ck, cv in pairs(v) do
      table.insert(insert, string_format('`%s`', ck))
      table.insert(val, cv)
    end
    table.insert(sql_insert, '('..table.concat(insert, ",")..')')
    table.insert(sql_values, '('..table.concat(val, ",")..')')
  end
  local sql = "INSERT INTO "..self.tablename.." "..tostring(sql_insert[1]).." ".."VALUES "..table.concat(sql_values, ",")
  return self:execute_sql(sql)
end

function _M:execute_sql(sql)   
    if sql_debug then 
        ngx.log(ngx.INFO, "execute sql:", tostring(sql))
    end
    local effects, err, errno = self.mysql_util:execute(sql, self.connection)
    if effects == -1 then
        ngx.log(ngx.ERR, "execute [", sql, "] failed! err:", tostring(err))
        if errno == 1062 then
            return false, error.err_data_exist
        else
            return false, err
        end
    end
    return true, effects
end

return _M