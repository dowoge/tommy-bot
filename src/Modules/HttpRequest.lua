local Http = require('coro-http')
local HTTPRequest = Http.request

local Timer = require("timer")
local Sleep = Timer.sleep

local function Wait(n)
    return Sleep(n * 1000)
end

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

local function Request(Method, Url, Params, RequestHeaders, RequestBody, Callback, MaxRetries)
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

    local FormattedHeaders = CreateHeaders(RequestHeaders) -- at worse, this will just be an empty table (which cannot mess up the request)

    local RequestUrl = Url .. QueryString
    print(RequestUrl)

    MaxRetries = MaxRetries or 10

    local function DoRequest()
        local Attempt = 0
        local Delay = 2

        while Attempt <= MaxRetries do
            local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
            NormalizeHeaders(Headers)
            print("Attempt:", Attempt + 1, "Status code:", Headers.code)

            -- we will assume <400 = success i guess
            if Headers.code and Headers.code < 400 then
                return Headers, TryDecodeJson(Body)
            end

            Attempt = Attempt + 1
            if Attempt > MaxRetries then
                break
            end

            print("Request failed, retrying in " .. Delay .. " seconds...")
            Wait(Delay)
            Delay = Delay * 2 -- exponential back-off
        end

        local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
        NormalizeHeaders(Headers)
        return Headers, TryDecodeJson(Body)
    end

    if Callback and type(Callback) == "function" then
        return coroutine.wrap(function()
            local Headers, DecodedBody = DoRequest()
            Callback(Headers, DecodedBody)
        end)
    else
        return DoRequest()
    end
end

return {
    Request = Request
}
