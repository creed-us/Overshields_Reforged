local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

function OvershieldsReforged:OnInitialize()
	self:InitializeDatabase()
	self:SetupOptions()
end

function OvershieldsReforged:OnEnable()
	self:RegisterChatCommand("overshieldsreforged", "HandleSlashCommand")
	self:RegisterChatCommand("osr", "HandleSlashCommand")

	-- Hook Bliz's heal-prediction.
    hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		if ns.hibernating then return end

		if not OvershieldsReforged:IsFrameContextEnabled(frame) then
			ns.ReleaseFrame(frame, ns.StyleCache)
			return
		end

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
	-- Defer to allow frame containers to fully initialize.
	-- Evaluate hibernation AFTER initial appearance pass to ensure proper state.
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			-- First evaluate hibernation state
			if ns.EvaluateHibernation then
				ns.EvaluateHibernation()
			end
			-- If not hibernating, update frame appearances
			if not ns.hibernating then
				ns.UpdateAllFrameAppearances()
			end
		end)
	else
		-- Fallback for clients without C_Timer
		if ns.EvaluateHibernation then
			ns.EvaluateHibernation()
		end
		if not ns.hibernating then
			ns.UpdateAllFrameAppearances()
		end
	end

	-- Re-apply appearance after Blizzard UI refreshes
	if not self._appearanceEventFrame then
		self._appearanceEventFrame = CreateFrame("Frame")
		self._appearanceEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		self._appearanceEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		self._appearanceEventFrame:SetScript("OnEvent", function()
			if ns.hibernating then return end
			ns.UpdateAllFrameAppearances()
		end)
	end
end
