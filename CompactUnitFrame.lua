local _, ns = ...

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local wipe = wipe
local next = next

--- Batch update frame used to defer frame updates until OnUpdate cycle
local batchFrame = CreateFrame("Frame", nil, UIParent)
batchFrame:Hide()

--- Queue of frames pending updates in current batch
local updateQueue = {}

--- Cache mapping frame → custom shield bar StatusBar
local containers = {}

--- Cache mapping frame → custom overlay bar StatusBar
local overlayContainers = {}

--- Tracks how many batch cycles each unready frame has been retried
local retryCount = {}

--- Maximum OnUpdate cycles to retry an unready frame before dropping it
local MAX_RETRIES = 10

--- Exports caches for use by AppearanceManager
ns.absorbCache = containers
ns.overlayCache = overlayContainers

--- Creates or retrieves a custom StatusBar for a compact unit frame.
-- @param cache The cache table to read/write
-- @param frame The compact unit frame
-- @param levelOffset Frame level offset from healthBar (0 = absorb, 1 = overlay)
-- @return StatusBar frame, or nil if healthBar unavailable
local function GetOrCreate(cache, frame, levelOffset)
	if cache[frame] then
		--@alpha@
		ns.Debug.Inc("barReuses")
		--@end-alpha@
		return cache[frame]
	end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	--@alpha@
	ns.Debug.Inc("barCreates")
	--@end-alpha@

	local bar = CreateFrame("StatusBar", nil, healthBar)
	bar:SetAllPoints(healthBar)
	bar:SetReverseFill(true)
	bar:SetFrameLevel(healthBar:GetFrameLevel() + levelOffset)
	bar:Hide()
	-- Track anchor mode for conditional positioning
	bar._anchorMode = "default"

	cache[frame] = bar

	return bar
end

local function ResolveShieldState(frame, glowVisible)
	if glowVisible then
		return "overshielded"
	end

	local nativeAbsorb = frame and frame.totalAbsorb
	if nativeAbsorb and not nativeAbsorb:IsForbidden() and nativeAbsorb:IsShown() then
		return "shielded"
	end

	local nativeOverlay = frame and frame.totalAbsorbOverlay
	if nativeOverlay and not nativeOverlay:IsForbidden() and nativeOverlay:IsShown() then
		return "shielded"
	end

	return "unshielded"
end

local function ResolveAnchorMode(profile, shieldState)
	if not profile then
		return "default"
	end

	if shieldState == "overshielded" then
		return profile.anchorModeOvershielded or "frame_right"
	end

	if shieldState == "shielded" then
		return profile.anchorModeShielded or "health_right"
	end

	return "default"
end

local function ShouldUseNativeVisualOnly(profile, shieldState)
	return profile
		and shieldState == "shielded"
		and profile.anchorModeShielded == "health_right"
end

--- Updates the anchor and fill direction for a bar based on overshield state and user setting.
-- Uses condition-specific anchor mode settings for shielded and overshielded states.
-- @param bar The StatusBar to update
-- @param frame The compact unit frame
-- @param healthBar The parent health bar
-- @param shieldState One of: "unshielded", "shielded", "overshielded"
-- @param profile The active db.profile table
local function UpdateBarAnchor(bar, frame, healthBar, shieldState, profile)
	if not bar or not frame or not healthBar then return end

	local targetMode = ResolveAnchorMode(profile, shieldState)
	local healthTexture = healthBar:GetStatusBarTexture()
	if targetMode ~= "health_left"
		and targetMode ~= "health_right"
		and targetMode ~= "frame_left"
		and targetMode ~= "frame_right" then
		targetMode = "default"
	end

	if (targetMode == "health_left" or targetMode == "health_right") and not healthTexture then
		targetMode = "default"
	end

	if bar._anchorMode == targetMode then
		return
	end

	--@alpha@
	ns.Debug.Inc("anchorModeChanges")
	--@end-alpha@

	bar._anchorMode = targetMode
	bar:ClearAllPoints()

	if targetMode == "health_left" then
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(true)
	elseif targetMode == "health_right" then
		bar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(false)
	elseif targetMode == "frame_left" then
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(false)
	elseif targetMode == "frame_right" then
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(true)
	else
		bar:SetAllPoints(healthBar)
		bar:SetReverseFill(true)
	end
end

--- Updates a compact unit frame with current absorb bar values and glow state.
-- Synchronizes bar values with unit API and glow visibility.
-- Appearance is managed exclusively by AppearanceManager.
-- Note: IsFrameContextEnabled check is done at queue time, not here.
-- @param frame The compact unit frame to update
-- @param profile The active db.profile table
-- @return true if the frame was processed (or intentionally skipped), false if unready for retry
local function HandleCompactUnitFrameUpdate(frame, profile)
	local unit = frame.displayedUnit
	if not unit or not UnitExists(unit) then
		--@alpha@
		ns.Debug.Inc("earlyExits")
		--@end-alpha@
		return true
	end

	local glow = frame.overAbsorbGlow
	if not glow or glow:IsForbidden() then
		--@alpha@
		ns.Debug.Inc("earlyExits")
		--@end-alpha@
		return true
	end

	local glowVisible = glow:IsVisible()
	if (glowVisible) then
		ns.ApplyAppearanceToOverAbsorbGlow(glow, profile)
	end

	local healthBar = frame.healthBar
	if not healthBar then
		--@alpha@
		ns.Debug.Inc("earlyExits")
		--@end-alpha@
		return false
	end

	--@alpha@
	ns.Debug.Inc("frameUpdates")
	--@end-alpha@

	local shieldState = ResolveShieldState(frame, glowVisible)
	local useNativeVisualOnly = ShouldUseNativeVisualOnly(profile, shieldState)

	if useNativeVisualOnly then
		ns.HideCustomBars(frame)
		ns.ApplyAppearanceToNativeBar(frame.totalAbsorb, false, profile)
		ns.ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, false, profile)
		return true
	end

	local _, maxHealth = healthBar:GetMinMaxValues()
	local absorbValue = UnitGetTotalAbsorbs(unit) or 0

	-- Update custom shield bar values using state-specific anchor modes.
	local absorb = GetOrCreate(containers, frame, 0)
	if absorb then
		UpdateBarAnchor(absorb, frame, healthBar, shieldState, profile)
		absorb:SetShown(frame:IsVisible())
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		ns.ApplyAppearanceToBar(absorb, glowVisible, profile)
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreate(overlayContainers, frame, 1)
	if overlay then
		UpdateBarAnchor(overlay, frame, healthBar, shieldState, profile)
		overlay:SetShown(frame:IsVisible())
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		ns.ApplyAppearanceToOverlay(overlay, glowVisible, profile)
	end

	return true
end

--- Hook into Bliz's fill bar update to prevent native absorb bars from interfering.
-- Clears anchor points on non-forbidden frames to suppress the native bar layout.
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		return
	end

	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then
		return
	end

	local glow = frame and frame.overAbsorbGlow
	local glowVisible = glow and not glow:IsForbidden() and glow:IsVisible() or false
	if profile.anchorModeShielded == "health_right" and not glowVisible then
		return
	end

	if bar == frame.overAbsorbGlow or bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay then
		if bar and not bar:IsForbidden() then
			bar:ClearAllPoints()
			--@alpha@
			ns.Debug.Inc("nativeBarsSuppressed")
			--@end-alpha@
		end
	end
end)

--- Process queued frame updates once per cycle.
-- Frames whose healthBar is not yet available are retried on subsequent cycles
-- up to MAX_RETRIES times before being dropped.
batchFrame:SetScript("OnUpdate", function()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then return end

	--@alpha@
	local batchSize = 0
	--@end-alpha@

	local hasRetries = false

	for frame in next, updateQueue do
		local success = HandleCompactUnitFrameUpdate(frame, profile)
		--@alpha@
		batchSize = batchSize + 1
		--@end-alpha@

		if success then
			--@alpha@
			if retryCount[frame] then ns.Debug.Inc("retrySuccesses") end
			--@end-alpha@
			updateQueue[frame] = nil
			retryCount[frame] = nil
		else
			local count = (retryCount[frame] or 0) + 1
			--@alpha@
			ns.Debug.Inc("retryAttempts")
			--@end-alpha@
			if count >= MAX_RETRIES then
				updateQueue[frame] = nil
				retryCount[frame] = nil
				--@alpha@
				ns.Debug.Inc("retryDrops")
				--@end-alpha@
			else
				retryCount[frame] = count
				hasRetries = true
			end
		end
	end

	--@alpha@
	ns.Debug.Inc("batchCycles")
	ns.Debug.Inc("batchFramesTotal", batchSize)
	ns.Debug.Max("peakBatchSize", batchSize)
	--@end-alpha@

	if not hasRetries then
		wipe(updateQueue)
		batchFrame:Hide()
	end
end)

--- Queues a compact unit frame for appearance update.
-- Frames are batched and processed during the next OnUpdate cycle for efficiency.
-- @param frame The compact unit frame to queue for update
function ns.QueueCompactUnitFrameUpdate(frame)
	if not frame then
		return
	end

	--@alpha@
	ns.Debug.Inc("queueAttempts")
	--@end-alpha@

	if updateQueue[frame] then
		--@alpha@
		ns.Debug.Inc("queueSkipsDuplicate")
		--@end-alpha@
		return
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		ns.HideCustomBars(frame)
		--@alpha@
		ns.Debug.Inc("queueSkipsDisabled")
		--@end-alpha@
		return
	end

	--@alpha@
	ns.Debug.Inc("queueAdds")
	--@end-alpha@

	updateQueue[frame] = true
	batchFrame:Show()
end

--- Releases all custom bars, hiding them and clearing both container caches.
-- Called on profile change to ensure a clean slate.
function ns.ReleaseAllBars()
	for _, bar in next, containers do
		bar:Hide()
	end
	wipe(containers)

	for _, bar in next, overlayContainers do
		bar:Hide()
	end
	wipe(overlayContainers)

	wipe(retryCount)
end

--- Removes cache entries for frames that no longer display a unit or are hidden.
-- Safe to call periodically to prevent stale entries from accumulating.
function ns.CleanupStaleCacheEntries()
	for frame, bar in next, containers do
		if not frame.displayedUnit or not frame:IsShown() then
			bar:Hide()
			containers[frame] = nil
		end
	end

	for frame, bar in next, overlayContainers do
		if not frame.displayedUnit or not frame:IsShown() then
			bar:Hide()
			overlayContainers[frame] = nil
		end
	end
end

local cleanupEventFrame = CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cleanupEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
cleanupEventFrame:SetScript("OnEvent", function()
	ns.CleanupStaleCacheEntries()
end)
