--[[
供config.lua使用的代码，不能包含任何其它lua文件中的代码。
]]

local _M = {}

local function exist(filename)
    local f, err = io.open(filename,"r+")
    local is_exist = f ~= nil 
    if f then
        f:close()
    end
    return is_exist
end

local function startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end
local function popen(cmd)
    local fp = io.popen(cmd .. '; echo "retcode:$?"', "r")
    local line_reader = fp:lines()
    local lines = {}
    local lastline = nil
    for line in line_reader do
        lastline = line
        if not startswith(line, "retcode:") then
            table.insert(lines, line)                
        end
    end
    fp:close()
    if lastline == nil or string.sub(lastline, 1, 8) ~= "retcode:" then
        return false, lastline, -1
    else
        local code = tonumber(string.sub(lastline, 9))
        return code == 0, lines, code
    end
end

function _M.gethostname()
    local ok, lines, code = popen("hostname")
    if ok and table.getn(lines)==1 then
        return lines[1]
    else
        return nil
    end
end

-- delimiter 应该是单个字符。如果是多个字符，表示以其中任意一个字符做分割。
local function split(s, delimiter)
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

local function trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function filter(k, v)
    if k == 'password' then 
        return k, "***"
    else 
        return k, v 
    end
end

local function table_to_string(t, seq)
    if seq == nil then
        seq = ","
    end
    if type(t) ~= 'table' then
        return tostring(t)
    end
    local l = {}
    for k,v in pairs(t) do
        k, v = filter(k, v)
        if type(v) == 'table' then
            v = "{" .. table_to_string(v) .. "}"
        elseif type(v) == 'string' then
            v = "'" .. v .. "'"
        end
        if type(k) == 'number' then
            table.insert(l, v)
        else
            table.insert(l, k .. "=" .. tostring(v))
        end
    end
    return "{" .. table.concat(l, seq) .. "}"
end

local ignores = {aes_key=true, aes_iv=true}
function _M.config_to_string(config)
    local configlist = {}
    for k, v in pairs(config) do 
        if type(v) == "table" then
            v = table_to_string(v, ",")
        elseif type(v) == 'string' then
            v = "'" .. v .. "'"
        end
        if type(v) ~= "function" and not ignores[k] then
            table.insert(configlist, "config." .. k .. "=" .. tostring(v))
        end
    end
    return table.concat(configlist, "\n")
end

local function read_content(filename)
    local f, err = io.open(filename, 'r')
    if f then
        local lines = {}
        while true do
            local line = f:read("*line")
            if line == nil then
                break
            end
            table.insert(lines, line)
        end
        f:close()
        return true, lines
    else 
        return false, err 
    end
end

local function read_userinfo(filename)
    local userinfo = nil
    local ok, lines = read_content(filename)
    if ok then
        userinfo = {username='test', password=''}
        for i, line in ipairs(lines) do 
            if not startswith(line, "#") then
                local arr = split(line, ":")
                if #arr == 1 then
                    userinfo.username = trim(arr[1])
                elseif #arr == 2 then
                    userinfo.username = trim(arr[1])
                    userinfo.password = trim(arr[2]) or ''
                else 
                    ngx.log(ngx.ERR, " invalid line [", line, "] in file:", filename)
                end
            end
        end
    else
        userinfo = lines
    end
    return ok, userinfo
end

function _M.init_from_ext_config(config)
    config.hostname = _M.gethostname()
    -- local hostname = config.hostname
    -- ngx.log(ngx.WARN, "# hostname:", hostname)
    package.path = '/opt/leo_cfg/?.lua;' .. package.path

    local ext_config_file = config.ext_config or 'ext_config'
    -- ngx.log(ngx.WARN, "--- ext_config_file:", tostring(ext_config_file))
    local ok, ext_config = pcall(require, ext_config_file)
    if not ok then
        ngx.log(ngx.WARN, "# require 'ext_config failed! ", ext_config)
        return
    end
    if ext_config then       
        local NIL = 'nil'
        if type(ext_config) == 'table' then
            for key, value in pairs(ext_config) do   
                if value == NIL then
                    value = nil 
                end
                config[key] = value
                if type(value) == 'table' then
                    value = table_to_string(value, ',')
                end
                ngx.log(ngx.WARN, "config.",key, " set to [",tostring(value), "]") 
            end
        end 
    end -- if ext_config then
end

return _M