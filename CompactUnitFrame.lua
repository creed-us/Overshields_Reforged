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

local function HideCustomBars(frame)
	local absorb = containers[frame]
	if absorb then
		absorb:Hide()
	end

	local overlay = overlayContainers[frame]
	if overlay then
		overlay:Hide()
	end
end

--- Creates or retrieves a custom StatusBar for a compact unit frame.
-- @param cache The cache table to read/write
-- @param frame The compact unit frame
-- @param levelOffset Frame level offset from healthBar (0 = absorb, 1 = overlay)
-- @return StatusBar frame, or nil if healthBar unavailable
local function GetOrCreate(cache, frame, levelOffset)
	if cache[frame] then return cache[frame] end

	local healthBar = frame.healthBar
	if not healthBar then return nil end

	local bar = CreateFrame("StatusBar", nil, healthBar)
	bar:SetAllPoints(healthBar)
	bar:SetReverseFill(true)
	bar:SetFrameLevel(healthBar:GetFrameLevel() + levelOffset)
	bar:SetFrameStrata(healthBar:GetFrameStrata())
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
local function UpdateBarAnchor(bar, healthBar, glowVisible)
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	local useHealthAnchor = db.anchorShieldToHealth and not glowVisible

	-- Fast-fail: default mode is most common (dynamic anchoring disabled)
	if not useHealthAnchor then
		if bar._anchorMode ~= "default" then
			bar._anchorMode = "default"
			bar:ClearAllPoints()
			bar:SetAllPoints(healthBar)
			bar:SetReverseFill(true)
		end
		return
	end

	local useTextureAnchor = db.anchorToHealthTexture and useHealthAnchor

	if useTextureAnchor then
		-- Texture mode: layout engine tracks anchor automatically
		if bar._anchorMode == "texture" then
			return
		end
		local healthTexture = healthBar:GetStatusBarTexture()
		if healthTexture then
			bar._anchorMode = "texture"
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
			bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
			bar:SetReverseFill(false)
		end
	else
		-- Pixel mode: must update offset each frame since health changes
		local healthTexture = healthBar:GetStatusBarTexture()
		local offset = healthTexture and healthTexture:GetWidth() or 0
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", offset, 0)
		bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		if bar._anchorMode ~= "health" then
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
local function HandleCompactUnitFrameUpdate(frame)
	local unit = frame.displayedUnit
	if not unit or not UnitExists(unit) then return end

	local glow = frame.overAbsorbGlow
	if not glow or glow:IsForbidden() then return end

	local glowVisible = glow:IsVisible()
	if (glowVisible) then
		ns.ApplyAppearanceToOverAbsorbGlow(glow)
	end

	local healthBar = frame.healthBar
	if not healthBar then return end

	-- Get max health from healthBar
	local _, maxHealth = healthBar:GetMinMaxValues()
	local absorbValue = UnitGetTotalAbsorbs(unit) or 0

	-- Update custom shield bar values
	-- Note: In health-anchor mode, shield fills proportionally to maxHealth within the
	-- missing health area. This is a visual compromise to avoid secret number arithmetic.
	local absorb = GetOrCreate(containers, frame, 0)
	if absorb then
		UpdateBarAnchor(absorb, healthBar, glowVisible)
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorbValue)
		absorb:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToBar(absorb, glowVisible)
	end

	-- Update custom overlay bar values
	local overlay = GetOrCreate(overlayContainers, frame, 1)
	if overlay then
		UpdateBarAnchor(overlay, healthBar, glowVisible)
		overlay:SetMinMaxValues(0, maxHealth)
		overlay:SetValue(absorbValue)
		overlay:SetShown(frame:IsVisible())
		ns.ApplyAppearanceToOverlay(overlay, glowVisible)
	end
end

--- Hook into Bliz's fill bar update to prevent native absorb bars from interfering.
-- Clears anchor points on non-forbidden frames to suppress the native bar layout.
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		return
	end

	if bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay or bar == frame.overAbsorbGlow then
		if bar and not bar:IsForbidden() then
			bar:ClearAllPoints()
		end
	end
end)

--- Process queued frame updates once per cycle.
batchFrame:SetScript("OnUpdate", function()
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
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
	if not frame then
		return
	end

	if updateQueue[frame] then
		return
	end

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		HideCustomBars(frame)
		return
	end

	updateQueue[frame] = true
	batchFrame:Show()
end
