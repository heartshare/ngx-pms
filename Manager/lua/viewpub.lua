local appdao = require("dao.app_dao")

local _M = {}

-- 获取用于查询的app及用于前端显示的app列表。
function _M.get_app_and_apps()
    local cur_userinfo = ngx.ctx.userinfo
    local app = nil
    local app_ok, apps = nil
    if cur_userinfo.manager == "super" then
        --可选择多个应用。
        local dao = appdao:new()
        app_ok, apps = dao:list(1, 1024)
        if not app_ok then
            ngx.log(ngx.ERR, "appdao:list() failed! err:", tostring(apps))
            apps = {}
        end
    else
        app = cur_userinfo.app
        apps = {cur_userinfo.app}
    end
    return app, apps
end

function print_tab(tab, name)
    if tab == nil then
        tab = {}
    end
    local str = name .. table.concat(tab, " | ")
    ngx.log(ngx.INFO, "-----", str)
end

-- return all_permissions - sub_permissions
function _M.perm_sub(all_permissions, sub_permissions)
    --print_tab(all_permissions, 'all_permissions')
    --print_tab(sub_permissions, 'sub_permissions')

    if not sub_permissions then
        return all_permissions
    end
    if not all_permissions then
        return all_permissions
    end

    local sub_permissions_as_map = {}
    for i, value in ipairs(sub_permissions) do 
        sub_permissions_as_map[value] = 1
    end

    local tmp_values = {}
    for i, permission in ipairs(all_permissions) do 
        if not sub_permissions_as_map[permission.id] then
            table.insert(tmp_values, permission)
        end
    end
    return tmp_values   
end

return _M