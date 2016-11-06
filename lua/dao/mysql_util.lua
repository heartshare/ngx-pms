--[[
author: jie123108@163.com
date: 20150901
]]

local dbConfig = require("config")
local mysql = require("resty.mysql")
local json = require("util.json")
local error = require('dao.error')
local util = require("util.util")
local http = require("resty.http_client")

local _M = {}

local mt = {}
--[[
	返回：
		false, 出错信息
		true, 数据库连接
--]]
function mt.connection_get(self)
	local client, errmsg = mysql:new()
	if not client then
		ngx.log(ngx.ERR, "mysql:new failed! err:", errmsg)
		return	false, tostring(errmsg)
	end

	local timeout = self.db["timeout"] or 1000*10
	local max_idle_timeout = self.db["max_idle_timeout"] or 1000*10
	local pool_size = self.db["pool_size"] or 100

	client:set_timeout(timeout)	--10秒

	local db_ip = self.db["db_ip"]
	if db_ip == nil then
		db_ip = self.db["host"]
		if not http.is_ip(db_ip) then
		    local addr = http.dns_query(db_ip)
		    if addr then
		        db_ip = addr
		    end
		end
		self.db["db_ip"] = db_ip
	end

	local options = {
		host = db_ip,
		port = self.db["port"],
		user = self.db["user"],
		password = self.db["password"],
		database = self.db["database"],
		max_packet_size = 1024 * 1024 * 10, 
	}

	local ok, errmsg = client:connect(options)
	if not ok then
		client:set_keepalive(max_idle_timeout, pool_size)
		ngx.log(ngx.ERR, "mysql:connect(", json.dumps(options) , ") failed! err:", tostring(errmsg))
		return	false, error.err_database
	end

	if self.db["DEFAULT_CHARSET"] then
		local query = "SET NAMES " .. self.db["DEFAULT_CHARSET"]
		local result, errmsg, errno, sqlstate = client:query(query)
		if not result then
			client:set_keepalive(max_idle_timeout, pool_size)
			ngx.log(ngx.ERR, "mysql:query(", query, ") failed! err:", tostring(errmsg), ", errno:", tostring(errno))
			return	false, error.err_sql
		end
	end

	return	true, client
end

--[[
	把连接放回连接池
	用set_keepalive代替close将开启连接池特性，可以为每个nginx工作进程指定最大空闲时间和连接池最大连接数
--]]
function mt.connection_put(self,client)
	if client then
		local max_idle_timeout = self.db["max_idle_timeout"] or 1000*10
		local pool_size = self.db["pool_size"] or 100
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
local function mysql_query_internal(mysql_mgr,sql, connection)
	local ok, client = true, connection 
	if client == nil then
		ok, client = mysql_mgr:connection_get()
	end
	if not ok then
		return	false, client
	end

	local result, errmsg, errno, sqlstate = client:query(sql)
	if client ~= connection then
		mysql_mgr:connection_put(client)
	end

	if not result then
		local log_level = ngx.ERR 
		if errno == 1062 then
			log_level = ngx.INFO
		end
		ngx.log(log_level, "mysql:query(", string.sub(sql, 1, 500), ") failed! err:", tostring(errmsg), ", errno:", tostring(errno))
		return	false, error.err_sql, errno, errmsg
	end

	return	true, result
end

function mt.tx_begin(self, connection)
	return mysql_query_internal(self, "START TRANSACTION", connection)
end

function mt.tx_commit(self, connection)
	return mysql_query_internal(self, "COMMIT", connection)
end

function mt.tx_rollback(self, connection)
	return mysql_query_internal(self, "ROLLBACK", connection)
end

function mt.query(self, sql, connection)
    local ok, res, errno, errmsg = mysql_query_internal(self, sql, connection)
    if not ok then
        return nil, res, errno, errmsg
    end
        
    return res
end

function mt.execute(self, sql, connection)
    local ok, res, errno, errmsg = mysql_query_internal(self, sql, connection)
    if not ok then
        return -1, res, errno, errmsg
    end

    return res.affected_rows, res.insert_id
end

function mt.execute_bat(self, sql, connection)
    local ok, res, errno, errmsg = mysql_query_internal(self, sql, connection)
    if not ok then
        mysql_query_internal(self, "ROLLBACK", connection)
        return -1, res, errno, errmsg
    end

    return res.affected_rows
end

_M.mysql_mgr_pool = {}
function _M.get_mysql_mgr(db)
	if not db then
		db = dbConfig.db
	end

	if _M.mysql_mgr_pool[db] then
		return _M.mysql_mgr_pool[db]
	end

	local mysql_mgr = {db = db}
	_M.mysql_mgr_pool[db] = mysql_mgr
	return setmetatable(mysql_mgr,{__index = mt})
end

return	_M