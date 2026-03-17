local _, ns = ...

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local GetTime = GetTime
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
local CACHE_CLEANUP_INTERVAL = 5
local lastCleanupAt = 0

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

local function SuppressNativeAbsorbVisuals(frame)
	if not frame then
		return
	end

	local nativeAbsorb = frame.totalAbsorb
	if nativeAbsorb and not nativeAbsorb:IsForbidden() then
		nativeAbsorb:Hide()
		if nativeAbsorb.overlay and not nativeAbsorb.overlay:IsForbidden() then
			nativeAbsorb.overlay:Hide()
		end
	end

	local nativeOverlay = frame.totalAbsorbOverlay
	if nativeOverlay and not nativeOverlay:IsForbidden() then
		nativeOverlay:Hide()
	end
end

function ns.EnforceNativeAbsorbVisibility(frame, profile)
	if not frame or frame:IsForbidden() then
		return
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		return
	end

	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then
		return
	end

	local glow = frame.overAbsorbGlow
	local glowVisible = glow and not glow:IsForbidden() and glow:IsVisible() or false
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
	ns.HideCustomBars(frame)
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
	ns.Debug.Inc("anchorModeChanges")
	--@end-alpha@

	bar._anchorMode = targetMode
	bar:ClearAllPoints()
	ns.ApplyAnchorStrategy(bar, frame, healthBar, targetMode, healthTexture)
end

local function ApplyCustomBars(frame, profile, healthBar, unit, shieldState, glowVisible)
	local _, maxHealth = healthBar:GetMinMaxValues()
	local absorbValue = UnitGetTotalAbsorbs(unit) or 0
	local frameVisible = frame:IsVisible()
	local healthTexture = healthBar:GetStatusBarTexture()
	local targetMode = ns.NormalizeAnchorMode(ns.ResolveAnchorMode(profile, shieldState), healthTexture)

	-- Update custom shield bar values using state-specific anchor modes.
	local absorb = GetOrCreate(containers, frame, 0)
	if absorb then
		UpdateBarAnchor(absorb, frame, healthBar, targetMode, healthTexture)
		absorb:SetShown(frameVisible)
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		ns.ApplyAppearanceToBar(absorb, glowVisible, profile)
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreate(overlayContainers, frame, 1)
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
-- Note: IsFrameContextEnabled check is done at queue time, not here.
-- @param frame The compact unit frame to update
-- @param profile The active db.profile table
-- @return true if the frame was processed (or intentionally skipped), false if unready for retry
local function HandleCompactUnitFrameUpdate(frame, profile)
	if not frame or frame:IsForbidden() then
		return true
	end

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

	local shieldState = ns.ResolveShieldState(frame, glowVisible)
	local useNativeVisualOnly = ns.ShouldUseNativeVisualOnly(profile, shieldState)

	if useNativeVisualOnly then
		ApplyNativeVisualOnlyShielded(frame, profile)
		return true
	end

	SuppressNativeAbsorbVisuals(frame)
	ApplyCustomBars(frame, profile, healthBar, unit, shieldState, glowVisible)

	return true
end

--- Process queued frame updates once per cycle.
-- Frames whose healthBar is not yet available are retried on subsequent cycles
-- up to MAX_RETRIES times before being dropped.
batchFrame:SetScript("OnUpdate", function()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then return end

	local now = GetTime()
	if now - lastCleanupAt >= CACHE_CLEANUP_INTERVAL then
		ns.CleanupStaleCacheEntries()
		lastCleanupAt = now
	end

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
	if not frame or frame:IsForbidden() then
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
