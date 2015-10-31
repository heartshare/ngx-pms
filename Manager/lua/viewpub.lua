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

return _M