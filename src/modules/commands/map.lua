local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
discordia.extensions()

commands:Add('map',{},'get map info', function(t)
    local args = t.args
    local message = t.message

    local game = API.GAMES[args[1]]
    local map
    if not game then
        local str = table.concat(args,' ')
        map = API.MAPS[1][str] or API.MAPS[2][str]
        print('no game',str)
    else
        map = API.MAPS[game][table.concat(args,' ',2)]
        print(game,table.concat(args,' ',2))
    end
    
    if not map then return message:reply('```No map found```') end
    local formatted_message = '```'..
                            'Map: '..map.DisplayName..' ('..API.GAMES[map.Game]..')\n'..
                            'ID: '..map.ID..'\n'..
                            'Creator: '..map.Creator..'\n'..
                            'PlayCount: '..map.PlayCount..'\n'..
                            'Published: '..os.date('%A, %B %d %Y @ %I:%M (%p)',map.Date)..
                            '```'
    return message:reply(formatted_message)
end)