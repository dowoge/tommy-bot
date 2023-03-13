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
Badges = {
    '275640532', --Bhop, pre-group
    '363928432', --Surf, pre-group
    '2124614454', --Bhop, post-group
    '2124615096', --Surf, post-group
}
BadgesToName = {
    [275640532]='old bhop',
    [363928432]='old surf',
    [2124614454]='new bhop',
    [2124615096]='new surf',
}
local function round(x,n)
    return string.format('%.'..(n or 0)..'f',x)
end
discordia.extensions()
commands:Add('user',{},'user <username|mention|"me">', function(t)
    local args=t.args
    local message=t.message
    local user=args[1] or 'me'
    local user_info=API:GetUserFromAny(user,message)
    if type(user_info)=='string' then return message:reply('```'..user_info..'```') end

    local description = user_info.description=='' and 'This user has no description' or user_info.description
    table.foreach(user_info,print)
    local created = tostring(date.fromISO(user_info.created):toSeconds())
    local current = date():toSeconds()
    local accountAge = round((current-created)/86400)
    local isBanned = user_info.isBanned
    local id = user_info.id
    local name = user_info.name
    local displayName = user_info.displayName

    local onlineStatus_info = API:GetUserOnlineStatus(id)
    table.foreach(onlineStatus_info,print)

    local LastLocation = onlineStatus_info.lastLocation
    if onlineStatus_info.userPresenceType==2 then LastLocation="Ingame" end
    local LastOnline = date.fromISO(onlineStatus_info.lastOnline):toSeconds()+(3600*5)

    local badgeRequest = API:GetBadgesAwardedDates(id,Badges)
    local badgeData = badgeRequest.data

    -- local badgesDates = {}

    local firstBadge,firstBadgeDate = 0,math.huge
    for _,badge in next,badgeData do
        local badgeId = badge.badgeId
        local awardedDate = tonumber(date.fromISO(badge.awardedDate):toSeconds())
        if firstBadgeDate>awardedDate then
            firstBadge=badgeId
            firstBadgeDate=awardedDate
        end
        -- badgesDates[badgeId]=awardedDate
    end
    local userThumbnail = API:GetUserThumbnail(id).data[1]

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
    if firstBadge and firstBadgeDate~=math.huge then
        table.insert(embed.fields,{name='FQG',value=BadgesToName[firstBadge],inline=true})
        table.insert(embed.fields,{name='Joined',value='<t:'..round(firstBadgeDate)..':R>',inline=true})
    end
    message:reply({embed=embed})
end)