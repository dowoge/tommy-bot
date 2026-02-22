local SlashCommandTools = require('discordia-slash').util.tools()

local Discordia = require('discordia')
local Date = Discordia.Date
Discordia.extensions()
local StrafesNET = require('../Modules/StrafesNET.lua')

local SafeNumberToString = StrafesNET.SafeNumberToString

local StrafesNETMaps = StrafesNET.GetAllMaps()

local CalculateCommand = SlashCommandTools.slashCommand('calculate', 'Calculate rank and skill points')

local UsernameOption = SlashCommandTools.string('username', 'Username to look up')
local UserIdOption = SlashCommandTools.integer('user_id', 'User ID to look up')
local MemberOption = SlashCommandTools.user('member', 'User to look up')

local GameOption = SlashCommandTools.string("game", "Which game to use times from")
for Game, GameId in next, StrafesNET.GameIds do
    GameOption = GameOption:addChoice(SlashCommandTools.choice(StrafesNET.GameIdsString[GameId], Game))
end
GameOption = GameOption:setRequired(true)

local StyleOption = SlashCommandTools.string("style", "Which style to use times from")
for Style, StyleId in next, StrafesNET.Styles do
    StyleOption = StyleOption:addChoice(SlashCommandTools.choice(StrafesNET.StylesString[StyleId], Style))
end
StyleOption = StyleOption:setRequired(true)

local SortOption = SlashCommandTools.string("sort", "Which sorting method to use on the times list")
SortOption:addChoice(SlashCommandTools.choice("Points", "points"))
SortOption:addChoice(SlashCommandTools.choice("Skill", "skill"))

CalculateCommand:addOption(GameOption)
CalculateCommand:addOption(StyleOption)
CalculateCommand:addOption(SortOption)

CalculateCommand:addOption(UsernameOption)
CalculateCommand:addOption(UserIdOption)
CalculateCommand:addOption(MemberOption)

local function Pad(String, Padding)
    Padding = Padding or 20
    String = tostring(String)
    return String..string.rep(" ", Padding - #String)
end

local function RankPointsSort(Time1, Time2)
    return Time1.RankPoints < Time2.RankPoints
end

local function SkillSort(Time1, Time2)
    return Time1.Skill < Time2.Skill
end

local SortFunctions = {
    points = RankPointsSort,
    skill = SkillSort
}

local AllowList = {
    ["697004725123416095"] = true,
    ["260016427900076033"] = true
}

local function Callback(Interaction, Command, Args)
    if not AllowList[Interaction.user.id] then
        return Interaction:reply("You are not allowed to use this command", true)
    end

    Interaction:replyDeferred()

    local UserInfo
    local ErrorMessage = "Something went very very wrong"
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

    local GameId, StyleId = StrafesNET.GameIds[Args.game], StrafesNET.Styles[Args.style]

    local GameMaps = StrafesNETMaps[GameId]

    local NTimes = 0

    local Times = StrafesNET.GetAllUserTimes(UserInfo.id, GameId, 0, StyleId)
    local TimeIds = {}
    for _, Time in next, Times do
        local MapId = SafeNumberToString(Time.map.id)
        local Map = GameMaps[MapId]
        local MapDate = Map and Map.date and Date.fromISO(Map.date):toSeconds() or nil
        if MapDate and MapDate < os.time() then
            NTimes = NTimes + 1
            table.insert(TimeIds, SafeNumberToString(Time.id))
        end
    end
    local TimePlacements = StrafesNET.GetAllTimePlacements(TimeIds)

    local MapIds = {}
    for _, Time in next, Times do
        local MapId = SafeNumberToString(Time.map.id)
        local Map = GameMaps[MapId]
        local MapDate = Map and Map.date and Date.fromISO(Map.date):toSeconds() or nil
        if MapDate and MapDate < os.time() then
            table.insert(MapIds, MapId)
        end
    end
    local MapCompletions = StrafesNET.GetMapsCompletionCounts(MapIds, GameId, 0, StyleId)

    local TotalPoints = 0
    local SkillNumerator = 0
    local SkillDenominator = 0
    local TimesConcise = {}

    for _, Time in next, Times do
        local Placement = TimePlacements[SafeNumberToString(Time.id)]
        local MapId = SafeNumberToString(Time.map.id)
        local MapCompletion = MapCompletions[MapId]
        local Map = GameMaps[MapId]
        local MapDate = Date.fromISO(Map.date):toSeconds()
        if MapDate and MapDate < os.time() and Placement and MapCompletion then
            local RankPoints = StrafesNET.CalculatePoints(Placement, MapCompletion)
            local Skill = StrafesNET.CalculateSkill(Placement, MapCompletion)

            TotalPoints = TotalPoints + RankPoints
            SkillNumerator = SkillNumerator + (MapCompletion - Placement)
            SkillDenominator = SkillDenominator + (MapCompletion - 1)

            table.insert(TimesConcise, {
                Time = Time,
                Placement = Placement,
                MapCompletion = MapCompletion,
                RankPoints = RankPoints,
                Skill = Skill
            })
        end
    end

    local SortMethod = Args.sort
    local SortFunction = SortMethod and SortFunctions[SortMethod] or RankPointsSort

    table.sort(TimesConcise, SortFunction)

    local WeightedSkill = 0
    if NTimes >= 20 and SkillDenominator > 0 then
        WeightedSkill = SkillNumerator / SkillDenominator
    end

    local FinalText = "Rank calculation for " .. UserInfo.displayName .. " (@" .. UserInfo.name .. ") / " .. UserInfo.id .. ": ".. StrafesNET.GameIdsString[GameId]..", "..StrafesNET.StylesString[StyleId] .."\n" ..
                        "Points: " .. TotalPoints .. "\n" ..
                        "Skill: " .. StrafesNET.FormatSkill(WeightedSkill) .. "\n" ..
                        "Times: " .. NTimes .. "\n\n" ..
                        Pad("Map", 50) .. " | " .. Pad("Points") .. " | " .. Pad("Skill", 11) .. " | " .. Pad("Placement", 14) .. " | Time\n"

    for _, TimeData in next, TimesConcise do
        local Placement = TimeData.Placement
        local MapCompletion = TimeData.MapCompletion
        local PlacementString = Placement .. "/" .. MapCompletion

        local RankPoints = string.format("%.11f", TimeData.RankPoints)
        local Skill = StrafesNET.FormatSkill(TimeData.Skill)

        local TimeString = StrafesNET.FormatTime(TimeData.Time.time)

        local Map = TimeData.Time.map
        local MapString = Map.display_name .. " (" .. SafeNumberToString(Map.id) .. ")"

        FinalText = FinalText .. Pad(MapString, 50) .. " | " .. Pad(RankPoints) .. " | " .. Pad(Skill, 7) .. " | " .. Pad(PlacementString, 14) .. " | " .. TimeString .. "\n"
    end

    local FileName = "./rank-" .. StrafesNET.GameIdsString[GameId]:lower() .. "-" .. StrafesNET.StylesString[StyleId]:lower() .. "-" .. UserInfo.name .. "-" .. UserInfo.id .. ".txt"
    local FileHandle = io.open(FileName, "w+")
    FileHandle:write(FinalText)
    FileHandle:close()

    Interaction:reply({
        file = FileName
    })

    os.remove(FileName)
end

return {
    Command = CalculateCommand,
    Callback = Callback
}
