
local _M = {}

local login_url = "/pms/login"
local login_post_url = "/pms/login_post"
local logout_url = "/pms/logout"
local no_access_page = "/pms/no_access_page"
local right_check_url = "/pms/right_check"
local change_pwd_url = "/pms/change_pwd"
local change_pwd_post_url = "/pms/change_pwd_post"


local ignore_list = {login_url, login_post_url,logout_url,no_access_page,right_check_url, change_pwd_url, change_pwd_post_url}

function _M.is_ignore_url(url)
    if ignore_list == nil then
        return false
    end
    local matched = false
    -- 精确匹配。
    if type(ignore_list)=='table' then
        for i, item in ipairs(ignore_list) do 
            --ngx.log(ngx.INFO, "### compare(", item, ",", url, ")...")
            if item == url then
                matched = true
                break
            end
        end
    end
    return matched
end

local function split(s, delimiter)
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

local function need_replace_internal()
    if _M.is_ignore_url(ngx.var.uri) then
        ngx.log(ngx.INFO, "### filter ignore : ", ngx.var.uri)
        return false
    end
    local content_type = ngx.header["Content-Type"]
    if content_type == nil then 
       ngx.log(ngx.INFO, "---- ignore type: ", tostring(content_type));
       return false
    end
    local arr = split(content_type, ";")
    content_type = arr[1]

    return content_type == "text/plain" or content_type == "text/html"
end

function _M.need_replace()
    if ngx.ctx.need_replace == nil then 
        ngx.ctx.need_replace = need_replace_internal()
    end
    return ngx.ctx.need_replace
end 

return _M