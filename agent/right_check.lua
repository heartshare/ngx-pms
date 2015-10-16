local config = require("config")
local util = require("util.util")
local ck = require('util.cookie')

local login_url = config.login_url or "/nright/login"
local no_access_page = config.no_access_page or "/nright/no_access_page"
local right_check_url = config.right_check_url or "/nright/right_check"


local function uri_args_as_args()
	local args = ngx.req.get_uri_args()
	local full_uri = (ngx.var.scheme or "http") .. "://" .. ngx.var.host .. ngx.var.uri
	args["uri"] = full_uri
	return ngx.encode_args(args)
end

local function check_uri_permission(app, uri, cookie)
	local retry_max = 3
	local right_check_url_full = util.get_full_uri(right_check_url)
	local res, err = nil
    for i = 1,retry_max do    	
    	local args = ngx.encode_args({app=app, uri=uri, cookie=cookie})
        local url = right_check_url_full .. "?" .. args
        res, err = util.http_get(url, {})

        if res then
            ngx.log(ngx.INFO, "check permission request:", url, ", status:", res.status, ",body:", tostring(res.body))

            if res.status == 200 then
                break
            else
                ngx.log(ngx.ERR, string.format("request [curl -v %s] failed! status:%d", url, res.status))
            end
        else
            ngx.log(ngx.ERR, "fail request: ", url, " err: ", err)
        end
    end
    if not res then
        return false, 500
    end
    if res.status ~= 200 then
        return false, res.status
    end
    return true, res.status
end

local function check_right()
	local url = ngx.var.uri
	if util.url_in_ignore_list(url) then
		ngx.log(ngx.INFO, "check right, ignore current request!")
		return
	end
	local app = ngx.var.app or "def"

	ngx.log(ngx.INFO, "Cookie: ", ngx.var.http_cookie)
	
	local cookie_value = ck.get_cookie()
	if cookie_value == nil then
		ngx.log(ngx.WARN, "no rights to access [", url, "], need login!")
		util.redirect(login_url, uri_args_as_args())
	elseif cookie_value == "logouted" then
		ngx.log(ngx.WARN, "logouted, no rights to access [", url, "], need login!")
		util.redirect(login_url, uri_args_as_args())
	end
	ngx.log(ngx.INFO, "Cookie: ", cookie_value)
	ngx.ctx.cookie = cookie_value
	
	-- TODO: 取出COOKIE
	local ok, status = check_uri_permission(app, url, cookie_value)
	ngx.log(ngx.INFO, " check_uri_permission(app=", tostring(app),
		",url=", tostring(url), ",cookie=", tostring(cookie_value), ")=", ok, ",", tostring(status))
	if not ok then
		-- no permission.
		if no_access_page and status == ngx.HTTP_UNAUTHORIZED then
			util.redirect(no_access_page, uri_args_as_args())
		else
			ngx.status = status
			ngx.send_headers()
			ngx.flush(true)
			ngx.say("NRight check permission failed! status:" .. tostring(status))
			ngx.flush(true)
		end
	end

end

check_right()