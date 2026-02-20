local _, ns = ...

--- Batch update frame used to defer frame updates until OnUpdate cycle
local batchFrame = CreateFrame("Frame", nil, UIParent)
batchFrame:Hide()

--- Queue of frames pending updates in current batch
local updateQueue = {}

--- Cache mapping frame → custom shield bar StatusBar
local containers = {}

--- Cache mapping frame → custom overlay bar StatusBar
local overlayContainers = {}

--- Exports caches for use by AppearanceManager
ns.absorbCache = containers
ns.overlayCache = overlayContainers

--- Creates or retrieves the custom shield bar for a compact unit frame.
-- @param frame The compact unit frame to process
-- @return StatusBar frame for absorb display, or nil if healthBar unavailable
local function GetOrCreateAbsorb(frame)
	if containers[frame] then
		return containers[frame]
	end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	local absorb = CreateFrame("StatusBar", nil, healthBar)
	absorb:SetAllPoints(healthBar)
	absorb:SetReverseFill(true)
	absorb:SetFrameLevel(healthBar:GetFrameLevel())
	absorb:SetFrameStrata(healthBar:GetFrameStrata())
	absorb:Hide()

	containers[frame] = absorb

	return absorb
end

--- Creates or retrieves the custom overlay bar for a compact unit frame.
-- @param frame The compact unit frame to process
-- @return StatusBar frame for overlay display, or nil if healthBar unavailable
local function GetOrCreateOverlay(frame)
	if overlayContainers[frame] then
		return overlayContainers[frame]
	end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	local overlay = CreateFrame("StatusBar", nil, healthBar)
	overlay:SetAllPoints(healthBar)
	overlay:SetReverseFill(true)
	overlay:SetFrameLevel(healthBar:GetFrameLevel() + 1)
	overlay:SetFrameStrata(healthBar:GetFrameStrata())
	overlay:Hide()

	overlayContainers[frame] = overlay

	return overlay
end

--- Updates a compact unit frame with current absorb bar values and glow state.
-- Synchronizes bar values with unit API and glow visibility.
-- Appearance is managed exclusively by AppearanceManager.
-- @param frame The compact unit frame to update
local function HandleCompactUnitFrameUpdate(frame)
	local unit = frame.displayedUnit
	if not unit or not UnitExists(unit) then return end

	local glow = frame.overAbsorbGlow
	if not glow or glow:IsForbidden() then return end

	local glowVisible = glow:IsVisible()
	if (glowVisible) then
		ns.ApplyAppearanceToOverAbsorbGlow(glow)
	end
	local maxHealth = UnitHealthMax(unit) or 0
	local absorbValue = UnitGetTotalAbsorbs(unit)

	-- Update custom shield bar values
	local absorb = GetOrCreateAbsorb(frame)
	if absorb then
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		absorb:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToBar(absorb, glowVisible)
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreateOverlay(frame)
	if overlay then
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		overlay:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToOverlay(overlay, glowVisible)
	end
end

--- Hook into Bliz's fill bar update to prevent native absorb bars from interfering.
-- Clears anchor points on non-forbidden frames to suppress the native bar layout.
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay or bar == frame.overAbsorbGlow then
		if bar and not bar:IsForbidden() then
			bar:ClearAllPoints()
		end
	end
end)

--- Process queued frame updates once per cycle.
batchFrame:SetScript("OnUpdate", function()
	local db = OvershieldsReforged.db.profile
	if not db then return end

	for frame in next, updateQueue do
		HandleCompactUnitFrameUpdate(frame)
	end

	wipe(updateQueue)
	batchFrame:Hide()
end)

--- Queues a compact unit frame for appearance update.
-- Frames are batched and processed during the next OnUpdate cycle for efficiency.
-- @param frame The compact unit frame to queue for update
function ns.QueueCompactUnitFrameUpdate(frame)
	if not frame or updateQueue[frame] then return end
	updateQueue[frame] = true
	batchFrame:Show()
end
