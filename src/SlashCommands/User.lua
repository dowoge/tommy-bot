local SlashCommandTools = require('discordia-slash').util.tools()

local Discordia = require('discordia')
local Date = Discordia.Date
Discordia.extensions()

local StrafesNET = require('../Modules/StrafesNET.lua')

local UserCommand = SlashCommandTools.slashCommand('user', 'Looks up specified user on Roblox')

local UsernameOption = SlashCommandTools.string('username', 'Username to look up')
local UserIdOption = SlashCommandTools.integer('user_id', 'User ID to look up')
local MemberOption = SlashCommandTools.user('member', 'User to look up')

UserCommand:addOption(UsernameOption)
UserCommand:addOption(UserIdOption)
UserCommand:addOption(MemberOption)

Badges = {
    '275640532',  --Bhop, pre-group
    '363928432',  --Surf, pre-group
    '2124614454', --Bhop, post-group
    '2124615096', --Surf, post-group
}
BadgesToName = {
    [Badges[1]] = 'old bhop',
    [Badges[2]] = 'old surf',
    [Badges[3]] = 'new bhop',
    [Badges[4]] = 'new surf',
}
local function round(x, n)
    return string.format('%.' .. (n or 0) .. 'f', x)
end

local function FromYMD(ymd)
    return Date.fromISO(ymd .. "T00:00:00")[1]
end
local function leftpad(s, n, p)
    return string.rep(p, n - #tostring(s)) .. s
end
local function ToYMD(seconds)
    return "<t:" .. seconds .. ":R>"
end
local IDToDate = { --Terrible ranges but it's all we have
    -- {1000000000, FromYMD("2006-01-01")}, --I guess?
    -- {1864564055, FromYMD("2008-08-04")},
    { 1228821079,   FromYMD("2013-02-07") }, -- asomstephano12344 (mass scanning near sign removal date)
    { 3800920136,   FromYMD("2016-04-16") },
    { 9855616205,   FromYMD("2017-04-02") },
    { 30361018662,  FromYMD("2018-11-14") },
    { 32665806459,  FromYMD("2019-01-07") },
    { 34758058773,  FromYMD("2019-02-24") },
    { 65918261258,  FromYMD("2020-06-05") },
    { 171994717435, FromYMD("2023-03-24") },
    { 173210319088, FromYMD("2023-04-14") },
    { 206368884641, FromYMD("2023-07-16") },
    { 229093879745, FromYMD("2024-01-02") },
    { 232802028144, FromYMD("2024-04-08") },
    { 234886704167, FromYMD("2024-06-28") },
    { 241580400713, FromYMD("2025-02-16") },
}
--We assume linear interpolation since anything more complex I can't process
local function linterp(i1, i2, m)
    return math.floor(i1 + (i2 - i1) * m)
end
local function GuessDateFromAssetID(InstanceID, AssetID)
    InstanceID = tonumber(InstanceID)
    local note = ""
    if AssetID == 1567446 then
        note = " (Verification Sign)"
    end
    for i = #IDToDate, 1, -1 do --Newest to oldest
        local ID, Time = unpack(IDToDate[i])
        if ID < InstanceID then
            if not IDToDate[i + 1] then
                -- Screw it we ball, just do unjustified interpolation
                local ID1, Time1 = unpack(IDToDate[#IDToDate - 1])
                local ID2, Time2 = unpack(IDToDate[#IDToDate])
                return "Around " .. ToYMD(linterp(Time1, Time2, (InstanceID - ID1) / (ID2 - ID1))) .. note
            end
            local ParentID, ParentTime = unpack(IDToDate[i + 1])
            return "Around " .. ToYMD(linterp(Time, ParentTime, (InstanceID - ID) / (ParentID - ID))) .. note
        end
    end
    -- Screw it we ball, just do unjustified interpolation
    local ID1, Time1 = unpack(IDToDate[1])
    local ID2, Time2 = unpack(IDToDate[2])
    return "Around " .. ToYMD(linterp(Time1, Time2, (InstanceID - ID1) / (ID2 - ID1))) .. note
end

local function Callback(Interaction, Command, Args)
    local user_info
    if Args then
        local username = Args.username
        local user_id = Args.user_id
        local member = Args.member
        if username then
            _, user_info = StrafesNET.GetRobloxInfoFromUsername(username)
        elseif user_id then
            _, user_info = StrafesNET.GetRobloxInfoFromUserId(user_id)
        elseif member then
            _, user_info = StrafesNET.GetRobloxInfoFromDiscordId(member.id)
        end
    else
        local user = Interaction.member or Interaction.user
        if user then
            _, user_info = StrafesNET.GetRobloxInfoFromDiscordId(user.id)
        end
    end
    if not user_info or not user_info.id then
        return error("User not found")
    end

    Interaction:replyDeferred()

    local description = user_info.description == '' and 'This user has no description' or user_info.description
    local created = tostring(Date.fromISO(user_info.created):toSeconds())
    local current = Date():toSeconds()
    local accountAge = round((current - created) / 86400)
    local isBanned = user_info.isBanned
    local id = user_info.id
    local name = user_info.name
    local displayName = user_info.displayName

    local usernameHistoryHeaders, usernameHistoryBody = StrafesNET.GetUserUsernameHistory(id)
    local usernameHistory = usernameHistoryBody.data or {}
    local usernameHistoryTable = {}
    for index, usernameObj in next, usernameHistory do
        table.insert(usernameHistoryTable, usernameObj.name)
    end
    local usernameHistoryString = table.concat(usernameHistoryTable, ', ')

    local onlineStatus_info = { lastLocation = "Unknown", lastOnline = 0, userPresenceType = -1 }
    -- table.foreach(onlineStatus_info,print)

    local LastLocation = onlineStatus_info.lastLocation
    if onlineStatus_info.userPresenceType == 2 then LastLocation = "Ingame" end
    local LastOnline = 0 --Date.fromISO(onlineStatus_info.lastOnline):toSeconds()

    local verificationAssetId = StrafesNET.GetVerificationItemID(id)
    local verificationDate = "Not verified"
    if verificationAssetId.errors then
        verificationDate = "Failed to fetch"
    elseif verificationAssetId.data[1] then
        verificationDate = ""
        for i, data in next, verificationAssetId.data do
            verificationDate = verificationDate .. GuessDateFromAssetID(data.instanceId, data.id)
            if i ~= #verificationAssetId.data then
                verificationDate = verificationDate .. "\n"
            end
        end
    end

    local _, badgeRequest = StrafesNET.GetBadgesAwardedDates(id, Badges)
    local badgeData = badgeRequest.data

    -- local badgesDates = {}

    local firstBadge, firstBadgeDate = 0, math.huge
    for _, badge in next, badgeData do
        local badgeId = badge.badgeId
        local awardedDate = tonumber(Date.fromISO(badge.awardedDate):toSeconds())
        if firstBadgeDate > awardedDate then
            firstBadge = badgeId
            firstBadgeDate = awardedDate
        end
        -- badgesDates[badgeId]=awardedDate
    end
    local userThumbnailHeaders, userThumbnailBody = StrafesNET.GetUserThumbnail(id)
    local userThumbnail = userThumbnailBody.data[1]

    local embed = {
        title = displayName .. ' (@' .. name .. ')',
        url = 'https://roblox.com/users/' .. id .. '/profile',
        thumbnail = {
            url = userThumbnail.imageUrl,
        },
        fields = {
            { name = 'ID',                                                                                                value = id,                                  inline = true },
            { name = 'Account Age',                                                                                       value = accountAge .. ' days',               inline = true },
            { name = 'Created',                                                                                           value = '<t:' .. round(created) .. ':R>',    inline = true },
            { name = 'Verified Email',                                                                                    value = verificationDate,                    inline = true },
            { name = 'Last Online',                                                                                       value = '<t:' .. round(LastOnline) .. ':R>', inline = true },
            { name = 'Last Location',                                                                                     value = LastLocation,                        inline = true },
            { name = 'Banned',                                                                                            value = isBanned,                            inline = true },
            { name = 'Description',                                                                                       value = description,                         inline = false },
            { name = 'Username History (' .. #usernameHistoryTable .. (#usernameHistoryTable == 50 and '*' or '') .. ')', value = usernameHistoryString,               inline = false },
        }
    }
    if firstBadge and firstBadgeDate ~= math.huge then
        table.insert(embed.fields, { name = 'FQG', value = BadgesToName[firstBadge], inline = true })
        table.insert(embed.fields, { name = 'Joined', value = '<t:' .. round(firstBadgeDate) .. ':R>', inline = true })
    end
    Interaction:reply({ embed = embed })
end

return {
    Command = UserCommand,
    Callback = Callback
}
