local SlashCommandTools = require('discordia-slash').util.tools()
local StrafesNET = require('../Modules/StrafesNET.lua')

local FasteAuditCommand = SlashCommandTools.slashCommand('fasteaudit', 'Audits faste role members for world record eligibility')
local CleanupOption = SlashCommandTools.boolean('cleanup', 'Remove Discord faste role from ineligible users')
FasteAuditCommand:addOption(CleanupOption)

local GROUP_ID = "2607715"
local MODE_ID = 0
local AUTOHOP_WR_THRESHOLD = 10
local OTHER_STYLE_WR_THRESHOLD = 50
local ALLOWED_USER_ID = "697004725123416095"

local ALL_STYLES = {}
for _, StyleId in next, StrafesNET.BhopStyles do
	ALL_STYLES[StyleId] = true
end
for _, StyleId in next, StrafesNET.SurfStyles do
	ALL_STYLES[StyleId] = true
end

local SORTED_STYLES = {}
for StyleId in next, ALL_STYLES do
	table.insert(SORTED_STYLES, StyleId)
end
table.sort(SORTED_STYLES)

local function Pad(String, Padding)
	Padding = Padding or 20
	String = tostring(String)
	return String .. string.rep(" ", math.max(0, Padding - #String))
end

local function GetFasteRoleId()
	local _, Body = StrafesNET.GetGroupRoles(GROUP_ID)
	if not Body or not Body.roles then
		error("Failed to fetch group roles")
	end
	local FasteId, FasteRank
	local MemberRoleId
	local LowestRank
	for _, Role in next, Body.roles do
		if Role.name and Role.name:lower() == "faste" then
			FasteId = Role.id
			FasteRank = Role.rank
		end
		local RoleRank = Role.rank or 0
		if RoleRank > 0 and (LowestRank == nil or RoleRank < LowestRank) then
			MemberRoleId = Role.id
			LowestRank = RoleRank
		end
	end
	if not FasteId then
		error("Could not find the 'faste' role in group " .. GROUP_ID)
	end
	return FasteId, FasteRank, MemberRoleId
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

local function MergeStyleCounts(GameStyleCounts)
	local Merged = {}
	for _, StyleCounts in next, GameStyleCounts do
		for StyleId, Count in next, StyleCounts do
			Merged[StyleId] = (Merged[StyleId] or 0) + Count
		end
	end
	return Merged
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

local function FormatTopStyle(StyleCounts)
	local BestStyleId, BestCount = nil, 0
	for _, StyleId in next, SORTED_STYLES do
		local Count = StyleCounts[StyleId] or 0
		if Count > BestCount then
			BestStyleId = StyleId
			BestCount = Count
		end
	end
	if not BestStyleId then return "None" end
	return StrafesNET.StylesString[BestStyleId] .. ": " .. BestCount
end

local function Callback(Interaction, Command, Args)
	if Interaction.user.id ~= ALLOWED_USER_ID then
		return Interaction:reply("You do not have permission to use this command.", true)
	end

	Interaction:replyDeferred()
	Args = Args or {}

	local RoleSetId, FasteRoleRank, MemberRoleId = GetFasteRoleId()
	local Members = StrafesNET.GetAllGroupRoleMembers(GROUP_ID, RoleSetId)

	if #Members == 0 then
		return Interaction:reply("No members found with the faste role.")
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
			local Entry = {Username = Username, DisplayName = DisplayName, UserId = UserId, StyleCounts = MergeStyleCounts(GameStyleCounts), IsEligible = IsEligible, EligibilityReason = EligibilityReason}

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

	local function FormatEntry(Entry)
		local UserString = Entry.DisplayName .. " (@" .. Entry.Username .. ")"
		local Status = Entry.IsEligible and "ELIGIBLE" or "NOT ELIGIBLE"
		if Entry.IsEligible and Entry.EligibilityReason then
			Status = Status .. " (" .. Entry.EligibilityReason .. ")"
		end
		return Pad(UserString, 46) .. " | " .. Pad(FormatTopStyle(Entry.StyleCounts), 20) .. " | " .. Status .. "\n"
	end

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
			if (GameId == 1 or GameId == 2) and WR.user then
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
						StyleCounts = MergeStyleCounts(GameStyleCounts),
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
								GroupRoleRank = GroupEntry.role and GroupEntry.role.rank
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
				FinalText = FinalText .. Pad(UserString, 46) .. " | " .. Pad(FormatTopStyle(Entry.StyleCounts), 20) .. " | " .. Entry.UnavailableReason .. "\n"
			end
			FinalText = FinalText .. "\n"
		end
	end

	-- Cleanup: Roblox role management + Discord role removal (when cleanup = true)
	if Args.cleanup then
		-- Roblox demotions (ineligible users)
		local RobloxChangeLines = {}
		if MemberRoleId then
			for _, Entry in next, IneligibleLines do
				local Ok, Headers = pcall(StrafesNET.UpdateGroupMemberRole, GROUP_ID, Entry.UserId, tostring(MemberRoleId))
				if Ok and Headers and tonumber(Headers.code) and tonumber(Headers.code) < 400 then
					table.insert(RobloxChangeLines, Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "] | Demoted to Member")
				else
					local ErrMsg = Ok and ("HTTP " .. tostring(Headers.code)) or tostring(Headers)
					table.insert(RobloxChangeLines, Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "] | Demotion failed: " .. ErrMsg)
				end
			end
		end

		-- Roblox promotions (eligible discovered candidates in group with lower role)
		if not DiscoveryFailed then
			for _, Entry in next, DiscoveryLines do
				local Ok, Headers = pcall(StrafesNET.UpdateGroupMemberRole, GROUP_ID, Entry.UserId, tostring(RoleSetId))
				if Ok and Headers and tonumber(Headers.code) and tonumber(Headers.code) < 400 then
					table.insert(RobloxChangeLines, Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "] | Promoted to Faste")
				else
					local ErrMsg = Ok and ("HTTP " .. tostring(Headers.code)) or tostring(Headers)
					table.insert(RobloxChangeLines, Entry.DisplayName .. " (@" .. Entry.Username .. ") [" .. Entry.UserId .. "] | Promotion failed: " .. ErrMsg)
				end
			end
		end

		if #RobloxChangeLines > 0 then
			FinalText = FinalText .. "--- ROBLOX ROLE CHANGES ---\n"
			for _, Line in next, RobloxChangeLines do
				FinalText = FinalText .. Line .. "\n"
			end
			FinalText = FinalText .. "\n"
		end
	end

	local FileName = "./fasteaudit-output.txt"
	local FileHandle = io.open(FileName, "w+")
	FileHandle:write(FinalText)
	FileHandle:close()

	Interaction:reply({ file = FileName })

	os.remove(FileName)
end

return {
	Command = FasteAuditCommand,
	Callback = Callback
}
