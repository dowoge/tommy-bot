local discordia=require('discordia')
discordia.extensions()
local commands={command_list={}}
setmetatable(commands.command_list,{__index=function(self,index)
    for i,v in pairs(self) do
        for i2,v2 in pairs(v.alias) do
            if v2==index then
                return self[i]
            end
        end
    end
    return nil
end})
function commands:Add(name,alias,desc,exec)
    name=type(name)=='string' and name or ('Command'..#self.command_list)
    self.command_list[name]={
        name=name,
        alias=type(alias)=='table'and alias or {'None'},
        desc=type(desc)=='string'and desc or ('No description provided'),
        exec=type(exec)=='function'and exec or function(message)
            return message:reply('No command assigned')
        end
    }
    return self.command_list[name]
end
function commands:Get(name)
    return self.command_list[name]
end
function commands:INIT()
    for file in io.popen([[dir "./src/modules/commands" /b]]):lines() do require('./commands/'..file) end
    print('commands done')
end

return commands