
local _M = {}

local w3school_style = [[
<style type="text/css">
<!--
#topbar {
    width: 100px;
    height: 80px;
    right: 5px;
    top: 0px;
    background-color: #EFEFEF;
    font-size: 12px;
    background-position: top;
    border-top-width: thin;
    border-right-width: thin;
    border-bottom-width: thin;
    border-left-width: thin;
    border-top-style: none;
    border-right-style: none;
    border-bottom-style: none;
    border-left-style: none;
    padding: 5px;
    margin: 5px;
    visibility: visible;
    z-index: 10000;
    font-weight: bold;
    position: fixed;
    border-radius: 8px;
}
#pms-sysname {
	float:none;
	width:auto;
	height:20px;
	text-align:left;
}
#pms-info {
	margin-top:5px;
	float:none;
	width:auto;
	text-align:left;
}

#pms-info div {
	float:none;
	width:auto;
	height:18px;
	text-align:left;
}

-->
</style>
]]

local openresty_style = [[
<style type="text/css">
#topbar {
    width: 150px;
    height: 75px;
    right: 2px;
    top: 85px;
    background-color: #aae3aa;
    font-size: 12px;
    background-position: top;
    border-top-width: thin;
    border-right-width: thin;
    border-bottom-width: thin;
    border-left-width: thin;
    border-top-style: none;
    border-right-style: none;
    border-bottom-style: none;
    border-left-style: none;
    padding: 5px;
    margin: 5px;
    visibility: visible;
    z-index: 10000;
    font-weight: bold;
    position: fixed;
    border-radius: 8px;
}
#pms-sysname {
    float:none;
    width:auto;
    height:20px;
    text-align:left;
}
#pms-info {
    margin-top:5px;
    float:none;
    width:auto;
    text-align:left;
}

#pms-info div {
    float:none;
    width:auto;
    height:18px;
    text-align:left;
}

</style>
]]

local styles = {
    openresty = openresty_style,
    w3school = w3school_style,
}
function _M.get_style(app)
    return styles[app]
end

function _M.filter(arg)
	local args = ngx.req.get_uri_args()
	ngx.log(ngx.INFO, " ############# args.app:", tostring(args.app))
	ngx.log(ngx.INFO, " ############# ngx.var.app:", tostring(ngx.var.app))
	
	local app = args.app or ngx.var.app or "def"
	local do_replace = ngx.ctx.topbar_added or ngx.var.uri == "/pms/no_access_page"
	ngx.log(ngx.INFO, "app:", app, ", do_replace:", do_replace)

	if do_replace and app == 'w3school' then 
		ngx.log(ngx.INFO, "add w3school style ..")
		arg = ngx.re.sub(arg, "Change Password", "PWD", "jom")
		return arg
    elseif do_replace and app == "openresty" then 
        ngx.log(ngx.INFO, "add openresty style ..")
        arg = ngx.re.sub(arg, "Change Password", "PWD", "jom")
        return arg
	end
end

return _M