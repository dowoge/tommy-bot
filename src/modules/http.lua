local http = require('coro-http')
local json = require('json')
function wait(n)c=os.clock t=c()while c()-t<=n do end;end
--[[
1: method
2: url
3: headers
4: body
5: options]]
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
    local reset = tonumber(rheaders['RateLimit-Reset'])
    if remaining and reset then
        local t = remaining==0 and reset or .38
        wait(t)
    end
    return rbody,rheaders
end

-- local urlparamencode=function()
return request