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
        --@alpha@
        if ns.Debug then ns.Debug.Inc("hookFires") end
        --@end-alpha@
        ns.QueueCompactUnitFrameUpdate(frame)
    end)
end
