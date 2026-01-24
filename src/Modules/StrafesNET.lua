local HttpRequest = require("./HttpRequest.lua")
local Request = HttpRequest.Request
local APIKeys = require("./APIKeys.lua")

local RankConstants = require("./RankConstants.lua")

local RequestHeaders = {
    ["Content-Type"] = "application/json",
    ["X-API-Key"] = APIKeys.StrafesNET
}

function L1Copy(t, b)
    b = b or {}
    for x, y in next, t do b[x] = y end
    return b
end

local STRAFESNET_API_URL = "https://api.strafes.net/api/v1/"
local FIVEMAN_API_URL = 'https://api.fiveman1.net/v1/'
local ROBLOX_API_URL = 'https://users.roproxy.com/v1/'
local ROBLOX_BADGES_API = 'https://badges.roproxy.com/v1/'
local ROBLOX_PRESENCE_URL = 'https://presence.roproxy.com/v1/'
local ROBLOX_THUMBNAIL_URL = 'https://thumbnails.roproxy.com/v1/'
local ROBLOX_INVENTORY_API = 'https://inventory.roproxy.com/v1/'
local ROBLOX_GROUPS_ROLES_URL = 'https://groups.roproxy.com/v2/users/%s/groups/roles'

local GAME_IDS = {
    BHOP = 1,
    SURF = 2,
    -- FLY_TRIALS = 5
}

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
StrafesNET.GameIds = GAME_IDS

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
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.MAPS.LIST
    local Params = { game_id = GameId, page_size = PageSize or 10, page_number = PageNumber or 1 }
    return Request("GET", RequestUrl, Params, RequestHeaders)
end

function StrafesNET.GetMap(MapId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.MAPS.GET:format(MapId)
    local Params = { id = MapId }
    return Request("GET", RequestUrl, Params, RequestHeaders)
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
    return Request("GET", RequestUrl, Params, RequestHeaders)
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
    return Request("GET", RequestUrl, Params, RequestHeaders)
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
    return Request("GET", RequestUrl, Params, RequestHeaders)
end

function StrafesNET.GetTime(TimeId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.TIMES.GET:format(TimeId)
    return Request("GET", RequestUrl, nil, RequestHeaders)
end

function StrafesNET.ListUsers(StateId, PageSize, PageNumber)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.LIST
    local Params = {
        state_id = StateId,
        page_size = PageSize or 10,
        page_number = PageNumber or 1,
    }
    return Request("GET", RequestUrl, Params, RequestHeaders)
end

function StrafesNET.GetUser(UserId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.GET:format(UserId)
    return Request("GET", RequestUrl, nil, RequestHeaders)
end

function StrafesNET.GetUserRank(UserId, GameId, ModeId, StyleId)
    local RequestUrl = STRAFESNET_API_URL .. STRAFESNET_API_ENDPOINTS.USERS.RANKS.GET:format(UserId)
    local Params = {
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
    }
    return Request("GET", RequestUrl, Params, RequestHeaders)
end

-- util stuff or something
function StrafesNET.GetMapCompletionCount(MapId, GameId, ModeId, StyleId)
    local Headers, Response = StrafesNET.ListTimes(MapId, GameId, ModeId, StyleId)
    if Headers.code >= 400 then
        return error("HTTP Error while getting map completion count")
    end
    return Response.pagination.total_items
end

function StrafesNET.GetAllUserTimes(UserId, GameId, ModeId, StyleId)
    local Times = {}
    local CurrentPage = 1
    local Headers, Response = StrafesNET.ListTimes(nil, GameId, ModeId, StyleId, UserId, 0, 100, CurrentPage)
    if Headers.code >= 400 then
        return error("HTTP error while getting times for something")
    end
    for TimeIndex, Time in next, Response.data do
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
            Times[Time.id] = Time
        end
    end

    return Times
end

function StrafesNET.GetAllMaps()
    local Maps = {}
    -- TODO
    return Maps
end

function StrafesNET.GetRobloxInfoFromUserId(USER_ID)
    if not USER_ID then return 'empty id' end
    return Request("GET", ROBLOX_API_URL .. "users/" .. USER_ID)
end

function StrafesNET.GetRobloxInfoFromUsername(USERNAME)
    if not USERNAME then return 'empty username' end
    if #USERNAME > 32 then return 'Username too long' end

    local headers, body = Request("POST", ROBLOX_API_URL .. "usernames/users", nil,
        { ["Content-Type"] = "application/json" }, { usernames = { USERNAME } })
    if not body or not body.data or not body.data[1] then
        return 'Username \'' .. USERNAME .. '\' not found.'
    end

    return StrafesNET.GetRobloxInfoFromUserId(body.data[1].id)
end

function StrafesNET.GetRobloxInfoFromDiscordId(DISCORD_ID)
    if not DISCORD_ID then return 'empty id' end
    -- table.foreach(DISCORD_ID, print)
    local headers, body = Request("GET", FIVEMAN_API_URL .. "users/" .. DISCORD_ID)
    if headers.status == "error" then return headers.messages end

    return Request("GET", ROBLOX_API_URL .. "users/" .. body.result.robloxId)
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
        { limit = 50, sortOrder = 'Desc' })
end

function StrafesNET.GetBadgesAwardedDates(USER_ID, BADGE_LIST)
    if not USER_ID then return 'empty id' end
    return Request("GET", ROBLOX_BADGES_API .. "users/" .. USER_ID .. "/badges/awarded-dates",
        { badgeIds = table.concat(BADGE_LIST, ",") })
end

function StrafesNET.GetVerificationItemID(USER_ID)
    if not USER_ID then return 'empty id' end

    local headers1, body1 = Request("GET", ROBLOX_INVENTORY_API .. "users/" .. USER_ID .. "/items/Asset/102611803")
    if body1.errors then return body1 end

    local headers2, body2 = Request("GET", ROBLOX_INVENTORY_API .. "users/" .. USER_ID .. "/items/Asset/1567446")
    if body2.errors then return body2 end

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
        { userIds = USER_ID, size = _SIZE, format = "Png", isCircular = false })
end

return StrafesNET
