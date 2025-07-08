local SlashCommandTools = require('discordia-slash').util.tools()

local Discordia = require('discordia')
local Date = Discordia.Date
Discordia.extensions()
local StrafesNET = require('../Modules/StrafesNET.lua')

local CalculateCommand = SlashCommandTools.slashCommand('calculate', 'Calculate rank and skill points')

local UsernameOption = SlashCommandTools.string('username', 'Username to look up')
local UserIdOption = SlashCommandTools.integer('user_id', 'User ID to look up')
local MemberOption = SlashCommandTools.user('member', 'User to look up')

local GameIdOption = SlashCommandTools.integer

CalculateCommand:addOption(UsernameOption)
CalculateCommand:addOption(UserIdOption)
CalculateCommand:addOption(MemberOption)

local function Callback(Interaction, Command, Args)
    local UserInfo
    if Args then
        if Args.username then
            local Headers, Response = StrafesNET.GetRobloxInfoFromUsername(Args.username)
            if Headers.code < 400 then
                UserInfo = Response
            end
        elseif Args.user_id then
            local Headers, Response = StrafesNET.GetRobloxInfoFromUserId(Args.user_id)
            if Headers.code < 400 then
                UserInfo = Response
            end
        elseif Args.member then
            local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId(Args.member.id)
            if Headers.code < 400 then
                UserInfo = Response
            end
        end
    else
        local Headers, Response = StrafesNET.GetRobloxInfoFromDiscordId((Interaction.member or Interaction.user).id)
        if Headers.code < 400 then
            UserInfo = Response
        end
    end

    if UserInfo == nil then
        error("SOMETHING WENT REALLY WRONG")
    end

    -- Add args for game/style etc and grab all times and grab all placements
end

return {
    Command = CalculateCommand,
    Callback = Callback
}
