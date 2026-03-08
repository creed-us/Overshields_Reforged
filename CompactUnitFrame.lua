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
		if ns.Debug then ns.Debug.Inc("barReuses") end
		--@end-alpha@
		return cache[frame]
	end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	--@alpha@
	if ns.Debug then ns.Debug.Inc("barCreates") end
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

--- Updates the anchor and fill direction for a bar based on overshield state and user setting.
-- Uses pixel-based positioning from healthBar texture to avoid secret number arithmetic (Midnight 11.1+).
-- @param bar The StatusBar to update
-- @param healthBar The parent health bar
-- @param glowVisible true when unit has overshield
-- @param profile The active db.profile table
local function UpdateBarAnchor(bar, healthBar, glowVisible, profile)
	if not profile then return end

	local useHealthAnchor = profile.anchorShieldToHealth and not glowVisible

	-- Default mode is most common (dynamic anchoring disabled)
	if not useHealthAnchor then
		if bar._anchorMode ~= "default" then
			--@alpha@
			if ns.Debug then ns.Debug.Inc("anchorModeChanges") end
			--@end-alpha@
			bar._anchorMode = "default"
			bar:ClearAllPoints()
			bar:SetAllPoints(healthBar)
			bar:SetReverseFill(true)
		end
		return
	end

	local useTextureAnchor = profile.anchorToHealthTexture and useHealthAnchor

	if useTextureAnchor then
		if bar._anchorMode == "texture" then
			return
		end
		local healthTexture = healthBar:GetStatusBarTexture()
		if healthTexture then
			--@alpha@
			if ns.Debug then ns.Debug.Inc("anchorModeChanges") end
			--@end-alpha@
			bar._anchorMode = "texture"
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
			bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
			bar:SetReverseFill(false)
		end
	else
		local healthTexture = healthBar:GetStatusBarTexture()
		local offset = healthTexture and healthTexture:GetWidth() or 0
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", offset, 0)
		bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		if bar._anchorMode ~= "health" then
			--@alpha@
			if ns.Debug then ns.Debug.Inc("anchorModeChanges") end
			--@end-alpha@
			bar:SetReverseFill(false)
			bar._anchorMode = "health"
		end
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
		if ns.Debug then ns.Debug.Inc("earlyExits") end
		--@end-alpha@
		return true
	end

	local glow = frame.overAbsorbGlow
	if not glow or glow:IsForbidden() then
		--@alpha@
		if ns.Debug then ns.Debug.Inc("earlyExits") end
		--@end-alpha@
		return true
	end

	local glowVisible = glow:IsVisible()
	if (glowVisible) then
		ns.ApplyAppearanceToOverAbsorbGlow(glow)
	end

	local healthBar = frame.healthBar
	if not healthBar then
		--@alpha@
		if ns.Debug then ns.Debug.Inc("earlyExits") end
		--@end-alpha@
		return false
	end

	--@alpha@
	if ns.Debug then ns.Debug.Inc("frameUpdates") end
	--@end-alpha@

	-- Get max health from healthBar
	local _, maxHealth = healthBar:GetMinMaxValues()
	local absorbValue = UnitGetTotalAbsorbs(unit) or 0

	-- Update custom shield bar values
	-- Note: In health-anchor mode, shield fills proportionally to maxHealth within the
	-- missing health area. This is a visual compromise to avoid secret number arithmetic.
	local absorb = GetOrCreate(containers, frame, 0)
	if absorb then
		UpdateBarAnchor(absorb, healthBar, glowVisible, profile)
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		absorb:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToBar(absorb, glowVisible)
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreate(overlayContainers, frame, 1)
	if overlay then
		UpdateBarAnchor(overlay, healthBar, glowVisible, profile)
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		overlay:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToOverlay(overlay, glowVisible)
	end

	return true
end

--- Hook into Bliz's fill bar update to prevent native absorb bars from interfering.
-- Clears anchor points on non-forbidden frames to suppress the native bar layout.
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		return
	end

	if bar == frame.overAbsorbGlow or bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay then
		if bar and not bar:IsForbidden() then
			bar:ClearAllPoints()
			--@alpha@
			if ns.Debug then ns.Debug.Inc("nativeBarsSuppressed") end
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
			if ns.Debug and retryCount[frame] then ns.Debug.Inc("retrySuccesses") end
			--@end-alpha@
			updateQueue[frame] = nil
			retryCount[frame] = nil
		else
			local count = (retryCount[frame] or 0) + 1
			--@alpha@
			if ns.Debug then ns.Debug.Inc("retryAttempts") end
			--@end-alpha@
			if count >= MAX_RETRIES then
				updateQueue[frame] = nil
				retryCount[frame] = nil
				--@alpha@
				if ns.Debug then ns.Debug.Inc("retryDrops") end
				--@end-alpha@
			else
				retryCount[frame] = count
				hasRetries = true
			end
		end
	end

	--@alpha@
	if ns.Debug then
		ns.Debug.Inc("batchCycles")
		ns.Debug.Inc("batchFramesTotal", batchSize)
		ns.Debug.Max("peakBatchSize", batchSize)
	end
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
	if ns.Debug then ns.Debug.Inc("queueAttempts") end
	--@end-alpha@

	if updateQueue[frame] then
		--@alpha@
		if ns.Debug then ns.Debug.Inc("queueSkipsDuplicate") end
		--@end-alpha@
		return
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		ns.HideCustomBars(frame)
		--@alpha@
		if ns.Debug then ns.Debug.Inc("queueSkipsDisabled") end
		--@end-alpha@
		return
	end

	--@alpha@
	if ns.Debug then ns.Debug.Inc("queueAdds") end
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
