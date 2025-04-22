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
		ns.HandleCompactUnitFrame_Update(frame)
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
	else
		print("Usage:")
		print("/osr version (v) - Display the addon version.")
		print("/osr options (o) - Open the addon options.")
	end
end
