local discordia=require('discordia')
local API=require('./../strafes_net.lua')
discordia.extensions()
API.MAPS={}

local function insert(t, value)
    local start, ending, mid, state = 1, #t, 1, 0

    while start <= ending do
        mid = math.floor((start + ending) / 2)
        if #value.DisplayName < #t[mid].DisplayName then
            ending, state = mid - 1, 0
        else
            start, state = mid + 1, 1
        end
    end

    table.insert(t, mid + state, value.DisplayName)
end

for _, game in next, API.GAMES do
    if type(tonumber(game)) == 'number' then
        local count = 0 -- add into the maps table afterwards
        local maps = {}
        local res, headers = API:GetMaps(game)
        local pages = tonumber(headers['Pagination-Count'])

        count = count + #res

        for _, v in next, res do
            insert(maps, v)
        end

        if pages > 1 then
            for i = 2, pages do
                res, headers = API:GetMaps(game, i)
                count = count + #res

                for _, j in next, res do
                    insert(maps, j)
                end
            end
        end

        setmetatable(maps, {__index = function(self, k)
            if k=='count' then return self.count end

            -- Just to make sure it goes in the right order
            for i = 1, self.count do
                local v = self[i]

                if type(v) == 'table' and v.DisplayName:lower():find(k:lower()) then
                    return v
                end
            end
        end})

        maps.count = count
        API.MAPS[game] = maps
        print('map init done for game:', API.GAMES[game], 'count:', API.MAPS[game].count)
    end
end