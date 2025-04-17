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

-- Slash command to open the options
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function()
	OvershieldsReforged:OpenOptions()
end
