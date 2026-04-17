local SlashCommandTools = require('discordia-slash').util.tools()

local PongCommand = SlashCommandTools.slashCommand('ping', 'Replies with pong')

local MessageOption = SlashCommandTools.string('message', 'What the bot will append to the message')

PongCommand:addOption(MessageOption)

local function Callback(Interaction, Command, Args)
	local Message = Args and Args.message or ''
	-- pass `true` as the second arg to Interaction:reply to make replies ephemeral
	return Interaction:reply('Pong! ' .. Message)
end

return {
	Command = PongCommand,
	Callback = Callback
}