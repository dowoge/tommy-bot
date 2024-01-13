local discordia=require('discordia')
local commands=require('./../commands.lua')
discordia.extensions()
function wait(n)local c=os.clock local t=c()while c()-t < n do end;end
commands:Add('restart',{},"restart bot [dev]", function(t)
    if t.message.author==t.t[1].owner then
        t.message:addReaction('👍')
        t.t[1]:stop()
        wait(1.5)
        io.open('restart.txt','w+'):write(t.message.guild.id..','..t.message.channel.id..','..t.message.id):close()
        os.execute('.\\exes\\luvit ./src/main.lua')
    end
end)
commands:Add('leave',{},'leave',function(t)
    if t.message.author==t.t[1].owner then
        t.message:delete()
        local left = t.message.guild:leave()
        if left then
            print('left')
        end
    end
end)