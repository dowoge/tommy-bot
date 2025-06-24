local HttpRequest = require("./HttpRequest.lua")
local Request = HttpRequest.Request
local APIKeys = require("./APIKeys.lua")

local Headers = {
    ["Content-Type"] = "application/json",
    ["X-API-Key"] = APIKeys.StrafesNET
}

local API_URL = "https://api.strafes.net/api/v1/"

local API_ENDPOINTS = {
    MAPS = {
        LIST = "map",
        GET = "map/%d"
    },
    RANKS = {
        LIST = "rank"
    },
    TIMES = {
        LIST = "time",
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

function StrafesNET.ListMaps(GameId, PageSize, PageNumber)
    local RequestUrl = API_URL .. API_ENDPOINTS.MAPS.LIST
    local Params = { game_id = GameId, page_size = PageSize or 10, page_number = PageNumber or 1 }
    return Request("GET", RequestUrl, Params, Headers)
end

function StrafesNET.GetMap(MapId)
    local RequestUrl = API_URL .. API_ENDPOINTS.MAPS.GET:format(MapId)
    local Params = { id = MapId }
    return Request("GET", RequestUrl, Params, Headers)
end

function StrafesNET.ListRanks(GameId, ModeId, StyleId, SortBy, PageSize, PageNumber)
    local RequestUrl = API_URL .. API_ENDPOINTS.RANKS.LIST
    local Params = {
        gameId = GameId,
        modeId = ModeId,
        styleId = StyleId,
        sort_by = SortBy or 1,
        page_size = PageSize or 10,
        page_number = PageNumber or 1
    }
    return Request("GET", RequestUrl, Params, Headers)
end

function StrafesNET.ListTimes(UserId, MapId, GameId, ModeId, StyleId, SortBy, PageSize, PageNumber)
    local RequestUrl = API_URL .. API_ENDPOINTS.TIMES.LIST
    local Params = {
        user_id = UserId,
        map_id = MapId,
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
        sort_by = SortBy or 1,
        page_size = PageSize or 10,
        page_number = PageNumber or 0
    }
    return Request("GET", RequestUrl, Params, Headers)
end

function StrafesNET.GetTime(TimeId)
    local RequestUrl = API_URL .. API_ENDPOINTS.TIMES.GET:format(TimeId)
    return Request("GET", RequestUrl, nil, Headers)
end

function StrafesNET.ListUsers(StateId, PageSize, PageNumber)
    local RequestUrl = API_URL .. API_ENDPOINTS.USERS.LIST
    local Params = {
        state_id = StateId,
        page_size = PageSize or 10,
        page_number = PageNumber or 1,
    }
    return Request("GET", RequestUrl, Params, Headers)
end

function StrafesNET.GetUser(UserId)
    local RequestUrl = API_URL .. API_ENDPOINTS.USERS.GET:format(UserId)
    return Request("GET", RequestUrl, nil, Headers)
end

function StrafesNET.GetUserRank(UserId, GameId, ModeId, StyleId)
    local RequestUrl = API_URL .. API_ENDPOINTS.USERS.RANKS.GET:format(UserId)
    local Params = {
        game_id = GameId,
        mode_id = ModeId,
        style_id = StyleId,
    }
    return Request("GET", RequestUrl, Params, Headers)
end

return StrafesNET
