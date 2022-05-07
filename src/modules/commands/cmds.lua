local discordia=require('discordia')
local commands=require('./../commands.lua')
discordia.extensions()
commands:Add('cmds',{'commands','cmd','help'},'Returns a list of all commands',function(t)
    local final='```\n'
    for i,v in pairs(commands.command_list) do
        local name=v.name
        local alias=table.concat(v.alias,', ') or 'None'
        local desc=v.desc
        final=final..'Name: '..name..'\nDescription: '..desc..'\n'..'Aliases: '..alias..'\n\n'
    end
    final=final..'```'
    t.message:reply(final)
end)