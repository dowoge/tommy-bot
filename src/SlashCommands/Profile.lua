local SlashCommandTools = require('discordia-slash').util.tools()

local Discordia = require('discordia')
local Date = Discordia.Date
Discordia.extensions()

local StrafesNET = require('../Modules/StrafesNET.lua')

local ProfileCommand = SlashCommandTools.slashCommand('profile', 'Displays StrafesNET profile for a given game and style')

local GameOption = SlashCommandTools.string('game', 'Which game to look up')
for Game, GameId in next, StrafesNET.GameIds do
	GameOption = GameOption:addChoice(SlashCommandTools.choice(StrafesNET.GameIdsString[GameId], Game))
end
GameOption = GameOption:setRequired(true)

local StyleOption = SlashCommandTools.string('style', 'Which style to look up')
for Style, StyleId in next, StrafesNET.Styles do
	StyleOption = StyleOption:addChoice(SlashCommandTools.choice(StrafesNET.StylesString[StyleId], Style))
end
StyleOption = StyleOption:setRequired(true)

local UsernameOption = SlashCommandTools.string('username', 'Username to look up')
local UserIdOption = SlashCommandTools.integer('user_id', 'User ID to look up')
local MemberOption = SlashCommandTools.user('member', 'User to look up')

ProfileCommand:addOption(GameOption)
ProfileCommand:addOption(StyleOption)
ProfileCommand:addOption(UsernameOption)
ProfileCommand:addOption(UserIdOption)
ProfileCommand:addOption(MemberOption)

local StateIdToString = {
	[0] = 'Normal',
	[1] = 'Whitelisted',
	[2] = 'Blacklisted',
	[3] = 'Pending',
}

local function Callback(Interaction, Command, Args)
	Interaction:replyDeferred()

	local UserInfo
	local ErrorMessage = 'Something went very very wrong'

	if Args.username then
		local Headers, Response = StrafesNET.GetRobloxInfoFromUsername(Args.username)
		if tonumber(Headers.code) < 400 then
			UserInfo = Response
		else
			ErrorMessage = 'Could not find user info from username (' .. Args.username .. ')'
		end
	elseif Args.user_id then
		if tostring(Args.user_id):match('e') then
			ErrorMessage = 'User id too high for lua number precision (User id: ' .. tostring(Args.user_id) .. ')'
		else
			local Headers, Response = StrafesNET.GetRobloxInfoFromUserId(Args.user_id)
			if tonumber(Headers.code) < 400 then
				UserInfo = Response
			else
				ErrorMessage = 'Could not find user info from user id (' .. tostring(Args.user_id) .. ')'
			end
		end
	elseif Args.member then
		local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId(Args.member.id)
		if tonumber(Headers.code) < 400 then
			UserInfo = Response
		else
			ErrorMessage = 'User has not linked their roblox account to their discord (they must link their accounts using the rbhop dog\'s !link command)'
		end
	else
		local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId((Interaction.member or Interaction.user).id)
		if tonumber(Headers.code) < 400 then
			UserInfo = Response
		else
			ErrorMessage = 'User has not linked their roblox account to their discord (they must link their accounts using the rbhop dog\'s !link command)'
		end
	end

	if UserInfo == nil then
		return Interaction:reply(ErrorMessage, true)
	end

	local Id = UserInfo.id
	local Name = UserInfo.name
	local DisplayName = UserInfo.displayName
	local GameId = StrafesNET.GameIds[Args.game]
	local StyleId = StrafesNET.Styles[Args.style]
	local GameName = StrafesNET.GameIdsString[GameId]
	local StyleName = StrafesNET.StylesString[StyleId]

	-- User thumbnail
	local _, UserThumbnailBody = StrafesNET.GetUserThumbnail(Id)
	local UserThumbnail = UserThumbnailBody.data[1]

	-- Moderation status from StrafesNET
	local ModerationStatus = 'Unknown'
	local StrafesHeaders, StrafesUser = StrafesNET.GetUser(Id)
	if tonumber(StrafesHeaders.code) < 400 and StrafesUser then
		local StateId = StrafesUser.state_id
		ModerationStatus = StateIdToString[StateId] or ('State ' .. tostring(StateId))
	elseif tonumber(StrafesHeaders.code) == 404 then
		ModerationStatus = 'Not registered'
	end

	-- Rank and skill
	local Rank = 'N/A'
	local Skill = 'N/A'
	local RankHeaders, RankResponse = StrafesNET.GetUserRank(Id, GameId, 0, StyleId)
	if tonumber(RankHeaders.code) < 400 and RankResponse then
		if RankResponse.rank then
			Rank = tostring(RankResponse.rank)
		end
		if RankResponse.skill then
			Skill = StrafesNET.FormatSkill(RankResponse.skill)
		end
	end

	-- Completion count (released maps only)
	local CompletionCount = 'N/A'
	local AllMaps = StrafesNET.GetAllMaps()
	local GameMaps = AllMaps[GameId]

	local AllTimesOk, AllTimes = pcall(StrafesNET.GetAllUserTimes, Id, GameId, 0, StyleId)
	if AllTimesOk then
		local ReleasedCompletions = 0
		local TotalReleasedMaps = 0
		local Now = os.time()

		for _, Map in next, GameMaps do
			local MapDate = Map.date and Date.fromISO(Map.date):toSeconds() or nil
			if MapDate and MapDate < Now then
				TotalReleasedMaps = TotalReleasedMaps + 1
			end
		end

		for _, Time in next, AllTimes do
			local MapId = StrafesNET.SafeNumberToString(Time.map.id)
			local Map = GameMaps[MapId]
			local MapDate = Map and Map.date and Date.fromISO(Map.date):toSeconds() or nil
			if MapDate and MapDate < Now then
				ReleasedCompletions = ReleasedCompletions + 1
			end
		end

		CompletionCount = ReleasedCompletions .. '/' .. TotalReleasedMaps
	end

	-- WR count (paginate through all pages)
	local WRCount = 'N/A'
	local WRTotal = 0
	local WRPage = 0
	local WRFetched = false
	local WRDone = false
	while not WRDone do
		local WRHeaders, WRResponse = StrafesNET.GetWorldRecords(Id, nil, GameId, 0, StyleId, 100, WRPage)
		if tonumber(WRHeaders.code) < 400 and WRResponse then
			WRFetched = true
			if WRResponse.pagination and WRResponse.pagination.total_items then
				WRTotal = WRResponse.pagination.total_items
				WRDone = true
			elseif WRResponse.data then
				WRTotal = WRTotal + #WRResponse.data
				if #WRResponse.data < 100 then
					WRDone = true
				else
					WRPage = WRPage + 1
				end
			else
				WRDone = true
			end
		else
			WRDone = true
		end
	end
	if WRFetched then
		WRCount = tostring(WRTotal)
	end

	local Embed = {
		title = DisplayName .. ' (@' .. Name .. ')',
		url = 'https://roblox.com/users/' .. Id .. '/profile',
		thumbnail = {
			url = UserThumbnail.imageUrl,
		},
		description = GameName .. ' — ' .. StyleName,
		fields = {
			{ name = 'ID',            value = Id,               inline = true },
			{ name = 'Rank',          value = Rank,             inline = true },
			{ name = 'Skill',         value = Skill,            inline = true },
			{ name = 'Completions',   value = CompletionCount,  inline = true },
			{ name = 'World Records', value = WRCount,          inline = true },
			{ name = 'Status',        value = ModerationStatus, inline = true },
		}
	}

	Interaction:reply({ embed = Embed })
end

return {
	Command = ProfileCommand,
	Callback = Callback
}
