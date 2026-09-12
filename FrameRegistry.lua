local _, ns = ...

--- Cache mapping frame → custom shield bar StatusBar
local containers = {}

--- Cache mapping frame → custom overlay bar StatusBar
local overlayContainers = {}

--- Exports caches for use by AppearanceManager
ns.absorbCache = containers
ns.overlayCache = overlayContainers

--- Creates or retrieves a custom StatusBar for a compact unit frame.
-- @param cache The cache table to read/write
-- @param frame The compact unit frame
-- @param levelOffset Frame level offset from healthBar (0 = absorb, 1 = overlay)
-- @return StatusBar frame, or nil if healthBar unavailable
function ns.GetOrCreateBar(cache, frame, levelOffset)
	if cache[frame] then
		--@alpha@
		ns.Emit("barReuses")
		--@end-alpha@
		return cache[frame]
	end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	--@alpha@
	ns.Emit("barCreates")
	--@end-alpha@

	local bar = ns.CreateFrame("StatusBar", nil, healthBar)
	bar:SetAllPoints(healthBar)
	bar:SetReverseFill(true)
	bar:SetFrameLevel(healthBar:GetFrameLevel() + levelOffset)
	bar:Hide()
	-- Track anchor mode for conditional positioning
	bar._anchorMode = "default"

	cache[frame] = bar

	return bar
end

--- Releases all custom bars, hiding them and clearing both container caches.
-- Also restores all previously managed frames to vanilla Blizzard behavior.
-- Called on profile change or hibernation to ensure a clean slate.
function ns.ReleaseAllBars()
	local frames = {}
	for frame in ns.next, containers do
		frames[frame] = true
	end
	for frame in ns.next, overlayContainers do
		frames[frame] = true
	end

	for frame in ns.next, frames do
		ns.HideCustomBars(frame, ns.StyleCache)
		ns.RestoreNativeAbsorbVisuals(frame, ns.StyleCache)
	end

	-- Clear all caches
	ns.wipe(containers)
	ns.wipe(overlayContainers)
	ns.ResetUpdateQueue()
end

--- Removes cache entries for frames that no longer display a unit or are hidden.
-- Restores frames to vanilla Blizzard behavior before removing from cache.
-- Safe to call periodically to prevent stale entries from accumulating.
function ns.CleanupStaleCacheEntries()
	local framesToClean = {}
	for frame in ns.next, containers do
		if ns.FrameIsForbidden(frame) or not frame.displayedUnit or not frame:IsShown() then
			framesToClean[frame] = true
		end
	end
	for frame in ns.next, overlayContainers do
		if ns.FrameIsForbidden(frame) or not frame.displayedUnit or not frame:IsShown() then
			framesToClean[frame] = true
		end
	end

	for frame in ns.next, framesToClean do
		ns.ReleaseFrame(frame, ns.StyleCache)
		if containers[frame] then
			containers[frame] = nil
		end
		if overlayContainers[frame] then
			overlayContainers[frame] = nil
		end
	end
end

local cleanupEventFrame = ns.CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cleanupEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
cleanupEventFrame:SetScript("OnEvent", function()
	ns.CleanupStaleCacheEntries()
end)

