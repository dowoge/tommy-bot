local SlashCommandTools = require('discordia-slash').util.tools()

local PongCommand = SlashCommandTools.slashCommand('ping', 'Replies with pong')

local MessageOption = SlashCommandTools.string('message', 'What the bot will append to the message')

PongCommand:addOption(MessageOption)

local function Callback(Interaction, Command, Args)
	local Message = Args.message
	return Interaction:reply('Pong! '..Message)
end

return {
	Command = PongCommand,
	Callback = Callback
}