local discordia=require('discordia')
local commands=require('./../commands.lua')
function dump(a,b,c,d)b=b or 50;d=d or("DUMP START "..tostring(a))c=c or 0;for e,f in next,a do local g;if type(f)=="string"then g="\""..f.."\""else g=tostring(f)end;d=d.."\nD "..string.rep(" ",c*2)..tostring(e)..": "..g;if type(f)=="table"then if c>=b then d=d.." [ ... ]"else d=dump(f,b,c+1,d)end end end;return d end
discordia.extensions()
commands:Add('rank',{},'rank <username|mention|"me"> <game> <style>', function(t)
    -- ok http requests work
    -- for _, v in next, res do
    --     print(v.company.name)
    -- end
end)