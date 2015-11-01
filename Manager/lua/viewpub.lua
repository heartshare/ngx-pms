local appdao = require("dao.app_dao")
local permdao = require('dao.perm_dao')

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

function _M.get_permissions(app)
    local dao = permdao:new()
    local perm_ok, permissions = dao:list(app, 1, 1024)
    if not perm_ok then
        if permissions == error.err_data_not_exist then

        else
            ngx.log(ngx.ERR, "permdao:list(", tostring(app), ") failed! err:", tostring(permissions))
        end
        permissions = {}
    end
    return permissions
end

function _M.get_url_types()
    -- 1.equal 精确匹配\r\n  2.suffix 后缀匹配\r\n  3.prefix 前缀匹配(最大匹配原则)\r\n  4.regex 正则匹配
    local types = {}
    table.insert(types, {id='equal', name="精确匹配"})
    table.insert(types, {id='suffix', name="后缀匹配"})
    table.insert(types, {id='prefix', name="前缀匹配"})
    --table.insert(types, {id='regex', name="正则匹配"})

    return types
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