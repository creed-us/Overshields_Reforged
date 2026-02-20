local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

function OvershieldsReforged:OnInitialize()
	self:InitializeDatabase()
	self:SetupOptions()
end

function OvershieldsReforged:OnEnable()
	-- Register chat commands via AceConsole.
	self:RegisterChatCommand("overshieldsreforged", "HandleSlashCommand")
	self:RegisterChatCommand("osr", "HandleSlashCommand")

	-- Hook Bliz's heal-prediction.
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		ns.QueueCompactUnitFrameUpdate(frame)
	end)
end

--- Handles slash commands.
function OvershieldsReforged:HandleSlashCommand(input)
	local command = strtrim(input):lower()

	if command == "version" or command == "v" then
		self:Print("Version: " .. C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
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
		self:Print("/osr options (o) - Open the addon options.")
		self:Print("/osr reset (r) - Reset all settings to default and reload the UI.")
	end
end
