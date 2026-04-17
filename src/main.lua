local Discordia = require('discordia')
local Timer = require('timer')
local Token = require('./Modules/Token.lua')
assert(type(Token) == "string" and #Token > 0,
    "src/Modules/Token.lua must return your bot token as a string (see README setup)")
local CommandCollector = require('./Modules/CommandCollector.lua')
local FasteAudit = require('./SlashCommands/FasteAudit.lua')
require('discordia-slash')

local Client = Discordia.Client():useApplicationCommands()
Discordia.extensions()

if not table.clear then
    table.clear = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

local MessageCommandCollector = CommandCollector.new('Message'):Collect()
local SlashCommandCollector = CommandCollector.new('Slash'):Collect()
local UserCommandCollector = CommandCollector.new('User'):Collect()

Client:on('ready', function()
    MessageCommandCollector:Publish(Client)
    SlashCommandCollector:Publish(Client)
    UserCommandCollector:Publish(Client)

    local AuditInProgress = false

    local function RunScheduledAudit()
        if AuditInProgress then
            print("[Scheduled Audit] Skipped: previous run still in progress")
            return
        end
        AuditInProgress = true
        coroutine.wrap(function()
            local Success, Error = pcall(function()
                local Guild = Client:getGuild(FasteAudit.BHOP_SERVER_ID)
                local FileName = FasteAudit.RunAudit(Guild, true, false)

                local Channel = Client:getChannel(FasteAudit.AUDIT_LOG_CHANNEL_ID)
                if Channel then
                    Channel:send({ file = FileName })
                end

                os.remove(FileName)
            end)

            if not Success then
                print("[Scheduled Audit] Error: " .. tostring(Error))
                pcall(function()
                    local Channel = Client:getChannel(FasteAudit.AUDIT_LOG_CHANNEL_ID)
                    if Channel then
                        Channel:send("Scheduled faste audit failed: " .. tostring(Error))
                    end
                end)
            end

            AuditInProgress = false
        end)()
    end

    local SecondsUntilNextUtcMidnight = 86400 - (os.time() % 86400)
    Timer.setTimeout(SecondsUntilNextUtcMidnight * 1000, function()
        RunScheduledAudit()
        Timer.setInterval(24 * 60 * 60 * 1000, RunScheduledAudit)
    end)
    RunScheduledAudit()
end)

local function RunCallback(Callback, Interaction, Command, Args)
    local Success, Return = pcall(Callback, Interaction, Command, Args)
    if not Success then
        local ReplySuccess = pcall(Interaction.reply, Interaction,
            'Error encountered when trying to run command: ' .. tostring(Return), true)
        if not ReplySuccess then
            print('[Callback] Failed to send error reply for ' .. tostring(Command and Command.name) .. ': ' .. tostring(Return))
        end
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
