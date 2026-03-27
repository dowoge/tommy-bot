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

local BhopBadges = {
	'275640532',  --Bhop, pre-group
	'363928432',  --Surf, pre-group
	'2124614454', --Bhop, post-group
	'2124615096', --Surf, post-group
}
local BhopBadgesToName = {
	[BhopBadges[1]] = 'Old bhop',
	[BhopBadges[2]] = 'Old surf',
	[BhopBadges[3]] = 'New bhop',
	[BhopBadges[4]] = 'New surf',
}
local PopularBadges = {
	"2124444712",		-- Arsenal "Stepping Stone"				190M won, made Dec 2018
	"66918518",			-- NDS "Survived a Disaster"			418M won, made Dec 2011
	"2904819966736756",	-- RIVALS "Welcome!"					335M won, made June 2024
	"161222105",		-- Mega Marble Run Pit "10 credits"		 84M won, made June 2014
	"2124780104",		-- CAC "Catalog Avatar Creator"			333M won, made July 2021
	"2127839123",		-- Evade "Flawless Survival"			 87M won, made August 2022
	"2124935409",		-- PLS DONATE "Welcome!"				335M won, made February 2022
	"282537385",		-- Epic Minigames "Welcome"				300M won, made August 2015
	"174605507",		-- Super Bomb Survival "It's A Blast!"	 52M won, made August 2014
	"176685910",		-- WaaPP "Pizza Boxer"					 38M won, made September 2014
	"697770868",		-- Miner's Haven "Welcome!"				 22M won, made March 2017
	"2124445748",		-- Broken Bones "Alpha Tester"			137M won, made December 2018
}

local function Round(Value, Digits)
	return string.format('%.' .. (Digits or 0) .. 'f', Value)
end

local function FromYMD(Ymd)
	return Date.fromISO(Ymd .. "T00:00:00")[1]
end

local function LeftPad(String, Length, Padding)
	return string.rep(Padding, Length - #tostring(String)) .. String
end

local function ToYMD(Seconds)
	return "<t:" .. Seconds .. ":R>"
end

local IdToDate = { --Terrible ranges but it's all we have
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
local function Linterp(Value1, Value2, Alpha)
	return math.floor(Value1 + (Value2 - Value1) * Alpha)
end

local function GuessDateFromAssetId(InstanceId, AssetId)
	InstanceId = tonumber(InstanceId)
	local Note = ""
	if AssetId == 1567446 then
		Note = " (Verification Sign)"
	end
	for Index = #IdToDate, 1, -1 do --Newest to oldest
		local Id, Time = unpack(IdToDate[Index])
		if Id < InstanceId then
			if not IdToDate[Index + 1] then
				local Id1, Time1 = unpack(IdToDate[#IdToDate - 1])
				local Id2, Time2 = unpack(IdToDate[#IdToDate])
				return "Around " .. ToYMD(Linterp(Time1, Time2, (InstanceId - Id1) / (Id2 - Id1))) .. Note
			end
			local ParentId, ParentTime = unpack(IdToDate[Index + 1])
			return "Around " .. ToYMD(Linterp(Time, ParentTime, (InstanceId - Id) / (ParentId - Id))) .. Note
		end
	end
	local Id1, Time1 = unpack(IdToDate[1])
	local Id2, Time2 = unpack(IdToDate[2])
	return "Around " .. ToYMD(Linterp(Time1, Time2, (InstanceId - Id1) / (Id2 - Id1))) .. Note
end

local function Callback(Interaction, Command, Args)
	Interaction:replyDeferred()

	local UserInfo
	local ErrorMessage = "Something went very very wrong"
	if Args then
		if Args.username then
			local Headers, Response = StrafesNET.GetRobloxInfoFromUsername(Args.username)
			if tonumber(Headers.code) < 400 then
				UserInfo = Response
			else
				ErrorMessage = "Could not find user info from user id ("..Args.username..")"
			end
		elseif Args.user_id then
			if tostring(Args.user_id):match("e") then
				ErrorMessage = "User id too high for lua number precision (User id: " .. tostring(Args.user_id) .. ")"
			else
				local Headers, Response = StrafesNET.GetRobloxInfoFromUserId(Args.user_id)
				if tonumber(Headers.code) < 400 then
					UserInfo = Response
				else
					ErrorMessage = "Could not find user info from user id (" .. tostring(Args.user_id) .. ")"
				end
			end
		elseif Args.member then
			local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId(Args.member.id)
			if tonumber(Headers.code) < 400 then
				UserInfo = Response
			else
				ErrorMessage = "User has not linked their roblox account to their discord (they must link their accounts using the rbhop dog's !link command)"
			end
		end
	else
		local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId((Interaction.member or Interaction.user).id)
		if tonumber(Headers.code) < 400 then
			UserInfo = Response
		else
			ErrorMessage = "User has not linked their roblox account to their discord (they must link their accounts using the rbhop dog's !link command)"
		end
	end

	if UserInfo == nil then
		return Interaction:reply(ErrorMessage, true)
	end

	local Description = UserInfo.description == '' and 'This user has no description' or UserInfo.description
	local Created = tostring(Date.fromISO(UserInfo.created):toSeconds())
	local Current = Date():toSeconds()
	local AccountAge = Round((Current - Created) / 86400)
	local IsBanned = UserInfo.isBanned
	local Id = UserInfo.id
	local Name = UserInfo.name
	local DisplayName = UserInfo.displayName

	local _, UsernameHistoryBody = StrafesNET.GetUserUsernameHistory(Id)
	local UsernameHistory = UsernameHistoryBody.data or {}
	local UsernameHistoryTable = {}
	for _, UsernameObj in next, UsernameHistory do
		table.insert(UsernameHistoryTable, UsernameObj.name)
	end
	local UsernameHistoryString = table.concat(UsernameHistoryTable, ', ')

	local OnlineStatusInfo = { lastLocation = "Unknown", lastOnline = 0, userPresenceType = -1 }

	local LastLocation = OnlineStatusInfo.lastLocation
	if OnlineStatusInfo.userPresenceType == 2 then LastLocation = "Ingame" end
	local LastOnline = 0

	local VerificationAssetId = StrafesNET.GetVerificationItemId(Id)
	local VerificationDate = "Not verified"
	if VerificationAssetId.errors then
		VerificationDate = "Failed to fetch"
	elseif VerificationAssetId.data[1] then
		VerificationDate = ""
		for Index, Data in next, VerificationAssetId.data do
			VerificationDate = VerificationDate .. GuessDateFromAssetId(Data.instanceId, Data.id)
			if Index ~= #VerificationAssetId.data then
				VerificationDate = VerificationDate .. "\n"
			end
		end
	end

	local _, BadgeRequest = StrafesNET.GetBadgesAwardedDates(Id, BhopBadges)
	local BadgeData = BadgeRequest.data

	local FirstBadge, FirstBadgeDate = 0, math.huge
	if BadgeData then
		for _, Badge in next, BadgeData do
			local BadgeId = Badge.badgeId
			local AwardedDate = tonumber(Date.fromISO(Badge.awardedDate):toSeconds())
			if FirstBadgeDate > AwardedDate then
				FirstBadge = BadgeId
				FirstBadgeDate = AwardedDate
			end
		end
	end

	local _, PopularBadgeRequest = StrafesNET.GetBadgesAwardedDates(Id, PopularBadges)
	local PopularBadgeData = PopularBadgeRequest.data

	local OldestThree = {{math.huge}, {math.huge}, {math.huge}}
	if PopularBadgeData then
		for _, Badge in next, PopularBadgeData do
			local BadgeId = Badge.badgeId
			local AwardedDate = tonumber(Date.fromISO(Badge.awardedDate):toSeconds())
			for Index = 1, 3 do
				if OldestThree[Index][1] > AwardedDate then
					table.insert(OldestThree, Index, {AwardedDate, BadgeId})
					OldestThree[4] = nil
					break
				end
			end
		end
	end

	local OldestThreeText
	if OldestThree[1][1] ~= math.huge then
		OldestThreeText = {}
		for Index = 1, 3 do
			local Data = OldestThree[Index]
			if Data[1] ~= math.huge then
				OldestThreeText[Index] = ToYMD(Round(Data[1])) .. " ([" .. Data[2] .. "](https://www.roblox.com/badges/" .. Data[2] .. "))"
			end
		end
		OldestThreeText = table.concat(OldestThreeText, "\n")
	else
		OldestThreeText = "None earned"
	end

	local _, UserThumbnailBody = StrafesNET.GetUserThumbnail(Id)
	local UserThumbnail = UserThumbnailBody.data[1]

	local Embed = {
		title = DisplayName .. ' (@' .. Name .. ')',
		url = 'https://roblox.com/users/' .. Id .. '/profile',
		thumbnail = {
			url = UserThumbnail.imageUrl,
		},
		fields = {
			{ name = 'ID',             value = Id,                                  inline = true },
			{ name = 'Account Age',    value = AccountAge .. ' days',               inline = true },
			{ name = 'Created',        value = '<t:' .. Round(Created) .. ':R>',    inline = true },
			{ name = 'Verified Email', value = VerificationDate,                    inline = true },
			{ name = 'Last Online',    value = '<t:' .. Round(LastOnline) .. ':R>', inline = true },
			{ name = 'Last Location',  value = LastLocation,                        inline = true },
			{ name = 'Banned',         value = IsBanned,                            inline = true },
			{ name = 'Description',    value = Description,                         inline = false },
			{ name = 'Username History (' .. #UsernameHistoryTable .. (#UsernameHistoryTable == 50 and '*' or '') .. ')', value = UsernameHistoryString, inline = false },
		}
	}
	if FirstBadge and FirstBadgeDate ~= math.huge then
		table.insert(Embed.fields, { name = 'First Quat Game', value = BhopBadgesToName[FirstBadge] .. '\n<t:' .. Round(FirstBadgeDate) .. ':R>', inline = true })
	end
	table.insert(Embed.fields, { name = 'Oldest Popular Badges', value = OldestThreeText, inline = true })
	Interaction:reply({ embed = Embed })
end

return {
	Command = UserCommand,
	Callback = Callback
}
