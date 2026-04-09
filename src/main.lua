local Discordia = require('discordia')
local Timer = require('timer')
local Token = require('./Modules/Token.lua')
local CommandCollector = require('./Modules/CommandCollector.lua')
local FasteAudit = require('./SlashCommands/FasteAudit.lua')
require('discordia-slash')

local Client = Discordia.Client():useApplicationCommands()
Discordia.extensions()

table.clear = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local MessageCommandCollector = CommandCollector.new('Message'):Collect()
local SlashCommandCollector = CommandCollector.new('Slash'):Collect()
local UserCommandCollector = CommandCollector.new('User'):Collect()

Client:on('ready', function()
    MessageCommandCollector:Publish(Client)
    SlashCommandCollector:Publish(Client)
    UserCommandCollector:Publish(Client)

    local function RunScheduledAudit()
        coroutine.wrap(function()
            local Success, Error = pcall(function()
                local Guild = Client:getGuild(FasteAudit.BHOP_SERVER_ID)
                local FileName = FasteAudit.RunAudit(Guild, true, false)

                local User = Client:getUser(FasteAudit.ALLOWED_USER_ID)
                if User then
                    User:send({ content = "Daily faste audit results:", file = FileName })
                end

                os.remove(FileName)
            end)

            if not Success then
                print("[Scheduled Audit] Error: " .. tostring(Error))
                pcall(function()
                    local User = Client:getUser(FasteAudit.ALLOWED_USER_ID)
                    if User then
                        User:send("Scheduled faste audit failed: " .. tostring(Error))
                    end
                end)
            end
        end)()
    end

    Timer.setInterval(24 * 60 * 60 * 1000, RunScheduledAudit)
    RunScheduledAudit()
end)

local function RunCallback(Callback, Interaction, Command, Args)
    local Success, Return = pcall(Callback, Interaction, Command, Args)
    if not Success then
        Interaction:reply('Error encountered when trying to run command: ' .. tostring(Return), true)
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

Client:run('Bot ' .. Token)
