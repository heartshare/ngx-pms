--[[
author: jie123108@163.com
date: 20150901
]]

local dbConfig = require("config")
local mysql = require("resty.mysql")
local json = require("util.json")
local err_sql = "ERR.SQL_EXEC_ERR"
local err_database = "ERR.DATABASE_ERR"

--[[
	先从连接池去连接，如果没有再建立连接
	返回：
		false, 出错信息
		true, 数据库连接
--]]
local function connection_get()

	local client, errmsg = mysql:new()
	if not client then
		ngx.log(ngx.ERR, "mysql:new failed! err:", errmsg)
		return	false, tostring(errmsg)
	end

	local timeout = dbConfig.db["timeout"] or 1000*10
	local max_idle_timeout = dbConfig.db["max_idle_timeout"] or 1000*10
	local pool_size = dbConfig.db["pool_size"] or 100

	client:set_timeout(timeout)	--10秒


	local db_ip = dbConfig.db["host"]
	

	local options = {
		host = db_ip,
		port = dbConfig.db["port"],
		user = dbConfig.db["user"],
		password = dbConfig.db["password"],
		database = dbConfig.db["database"]
	}

	local ok, errmsg = client:connect(options)
	if not ok then
		client:set_keepalive(max_idle_timeout, pool_size)
		ngx.log(ngx.ERR, "mysql:connect(", json.dumps(options) , ") failed! err:", tostring(errmsg))
		return	false, err_database
	end

	if dbConfig.db["DEFAULT_CHARSET"] then
		local query = "SET NAMES " .. dbConfig.db["DEFAULT_CHARSET"]
		local result, errmsg, errno, sqlstate = client:query(query)
		if not result then
			client:set_keepalive(max_idle_timeout, pool_size)
			ngx.log(ngx.ERR, "mysql:query(", query, ") failed! err:", tostring(errmsg), ", errno:", tostring(errno))
			return	false, err_sql
		end
	end

	return	true, client
end

--[[
	把连接放回连接池
	用set_keepalive代替close将开启连接池特性，可以为每个nginx工作进程指定最大空闲时间和连接池最大连接数
--]]
function connection_put(client)
	if client then
		local max_idle_timeout = dbConfig.db["max_idle_timeout"] or 1000*10
		local pool_size = dbConfig.db["pool_size"] or 100
		client:set_keepalive(max_idle_timeout, pool_size)
	end
end

--[[
	查询
	有结果集时返回结果集
	无结果集返回查询影响
	返回：
		false, 出错信息, sqlstate结构
		true, 结果集, sqlstate结构
--]]
local function mysql_query_internal(sql)
	local ok, client = connection_get()
	if not ok then
		return	false, client
	end

	local result, errmsg, errno, sqlstate = client:query(sql)
	connection_put(client)

	if not result then
		ngx.log(ngx.ERR, "mysql:query(", sql, ") failed! err:", tostring(errmsg), ", errno:", tostring(errno))
		return	false, err_sql
	end

	return	true, result
end

local _M = {}

function _M.query(sql)
    local ok, res = mysql_query_internal(sql)
    if not ok then
        return nil, res
    end
        
    return res
end

function _M.execute(sql)
    local ok, res = mysql_query_internal(sql)
    if not ok then
        return -1, res
    end

    return res.affected_rows
end

function _M.execute_bat(sql)
    local ok, res = mysql_query_internal(sql)
    if not ok then
        mysql_query_internal("ROLLBACK")
        return -1, res
    end

    return res.affected_rows
end

return	_M
