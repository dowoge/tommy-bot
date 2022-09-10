local discordia=require('discordia')
local API=require('./../strafes_net.lua')
discordia.extensions()
API.MAPS={}
for _,game in next,API.GAMES do
    if type(tonumber(game)) == 'number' then
        local maps = {count=0}
        local res,headers = API:GetMaps(game)
        local pages = tonumber(headers['Pagination-Count'])
        maps.count=maps.count+#res
        for _,v in next,res do
            maps[v.ID]=v
        end
        if pages>1 then
            for i=2,pages do
                res,headers = API:GetMaps(game,i)
                maps.count=maps.count+#res
                for _,j in next,res do
                    maps[j.ID]=j
                end
            end
        end
        setmetatable(maps,{__index=function(self,i)
            if i=='count' then return self.count end
            if not tonumber(i) then
                for ix,v in next,self do
                    if type(v)=='table' and v.DisplayName:lower():find(i:lower()) then
                        return v
                    end
                end
            elseif tonumber(i) then
                for ix,v in next,self do
                    if type(v)=='table' and v.ID==i then
                        return v
                    end
                end
            end
        end})
        API.MAPS[game]=maps
        print('map init done for game:',API.GAMES[game],'count:',API.MAPS[game].count)
    end
end