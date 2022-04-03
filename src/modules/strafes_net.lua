local http_request = require('./http.lua')
local API = {}
local API_KEY = require('./apikey.lua')
local API_URL = 'https://api.strafes.net/v1/'
local API_HEADER = { {'Content-Type','application/json'}, { 'api-key', API_KEY } }

local t=tostring
local r=function(n,nd) return tonumber(string.format('%.' .. (nd or 0) .. 'f', n)) end

local GAMES={BHOP=1,SURF=2,[1]='bhop',[2]='surf'}
local STATES={[0]='Default',[1]='Whitelisted',[2]='Blacklisted',[3]='Pending'}
local RANKS={'New (1)','Newb (2)','Bad (3)','Okay (4)','Not Bad (5)','Decent (6)','Getting There (7)','Advanced (8)','Good (9)','Great (10)','Superb (11)','Amazing (12)','Sick (13)','Master (14)','Insane (15)','Majestic (16)','Baby Jesus (17)','Jesus (18)','Half God (19)','God (20)'}
local STYLES_LIST={'Autohop','Scroll','Sideways','Half-Sideways','W-Only','A-Only','Backwards',}
local STYLES={AUTOHOP=1,SCROLL=2,SIDEWAYS=3,HALFSIDEWAYS=4,WONLY=5,AONLY=6,BACKWARDS=7}

-- insyri make this BTW
-- use as local err, res = parseToURLArgs(), thanks golang for this idea 
function parseToURLArgs(tb) function Err(err) return err, nil end function Ok(res) return nil, res end if not tb then return Err('got nothing') end if type(tb) ~= 'table' then return Err('expected table, got '..type(tb)) end local str = '?' local index = 1 for key, value in pairs(tb) do if index == 1 then str = str..key..'='..t(value) else str = str..'&'..key..'='..t(value) end index = index + 1 end return Ok(str) end
-- fiveman made these (converted to lua from python)
function formatHelper(time, digits) local time = tostring(time)while #time < digits do time = '0'..time end return time end
function formatTime(time) if time > 86400000 then return '>1 day' else local millis = formatHelper(time % 1000, 3) local seconds = formatHelper(r(time / 1000) % 60, 2) local minutes = formatHelper(r(time / (1000 * 60)) % 60, 2) local hours = formatHelper(r(time / (1000 * 60 * 60)) % 24, 2) if hours == '00' then return minutes..':'..seconds..'.'..millis else return hours..':'..minutes..':'..seconds end end end

function formatRank(n) return RANKS[1+math.floor(n*19)] end
function formatSkill(n) return r(n*100,3)..'%' end

-- Time from id.
function API:GetTime(ID)
    if not ID then return 'empty id' end
    local response = http_request('GET', API_URL..'time/'..ID, API_HEADER)
    return response
end
-- Time rank from id.
function API:GetTimeRank(MAP_ID)
    if not MAP_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'time/'..MAP_ID..'/rank', API_HEADER)
    return response
end
-- 10 recent world records.
function API:GetRecentWrs(STYLE_ID, GAME_ID, WHITELIST_FILTER)
    if not STYLE_ID or not GAME_ID then return 'empty id' end
    local err, res = parseToURLArgs({style=STYLE_ID, game=GAME_ID, whitelist=WHITELIST_FILTER})
    if err then return err end
    local response = http_request('GET', API_URL..'time/recent/wr'..res, API_HEADER)
    return response
end
-- Time by map id. Sorted in ascending order.
function API:GetMapTimes(MAP_ID, STYLE_ID, PAGE)
    if not MAP_ID then return 'empty id' end
    local err, res = parseToURLArgs({style=STYLE_ID, page=PAGE})
    if err then return err end
    local response = http_request('GET', API_URL..'time/map/'..MAP_ID..res, API_HEADER)
    return response
end
-- Get WR of map.
function API:GetMapWr(MAP_ID, STYLE_ID)
    if not MAP_ID or not STYLE_ID then return 'empty id' end
    local err, res = parseToURLArgs({style=STYLE_ID})
    if err then return err end
    local response = http_request('GET', API_URL..'time/map/'..MAP_ID..'/wr'..res, API_HEADER)
    return response
end
-- Time by user id.
function API:GetUserTimes(USER_ID, MAP_ID, STYLE_ID, GAME_ID, PAGE)
    if not USER_ID then return 'empty id' end
    local err, res = parseToURLArgs({map=MAP_ID, style=STYLE_ID, game=GAME_ID, page=PAGE})
    if err then return err end
    local response = http_request('GET', API_URL..'time/user/'..USER_ID..res , API_HEADER)
    return response
end
-- World records by user id.
function API:GetUserWrs(USER_ID,GAME_ID,STYLE_ID)
    if not USER_ID or not GAME_ID or not STYLE_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'time/user/'..USER_ID..'/wr?game='..GAME_ID..'&style='..STYLE_ID, API_HEADER)
    return response
end
-- User from id.
function API:GetUser(USER_ID)
    if not USER_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'user/'..USER_ID, API_HEADER)
    return response
end
-- Top ranked players, paged at 50 per page.
function API:GetRanks(STYLE_ID,GAME_ID,PAGE)
    if not STYLE_ID or not GAME_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'rank?style='..STYLE_ID..'&game='..GAME_ID..(PAGE and '&page='..PAGE or ''), API_HEADER)
    return response
end
-- Get rank of user by their id.
function API:GetRank(USER_ID,STYLE_ID,GAME_ID)
    if not USER_ID or not STYLE_ID or not GAME_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'rank/'..USER_ID..'?style='..STYLE_ID..'&game='..GAME_ID, API_HEADER)
    return response
end
-- Get list of maps.
function API:GetMaps(GAME_ID,PAGE)
    if not GAME_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'map?game='..GAME_ID..(PAGE and '&page='..PAGE or ''), API_HEADER)
    return response
end
-- Get map by ID.
function API:GetMap(MAP_ID)
    if not MAP_ID then return 'empty id' end
    local response = http_request('GET', API_URL..'map/'..MAP_ID, API_HEADER)
    return response
end

local rank = API:GetRank('36332018', STYLES.AUTOHOP, GAMES.SURF)
print(formatRank(rank.Rank),formatSkill(rank.Skill))