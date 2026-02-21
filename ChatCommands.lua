local ADDON_NAME, _ = ...

local addon = OvershieldsReforged
if not addon then
	return
end

local function IsSettingEnabled(value)
	return value ~= false
end

--- Handles slash commands.
function addon:HandleSlashCommand(input)
	local commandLine = strtrim(input or ""):lower()
	local command, argument = strsplit(" ", commandLine, 2)
	command = command or ""
	argument = strtrim(argument or "")

	if command == "version" or command == "v" then
		self:Print("Version: " .. C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
	elseif command == "perf" or command == "p" then
		if argument == "reset" then
			self:ResetPerformanceStats()
			self:Print("Performance counters reset.")
		else
			self:PrintPerformanceStats()
		end
	elseif command == "status" or command == "s" then
		local profile = self.db and self.db.profile
		if not profile then
			self:Print("Status unavailable (database not initialized).")
			return
		end

		self:Print("Party: " .. (IsSettingEnabled(profile.enableParty) and "On" or "Off"))
		self:Print("Raid: " .. (IsSettingEnabled(profile.enableRaid) and "On" or "Off"))
		self:Print("Pets: " .. (IsSettingEnabled(profile.enablePets) and "On" or "Off"))
	elseif command == "options" or command == "o" then
		self:Print("Opening options...")
		self:OpenOptions()
	elseif command == "reset" or command == "r" then
		StaticPopupDialogs["OVERSHIELDS_REFORGED_RESET"] = {
			text = "This will reset all Overshields Reforged settings to default and reload the UI. Proceed?",
			button1 = ACCEPT,
			button2 = CANCEL,
			OnAccept = function()
				OvershieldsReforgedDB = nil
				ReloadUI()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("OVERSHIELDS_REFORGED_RESET")
	else
		self:Print("Usage:")
		self:Print("/osr version (v) - Display the addon version.")
		self:Print("/osr perf (p) - Show performance diagnostics.")
		self:Print("/osr perf reset - Reset performance diagnostics counters.")
		self:Print("/osr status (s) - Show enable and frame-scope settings.")
		self:Print("/osr options (o) - Open the addon options.")
		self:Print("/osr reset (r) - Reset all settings to default and reload the UI.")
	end
end