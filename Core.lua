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
		local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
		if profile and profile.anchorModeShielded == "health_right" then
			ns.EnforceNativeAbsorbVisibility(frame, profile)
		end

		--@alpha@
		ns.Debug.Inc("hookFires")
		--@end-alpha@
		ns.QueueCompactUnitFrameUpdate(frame)
	end)

	-- Initial appearance pass to style any frames already visible when loading.
	-- Defer to next frame to ensure frame containers are fully initialized.
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			ns.UpdateAllFrameAppearances()
		end)
	end
end
