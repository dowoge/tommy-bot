local SlashCommandTools = require('discordia-slash').util.tools()

local CopyMessageCommand = SlashCommandTools.messageCommand('Copy message', 'Says the same exact message (text only)')

local function Callback(Interaction, Command, Message)
	local MessageContent = Message.content
	if MessageContent then
		return Interaction:reply(MessageContent)
	end
end

return {
	Command = CopyMessageCommand,
	Callback = Callback
}