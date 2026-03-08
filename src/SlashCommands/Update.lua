local SlashCommandTools = require('discordia-slash').util.tools()

local UpdateCommand = SlashCommandTools.slashCommand('update', 'Updates the bot')

local OPERATING_SYSTEM = package.loaded.jit.os
local START_FILE_TRANSLATIONS = {
	Windows = {
		FileName = "start.bat",

	},
	Linux = {
		FileName = "start.sh"
	}
}
local WAIT_TRANSLATIONS = {
	Windows = {
		FileName = "timeout /t",
	},
	Linux = {
		FileName = "sleep",
	}
}

local function Callback(Interaction, Command, Args)
	if Interaction.user.id ~= "697004725123416095" then
		return Interaction:reply('You do not have permission to use this command.')
	end

	-- pull
	local GitPullOutputHandle = io.popen("git pull")
	local OutputString = GitPullOutputHandle:read("*a")
	Interaction:reply(OutputString, true)
	GitPullOutputHandle:close()

	-- start the bot after 3 seconds
	local StartFileName = START_FILE_TRANSLATIONS[OPERATING_SYSTEM].FileName
	local WaitString = WAIT_TRANSLATIONS[OPERATING_SYSTEM].FileName
	io.popen(string.format('%s 3 && %s', WaitString, StartFileName)):close()

	os.exit()
end

return {
	Command = UpdateCommand,
	Callback = Callback
}