local SlashCommandTools = require('discordia-slash').util.tools()

local UpdateCommand = SlashCommandTools.slashCommand('update', 'Updates the bot')

local OPERATING_SYSTEM = package.loaded.jit.os
local START_FILE_TRANSLATIONS = {
	Windows = {
		FileName = "start.bat",
		RestartCommand = 'start "" cmd /c "(timeout /t 3 /nobreak > NUL && call .\\start.bat)"'
	},
	Linux = {
		FileName = "start.sh",
		RestartCommand = 'sh -c "(sleep 3; nohup sh ./start.sh >/dev/null 2>&1 &) "'
	}
}

local function Callback(Interaction, Command, Args)
	if Interaction.user.id ~= "697004725123416095" then
		return Interaction:reply('You do not have permission to use this command.')
	end

	local PlatformConfig = START_FILE_TRANSLATIONS[OPERATING_SYSTEM]
	if not PlatformConfig then
		return Interaction:reply('Unsupported operating system.', true)
	end

	-- pull
	local GitPullOutputHandle = io.popen("git pull")
	local OutputString = GitPullOutputHandle:read("*a")
	Interaction:reply(OutputString, true)
	GitPullOutputHandle:close()

	if OutputString == "Already up to date.\n" then
		return
	end

	-- start the bot after 3 seconds in a detached process so it survives this process exiting
	local RestartHandle = io.popen(PlatformConfig.RestartCommand)
	if RestartHandle then
		RestartHandle:close()
	else
		return Interaction:followUp('Failed to schedule restart.', true)
	end

	os.exit()
end

return {
	Command = UpdateCommand,
	Callback = Callback
}