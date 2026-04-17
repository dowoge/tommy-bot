local SlashCommandTools = require('discordia-slash').util.tools()

local CopyMessageCommand = SlashCommandTools.messageCommand('Copy message', 'Says the same exact message (text only)')

local function Callback(Interaction, Command, Message)
	local MessageContent = Message and Message.content
	if MessageContent and MessageContent ~= '' then
		return Interaction:reply(MessageContent)
	end
	return Interaction:reply('Nothing to copy', true)
end

return {
	Command = CopyMessageCommand,
	Callback = Callback
}