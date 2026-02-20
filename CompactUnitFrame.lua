local _, ns = ...

--- Batch update frame used to defer frame updates until OnUpdate cycle
local batchFrame = CreateFrame("Frame", nil, UIParent)
batchFrame:Hide()

--- Queue of frames pending value updates
local valueUpdateQueue = {}

--- Queue of frames pending appearance updates
local appearanceUpdateQueue = {}

--- Cache mapping frame → custom shield bar StatusBar
local containers = {}

--- Cache mapping frame → custom overlay bar StatusBar
local overlayContainers = {}

--- Cache mapping frame → last known glow visible state
local glowStateCache = {}

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
	absorb:SetFrameLevel(healthBar:GetFrameLevel() + 1)  -- Layer above health bar
	absorb:SetFrameStrata(healthBar:GetFrameStrata())
	absorb:Hide()

	containers[frame] = absorb
	frame._absorbBar = absorb

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
	overlay:SetReverseFill(true)  -- Fill from right to left
	overlay:SetFrameLevel(healthBar:GetFrameLevel() + 2)  -- Layer above shield bar
	overlay:SetFrameStrata(healthBar:GetFrameStrata())
	overlay:Hide()

	overlayContainers[frame] = overlay
	frame._overlayBar = overlay

	return overlay
end

--- Updates bar values only (cheap operation, batched).
-- Does NOT update appearance - that's handled separately on glow state change.
-- @param frame The compact unit frame to update
local function UpdateFrameValues(frame)
	local unit = frame.displayedUnit
	if not unit or not UnitExists(unit) then return end

	local maxHealth = UnitHealthMax(unit) or 0
	local absorbValue = UnitGetTotalAbsorbs(unit)

	-- Update custom shield bar values
	local absorb = GetOrCreateAbsorb(frame)
	if absorb then
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		absorb:SetShown(frame:IsVisible())
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreateOverlay(frame)
	if overlay then
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		overlay:SetShown(frame:IsVisible())
	end
end

--- Updates appearance for all custom bars and health bar.
-- Called from OnUpdate batch cycle for consistent timing.
-- @param frame The compact unit frame to update
-- @param glowVisible Whether the overAbsorbGlow is currently visible
local function UpdateFrameAppearance(frame, glowVisible)
	local unit = frame.displayedUnit
	if not unit then return end

	-- Update shield bar appearance
	local absorb = containers[frame]
	if absorb then
		ns.ApplyAppearanceToBar(absorb, glowVisible)
	end

	-- Update overlay appearance
	local overlay = overlayContainers[frame]
	if overlay then
		ns.ApplyAppearanceToOverlay(overlay, glowVisible)
	end

	-- Update overAbsorbGlow appearance
	local glow = frame.overAbsorbGlow
	if glow and not glow:IsForbidden() and glowVisible then
		ns.ApplyAppearanceToOverAbsorbGlow(glow)
	end

	-- Update health bar appearance
	if frame.healthBar then
		ns.ApplyAppearanceToHealthBar(frame.healthBar, unit, glowVisible)
	end
end

-- Export for use by AppearanceManager (settings changes)
ns.UpdateFrameAppearance = UpdateFrameAppearance

--- Checks glow state and queues appearance update if changed.
-- @param frame The compact unit frame to check
-- @return glowVisible The current glow state
local function CheckAndUpdateGlowState(frame)
	local glow = frame.overAbsorbGlow
	if not glow or glow:IsForbidden() then return false end

	local glowVisible = glow:IsVisible()
	local previousState = glowStateCache[frame]

	-- Detect state change - queue appearance update
	if previousState ~= glowVisible then
		glowStateCache[frame] = glowVisible
		-- Queue appearance update for next OnUpdate cycle
		if not appearanceUpdateQueue[frame] then
			appearanceUpdateQueue[frame] = true
			batchFrame:Show()
		end
	end

	return glowVisible
end

--- Hook into Blizzard's fill bar update to prevent native absorb bars from interfering.
-- Clears anchor points on protected frames to avoid layout conflicts.
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay or bar == frame.overAbsorbGlow then
		pcall(bar.ClearAllPoints, bar)
	end
end)

--- Hook into Blizzard's health color update to reapply our health bar customizations.
-- This is lightweight - only updates health bar color, not full appearance.
-- Runs after Blizzard resets color so our customization persists.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end
	if not frame or not frame.healthBar or not frame.displayedUnit then return end

	local glow = frame.overAbsorbGlow
	local glowVisible = glow and not glow:IsForbidden() and glow:IsVisible()

	-- Lightweight: only apply health bar appearance, not full frame appearance
	ns.ApplyAppearanceToHealthBar(frame.healthBar, frame.displayedUnit, glowVisible)
end)

--- Process queued updates once per frame.
-- Handles both value updates and appearance updates in a single cycle.
batchFrame:SetScript("OnUpdate", function()
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	-- Process appearance updates first (glow state changes)
	for frame in next, appearanceUpdateQueue do
		local glow = frame.overAbsorbGlow
		local glowVisible = glow and not glow:IsForbidden() and glow:IsVisible()
		UpdateFrameAppearance(frame, glowVisible)
	end
	wipe(appearanceUpdateQueue)

	-- Process value updates (cheap)
	for frame in next, valueUpdateQueue do
		UpdateFrameValues(frame)
	end
	wipe(valueUpdateQueue)

	batchFrame:Hide()
end)

--- Queues a compact unit frame for value update and checks glow state.
-- Values are batched; appearance updates happen immediately on glow state change.
-- @param frame The compact unit frame to process
function ns.QueueCompactUnitFrameUpdate(frame)
	if not frame then return end

	-- Check glow state change (triggers immediate appearance update if changed)
	CheckAndUpdateGlowState(frame)

	-- Queue value update (batched for performance)
	if not valueUpdateQueue[frame] then
		valueUpdateQueue[frame] = true
		batchFrame:Show()
	end
end

--- Forces appearance update for a frame (used by settings changes).
-- Queues for next OnUpdate cycle to maintain consistent batching.
-- @param frame The compact unit frame to update
function ns.ForceAppearanceUpdate(frame)
	if not frame then return end
	if not appearanceUpdateQueue[frame] then
		appearanceUpdateQueue[frame] = true
		batchFrame:Show()
	end
end
