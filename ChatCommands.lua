local ADDON_NAME, ns = ...

local addon = OvershieldsReforged
if not addon then
	return
end

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

--- Handles slash commands.
function addon:HandleSlashCommand(input)
	local commandLine = strtrim(input or ""):lower()
	local command, argument = strsplit(" ", commandLine, 2)
	command = command or ""
	argument = strtrim(argument or "")

	if command == "version" or command == "v" then
        self:Print("Version: " .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"))
        return
	end

    if command == "status" or command == "s" then
        local profile = self.db and self.db.profile
        if not profile then
            self:Print("Status unavailable (database not initialized).")
            return
        end

        self:Print("Party: " .. (ns.IsSettingEnabled(profile.enableParty) and "On" or "Off"))
        self:Print("Raid: " .. (ns.IsSettingEnabled(profile.enableRaid) and "On" or "Off"))
        self:Print("Pets: " .. (ns.IsSettingEnabled(profile.enablePets) and "On" or "Off"))
        return
    end

	if command == "options" or command == "o" then
        self:OpenOptions()
		return
	end

	if command == "reset" or command == "r" then
        StaticPopup_Show("OVERSHIELDS_REFORGED_RESET")
        return
	end

	--@alpha@
	if command == "debug" or command == "d" then
        ns.Debug:Toggle()
        return
	end
	--@end-alpha@

	self:Print("Usage:")
	self:Print("/osr version (v) - Display the addon version.")
	self:Print("/osr status (s) - Show enable and frame-scope settings.")
	self:Print("/osr options (o) - Open the addon options.")
	self:Print("/osr reset (r) - Reset all settings to default and reload the UI.")
	--@alpha@
	self:Print("/osr debug (d) - Toggle the debug diagnostics window.")
	--@end-alpha@
end
