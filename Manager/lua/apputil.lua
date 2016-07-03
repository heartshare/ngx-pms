
local _M = {}
local cachename = "cache"

function _M.sel_app_set(userid, app)
	local cache = ngx.shared[cachename]
    if cache then        
        local key_cur_app = "cur_app:" .. userid
        local ok, err = cache:safe_set(key_cur_app, app)
        if not ok then
            ngx.log(ngx.ERR, "cache:safe_set(", key_cur_app, ",", app, ") failed! err:", err)
            return false
        end        
    else
        ngx.log(ngx.ERR, "lua_shared_dict named '", cachename, "' not defined!")
        return false
    end
end


function _M.sel_app_get(userid)
	local cache = ngx.shared[cachename]
    if cache then        
        local key_cur_app = "cur_app:" .. userid
        local value, flags = cache:get(key_cur_app)
        return value  
    else
        ngx.log(ngx.ERR, "lua_shared_dict named '", cachename, "' not defined!")
        return nil
    end
end

return _M