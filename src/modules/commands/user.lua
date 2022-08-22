local discordia=require('discordia')
local date = discordia.Date
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
--[[
    {
  "description": "string",
  "created": "2022-08-22T02:55:01.607Z",
  "isBanned": true,
  "externalAppDisplayName": "string",
  "hasVerifiedBadge": true,
  "id": 0,
  "name": "string",
  "displayName": "string"
}]]
--[[
{"GameId":null,
"IsOnline":false,
"LastLocation":"Offline",
"LastOnline":"2022-08-21T22:32:23.4-05:00",
"LocationType":2,
"PlaceId":null,
"VisitorId":1455906620,
"PresenceType":0,
"UniverseId":null,
"Visibility":0}
]]
local function round(x,n)
    return string.format('%.'..(n or 0)..'f',x)
end
discordia.extensions()
commands:Add('user',{},'user <username|mention|"me">', function(t)
    local args=t.args
    local message=t.message
    local user=args[1]
    local user_info=API:GetUserFromAny(user,message)
    if type(user_info)=='string' then return message:reply('```'..user_info..'```') end
    -- for a,b in next,user_info do user_info[a]=tostring(b)end
    local description = user_info.description=='' and 'null' or user_info.description
    local created = tostring(date.fromISO(user_info.created):toSeconds())
    local current = date():toSeconds()
    local accountAge = round((current-created)/86400)
    local isBanned = user_info.isBanned
    local id = user_info.id
    local name = user_info.name
    local displayName = user_info.displayName

    local onlineStatus_info = API:GetUserOnlineStatus(user_info.id)
    
    -- for a,b in next,onlineStatus_info do onlineStatus_info[a]=tostring(b)end
    local LastLocation = onlineStatus_info.LastLocation
    local LastOnline = date.fromISO(onlineStatus_info.LastOnline):toSeconds()
    
    local userThumbnail = API:GetUserThumbnail(user_info.id).data[1]

    local embed = {
        title = displayName..' (@'..name..')',
        url = 'https://roblox.com/users/'..id..'/profile',
        thumbnail = {
            url = userThumbnail.imageUrl,
        },
        fields = {
            {name='ID',value=id,inline=true},
            {name='Account Age',value=accountAge..' days',inline=true},
            {name='Created',value='<t:'..round(created)..':R>',inline=true},
            {name='Last Online',value='<t:'..round(LastOnline)..':R>',inline=true},
            {name='Last Location',value=LastLocation,inline=true},
            {name='Banned',value=isBanned,inline=true},
            {name='Description',value=description,inline=false},
        }
    }
    message:reply({embed=embed})
end)