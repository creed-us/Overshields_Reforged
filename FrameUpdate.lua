local _, ns = ...

local function SuppressNativeAbsorbVisuals(frame)
	if not frame then
		return
	end

	--@alpha@
	ns.Emit("nativeBarsSuppressed")
	--@end-alpha@

	local nativeAbsorb = frame.totalAbsorb
	if not ns.FrameIsForbidden(nativeAbsorb) then
		nativeAbsorb:Hide()
		if not ns.FrameIsForbidden(nativeAbsorb.overlay) then
			nativeAbsorb.overlay:Hide()
		end
	end

	local nativeOverlay = frame.totalAbsorbOverlay
	if not ns.FrameIsForbidden(nativeOverlay) then
		nativeOverlay:Hide()
	end
end

function ns.IsKnownCompactUnitFrame(frame)
	if ns.FrameIsForbidden(frame) then
		return false
	end

	local frameName = frame.GetName and frame:GetName()
	if frameName then
		if ns.string_find(frameName, "CompactPartyFrameMember", 1, true) == 1
			or ns.string_find(frameName, "CompactRaidFramePet", 1, true) == 1
			or ns.string_find(frameName, "CompactPartyFramePet", 1, true) == 1
			or ns.string_find(frameName, "CompactRaidFrame", 1, true) == 1 then
			return true
		end
	end

	-- If Blizzard's containers ever aren't loaded, comparing an
	-- unparented frame against them would be nil == nil, and every
	-- frame in the UI would look like one of ours.
	local parent = frame.GetParent and frame:GetParent()
	if parent and (parent == CompactPartyFrame or parent == CompactRaidFrameContainer) then
		return true
	end

	-- Raid frames under the "Separate Groups" display modes are nested an extra level.
	local grandparent = parent and parent.GetParent and parent:GetParent()
	if grandparent and grandparent == CompactRaidFrameContainer then
		return true
	end

	return false
end

function ns.EnforceNativeAbsorbVisibility(frame, profile)
	if ns.FrameIsForbidden(frame) or not ns.IsKnownCompactUnitFrame(frame) then
		return
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		return
	end

	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then
		return
	end

	local glowVisible = ns.IsGlowVisible(frame)
	if glowVisible then
		SuppressNativeAbsorbVisuals(frame)
		return
	end

	local shieldState = ns.ResolveShieldState(frame, glowVisible)
	if not ns.ShouldUseNativeVisualOnly(db, shieldState) then
		SuppressNativeAbsorbVisuals(frame)
	end
end

local function ApplyNativeVisualOnlyShielded(frame, profile)
	ns.HideCustomBars(frame, ns.StyleCache)
	ns.ApplyAppearanceToNativeBar(frame.totalAbsorb, false, profile)
	ns.ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, false, profile)
end

--- Updates the anchor and fill direction for a bar based on overshield state and user setting.
-- Uses condition-specific anchor mode settings for shielded and overshielded states.
-- @param bar The StatusBar to update
-- @param frame The compact unit frame
-- @param healthBar The parent health bar
-- @param targetMode Normalized anchor mode string
-- @param healthTexture The health bar status bar texture (or nil)
local function UpdateBarAnchor(bar, frame, healthBar, targetMode, healthTexture)
	if not bar or not frame or not healthBar then return end

	if bar._anchorMode == targetMode then
		return
	end

	--@alpha@
	ns.Emit("anchorModeChanges")
	--@end-alpha@

	bar._anchorMode = targetMode
	bar:ClearAllPoints()
	ns.ApplyAnchorStrategy(bar, frame, healthBar, targetMode, healthTexture)
end

local function ApplyCustomBars(frame, profile, healthBar, unit, shieldState, glowVisible, absorbValue)
	local _, maxHealth = healthBar:GetMinMaxValues()
	absorbValue = absorbValue or (ns.UnitGetTotalAbsorbs(unit) or 0)
	local frameVisible = frame:IsVisible()
	local healthTexture = healthBar:GetStatusBarTexture()
	local targetMode = ns.NormalizeAnchorMode(ns.ResolveAnchorMode(profile, shieldState), healthTexture)

	-- Update custom shield bar values using state-specific anchor modes.
	local absorb = ns.GetOrCreateBar(ns.absorbCache, frame, 0)
	if absorb then
		UpdateBarAnchor(absorb, frame, healthBar, targetMode, healthTexture)
		absorb:SetShown(frameVisible)
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		ns.ApplyAppearanceToBar(absorb, glowVisible, profile)
	end

	-- Update custom overlay bar values
	local overlay = ns.GetOrCreateBar(ns.overlayCache, frame, 1)
	if overlay then
		UpdateBarAnchor(overlay, frame, healthBar, targetMode, healthTexture)
		overlay:SetShown(frameVisible)
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		ns.ApplyAppearanceToOverlay(overlay, glowVisible, profile)
	end
end

--- Updates a compact unit frame with current absorb bar values and glow state.
-- Synchronizes bar values with unit API and glow visibility.
-- Appearance is managed exclusively by AppearanceManager.
-- Note: re-checks IsFrameContextEnabled even though QueueCompactUnitFrameUpdate already
-- checked it at queue time — a toggle can flip between queueing and batch processing.
-- @param frame The compact unit frame to update
-- @param profile The active db.profile table
-- @return true if the frame was processed (or intentionally skipped), false if unready for retry
function ns.ProcessQueuedFrame(frame, profile)
	if ns.FrameIsForbidden(frame) then
		return true
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		ns.ReleaseFrame(frame, ns.StyleCache)
		return true
	end

	local unit = frame.displayedUnit
	if not unit or not ns.UnitExists(unit) then
		--@alpha@
		ns.Emit("earlyExits")
		--@end-alpha@
		return true
	end

	local glow = frame.overAbsorbGlow
	if ns.FrameIsForbidden(glow) then
		--@alpha@
		ns.Emit("earlyExits")
		--@end-alpha@
		return true
	end

	local glowVisible = glow:IsVisible()
	if glowVisible then
		ns.ApplyAppearanceToOverAbsorbGlow(glow, profile)
	end

	local absorbValue = ns.UnitGetTotalAbsorbs(unit) or 0

	local healthBar = frame.healthBar
	if not healthBar then
		--@alpha@
		ns.Emit("earlyExits")
		--@end-alpha@
		return false
	end

	--@alpha@
	ns.Emit("frameUpdates")
	--@end-alpha@

	local shieldState = ns.ResolveShieldState(frame, glowVisible)
	local useNativeVisualOnly = ns.ShouldUseNativeVisualOnly(profile, shieldState)

	if useNativeVisualOnly then
		ApplyNativeVisualOnlyShielded(frame, profile)
		return true
	end

	SuppressNativeAbsorbVisuals(frame)
	ApplyCustomBars(frame, profile, healthBar, unit, shieldState, glowVisible, absorbValue)

	return true
end
