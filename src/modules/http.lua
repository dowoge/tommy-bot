local http = require('coro-http')
local json = require('json')
function wait(n)c=os.clock t=c()while c()-t<=n do end;end
--[[
1: method
2: url
3: headers
4: body
5: options]]
local STRAFES_NET_RATELIMIMT = {
    HOUR = 3000,
    MINUTE = 100,
}
local remaining_timeout = 0
local function request(method,url,headers,body,options)
    local headers,body=http.request(method,url,headers,body,options)
    local rbody=json.decode(body)
    local rheaders={}
    for _,t in pairs(headers) do
        if type(t)=='table' then
            rheaders[t[1]]=t[2]
        else
            rheaders[_]=t
        end
    end
    local remaining = tonumber(rheaders['RateLimit-Remaining'])
    local remaining_hour = tonumber(rheaders['X-RateLimit-Remaining-Hour'])
    local reset = tonumber(rheaders['RateLimit-Reset'])
    local retry_after = tonumber(rheaders['Retry-After'])
    if remaining and reset then
        local t = remaining==0 and reset or .38
        if retry_after then t = retry_after end
        wait(t)
    end
    return rbody,rheaders
end

-- local urlparamencode=function()
return request