local HttpRequest = require("./HttpRequest.lua")
local Request = HttpRequest.Request
local APIKeys = require("./APIKeys.lua")

local RankConstants = require("./RankConstants.lua")

local RequestHeaders = {
    ["Content-Type"] = "application/json",
    ["X-API-Key"] = APIKeys.StrafesNET
}

local function L1Copy(t, b)
    b = b or {}
    for x, y in next, t do b[x] = y end
    return b
end

local function Round(Number, Digit)
    return tonumber(string.format('%.' .. (Digit or 0) .. 'f', Number))
end

local function SafeNumberToString(Value)
    if Value == nil then return nil end
    local ValueType = type(Value)
    if ValueType == "string" then
        return Value
    end
    if ValueType == "number" then
        local AsString = tostring(Value)
        if AsString:find("[eE]") then
            return string.format("%.0f", Value)
        end
        return AsString
    end
    return tostring(Value)
end

local function NormalizeMap(Map)
    if not Map then return Map end
    Map.id = SafeNumberToString(Map.id)
    return Map
end

local function NormalizeTime(Time)
    if not Time then return Time end
    Time.id = SafeNumberToString(Time.id)
    if Time.map then
        Time.map = NormalizeMap(Time.map)
    end
    return Time
end

local function FormatHelper(Value, Width)
    Value = tostring(Value)
    while #Value < Width do
        Value = "0" .. Value
    end
    return Value
end

local function FormatTime(Milliseconds)
    if Milliseconds > 86400000 then
        return ">1 day"
    end

    local Ms = FormatHelper(Milliseconds % 1000, 3)
    local Sec = FormatHelper(math.floor(Milliseconds / 1000) % 60, 2)
    local Min = FormatHelper(math.floor(Milliseconds / (1000 * 60)) % 60, 2)
    local Hour = FormatHelper(math.floor(Milliseconds / (1000 * 60 * 60)) % 24, 2)

    if Hour == "00" then
        return Min .. ":" .. Sec .. "." .. Ms
    end

    return Hour .. ":" .. Min .. ":" .. Sec
end

local function FormatSkill(Skill)
    return Round(Skill * 100, 3) .. "%"
end

local STRAFESNET_API_URL = "https://api.strafes.net/api/v1/"
local STRAFESNET_MAP_API_URL = "https://maps.strafes.net/public-api/v1/"
local FIVEMAN_API_URL = 'https://api.fiveman1.net/v1/'
local ROBLOX_API_URL = 'https://users.roblox.com/v1/'
local ROBLOX_BADGES_API = 'https://badges.roblox.com/v1/'
local ROBLOX_PRESENCE_URL = 'https://presence.roblox.com/v1/'
local ROBLOX_THUMBNAIL_URL = 'https://thumbnails.roblox.com/v1/'
local ROBLOX_INVENTORY_API = 'https://inventory.roblox.com/v1/'
local ROBLOX_GROUPS_ROLES_URL = 'https://groups.roblox.com/v2/users/%s/groups/roles'

ROBLOX_THUMBNAIL_SIZES = {
    [48] = '48x48',
    [50] = '50x50',
    [60] = '60x60',
    [75] = '75x75',
    [100] = '100x100',
    [110] = '110x110',
    [150] = '150x150',
    [180] = '180x180',
    [352] = '352x352',
    [420] = '420x420',
    [720] = '720x720'
}
ROBLOX_THUMBNAIL_TYPES = {
    AVATAR = 'avatar',
    BUST = 'avatar-bust',
    HEADSHOT = 'avatar-headshot'
}

local STRAFESNET_API_ENDPOINTS = {
    MAPS = {
        LIST = "map",
        GET = "map/%d"
    },
    RANKS = {
        LIST = "rank"
    },
    TIMES = {
        LIST = "time",
        WORLD_RECORD = {
            GET = "time/worldrecord"
        },
        PLACEMENT = {
            GET = "time/placement"
        },
        GET = "time/%d"
    },
    USERS = {
        LIST = "user",
        GET = "user/%d",
        RANKS = {
            GET = "user/%d/rank"
        }
    }
}

local StrafesNET = {}

local GAME_IDS = {
    BHOP = 1,
    SURF = 2,
    -- FLY_TRIALS = 5
}
local GAME_IDS_STRING = {
    "Bhop",
    "Surf",
    -- [5] = "Fly Trials"
}

local STYLES = {
    AUTOHOP = 1,
    SCROLL = 2,
    SIDEWAYS = 3,
    HSW = 4,
    WONLY = 5,
    AONLY = 6,
    BACKWARDS = 7,
    FASTE = 8,
    -- LOW_GRAVITY = 14
}
local STYLES_STRING = {
    "Autohop",
    "Scroll",
    "Sideways",
    "Half-Sideways",
    "W-Only",
    "A-Only",
    "Backwards",
    "Faste",
    -- [14] = "Low Gravity"
}
local BHOP_STYLES = {STYLES.AUTOHOP, STYLES.SCROLL, STYLES.SIDEWAYS, STYLES.HSW, STYLES.WONLY, STYLES.AONLY, STYLES.BACKWARDS, STYLES.FASTE}
local SURF_STYLES = {STYLES.AUTOHOP, STYLES.SIDEWAYS, STYLES.HSW, STYLES.WONLY, STYLES.AONLY, STYLES.BACKWARDS, STYLES.FASTE}

StrafesNET.SafeNumberToString = SafeNumberToString

StrafesNET.FormatTime = FormatTime
StrafesNET.FormatSkill = FormatSkill

StrafesNET.GameIds = GAME_IDS
StrafesNET.GameIdsString = GAME_IDS_STRING
StrafesNET.Styles = STYLES
StrafesNET.StylesString = STYLES_STRING
StrafesNET.BhopStyles = BHOP_STYLES
StrafesNET.SurfStyles = SURF_STYLES

function StrafesNET.CalculatePoints(Rank, Count)
    local ExpMagic2 = math.exp(RankConstants.Magic2)
    local Num1 = ExpMagic2 - 1.0
    local ExpDenomExp = math.max(-700.0, -RankConstants.Magic2 * Count)
    local Denom1 = 1.0 - math.exp(ExpDenomExp)

    local ExpRankExp = math.max(-700.0, -RankConstants.Magic2 * Rank)
    local ExpRank = math.exp(ExpRankExp)

    local Part1 = RankConstants.Magic1 * (Num1 / Denom1) * ExpRank
    local Part2 = (1.0 - RankConstants.Magic1) * (1.0 + 2.0 * (Count - Rank)) / (Count * Count)

    return Part1 + Part2
end

function StrafesNET.CalculateSkill(Rank, Count)
    local Denominator = Count - 1
    if Denominator == 0 then
        return 0
    else
        return (Count - Rank) / Denominator
    end
end

function StrafesNET.ListMaps(GameId, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_MAP_API_URL .. STRAFESNET_API_ENDPOINTS.MAPS.LIST
    local Params = { game_id = GameId, page_size = PageSize or 10, page_number = PageNumber or 1 }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 60 * 12})
end

function StrafesNET.GetMap(MapId)
    local RequestUrl = STRAFESNET_MAP_API_URL .. STRAFESNET_API_ENDPOINTS.MAPS.GET:format(MapId)
    local Params = { id = MapId }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 60 * 12})
end

function StrafesNET.ListRanks(GameId, ModeId, StyleId, SortBy, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.RANKS.LIST
    local Params = {
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
        sort_by = SortBy or 1,
        page_size = PageSize or 10,
        page_number = PageNumber or 1
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 10})
end

function StrafesNET.ListTimes(MapId, GameId, ModeId, StyleId, UserId, SortBy, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.TIMES.LIST
    local Params = {
        user_id = UserId,
        map_id = MapId,
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
        sort_by = SortBy or 0,
        page_size = PageSize or 10,
        page_number = PageNumber or 1
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 60 * 24 * 7})
end

function StrafesNET.GetWorldRecords(UserId, MapId, GameId, ModeId, StyleId, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.TIMES.WORLD_RECORD.GET
    local Params = {
        user_id = UserId,
        map_id = MapId,
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
        page_size = PageSize or 10,
        page_number = PageNumber or 0
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 10})
end

function StrafesNET.GetTimePlacement(TimeIds)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.TIMES.PLACEMENT.GET
    local Params = {
        ids = TimeIds
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 60})
end

function StrafesNET.GetAllTimePlacements(TimeIds)
    local Placements = {}
    if not TimeIds or #TimeIds == 0 then
        return Placements
    end

    local BatchSize = 25
    local Index = 1

    while Index <= #TimeIds do
        local Batch = {}
        for BatchIndex = Index, math.min(Index + BatchSize - 1, #TimeIds) do
            Batch[#Batch + 1] = TimeIds[BatchIndex]
        end

        local Headers, Response = StrafesNET.GetTimePlacement(Batch)
        if Headers.code and Headers.code >= 400 then
            return error("HTTP error while getting time placements")
        end

        if Response and Response.data then
            for _, Item in next, Response.data do
                local TimeId = SafeNumberToString(Item.id)
                Placements[TimeId] = Item.placement
            end
        end

        Index = Index + BatchSize
    end

    return Placements
end

function StrafesNET.GetTime(TimeId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.TIMES.GET:format(TimeId)
    return Request("GET", RequestUrl, nil, RequestHeaders, {CacheTTL = 60 * 60 * 6})
end

function StrafesNET.ListUsers(StateId, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.LIST
    local Params = {
        state_id = StateId,
        page_size = PageSize or 10,
        page_number = PageNumber or 1,
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 10})
end

function StrafesNET.GetUser(UserId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.GET:format(UserId)
    return Request("GET", RequestUrl, nil, RequestHeaders, {CacheTTL = 60 * 10})
end

function StrafesNET.GetUserRank(UserId, GameId, ModeId, StyleId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.RANKS.GET:format(UserId)
    local Params = {
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
    }
    return Request("GET", RequestUrl, Params, RequestHeaders, {CacheTTL = 60 * 10})
end

-- util stuff or something
function StrafesNET.GetMapCompletionCount(MapId, GameId, ModeId, StyleId)
    local Headers, Response = StrafesNET.ListTimes(MapId, GameId, ModeId, StyleId)
    if Headers.code >= 400 then
        return error("HTTP Error while getting map completion count")
    end
    return Response.pagination.total_items
end

function StrafesNET.GetMapsCompletionCounts(MapIds, GameId, ModeId, StyleId)
    local CompletionCounts = {}
    for _, MapId in next, MapIds do
        CompletionCounts[MapId] = StrafesNET.GetMapCompletionCount(MapId, GameId, ModeId, StyleId)
    end
    return CompletionCounts
end

function StrafesNET.GetAllUserTimes(UserId, GameId, ModeId, StyleId)
    local Times = {}
    local CurrentPage = 1
    local Headers, Response = StrafesNET.ListTimes(nil, GameId, ModeId, StyleId, UserId, 0, 100, CurrentPage)
    if Headers.code >= 400 then
        return error("HTTP error while getting times for something")
    end
    for TimeIndex, Time in next, Response.data do
        NormalizeTime(Time)
        Times[Time.id] = Time
    end
    
    local TotalPages = Response.pagination.total_pages
    while CurrentPage < TotalPages do
        CurrentPage = CurrentPage + 1

        local _Headers, _Response = StrafesNET.ListTimes(nil, GameId, ModeId, StyleId, UserId, 0, 100, CurrentPage)
        if _Headers.code >= 400 then
            return error("HTTP error while getting times for something")
        end
        for _, Time in next, _Response.data do
            NormalizeTime(Time)
            Times[Time.id] = Time
        end
    end

    return Times
end

function StrafesNET.GetAllMaps()
    if StrafesNET.Maps ~= nil then
        return StrafesNET.Maps
    end

    StrafesNET.Maps = {
        [GAME_IDS.BHOP] = {},
        [GAME_IDS.SURF] = {}
    }

    local PageSize = 100
    local Page = 1

    local LastPage = false
    while not LastPage do
        local _, Body = StrafesNET.ListMaps(GAME_IDS.BHOP, PageSize, Page)
        local MapsData = Body.data
        for MapIndex = 1, #MapsData do
            local Map = MapsData[MapIndex]
                local Map = NormalizeMap(MapsData[MapIndex])
                local MapId = Map.id
            StrafesNET.Maps[GAME_IDS.BHOP][MapId] = Map
        end
        Page = Page + 1
        if #MapsData < PageSize then
            LastPage = true
        end
    end

    LastPage = false
    Page = 1

    while not LastPage do
        local _, Body = StrafesNET.ListMaps(GAME_IDS.SURF, PageSize, Page)
        local MapsData = Body.data
        for MapIndex = 1, #MapsData do
            local Map = MapsData[MapIndex]
                local Map = NormalizeMap(MapsData[MapIndex])
                local MapId = Map.id
            StrafesNET.Maps[GAME_IDS.SURF][MapId] = Map
        end
        Page = Page + 1
        if #MapsData < PageSize then
            LastPage = true
        end
    end

    return StrafesNET.Maps
end

function StrafesNET.GetRobloxInfoFromUserId(USER_ID)
    if not USER_ID then return 'empty id' end
    return Request("GET", ROBLOX_API_URL .. "users/" .. USER_ID, {CacheTTL = 60 * 60 * 12})
end

function StrafesNET.GetRobloxInfoFromUsername(USERNAME)
    if not USERNAME then return 'empty username' end
    if #USERNAME > 32 then return 'Username too long' end

    local headers, body = Request("POST", ROBLOX_API_URL .. "usernames/users", nil,
        { ["Content-Type"] = "application/json" }, { usernames = { USERNAME } }, {CacheTTL = 60 * 60 * 12})
    if not body or not body.data or not body.data[1] then
        return 'Username \'' .. USERNAME .. '\' not found.'
    end

    return StrafesNET.GetRobloxInfoFromUserId(body.data[1].id)
end

function StrafesNET.GetRobloxInfoFromDiscordId(DISCORD_ID)
    if not DISCORD_ID then return 'empty id' end
    -- table.foreach(DISCORD_ID, print)
    local headers, body = Request("GET", FIVEMAN_API_URL .. "users/" .. DISCORD_ID, {CacheTTL = 60 * 60 * 24 * 7, MaxRetries = 0})
    if headers.status == "error" then return headers.messages end

    return StrafesNET.GetRobloxInfoFromUserId(body.result.robloxId)
end

function StrafesNET.GetUserOnlineStatus(USER_ID)
    if not USER_ID then return 'empty id' end

    local presence = Request("POST", ROBLOX_PRESENCE_URL .. "presence/users", { userIds = { USER_ID } }).userPresences
        [1]

    local last_online = Request("POST", ROBLOX_PRESENCE_URL .. "presence/last-online", { userIds = { USER_ID } })
        .lastOnlineTimestamps[1]

    L1Copy(last_online, presence)
    return presence
end

function StrafesNET.GetUserUsernameHistory(USER_ID)
    if not USER_ID then return 'empty id' end
    return Request("GET", ROBLOX_API_URL .. "users/" .. USER_ID .. "/username-history",
        { limit = 50, sortOrder = 'Desc' }, {CacheTTL = 60 * 60 * 24})
end

function StrafesNET.GetBadgesAwardedDates(USER_ID, BADGE_LIST)
    if not USER_ID then return 'empty id' end
    return Request("GET", ROBLOX_BADGES_API .. "users/" .. USER_ID .. "/badges/awarded-dates",
        { badgeIds = table.concat(BADGE_LIST, ",") }, {CacheTTL = 60 * 60 * 24 * 365})
end

function StrafesNET.GetVerificationItemID(USER_ID)
    if not USER_ID then return 'empty id' end

    local headers1, body1 = Request("GET", ROBLOX_INVENTORY_API .. "users/" .. USER_ID .. "/items/Asset/102611803", {CacheTTL = 60 * 60 * 24 * 7, MaxRetries = 0})

    local headers2, body2 = Request("GET", ROBLOX_INVENTORY_API .. "users/" .. USER_ID .. "/items/Asset/1567446", {CacheTTL = 60 * 60 * 24 * 7, MaxRetries = 0})

    local data = {}
    if body2.data and body2.data[1] then data[#data + 1] = body2.data[1] end
    if body1.data and body1.data[1] then data[#data + 1] = body1.data[1] end

    return { data = data }
end

function StrafesNET.GetUserThumbnail(USER_ID, TYPE, SIZE)
    if not USER_ID then return 'empty id' end

    local _TYPE = ROBLOX_THUMBNAIL_TYPES[TYPE] or "avatar"
    local _SIZE = ROBLOX_THUMBNAIL_SIZES[SIZE] or "180x180"

    return Request("GET", ROBLOX_THUMBNAIL_URL .. "users/" .. _TYPE,
        { userIds = USER_ID, size = _SIZE, format = "Png", isCircular = false }, {CacheTTL = 60 * 60 * 4})
end

return StrafesNET
