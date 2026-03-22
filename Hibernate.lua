local _, ns = ...

--- Runtime hibernate state. When true, all hot-path processing is skipped.
ns.hibernating = false

--- Manual override: nil = auto, true = force hibernate, false = force active.
ns.hibernateOverride = nil

--- Computes whether the addon should auto-hibernate based on current context.
-- Returns true when there is no useful work for the addon to do.
local function ComputeAutoHibernateState()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then
		return true
	end

	-- Stay active while in combat — shields matter most here.
	if ns.InCombatLockdown() then
		return false
	end

	-- Stay active while War Mode is enabled (world PvP shields).
	if C_PvP and C_PvP.IsWarModeActive and C_PvP.IsWarModeActive() then
		return false
	end

	-- Stay active while inside an instance (dungeon, raid, arena, bg).
	if ns.IsInInstance() then
		return false
	end

	-- In a raid group: defer to the Raid frame toggle.
	if ns.IsInRaid() then
		return not ns.IsSettingEnabled(profile.enableRaid)
	end

	-- In a non-raid group: defer to the Party frame toggle.
	if ns.IsInGroup() then
		return not ns.IsSettingEnabled(profile.enableParty)
	end

	-- Solo, out of combat, no War Mode, not in an instance → hibernate.
	return true
end

local function FormatHibernateSource()
	if ns.hibernateOverride == true then
		return "manual"
	elseif ns.hibernateOverride == false then
		return "manual override"
	end
	return "auto"
end

--- Evaluates hibernate state and performs transitions when the effective state changes.
-- Safe to call frequently; no-ops when the state hasn't changed.
function ns.EvaluateHibernation()
	local autoState = ComputeAutoHibernateState()

	-- Apply manual override when set.
	local effective
	if ns.hibernateOverride == true then
		effective = true
	elseif ns.hibernateOverride == false then
		effective = false
	else
		effective = autoState
	end

	--@alpha@
	ns.Debug.Inc("hibernateEvals")
	--@end-alpha@

	if effective == ns.hibernating then
		return
	end

	--@alpha@
	ns.Debug.Inc("hibernateTransitions")
	--@end-alpha@

	ns.hibernating = effective

	if effective then
		-- Entering hibernation: release everything to save CPU and memory.
		if ns.ReleaseAllBars then
			ns.ReleaseAllBars()
		end
		if ns.wipeStyleCache then
			ns.wipeStyleCache()
		end
		OvershieldsReforged:Print("Hibernate: |cffff8800On|r (" .. FormatHibernateSource() .. ")")
	else
		-- Waking from hibernation: rebuild frame appearances.
		OvershieldsReforged:Print("Hibernate: |cff00ff00Off|r (" .. FormatHibernateSource() .. ")")
		if ns.UpdateAllFrameAppearances then
			ns.UpdateAllFrameAppearances()
		end
	end
end

--- Sets the manual hibernate override and re-evaluates.
-- @param value true = force hibernate, false = force active, nil = return to auto
function ns.SetHibernateOverride(value)
	ns.hibernateOverride = value
	ns.EvaluateHibernation()
end

--- Event frame that triggers hibernate re-evaluation on context changes.
local hibernateEventFrame = ns.CreateFrame("Frame")
hibernateEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
hibernateEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hibernateEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
hibernateEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
hibernateEventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
hibernateEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
hibernateEventFrame:SetScript("OnEvent", function()
	ns.EvaluateHibernation()
end)
