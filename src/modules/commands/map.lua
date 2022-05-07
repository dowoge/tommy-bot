local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
discordia.extensions()

commands:Add('map',{},'get map info', function(t)
    local game = API.GAMES[t.args[1]]
    local map_name
    if not game then
        map_name = table.concat(t.args,' ')
    else
        map_name = table.concat(t.args,' ',2)
    end
    if not map_name then return t.message:reply('invalid arguments') end
    if game then
        if API.MAPS[game][map_name] then
            local map = API.MAPS[game][map_name]
            local formatted_message = '```'..
            'Map: '..map.DisplayName..' ('..API.GAMES[game]..')\n'..
            'ID: '..map.ID..'\n'..
            'Creator: '..map.Creator..'\n'..
            'PlayCount: '..map.PlayCount..'\n'..
            'Published: '..os.date('%A, %B %d %Y @ %I:%M (%p)',map.Date)..
            '```'
            return t.message:reply(formatted_message)
        end
    else
        for _,game in next,API.GAMES do
            if type(tonumber(game)) == 'number' then
                if API.MAPS[game][map_name] then
                    local map = API.MAPS[game][map_name]
                    local formatted_message = '```'..
                    'Map: '..map.DisplayName..' ('..API.GAMES[game]..')\n'..
                    'ID: '..map.ID..'\n'..
                    'Creator: '..map.Creator..'\n'..
                    'PlayCount: '..map.PlayCount..'\n'..
                    'Published: '..os.date('%A, %B %d %Y @ %I:%M (%p)',map.Date)..
                    '```'
                    return t.message:reply(formatted_message)
                else
                    return t.message:reply('map not found')
                end
            end
        end
    end
end)