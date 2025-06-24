local Http = require('coro-http')
local HTTPRequest = Http.request

local json = require('json')

local METHODS = {
    GET = true,
    POST = true
}

local function QueryParams(Params) -- {Name = Value, ...}
    local QueryString = "?"

    for ParamName, ParamValue in next, Params do
        if ParamValue ~= nil then
            QueryString = QueryString .. ParamName .. "=" .. ParamValue .. "&"
        end
    end

    return string.sub(QueryString, 1, -2) -- Remove last character (will always be a "&")
end

local function CreateHeaders(Headers) -- {Name = Value, ...}
    local RequestHeaders = {}

    for HeaderName, HeaderValue in next, Headers do
        RequestHeaders[#RequestHeaders + 1] = { HeaderName, HeaderValue }
    end

    return RequestHeaders
end

local function TryDecodeJson(Body)
    local Success, Result = pcall(json.decode, Body)
    if not Success then
        return Body
    end
    return Result
end

local function NormalizeHeaders(Response)
    for Index, Header in next, Response do
        if type(Header) == "table" and #Header == 2 then
            local HeaderName, HeaderValue = table.unpack(Header)
            Response[HeaderName] = HeaderValue
            Response[Index] = nil
        end
    end
end

local function Request(Method, Url, Params, Headers, Callback)
    if not METHODS[Method] then
        error("[HTTP] Method " .. Method .. " is not supported.")
    end

    if type(Url) ~= "string" then
        error("[HTTP] Url is not a string")
    end

    local QueryString = QueryParams(Params)       -- at worse (I think), this is an empty string (which cannot mess up the request)

    local RequestHeaders = CreateHeaders(Headers) -- At worse, this will just be an empty table (which cannot mess up the request)

    local RequestUrl = Url .. QueryString
    print(RequestUrl)

    if Callback and type(Callback) == "function" then
        return coroutine.wrap(function()
            local Response, Body = HTTPRequest(Method, RequestUrl, RequestHeaders)
            NormalizeHeaders(Response)
            Callback(Response, TryDecodeJson(Body))
        end)
    else
        local Response, Body = HTTPRequest(Method, RequestUrl, RequestHeaders)
        NormalizeHeaders(Response)
        return Response, TryDecodeJson(Body)
    end
end

return {
    Request = Request
}
