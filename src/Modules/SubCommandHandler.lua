local Discordia = require('discordia')

local ApplicationCommandOptionTypes = Discordia.enums.appCommandOptionType

local SubCommandHandler = {}
SubCommandHandler.__index = SubCommandHandler

function SubCommandHandler.new()
	local self = setmetatable({}, SubCommandHandler)

	self.SubCommandCallbacks = {}

	return self
end

function SubCommandHandler:AddSubCommand(SubCommandName, SubCommandCallback)
	if self.SubCommandCallbacks[SubCommandName] then
		error("Sub-command '" .. SubCommandName .. "' is already registered")
	end

	self.SubCommandCallbacks[SubCommandName] = SubCommandCallback

	return self
end

function SubCommandHandler:GetMainCommandCallback()
	return function(Interaction, Command, Args)
		local SubCommandOption = Command.options[1]
		if SubCommandOption.type == ApplicationCommandOptionTypes.subCommand then
			local SubCommandName = SubCommandOption.name
			local SubCommandCallback = self.SubCommandCallbacks[SubCommandName]
			local SubCommandArgs = Args[SubCommandName]
			if SubCommandCallback then
				SubCommandCallback(Interaction, Command, SubCommandArgs)
			else
				return Interaction:reply("Unknown sub-command: " .. SubCommandName, true)
			end
		end
	end
end

return SubCommandHandler