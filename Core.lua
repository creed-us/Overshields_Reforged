local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

function OvershieldsReforged:OnInitialize()
	-- Initialize database and options
	self:InitializeDatabase()
	self:SetupOptions()
	-- Hook Blizzard's heal-prediction functions
	hooksecurefunc("UnitFrameHealPredictionBars_Update", function(frame)
		ns.HandleUnitFrameUpdate(frame)
	end)
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		ns.QueueCompactUnitFrameUpdate(frame)
	end)
end

-- Slash command handler
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function(input)
	local args = { strsplit(" ", input) }
	local command = args[1] and args[1]:lower() or nil

	if command == "version" or command == "v" then
		print("Overshields Reforged version: " .. C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
	elseif command == "options" or command == "o" then
        OvershieldsReforged:OpenOptions()
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
		print("Usage:")
		print("/osr version (v) - Display the addon version.")
		print("/osr options (o) - Open the addon options.")
		print("/osr reset (r) - Reset all settings to default and reload the UI.")
	end
end
