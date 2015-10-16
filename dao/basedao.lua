local mysql_util = require("dao.mysql_util")
local util = require("util.util")
local config = require(config_name or "config")
local cjson = require "cjson"

local _M = {}
_M.db_inited = false
_M.err_dblock = "ERR.DATABASE_LOCKED"
_M.err_dbuninit = "ERR.DATABASE_NOT_INITED"
_M.err_sql = "ERR.SQL_EXEC_ERR"

local mt = { __index = _M }

function _M.new(self, table_name, fields)
    local sql_select = "SELECT " .. table.concat(fields, ",") .. " FROM " .. table_name
    return setmetatable({ table_name = table_name, fields = fields, sql_select=sql_select}, mt)
end

function _M.select_by(self, where)
    local sql = self.sql_select
    if where then
        sql = sql .. " " .. where
    end
    ngx.log(ngx.INFO, "sql is:", sql)
    local res, err = mysql_util.query(sql)
    if not res then
        return  false, err
    end
    local result = {}
    for i, v in ipairs(res) do
        result = v
    end

    if util.tableIsNull(result) then
        return  false, "not-exist"
    end

    return  true, result
end

return _M