local http = require('coro-http')
local json = require('json')
function wait(n)c=os.clock t=c()while c()-t<=n do end;end
local request=function(method,url,headers,params)
    local headers,body=http.request(method,url,headers or {{"Content-Type", "application/json"}},params)
    body=json.decode(body)
    local rheaders={}
    for _,t in pairs(headers) do
        if type(t)=='table' then
            rheaders[t[1]]=t[2]
        end
    end
    local remaining = tonumber(rheaders['RateLimit-Remaining'])
    local reset = tonumber(rheaders['RateLimit-Reset'])
    if remaining and reset then
        local t = remaining==0 and reset or .38
        wait(t)
    end
    return body,rheaders
end

-- local urlparamencode=function()
return request