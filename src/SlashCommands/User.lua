local SlashCommandTools = require('discordia-slash').util.tools()

local Discordia = require('discordia')
local Date = Discordia.Date
Discordia.extensions()

local API = require('../Modules/strafes_net.lua')

local UserCommand = SlashCommandTools.slashCommand('user', 'Looks up specified user on Roblox')

local UsernameOption = SlashCommandTools.string('username', 'Username to look up')
local UserIdOption = SlashCommandTools.integer('user_id', 'User ID to look up')
local MemberOption = SlashCommandTools.user('member', 'User to look up')

UserCommand:addOption(UsernameOption)
UserCommand:addOption(UserIdOption)
UserCommand:addOption(MemberOption)

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

local function FromYMD(ymd)
    return Date.fromISO(ymd.."T00:00:00")[1]
end
local function leftpad(s,n,p)
    return string.rep(p,n-#tostring(s))..s
end
local function ToYMD(seconds)
    return "<t:"..seconds..":R>"
end
local IDToDate = { --Terrible ranges but it's all we have
    -- {1000000000, FromYMD("2006-01-01")}, --I guess?
    -- {1864564055, FromYMD("2008-08-04")},
    {3800920136, FromYMD("2016-04-16")},
    {9855616205, FromYMD("2017-04-02")},
    {30361018662, FromYMD("2018-11-14")},
    {32665806459, FromYMD("2019-01-07")},
    {34758058773, FromYMD("2019-02-24")},
    {65918261258, FromYMD("2020-06-05")},
    {171994717435, FromYMD("2023-03-24")},
    {173210319088, FromYMD("2023-04-14")},
    {206368884641, FromYMD("2023-07-16")},
    {229093879745, FromYMD("2024-01-02")},
    {232802028144, FromYMD("2024-04-08")},
    {234886704167, FromYMD("2024-06-28")}
}
--We assume linear interpolation since anything more complex I can't process
local function linterp(i1, i2, m)
    return math.floor(i1 + (i2-i1)*m)
end
local function GuessDateFromAssetID(AssetID)
    for i = #IDToDate, 1, -1 do --Newest to oldest
        local ID,Time = unpack(IDToDate[i])
        if ID < AssetID then
            if not IDToDate[i+1] then
                return "After "..ToYMD(Time)
            end
            local ParentID, ParentTime = unpack(IDToDate[i+1])
            return "Around "..ToYMD(linterp(Time, ParentTime, (AssetID-ID)/(ParentID-ID)))
        end
    end
    return "Before "..ToYMD(IDToDate[1][2])
end

local function Callback(Interaction, Command, Args)
	local user_info
	if Args then
		local username = Args.username
		local user_id = Args.user_id
		local member = Args.member
		if username then
			user_info = API:GetRobloxInfoFromUsername(username)
		elseif user_id then
			user_info = API:GetRobloxInfoFromUserId(user_id)
		elseif member then
			user_info = API:GetRobloxInfoFromDiscordId(member.id)
		end
	else
		local user = Interaction.member or Interaction.user
		if user then
			user_info = API:GetRobloxInfoFromDiscordId(user.id)
		end
	end

    local description = user_info.description=='' and 'This user has no description' or user_info.description
    -- table.foreach(user_info,print)
    local created = tostring(Date.fromISO(user_info.created):toSeconds())
    local current = Date():toSeconds()
    local accountAge = round((current-created)/86400)
    local isBanned = user_info.isBanned
    local id = user_info.id
    local name = user_info.name
    local displayName = user_info.displayName

    local usernameHistory = API:GetUserUsernameHistory(id).data or {}
    local usernameHistoryTable = {}
    for index,usernameObj in next,usernameHistory do
        table.insert(usernameHistoryTable,usernameObj.name)
    end
    local usernameHistoryString = table.concat(usernameHistoryTable,', ')

    local onlineStatus_info = API:GetUserOnlineStatus(id) or {lastLocation="Unknown", lastOnline=0, userPresenceType=-1}
    -- table.foreach(onlineStatus_info,print)

    local LastLocation = onlineStatus_info.lastLocation
    if onlineStatus_info.userPresenceType==2 then LastLocation="Ingame" end
    local LastOnline = Date.fromISO(onlineStatus_info.lastOnline):toSeconds()

    local verificationAssetId = API:GetVerificationItemID(id)
    local verificationDate = "Not verified"
    if verificationAssetId.errors then
        verificationDate = "Failed to fetch"
    elseif verificationAssetId.data[1] then
        verificationDate = GuessDateFromAssetID(verificationAssetId.data[1].instanceId)
    end

    local badgeRequest = API:GetBadgesAwardedDates(id,Badges)
    local badgeData = badgeRequest.data

    -- local badgesDates = {}

    local firstBadge,firstBadgeDate = 0,math.huge
    for _,badge in next,badgeData do
        local badgeId = badge.badgeId
        local awardedDate = tonumber(Date.fromISO(badge.awardedDate):toSeconds())
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
            {name='Verified Email',value=verificationDate,inline=true},
            {name='Last Online',value='<t:'..round(LastOnline)..':R>',inline=true},
            {name='Last Location',value=LastLocation,inline=true},
            {name='Banned',value=isBanned,inline=true},
            {name='Description',value=description,inline=false},
            {name='Username History ('..#usernameHistoryTable..(#usernameHistoryTable==50 and '*' or '')..')',value=usernameHistoryString,inline=false},
        }
    }
    if firstBadge and firstBadgeDate~=math.huge then
        table.insert(embed.fields,{name='FQG',value=BadgesToName[firstBadge],inline=true})
        table.insert(embed.fields,{name='Joined',value='<t:'..round(firstBadgeDate)..':R>',inline=true})
    end
    Interaction:reply({embed=embed})
end

return {
	Command = UserCommand,
	Callback = Callback
}