local SlashCommandTools = require('discordia-slash').util.tools()
local StrafesNET = require('../Modules/StrafesNET.lua')
local Owners = require('../Modules/Owners.lua')
local Format = require('../Modules/Format.lua')
local Pad = Format.Pad

local FasteAuditCommand = SlashCommandTools.slashCommand('fasteaudit', 'Audits faste role members for world record eligibility')
local CleanupOption = SlashCommandTools.boolean('cleanup', 'Perform Roblox and Discord role changes')
local DryRunOption = SlashCommandTools.boolean('dryrun', 'Preview cleanup changes without applying them')
FasteAuditCommand:addOption(CleanupOption)
FasteAuditCommand:addOption(DryRunOption)

local GROUP_ID = "2607715"
local MODE_ID = 0
local AUTOHOP_WR_THRESHOLD = 10
local OTHER_STYLE_WR_THRESHOLD = 50
local ALLOWED_USER_ID = Owners.BotOwner
local BHOP_SERVER_ID = "167423382697148416"
local AUDIT_LOG_CHANNEL_ID = "1491857353174290565"
local DISCORD_FASTE_ROLE_ID = "167799859309445120"

local ALL_STYLES = {}
for _, StyleId in next, StrafesNET.BhopStyles do
	ALL_STYLES[StyleId] = true
end
for _, StyleId in next, StrafesNET.SurfStyles do
	ALL_STYLES[StyleId] = true
end

local function GetFasteRoleId()
	local Headers, Body = StrafesNET.GetGroupRoles(GROUP_ID)
	if not Body or not Body.roles then
		error("Failed to fetch group roles (HTTP " .. tostring(Headers and Headers.code) .. ")")
	end
	local FasteId, FasteRank
	local BhopperRoleId
	for _, Role in next, Body.roles do
		if Role.name then
			local LoweredName = Role.name:lower()
			if LoweredName == "faste" then
				FasteId = Role.id
				FasteRank = tonumber(Role.rank)
			elseif LoweredName == "bhopper" then
				BhopperRoleId = Role.id
			end
		end
	end
	if not FasteId then
		error("Could not find the 'faste' role in group " .. GROUP_ID)
	end
	return FasteId, FasteRank, BhopperRoleId
end

local VALID_GAME_IDS = {
	[StrafesNET.GameIds.BHOP] = true,
	[StrafesNET.GameIds.SURF] = true,
}

local function GetUserWorldRecordCounts(UserId)
	local GameStyleCounts = {}

	local Records, ErrorMsg = StrafesNET.GetAllUserWorldRecords(UserId, nil, MODE_ID)
	if ErrorMsg then
		return nil, ErrorMsg
	end
	for _, Record in next, Records do
		local GameId = tonumber(Record.game_id)
		if VALID_GAME_IDS[GameId] then
			if not GameStyleCounts[GameId] then GameStyleCounts[GameId] = {} end
			local StyleId = tonumber(Record.style_id)
			GameStyleCounts[GameId][StyleId] = (GameStyleCounts[GameId][StyleId] or 0) + 1
		end
	end

	return GameStyleCounts, nil
end

local function CheckEligibility(GameStyleCounts)
	for GameId, StyleCounts in next, GameStyleCounts do
		local GameName = StrafesNET.GameIdsString[GameId]
		local AutohopCount = StyleCounts[StrafesNET.Styles.AUTOHOP] or 0
		if AutohopCount >= AUTOHOP_WR_THRESHOLD then
			return true, GameName .. " Autohop: " .. AutohopCount .. " WRs"
		end

		for StyleId in next, ALL_STYLES do
			if StyleId ~= StrafesNET.Styles.AUTOHOP then
				local Count = StyleCounts[StyleId] or 0
				if Count >= OTHER_STYLE_WR_THRESHOLD then
					return true, GameName .. " " .. StrafesNET.StylesString[StyleId] .. ": " .. Count .. " WRs"
				end
			end
		end
	end

	return false, nil
end

local function FormatWRCounts(GameStyleCounts)
	if not GameStyleCounts then return "" end
	local Parts = {}
	for GameId, StyleCounts in next, GameStyleCounts do
		local GameName = StrafesNET.GameIdsString[GameId] or ("Game " .. GameId)
		for StyleId, Count in next, StyleCounts do
			local StyleName = StrafesNET.StylesString[StyleId] or ("Style " .. StyleId)
			Parts[#Parts + 1] = GameName .. " " .. StyleName .. ": " .. Count
		end
	end
	table.sort(Parts)
	return table.concat(Parts, ", ")
end

local function FormatEntry(Entry)
	local UserString = Entry.DisplayName .. " (@" .. Entry.Username .. ")"
	local Status = Entry.IsEligible and "ELIGIBLE" or "NOT ELIGIBLE"
	if Entry.IsEligible and Entry.EligibilityReason then
		Status = Status .. " (" .. Entry.EligibilityReason .. ")"
	elseif not Entry.IsEligible and Entry.GameStyleCounts then
		local CountSummary = FormatWRCounts(Entry.GameStyleCounts)
		if #CountSummary > 0 then
			Status = Status .. " (" .. CountSummary .. ")"
		end
	end
	return Pad(UserString, 46) .. " | " .. Status .. "\n"
end

local OUTCOME_LABELS = {
	Added = "Added faste role",
	Removed = "Removed faste role",
	AlreadyHad = "Already had role",
	AlreadyLacks = "Already lacked role",
	WouldAdd = "Would add faste role",
	WouldRemove = "Would remove faste role",
}

local function ApplyRoleChange(Member, Method, FailLabel)
	local Ok, Success, RoleErr = pcall(Member[Method], Member, DISCORD_FASTE_ROLE_ID)
	if not Ok then
		return false, FailLabel .. ": " .. tostring(Success)
	end
	if Success then
		return true
	end
	return false, FailLabel .. ": " .. tostring(RoleErr)
end

local function SyncDiscordRole(Guild, Entry, Action, DryRun)
	local Result = {
		UserPrefix = Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "]",
		Action = Action,
		LinkLookupOk = true,
		LinkedCount = 0,
		InGuildAlts = {},
	}

	local Ok, DiscordIds = pcall(StrafesNET.GetDiscordIdFromRobloxId, Entry.UserId)
	if not Ok or not DiscordIds then
		Result.LinkLookupOk = false
		return Result
	end

	Result.LinkedCount = #DiscordIds

	for _, DiscordId in next, DiscordIds do
		local Member = Guild:getMember(DiscordId)
		if Member then
			local Alt = { DiscordId = DiscordId }
			local HasRole = Member:hasRole(DISCORD_FASTE_ROLE_ID)
			if Action == "add" then
				if HasRole then
					Alt.Outcome = "AlreadyHad"
				elseif DryRun then
					Alt.Outcome = "WouldAdd"
				else
					local Success, ErrMsg = ApplyRoleChange(Member, "addRole", "Add failed")
					if Success then
						Alt.Outcome = "Added"
					else
						Alt.Outcome = "Failed"
						Alt.ErrorMsg = ErrMsg
					end
				end
			elseif Action == "remove" then
				if not HasRole then
					Alt.Outcome = "AlreadyLacks"
				elseif DryRun then
					Alt.Outcome = "WouldRemove"
				else
					local Success, ErrMsg = ApplyRoleChange(Member, "removeRole", "Remove failed")
					if Success then
						Alt.Outcome = "Removed"
					else
						Alt.Outcome = "Failed"
						Alt.ErrorMsg = ErrMsg
					end
				end
			end
			table.insert(Result.InGuildAlts, Alt)
		end
	end

	return Result
end

local function FormatDiscordRoleResult(Result, DryRun)
	local DryRunPrefix = DryRun and "[DRY RUN] " or ""

	if not Result.LinkLookupOk or Result.LinkedCount == 0 then
		return DryRunPrefix .. Result.UserPrefix .. " | No linked Discord accounts"
	end

	if #Result.InGuildAlts == 0 then
		return DryRunPrefix .. Result.UserPrefix .. " | " .. Result.LinkedCount .. " linked, none in this server"
	end

	if #Result.InGuildAlts == 1 then
		local Alt = Result.InGuildAlts[1]
		if Alt.Outcome == "AlreadyHad" or Alt.Outcome == "AlreadyLacks" then
			return nil
		end
	end

	local Parts = { DryRunPrefix .. Result.UserPrefix }
	for _, Alt in next, Result.InGuildAlts do
		local Label = Alt.ErrorMsg or OUTCOME_LABELS[Alt.Outcome] or Alt.Outcome
		Parts[#Parts + 1] = "<@" .. Alt.DiscordId .. "> " .. Label
	end
	return table.concat(Parts, " | ")
end

local function RunAudit(Guild, Cleanup, DryRun)
	local RoleSetId, FasteRoleRank, BhopperRoleId = GetFasteRoleId()
	local Members = StrafesNET.GetAllGroupRoleMembers(GROUP_ID, RoleSetId)

	if #Members == 0 then
		error("No members found with the faste role. (RoleSetId: " .. tostring(RoleSetId) .. ")")
	end

	local EligibleCount = 0
	local IneligibleCount = 0
	local ErrorCount = 0
	local EligibleLines = {}
	local IneligibleLines = {}
	local ErrorLines = {}

	for _, Member in next, Members do
		local UserId = tostring(Member.userId)
		local Username = Member.username
		local DisplayName = Member.displayName

		local GameStyleCounts, ErrorMsg = GetUserWorldRecordCounts(UserId)

		if ErrorMsg then
			ErrorCount = ErrorCount + 1
			table.insert(ErrorLines, {Username = Username, DisplayName = DisplayName, UserId = UserId, Error = ErrorMsg})
		else
			local IsEligible, EligibilityReason = CheckEligibility(GameStyleCounts)
			local Entry = {Username = Username, DisplayName = DisplayName, UserId = UserId, IsEligible = IsEligible, EligibilityReason = EligibilityReason, GameStyleCounts = GameStyleCounts}

			if IsEligible then
				EligibleCount = EligibleCount + 1
				table.insert(EligibleLines, Entry)
			else
				IneligibleCount = IneligibleCount + 1
				table.insert(IneligibleLines, Entry)
			end
		end
	end

	local FinalText = "Faste role audit for Roblox bhoppers (" .. GROUP_ID .. ")\n"
		.. "Total: " .. #Members .. " | Eligible: " .. EligibleCount .. " | Not Eligible: " .. IneligibleCount .. " | Errors: " .. ErrorCount .. "\n"
		.. "Eligibility: Autohop " .. AUTOHOP_WR_THRESHOLD .. "+ WRs OR any other style " .. OTHER_STYLE_WR_THRESHOLD .. "+ WRs\n\n"

	if #IneligibleLines > 0 then
		FinalText = FinalText .. "--- NOT ELIGIBLE (" .. IneligibleCount .. ") ---\n"
		for _, Entry in next, IneligibleLines do
			FinalText = FinalText .. FormatEntry(Entry)
		end
		FinalText = FinalText .. "\n"
	end

	if #EligibleLines > 0 then
		FinalText = FinalText .. "--- ELIGIBLE (" .. EligibleCount .. ") ---\n"
		for _, Entry in next, EligibleLines do
			FinalText = FinalText .. FormatEntry(Entry)
		end
		FinalText = FinalText .. "\n"
	end

	if #ErrorLines > 0 then
		FinalText = FinalText .. "--- ERRORS (" .. ErrorCount .. ") ---\n"
		for _, Entry in next, ErrorLines do
			FinalText = FinalText .. Pad(Entry.DisplayName .. " (@" .. Entry.Username .. ")", 46) .. " | ERROR: " .. Entry.Error .. "\n"
		end
		FinalText = FinalText .. "\n"
	end

	-- Discovery: find potential new faste candidates from recent WRs (last 30 days)
	local ExistingRobloxIds = {}
	for _, Member in next, Members do
		ExistingRobloxIds[tostring(Member.userId)] = true
	end

	local CandidateIds = {}
	local CandidateUsernames = {}
	local CutoffTime = os.time() - (30 * 24 * 60 * 60)
	local DiscoveryFailed = false
	local Page = 1

	while true do
		local Ok, WRHeaders, WRBody = pcall(StrafesNET.GetRecentWorldRecords, Page)
		if not Ok or not WRBody or not WRBody.data or #WRBody.data == 0 then
			if Page == 1 then DiscoveryFailed = true end
			break
		end

		local PageHasRecent = false
		for _, WR in next, WRBody.data do
			local Year, Month, Day = (WR.date or ""):match("(%d+)-(%d+)-(%d+)")
			local RecordTime = Year and os.time({year = tonumber(Year), month = tonumber(Month), day = tonumber(Day)}) or 0
			if RecordTime < CutoffTime then
				goto ContinueWR
			end

			PageHasRecent = true
			local GameId = tonumber(WR.game_id)
			if VALID_GAME_IDS[GameId] and WR.user then
				local WRUserId = tostring(WR.user.id)
				if not ExistingRobloxIds[WRUserId] and not CandidateIds[WRUserId] then
					CandidateIds[WRUserId] = true
					CandidateUsernames[WRUserId] = WR.user.username or "Unknown"
				end
			end

			::ContinueWR::
		end

		if not PageHasRecent then break end
		Page = Page + 1
	end

	local DiscoveryLines = {}
	if DiscoveryFailed then
		FinalText = FinalText .. "--- POTENTIAL NEW FASTE ---\nFailed to fetch recent world records.\n\n"
	else
		local UnavailableLines = {}
		for CandidateId in next, CandidateIds do
			local GameStyleCounts, ErrorMsg = GetUserWorldRecordCounts(CandidateId)
			if not ErrorMsg then
				local IsEligible, EligibilityReason = CheckEligibility(GameStyleCounts)
				if IsEligible then
					local Username = CandidateUsernames[CandidateId]
					local Entry = {
						Username = Username,
						DisplayName = Username,
						UserId = CandidateId,
						IsEligible = true,
						EligibilityReason = EligibilityReason
					}

					-- Check group membership
					local GroupOk, _, GroupBody = pcall(StrafesNET.GetUserGroups, CandidateId)
					local InGroup = false
					local GroupRoleRank = nil
					local GroupRoleName = nil
					if GroupOk and GroupBody and GroupBody.data then
						for _, GroupEntry in next, GroupBody.data do
							if GroupEntry.group and tostring(GroupEntry.group.id) == GROUP_ID then
								InGroup = true
								GroupRoleRank = GroupEntry.role and tonumber(GroupEntry.role.rank)
								GroupRoleName = GroupEntry.role and GroupEntry.role.name
								break
							end
						end
					end

					if not InGroup then
						Entry.UnavailableReason = "Not in group"
						table.insert(UnavailableLines, Entry)
					elseif GroupRoleRank and FasteRoleRank and GroupRoleRank > FasteRoleRank then
						Entry.UnavailableReason = "Higher role: " .. (GroupRoleName or "Unknown")
						table.insert(UnavailableLines, Entry)
					else
						table.insert(DiscoveryLines, Entry)
					end
				end
			end
		end

		if #DiscoveryLines > 0 then
			FinalText = FinalText .. "--- POTENTIAL NEW FASTE (" .. #DiscoveryLines .. ") ---\n"
			for _, Entry in next, DiscoveryLines do
				FinalText = FinalText .. FormatEntry(Entry)
			end
			FinalText = FinalText .. "\n"
		else
			FinalText = FinalText .. "--- POTENTIAL NEW FASTE ---\nNo new eligible candidates found in recent WRs (last 30 days).\n\n"
		end

		if #UnavailableLines > 0 then
			FinalText = FinalText .. "--- ELIGIBLE BUT UNAVAILABLE (" .. #UnavailableLines .. ") ---\n"
			for _, Entry in next, UnavailableLines do
				local UserString = Entry.DisplayName .. " (@" .. Entry.Username .. ")"
				FinalText = FinalText .. Pad(UserString, 46) .. " | " .. Entry.UnavailableReason .. "\n"
			end
			FinalText = FinalText .. "\n"
		end
	end

	-- Cleanup: Roblox + Discord role management (when cleanup or dryrun = true)
	-- Skip live Roblox changes when the Discord guild is unreachable, otherwise the
	-- Roblox and Discord role state would diverge until the next audit run.
	if Cleanup and not DryRun and not Guild then
		FinalText = FinalText .. "--- CLEANUP SKIPPED ---\nDiscord guild unreachable; Roblox role changes were not applied to keep state in sync.\n\n"
	elseif Cleanup or DryRun then
		local DryRunPrefix = DryRun and "[DRY RUN] " or ""

		-- Roblox demotions (ineligible users)
		local RobloxChangeLines = {}
		if not BhopperRoleId then
			if #IneligibleLines > 0 then
				table.insert(RobloxChangeLines, "Could not find the 'bhopper' role in group " .. GROUP_ID .. "; " .. #IneligibleLines .. " ineligible user(s) not demoted.")
			end
		else
			for _, Entry in next, IneligibleLines do
				local UserPrefix = Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "]"
				if DryRun then
					table.insert(RobloxChangeLines, DryRunPrefix .. UserPrefix .. " | Would demote to Bhopper")
				else
					local Ok, Headers = pcall(StrafesNET.UpdateGroupMemberRole, GROUP_ID, Entry.UserId, tostring(BhopperRoleId))
					if Ok and Headers and tonumber(Headers.code) and tonumber(Headers.code) < 400 then
						table.insert(RobloxChangeLines, UserPrefix .. " | Demoted to Bhopper")
					else
						local ErrMsg = Ok and ("HTTP " .. tostring(Headers.code)) or tostring(Headers)
						table.insert(RobloxChangeLines, UserPrefix .. " | Demotion failed: " .. ErrMsg)
					end
				end
			end
		end

		-- Roblox promotions (eligible discovered candidates in group with lower role)
		if not DiscoveryFailed then
			for _, Entry in next, DiscoveryLines do
				local UserPrefix = Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "]"
				if DryRun then
					table.insert(RobloxChangeLines, DryRunPrefix .. UserPrefix .. " | Would promote to Faste")
				else
					local Ok, Headers = pcall(StrafesNET.UpdateGroupMemberRole, GROUP_ID, Entry.UserId, tostring(RoleSetId))
					if Ok and Headers and tonumber(Headers.code) and tonumber(Headers.code) < 400 then
						table.insert(RobloxChangeLines, UserPrefix .. " | Promoted to Faste")
					else
						local ErrMsg = Ok and ("HTTP " .. tostring(Headers.code)) or tostring(Headers)
						table.insert(RobloxChangeLines, UserPrefix .. " | Promotion failed: " .. ErrMsg)
					end
				end
			end
		end

		if #RobloxChangeLines > 0 then
			FinalText = FinalText .. "--- ROBLOX ROLE CHANGES" .. (DryRun and " (DRY RUN)" or "") .. " ---\n"
			for _, Line in next, RobloxChangeLines do
				FinalText = FinalText .. Line .. "\n"
			end
			FinalText = FinalText .. "\n"
		end

		-- Discord role management
		local DiscordChangeLines = {}

		if Guild then
			local SyncQueue = {}
			for _, Entry in next, IneligibleLines do
				table.insert(SyncQueue, { Entry = Entry, Action = "remove" })
			end
			if not DiscoveryFailed then
				for _, Entry in next, DiscoveryLines do
					table.insert(SyncQueue, { Entry = Entry, Action = "add" })
				end
			end
			for _, Entry in next, EligibleLines do
				table.insert(SyncQueue, { Entry = Entry, Action = "add" })
			end

			local Totals = {
				UsersProcessed = 0, MultiAltUsers = 0, NoLinkUsers = 0, NoInGuildUsers = 0,
				Added = 0, Removed = 0, WouldAdd = 0, WouldRemove = 0,
				AlreadyHad = 0, AlreadyLacks = 0, Failed = 0,
			}

			local EntryLines = {}
			local ProcessedDiscordIds = {}
			for _, Item in next, SyncQueue do
				local Result = SyncDiscordRole(Guild, Item.Entry, Item.Action, DryRun)

				Totals.UsersProcessed = Totals.UsersProcessed + 1
				if not Result.LinkLookupOk or Result.LinkedCount == 0 then
					Totals.NoLinkUsers = Totals.NoLinkUsers + 1
				elseif #Result.InGuildAlts == 0 then
					Totals.NoInGuildUsers = Totals.NoInGuildUsers + 1
				else
					if #Result.InGuildAlts >= 2 then
						Totals.MultiAltUsers = Totals.MultiAltUsers + 1
					end
					for _, Alt in next, Result.InGuildAlts do
						Totals[Alt.Outcome] = (Totals[Alt.Outcome] or 0) + 1
						ProcessedDiscordIds[Alt.DiscordId] = true
					end
				end

				local Line = FormatDiscordRoleResult(Result, DryRun)
				if Line then
					table.insert(EntryLines, Line)
				end
			end

			-- Stale pass: Discord members with the faste role whose linked Roblox is no
			-- longer in the faste group (e.g. manually demoted, left the group). These
			-- never reach the Roblox-first SyncQueue above, so catch them here.
			local StaleTotals = {
				AlreadyProcessed = 0, NoLink = 0, LookupErr = 0,
				InGroupSkipped = 0, Removed = 0, WouldRemove = 0, Failed = 0,
			}
			local FasteRole = Guild:getRole(DISCORD_FASTE_ROLE_ID)
			if FasteRole then
				local Candidates = {}
				for Member in FasteRole.members:iter() do
					if ProcessedDiscordIds[Member.user.id] then
						StaleTotals.AlreadyProcessed = StaleTotals.AlreadyProcessed + 1
					else
						table.insert(Candidates, Member)
					end
				end

				local StaleDryRunPrefix = DryRun and "[DRY RUN] " or ""
				for _, Member in next, Candidates do
					local DiscordId = Member.user.id
					local Ok, Headers, Body = pcall(StrafesNET.GetRobloxInfoFromDiscordId, DiscordId)
					local Code = Headers and tonumber(Headers.code)
					if not Ok then
						StaleTotals.LookupErr = StaleTotals.LookupErr + 1
						table.insert(EntryLines, StaleDryRunPrefix .. "<@" .. DiscordId .. "> | Stale check lookup error: " .. tostring(Headers))
					elseif Code == 404 or (Code == 200 and (not Body or not Body.id)) then
						StaleTotals.NoLink = StaleTotals.NoLink + 1
						table.insert(EntryLines, StaleDryRunPrefix .. "<@" .. DiscordId .. "> | Has faste role but no linked Roblox account")
					elseif Code ~= 200 then
						StaleTotals.LookupErr = StaleTotals.LookupErr + 1
						table.insert(EntryLines, StaleDryRunPrefix .. "<@" .. DiscordId .. "> | Stale check lookup error: HTTP " .. tostring(Code))
					else
						local LinkedRobloxId = tostring(Body.id)
						if ExistingRobloxIds[LinkedRobloxId] then
							StaleTotals.InGroupSkipped = StaleTotals.InGroupSkipped + 1
							table.insert(EntryLines, StaleDryRunPrefix .. "<@" .. DiscordId .. "> | Linked to in-group Roblox [" .. LinkedRobloxId .. "], skipped stale removal")
						else
							local LinkedLabel = (Body.name or LinkedRobloxId) .. " [" .. LinkedRobloxId .. "]"
							if DryRun then
								StaleTotals.WouldRemove = StaleTotals.WouldRemove + 1
								table.insert(EntryLines, StaleDryRunPrefix .. "<@" .. DiscordId .. "> | Would remove stale faste role (linked to " .. LinkedLabel .. ")")
							else
								local Success, ErrMsg = ApplyRoleChange(Member, "removeRole", "Remove failed")
								if Success then
									StaleTotals.Removed = StaleTotals.Removed + 1
									table.insert(EntryLines, "<@" .. DiscordId .. "> | Removed stale faste role (linked to " .. LinkedLabel .. ")")
								else
									StaleTotals.Failed = StaleTotals.Failed + 1
									table.insert(EntryLines, "<@" .. DiscordId .. "> | Stale removal failed: " .. tostring(ErrMsg))
								end
							end
						end
					end
				end
			end

			table.insert(DiscordChangeLines, string.format(
				"Summary: %d users | %d multi-alt | +%d -%d (%d would-add %d would-remove) | %d failed | %d already had / %d already lacked | %d no link | %d no in-guild alts",
				Totals.UsersProcessed, Totals.MultiAltUsers,
				Totals.Added, Totals.Removed, Totals.WouldAdd, Totals.WouldRemove,
				Totals.Failed, Totals.AlreadyHad, Totals.AlreadyLacks,
				Totals.NoLinkUsers, Totals.NoInGuildUsers
			))
			table.insert(DiscordChangeLines, string.format(
				"Stale pass: %d skipped (processed) | %d no-link | %d lookup-err | %d in-group skipped | %d removed | %d would-remove | %d failed",
				StaleTotals.AlreadyProcessed, StaleTotals.NoLink, StaleTotals.LookupErr,
				StaleTotals.InGroupSkipped, StaleTotals.Removed, StaleTotals.WouldRemove, StaleTotals.Failed
			))
			for _, Line in next, EntryLines do
				table.insert(DiscordChangeLines, Line)
			end
		else
			table.insert(DiscordChangeLines, "Could not find bhop Discord server")
		end

		if #DiscordChangeLines > 0 then
			FinalText = FinalText .. "--- DISCORD ROLE CHANGES" .. (DryRun and " (DRY RUN)" or "") .. " ---\n"
			for _, Line in next, DiscordChangeLines do
				FinalText = FinalText .. Line .. "\n"
			end
			FinalText = FinalText .. "\n"
		end
	end

	local FileName = "./fasteaudit-output-" .. os.time() .. ".txt"
	local FileHandle, OpenError = io.open(FileName, "w+")
	if not FileHandle then
		error("Failed to open " .. FileName .. " for writing: " .. tostring(OpenError))
	end
	FileHandle:write(FinalText)
	FileHandle:close()

	return FileName
end

local function Callback(Interaction, Command, Args)
	if Interaction.user.id ~= ALLOWED_USER_ID then
		return Interaction:reply("You do not have permission to use this command.", true)
	end

	Interaction:replyDeferred()
	Args = Args or {}

	local Guild = Interaction.client:getGuild(BHOP_SERVER_ID)
	local FileName = RunAudit(Guild, Args.cleanup, Args.dryrun)

	Interaction:reply({ file = FileName })
	os.remove(FileName)
end

return {
	Command = FasteAuditCommand,
	Callback = Callback,
	RunAudit = RunAudit,
	BHOP_SERVER_ID = BHOP_SERVER_ID,
	ALLOWED_USER_ID = ALLOWED_USER_ID,
	AUDIT_LOG_CHANNEL_ID = AUDIT_LOG_CHANNEL_ID,
}
