local Discordia = require('discordia')
local DiscordiaSlash = require('discordia-slash')
local Token = require('./Modules/Token.lua')
local CommandCollector = require('./Modules/CommandCollector.lua')
local Client = Discordia.Client():useApplicationCommands()
Discordia.extensions()

local MessageCommandCollector = CommandCollector.new('Message'):Collect()
local SlashCommandCollector = CommandCollector.new('Slash'):Collect()
local UserCommandCollector = CommandCollector.new('User'):Collect()

Client:on('ready', function()
    -- local GlobalCommands = Client:getGlobalApplicationCommands()

    -- for CommandId in pairs(GlobalCommands) do
    --     Client:deleteGlobalApplicationCommand(CommandId)
    -- end

    MessageCommandCollector:Publish(Client)
    SlashCommandCollector:Publish(Client)
    UserCommandCollector:Publish(Client)
end)

local function RunCallback(Callback, Interaction, Command, Args)
    local Success, Return = pcall(Callback, Interaction, Command, Args)
    if not Success then
        Interaction:reply('Error encountered when trying to run command: '..Return, true)
    end
end

Client:on('slashCommand', function(Interaction, Command, Args)
    local SlashCommand = SlashCommandCollector:Get(Command.name)
    if SlashCommand then
        RunCallback(SlashCommand.Callback, Interaction, Command, Args)
    end
end)

Client:on('messageCommand', function(Interaction, Command, Message)
    local MessageCommand = MessageCommandCollector:Get(Command.name)
    if MessageCommand then
        RunCallback(MessageCommand.Callback, Interaction, Command, Message)
    end
end)

Client:on('userCommand', function(Interaction, Command, Member)
    local UserCommand = UserCommandCollector:Get(Command.name)
    if UserCommand then
        RunCallback(UserCommand.Callback, Interaction, Command, Member)
    end
end)

Client:run('Bot '..Token)