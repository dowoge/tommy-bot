local Http = require('coro-http')
local HTTPRequest = Http.request

local Timer = require("timer")
local Sleep = Timer.sleep

local function Wait(n)
    return Sleep(n * 1000)
end

local json = require('json')

local CacheStore = {}
local CacheFilePath = "./HTTPCache.json"
local CacheSaveIntervalSeconds = 300
local LastCacheSaveAt = 0
local CacheSavePending = false
local RateLimitState = {
    Server = {},
    Custom = {}
}

local function PruneCache()
    local NowTime = os.time()
    for Key, Entry in next, CacheStore do
        if not Entry or not Entry.ExpiresAt or Entry.ExpiresAt <= NowTime then
            CacheStore[Key] = nil
        end
    end
end

local function LoadCacheFromFile()
    local FileHandle = io.open(CacheFilePath, "r")
    if not FileHandle then return end
    local Contents = FileHandle:read("*a")
    FileHandle:close()

    if not Contents or #Contents == 0 then return end
    local Success, Decoded = pcall(json.decode, Contents)
    if not Success or type(Decoded) ~= "table" then return end

    if #Decoded > 0 then
        CacheStore = {}
        for _, Entry in next, Decoded do
            if Entry and Entry.Key then
                CacheStore[Entry.Key] = {
                    Headers = Entry.Headers or {},
                    Body = Entry.Body,
                    BodyIsJson = Entry.BodyIsJson,
                    ExpiresAt = Entry.ExpiresAt,
                    ETag = Entry.ETag
                }
            end
        end
    else
        CacheStore = {}
    end
    PruneCache()
end

local function SaveCacheToFile(Force)
    local NowTime = os.time()
    if not Force and (NowTime - LastCacheSaveAt) < 5 then
        if not CacheSavePending then
            CacheSavePending = true
            Timer.setTimeout(5000, function()
                CacheSavePending = false
                SaveCacheToFile(true)
            end)
        end
        return
    end
    PruneCache()
    local Serializable = {}
    for Key, Entry in next, CacheStore do
        Serializable[#Serializable + 1] = {
            Key = Key,
            Headers = Entry.Headers,
            Body = Entry.Body,
            BodyIsJson = Entry.BodyIsJson,
            ExpiresAt = Entry.ExpiresAt,
            ETag = Entry.ETag
        }
    end
    local Success, Encoded = pcall(json.encode, Serializable)
    if not Success then return end
    local FileHandle = io.open(CacheFilePath, "w+")
    if not FileHandle then return end
    FileHandle:write(Encoded)
    FileHandle:close()
    LastCacheSaveAt = NowTime
end

local function StartCachePersistence()
    LoadCacheFromFile()
    if CacheSaveIntervalSeconds and CacheSaveIntervalSeconds > 0 then
        Timer.setInterval(CacheSaveIntervalSeconds * 1000, SaveCacheToFile)
    end
end

local METHODS = {
    GET = true,
    POST = true
}

local function NormalizeQueryValue(Value)
    local ValueType = type(Value)
    if ValueType == "number" then
        local AsString = tostring(Value)
        if AsString:find("[eE]") then
            return string.format("%.0f", Value)
        end
        return AsString
    end
    if ValueType == "string" then
        if Value:find("[eE]") then
            local NumericValue = tonumber(Value)
            if NumericValue then
                return string.format("%.0f", NumericValue)
            end
        end
        return Value
    end
    if ValueType == "boolean" then
        return Value and "true" or "false"
    end
    if Value == nil then
        return nil
    end
    return tostring(Value)
end

local function QueryParams(Params) -- {Name = Value, ...}
    if not Params then return "" end
    local QueryString = "?"

    local Keys = {}
    for ParamName in next, Params do
        Keys[#Keys + 1] = ParamName
    end
    table.sort(Keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, ParamName in ipairs(Keys) do
        local ParamValue = Params[ParamName]
        if ParamValue ~= nil then
            if type(ParamValue) == "table" then
                local Parts = {}
                if #ParamValue > 0 then
                    for _, Item in ipairs(ParamValue) do
                        local Normalized = NormalizeQueryValue(Item)
                        if Normalized ~= nil then
                            Parts[#Parts + 1] = Normalized
                        end
                    end
                else
                    for _, Item in next, ParamValue do
                        local Normalized = NormalizeQueryValue(Item)
                        if Normalized ~= nil then
                            Parts[#Parts + 1] = Normalized
                        end
                    end
                end
                ParamValue = table.concat(Parts, ",")
            else
                ParamValue = NormalizeQueryValue(ParamValue)
            end
            if ParamValue ~= nil then
                QueryString = QueryString .. tostring(ParamName) .. "=" .. tostring(ParamValue) .. "&"
            end
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
    local function QuoteIdNumbers(JsonString)
        if type(JsonString) ~= "string" then
            return JsonString
        end
        return JsonString:gsub("\"([%w_]+)\"%s*:%s*(%d+)", function(Key, NumberValue)
            local LowerKey = Key:lower()
            if LowerKey == "id" or LowerKey:sub(-3) == "_id" or LowerKey:sub(-2) == "id" then
                return "\"" .. Key .. "\":\"" .. NumberValue .. "\""
            end
            return "\"" .. Key .. "\":" .. NumberValue
        end)
    end

    local PreparedBody = QuoteIdNumbers(Body)
    local Success, Result = pcall(json.decode, PreparedBody)
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

local function Now()
    return os.time()
end

local function GetUtcOffset()
    return os.difftime(os.time(os.date("!*t")), os.time())
end

local function ParseHttpDate(DateString)
    if type(DateString) ~= "string" then return nil end
    local _, Day, MonthStr, Year, Hour, Min, Sec = DateString:match("^(%a+), (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT$")
    if not Day then return nil end
    local Months = {
        Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
        Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
    }
    local Month = Months[MonthStr]
    if not Month then return nil end
    local LocalTime = os.time({
        year = tonumber(Year),
        month = Month,
        day = tonumber(Day),
        hour = tonumber(Hour),
        min = tonumber(Min),
        sec = tonumber(Sec)
    })
    return LocalTime + GetUtcOffset()
end

local function NextMinuteBoundary(TimeValue)
    local TimeNow = TimeValue or Now()
    return TimeNow - (TimeNow % 60) + 60
end

local function NextDayBoundary(TimeValue)
    local TimeNow = TimeValue or Now()
    local Utc = os.date("!*t", TimeNow)
    Utc.hour = 0
    Utc.min = 0
    Utc.sec = 0
    Utc.day = Utc.day + 1
    return os.time(Utc) + GetUtcOffset()
end

local function NextMonthBoundary(TimeValue)
    local TimeNow = TimeValue or Now()
    local Utc = os.date("!*t", TimeNow)
    Utc.hour = 0
    Utc.min = 0
    Utc.sec = 0
    Utc.day = 1
    if Utc.month == 12 then
        Utc.month = 1
        Utc.year = Utc.year + 1
    else
        Utc.month = Utc.month + 1
    end
    return os.time(Utc) + GetUtcOffset()
end

local function GetHeaderValue(Headers, Name)
    if not Headers or not Name then return nil end
    if Headers[Name] then return Headers[Name] end
    local LowerName = tostring(Name):lower()
    for Key, Value in next, Headers do
        if type(Key) == "string" and Key:lower() == LowerName then
            return Value
        end
    end
    return nil
end

local function CopyTable(Source)
    if not Source then return nil end
    local Copy = {}
    for Key, Value in next, Source do
        Copy[Key] = Value
    end
    return Copy
end

local function GetHostFromUrl(Url)
    if type(Url) ~= "string" then return nil end
    local Host = Url:match("^https?://([^/]+)") or Url:match("^([^/]+)")
    if Host then
        Host = Host:gsub(":%d+$", "")
        return Host:lower()
    end
    return nil
end

local function GetCacheTtlFromHeaders(Headers)
    local CacheControl = GetHeaderValue(Headers, "cache-control")
    if CacheControl and type(CacheControl) == "string" then
        local Lower = CacheControl:lower()
        if Lower:find("no%-store") or Lower:find("no%-cache") or Lower:find("max%-age=0") then
            return 0
        end
        local MaxAge = Lower:match("max%-age=(%d+)")
        if MaxAge then
            return tonumber(MaxAge)
        end
    end

    local Expires = GetHeaderValue(Headers, "expires")
    local ExpiresAt = ParseHttpDate(Expires)
    if ExpiresAt then
        local Ttl = ExpiresAt - Now()
        if Ttl < 0 then
            return 0
        end
        return Ttl
    end

    return nil
end

local function UpdateServerRateLimit(Domain, Headers)
    if not Domain or not Headers then return end
    local Remaining = tonumber(GetHeaderValue(Headers, "x-ratelimit-remaining"))
    local Reset = tonumber(GetHeaderValue(Headers, "x-ratelimit-reset"))
    local ResetAfter = tonumber(GetHeaderValue(Headers, "x-ratelimit-reset-after"))
    local Limit = tonumber(GetHeaderValue(Headers, "x-ratelimit-limit"))
    local BurstLimit = tonumber(GetHeaderValue(Headers, "x-rate-limit-burst"))
    local DailyLimit = tonumber(GetHeaderValue(Headers, "x-rate-limit-daily"))
    local MonthlyLimit = tonumber(GetHeaderValue(Headers, "x-rate-limit-monthly"))
    local RetryAfter = tonumber(GetHeaderValue(Headers, "retry-after"))

    local State = RateLimitState.Server[Domain] or {}
    State.Windows = State.Windows or {}

    local function SetServerWindowLimit(Key, WindowLimit, WindowSeconds, Align)
        if not WindowLimit then return end
        local Window = State.Windows[Key] or {}
        if not Window.Limit or Window.Limit ~= WindowLimit or Window.Window ~= WindowSeconds then
            Window.Limit = WindowLimit
            Window.Window = WindowSeconds
            Window.Align = Align
            Window.Remaining = WindowLimit
            if Align == "minute" then
                Window.ResetAt = NextMinuteBoundary(Now())
            elseif Align == "day" then
                Window.ResetAt = NextDayBoundary(Now())
            elseif Align == "month" then
                Window.ResetAt = NextMonthBoundary(Now())
            else
                Window.ResetAt = Now() + WindowSeconds
            end
        elseif not Window.Remaining or not Window.ResetAt then
            Window.Remaining = WindowLimit
            if Align == "minute" then
                Window.ResetAt = NextMinuteBoundary(Now())
            elseif Align == "day" then
                Window.ResetAt = NextDayBoundary(Now())
            elseif Align == "month" then
                Window.ResetAt = NextMonthBoundary(Now())
            else
                Window.ResetAt = Now() + WindowSeconds
            end
        end
        State.Windows[Key] = Window
    end

    SetServerWindowLimit("burst", BurstLimit, 60, "minute")
    SetServerWindowLimit("daily", DailyLimit, 86400, "day")
    SetServerWindowLimit("monthly", MonthlyLimit, 2592000, "month")

    if Limit then
        State.Limit = Limit
    end
    if Remaining then
        State.Remaining = Remaining
    end

    local NowTime = Now()
    if ResetAfter then
        State.ResetAt = NowTime + ResetAfter
    elseif Reset then
        if Reset > (NowTime + 60) then
            State.ResetAt = Reset
        else
            State.ResetAt = NowTime + Reset
        end
    end

    if RetryAfter then
        State.Remaining = 0
        State.ResetAt = NowTime + RetryAfter
    end

    if State.ResetAt or State.Remaining then
        RateLimitState.Server[Domain] = State
    end
end

local function EnforceRateLimit(Domain, Options)
    if not Domain or (Options and Options.ignoreRateLimit) then return end
    local NowTime = Now()
    local Server = RateLimitState.Server[Domain]
    local Custom = RateLimitState.Custom[Domain]

    local function GetWait(State)
        if not State then return 0 end
        if State.ResetAt and State.Remaining and State.Remaining <= 0 then
            if State.ResetAt > NowTime then
                return State.ResetAt - NowTime
            end
        end
        return 0
    end

    local function GetWindowWait(Windows)
        if not Windows then return 0 end
        local MaxWait = 0
        for _, Window in next, Windows do
            if Window.ResetAt and Window.Remaining and Window.Remaining <= 0 then
                if Window.ResetAt > NowTime then
                    local WaitSeconds = Window.ResetAt - NowTime
                    if WaitSeconds > MaxWait then
                        MaxWait = WaitSeconds
                    end
                end
            end
        end
        return MaxWait
    end

    local WaitSeconds = math.max(GetWait(Server), GetWait(Custom), GetWindowWait(Server and Server.Windows))
    if WaitSeconds > 0 then
        Wait(WaitSeconds)
    end
end

local function MarkRateLimited(Domain, Headers)
    if not Domain then return end
    local State = RateLimitState.Server[Domain]
    if not State then return end
    local NowTime = Now()
    local RetryAfter = tonumber(GetHeaderValue(Headers, "retry-after"))

    if State.Remaining ~= nil then
        State.Remaining = 0
    end

    if RetryAfter then
        State.ResetAt = NowTime + RetryAfter
    end

    if State.Windows then
        for _, Window in next, State.Windows do
            Window.Remaining = 0
            if RetryAfter then
                Window.ResetAt = NowTime + RetryAfter
            elseif not Window.ResetAt or Window.ResetAt <= NowTime then
                if Window.Align == "minute" then
                    Window.ResetAt = NextMinuteBoundary(NowTime)
                elseif Window.Align == "day" then
                    Window.ResetAt = NextDayBoundary(NowTime)
                elseif Window.Align == "month" then
                    Window.ResetAt = NextMonthBoundary(NowTime)
                else
                    Window.ResetAt = NowTime + Window.Window
                end
            end
        end
    end
end

local function GetRateLimitWaitSeconds(Domain, Headers)
    local RetryAfter = tonumber(GetHeaderValue(Headers, "retry-after"))
    if RetryAfter then return RetryAfter end
    if not Domain then return 0 end
    local NowTime = Now()
    local Server = RateLimitState.Server[Domain]
    if not Server then return 0 end

    local function GetWait(State)
        if not State then return 0 end
        if State.ResetAt and State.Remaining and State.Remaining <= 0 then
            if State.ResetAt > NowTime then
                return State.ResetAt - NowTime
            end
        end
        return 0
    end

    local function GetWindowWait(Windows)
        if not Windows then return 0 end
        local MaxWait = 0
        for _, Window in next, Windows do
            if Window.ResetAt and Window.Remaining and Window.Remaining <= 0 then
                if Window.ResetAt > NowTime then
                    local WaitSeconds = Window.ResetAt - NowTime
                    if WaitSeconds > MaxWait then
                        MaxWait = WaitSeconds
                    end
                end
            end
        end
        return MaxWait
    end

    return math.max(GetWait(Server), GetWindowWait(Server.Windows))
end

local function ConsumeServerWindowLimits(Domain)
    local State = RateLimitState.Server[Domain]
    if not State or not State.Windows then return end
    local NowTime = Now()
    for _, Window in next, State.Windows do
        if Window.Limit then
            if not Window.ResetAt or NowTime >= Window.ResetAt then
                Window.Remaining = Window.Limit
                if Window.Align == "minute" then
                    Window.ResetAt = NextMinuteBoundary(NowTime)
                elseif Window.Align == "day" then
                    Window.ResetAt = NextDayBoundary(NowTime)
                elseif Window.Align == "month" then
                    Window.ResetAt = NextMonthBoundary(NowTime)
                else
                    Window.ResetAt = NowTime + Window.Window
                end
            end
            Window.Remaining = Window.Remaining - 1
        end
    end
end

local function ConsumeCustomRateLimit(Domain)
    local State = RateLimitState.Custom[Domain]
    if not State then return end
    local NowTime = Now()
    if not State.ResetAt or NowTime >= State.ResetAt then
        State.Remaining = State.Limit
        State.ResetAt = NowTime + State.Window
    end
    State.Remaining = State.Remaining - 1
end

local function CanUseCache(Method, Options, RequestHeaders)
    if Method ~= "GET" then return false end
    if Options and Options.noCache then return false end
    local RequestCacheControl = GetHeaderValue(RequestHeaders, "cache-control")
    if RequestCacheControl and type(RequestCacheControl) == "string" then
        local Lower = RequestCacheControl:lower()
        if Lower:find("no%-store") or Lower:find("no%-cache") then
            return false
        end
    end
    return true
end

local function GetCacheKey(Method, RequestUrl, Options)
    if Options and Options.cacheKey then
        return tostring(Options.cacheKey)
    end
    return Method .. ":" .. RequestUrl
end

local function SetCache(Key, Headers, Body, Options)
    if not Key then return end
    local Ttl = nil
    if Options and Options.cacheTtl then
        Ttl = tonumber(Options.cacheTtl)
    end
    if not Ttl then
        Ttl = GetCacheTtlFromHeaders(Headers)
    end
    if not Ttl or Ttl <= 0 then
        return
    end
    local Etag = GetHeaderValue(Headers, "etag")
    local CachedBody = Body
    local BodyIsJson = false
    if type(Body) == "table" then
        local Success, Encoded = pcall(json.encode, Body)
        if Success then
            CachedBody = Encoded
            BodyIsJson = true
        else
            CachedBody = tostring(Body)
            BodyIsJson = false
        end
    end
    CacheStore[Key] = {
        Headers = CopyTable(Headers),
        Body = CachedBody,
        BodyIsJson = BodyIsJson,
        ExpiresAt = Now() + Ttl,
        ETag = Etag
    }
    -- print("Cached:", Key)
    SaveCacheToFile(false)
end

local function GetCached(Key)
    if not Key then return nil end
    local Entry = CacheStore[Key]
    if not Entry then return nil end
    if Entry.ExpiresAt and Entry.ExpiresAt > Now() then
        local HeadersCopy = CopyTable(Entry.Headers) or {}
        HeadersCopy.Cached = true
        if Entry.BodyIsJson then
            return HeadersCopy, TryDecodeJson(Entry.Body)
        end
        return HeadersCopy, Entry.Body
    end
    return nil
end

local function GetExpiredCache(Key)
    if not Key then return nil end
    return CacheStore[Key]
end

local function SetCustomRateLimit(Domain, Limit, WindowSeconds)
    if type(Domain) ~= "string" then
        error("[HTTP] Domain must be a string")
    end
    Limit = tonumber(Limit)
    WindowSeconds = tonumber(WindowSeconds)
    if not Limit or not WindowSeconds then
        error("[HTTP] Limit and WindowSeconds must be numbers")
    end
    RateLimitState.Custom[Domain:lower()] = {
        Limit = Limit,
        Window = WindowSeconds,
        Remaining = Limit,
        ResetAt = Now() + WindowSeconds
    }
end

local function ClearCustomRateLimit(Domain)
    if Domain then
        RateLimitState.Custom[Domain:lower()] = nil
        return
    end
    RateLimitState.Custom = {}
end

local function ClearCache(Key)
    if Key then
        CacheStore[Key] = nil
        return
    end
    CacheStore = {}
end

local function Request(Method, Url, Params, RequestHeaders, RequestBody, Callback, MaxRetries, Options)
    if not METHODS[Method] then
        error("[HTTP] Method " .. Method .. " is not supported.")
    end

    if type(Url) ~= "string" then
        error("[HTTP] Url is not a string")
    end

    local function IsOptionsTable(Value)
        return type(Value) == "table" and (
            Value.CacheTTL or Value.CacheTtl or Value.cacheTtl or Value.NoCache or Value.noCache
            or Value.CacheKey or Value.cacheKey or Value.WaitUntilSuccess or Value.waitUntilSuccess
            or Value.IgnoreRateLimit or Value.ignoreRateLimit or Value.MaxRetries or Value.maxRetries
        )
    end

    if Options == nil then
        if IsOptionsTable(Callback) then
            Options = Callback
            Callback = nil
        elseif IsOptionsTable(MaxRetries) then
            Options = MaxRetries
            MaxRetries = nil
        elseif IsOptionsTable(RequestBody) and Method == "GET" then
            Options = RequestBody
            RequestBody = nil
        elseif IsOptionsTable(RequestHeaders) then
            Options = RequestHeaders
            RequestHeaders = nil
        elseif IsOptionsTable(Params) then
            Options = Params
            Params = nil
        end
    end

    -- options detection handled above

    if Options then
        Options.cacheTtl = Options.cacheTtl or Options.CacheTtl or Options.CacheTTL
        Options.noCache = Options.noCache or Options.NoCache
        Options.cacheKey = Options.cacheKey or Options.CacheKey
        Options.waitUntilSuccess = Options.waitUntilSuccess or Options.WaitUntilSuccess
        Options.ignoreRateLimit = Options.ignoreRateLimit or Options.IgnoreRateLimit
        Options.maxRetries = Options.maxRetries or Options.MaxRetries
    end

    if type(RequestBody) == "table" then
        RequestBody = json.encode(RequestBody)
    end

    local QueryString = QueryParams(Params)                -- at worse (I think), this is an empty string (which cannot mess up the request)

    local MutableHeaders = CopyTable(RequestHeaders) or {}
    local FormattedHeaders = CreateHeaders(MutableHeaders) -- at worse, this will just be an empty table (which cannot mess up the request)

    local RequestUrl = Url .. QueryString
    -- print(RequestUrl)

    MaxRetries = MaxRetries or (Options and Options.maxRetries) or 10
    if Options and Options.waitUntilSuccess then
        MaxRetries = math.huge
    end

    local function DoRequest()
        local Attempt = 0
        local Delay = 2
        local Domain = GetHostFromUrl(RequestUrl)

        local UseCache = CanUseCache(Method, Options, MutableHeaders)
        local CacheKey = nil
        local CachedHeaders, CachedBody = nil, nil

        if UseCache then
            CacheKey = GetCacheKey(Method, RequestUrl, Options)
            CachedHeaders, CachedBody = GetCached(CacheKey)
            if CachedHeaders then
                -- print("Attempt:", 1, "Status code:", "CACHE")
                return CachedHeaders, CachedBody
            end

            local ExpiredEntry = GetExpiredCache(CacheKey)
            if ExpiredEntry and ExpiredEntry.ETag then
                MutableHeaders["If-None-Match"] = ExpiredEntry.ETag
                FormattedHeaders = CreateHeaders(MutableHeaders)
            end
        end

        while Attempt <= MaxRetries do
            EnforceRateLimit(Domain, Options)
            local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
            NormalizeHeaders(Headers)
            -- print("Attempt:", Attempt + 1, "Status code:", Headers.code)

            local ResponseCode = tonumber(Headers.code)

            if Domain then
                UpdateServerRateLimit(Domain, Headers)
                if not (Options and Options.ignoreRateLimit) then
                    ConsumeCustomRateLimit(Domain)
                    ConsumeServerWindowLimits(Domain)
                end
            end

            if ResponseCode == 304 and CacheKey then
                local ExpiredEntry = GetExpiredCache(CacheKey)
                if ExpiredEntry then
                    local HeadersCopy = CopyTable(ExpiredEntry.Headers) or {}
                    HeadersCopy.Cached = true
                    if ExpiredEntry.BodyIsJson then
                        return HeadersCopy, TryDecodeJson(ExpiredEntry.Body)
                    end
                    return HeadersCopy, ExpiredEntry.Body
                end
            end

            if ResponseCode == 429 and Attempt < MaxRetries then
                MarkRateLimited(Domain, Headers)
                local WaitSeconds = GetRateLimitWaitSeconds(Domain, Headers)
                if WaitSeconds and WaitSeconds > 0 then
                    -- print("Rate limited, retrying in " .. WaitSeconds .. " seconds...")
                    Wait(WaitSeconds)
                else
                    -- print("Rate limited, retrying in " .. Delay .. " seconds...")
                    Wait(Delay)
                    Delay = Delay * 2 -- exponential back-off
                end
                Attempt = Attempt + 1
            else
                -- we will assume <400 = success i guess
                if ResponseCode and ResponseCode < 400 then
                    local DecodedBody = TryDecodeJson(Body)
                    if UseCache and CacheKey then
                        SetCache(CacheKey, Headers, DecodedBody, Options)
                    end
                    return Headers, DecodedBody
                end

                Attempt = Attempt + 1
                if Attempt > MaxRetries then
                    break
                end

                -- print("Request failed, retrying in " .. Delay .. " seconds...")
                Wait(Delay)
                Delay = Delay * 2 -- exponential back-off
            end
        end

        local Headers, Body = HTTPRequest(Method, RequestUrl, FormattedHeaders, RequestBody)
        NormalizeHeaders(Headers)
        local ResponseCode = tonumber(Headers.code)
        local DecodedBody = TryDecodeJson(Body)
        if ResponseCode and ResponseCode < 400 and UseCache and CacheKey then
            SetCache(CacheKey, Headers, DecodedBody, Options)
        end
        return Headers, DecodedBody
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

StartCachePersistence()

return {
    Request = Request,
    SetCustomRateLimit = SetCustomRateLimit,
    ClearCustomRateLimit = ClearCustomRateLimit,
    ClearCache = ClearCache
}
