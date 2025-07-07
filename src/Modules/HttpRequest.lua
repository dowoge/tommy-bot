local Http = require('coro-http')
local HTTPRequest = Http.request

local json = require('json')

local METHODS = {
    GET = true,
    POST = true
}

local function QueryParams(Params) -- {Name = Value, ...}
    if not Params then return "" end
    local QueryString = "?"

    for ParamName, ParamValue in next, Params do
        if ParamValue ~= nil then
            QueryString = QueryString .. tostring(ParamName) .. "=" .. tostring(ParamValue) .. "&"
        end
    end

    return string.sub(QueryString, 1, -2) -- Remove last character (will always be a "&")
end

local function CreateHeaders(Headers) -- {Name = Value, ...}
    if not Headers then return {} end
    local RequestHeaders = {}

    for HeaderName, HeaderValue in next, Headers do
        RequestHeaders[#RequestHeaders + 1] = { tostring(HeaderName), tostring(HeaderValue) }
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

local function Request(Method, Url, Params, RequestHeaders, RequestBody, Callback)
    if not METHODS[Method] then
        error("[HTTP] Method " .. Method .. " is not supported.")
    end

    if type(Url) ~= "string" then
        error("[HTTP] Url is not a string")
    end

    if type(RequestBody) == "table" then
        RequestBody = json.encode(RequestBody)
    end

    local QueryString = QueryParams(Params)                -- at worse (I think), this is an empty string (which cannot mess up the request)

    local FormattedHeaders = CreateHeaders(RequestHeaders) -- At worse, this will just be an empty table (which cannot mess up the request)

    local RequestUrl = Url .. QueryString
    print(RequestUrl)

    if Callback and type(Callback) == "function" then
        return coroutine.wrap(function()
            local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
            NormalizeHeaders(Headers)
            print(Headers.code)
            Callback(Headers, TryDecodeJson(Body))
        end)
    else
        local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
        NormalizeHeaders(Headers)
        print(Headers.code)
        return Headers, TryDecodeJson(Body)
    end
end

return {
    Request = Request
}
