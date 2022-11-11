local discordia = require('discordia')
local token = require('./modules/token.lua')
local commands=require('./modules/commands.lua')
local prefix = ','
local client = discordia.Client()
_G.client = client
_G.locked = false

discordia.extensions()

client:on('ready',function()
    commands:INIT()
    local f=io.open('restart.txt','r+'):read()
    local t=tostring(f):split(',')
    if #t==3 then
        client:getGuild(t[1]):getChannel(t[2]):send(
            {
                content='bot ready',
                reference={
                    message=client:getChannel(t[2]):getMessage(t[3]),
                    mention=true
                }
            }
        )
        io.open('restart.txt','w+'):write(''):close()
    else
        print('restart.txt is empty or something so probably a first start')
    end
end)

function parseMentions(message)
    local content=message.content
    local usersMentioned={}
    if #message.mentionedUsers>0 then
        for user in message.mentionedUsers:iter() do
            usersMentioned[user.id]=user
        end
    end
    local msgSplit=content:split(' ')
    for i,v in next, msgSplit do
        if v:match('<@![0-9]+>') then
            local id=v:match('<@!([0-9]+)>')
            if usersMentioned[id] then
                msgSplit[i]=usersMentioned[id].mentionString
            end
        end
    end
    return table.concat(msgSplit,' ') or '',usersMentioned
end

client:on('messageCreate', function(message)
    if message.author.bot then return end
    local content,mentions=parseMentions(message)
    if content:sub(1,#prefix)==prefix then
        local cmd=content:sub(#prefix+1,#content)
        local args=cmd:split(' ')
        local cmdName=args[1]
        table.remove(args,1)
        local command=commands.command_list[cmdName]
        if command~=nil then
            if message.guild~=nil then
                local s,e=pcall(function()
                    command.exec({message=message,args=args,mentions=mentions,t={client,discordia,token}})
                end)
                if not s then
                    message:reply('tripped : '..e:split('/')[#e:split('/')])
                end
            end
        end
    end
end)

client:run('Bot '..token)