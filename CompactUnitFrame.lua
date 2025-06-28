local _, ns = ...
local batchFrame = CreateFrame("Frame", nil, UIParent)
batchFrame:Hide()
local updateQueue = {}

-- Anchor layouts
-- anchor0, anchor1, *offsetX, *offsetY
local AnchorLayouts = {
	OvershieldTick_MissingHealth = {
		{ "TOPLEFT", "TOPRIGHT", -7, 0 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", -7, 0 },
	},
	OvershieldTick_FullHealth = {
		{ "TOPLEFT", "TOPLEFT", -7, 0 },
		{ "BOTTOMLEFT", "BOTTOMLEFT", -7, 0 },
	},
	ShieldOverlay_MissingHealth = {
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
	},
	ShieldOverlay_FullHealth = {
		{ "TOPRIGHT", "TOPRIGHT" },
		{ "BOTTOMRIGHT","BOTTOMRIGHT" },
	},
	ShieldBar_MissingHealth = {
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
	},
	ShieldBar_FullHealth = {
		{ "TOPRIGHT", "TOPRIGHT" },
		{ "BOTTOMRIGHT","BOTTOMRIGHT" },
	},
}

local function ApplyPoints(region, targetFrame, layoutKey)
	if not region or not targetFrame then return end
	region:ClearAllPoints()
	local layout = AnchorLayouts[layoutKey]
	if not layout then return end
	for _, value in ipairs(layout) do
		local regionAnchor, targetAnchor, offsetX, offsetY = value[1], value[2], value[3] or 0, value[4] or 0
		region:SetPoint(regionAnchor, targetFrame, targetAnchor, offsetX, offsetY)
	end
end

local function HandleCompactUnitFrameUpdate(frame)
	local db = OvershieldsReforged.db.profile
	if not db or not frame then return end

	local unit = frame.displayedUnit
	if not unit or not UnitExists(unit) then return end

	local shieldBar, shieldOverlay, overshieldTick, healthBar = frame.totalAbsorb, frame.totalAbsorbOverlay, frame.overAbsorbGlow, frame.healthBar

    if (not shieldOverlay or shieldOverlay:IsForbidden())
        or (not overshieldTick or overshieldTick:IsForbidden())
        or (not healthBar or healthBar:IsForbidden())
    then
        return
    end

	local _, maxHealth = healthBar:GetMinMaxValues()

    local totalShield = UnitGetTotalAbsorbs(frame.unit) or 0

	if totalShield <= 0 or maxHealth <= 0 then
		shieldOverlay:Hide()
		shieldBar:Hide()
		overshieldTick:Hide()
		return
	end

	local healthFillBar = healthBar:GetStatusBarTexture()
	local currentHealth = healthBar:GetValue()
	local missingHealth = maxHealth - currentHealth
	local hasMissingHealth = missingHealth > 0
	local effectiveHealth = currentHealth + totalShield
	local hasOvershield = effectiveHealth > maxHealth
	local displayedShield = (currentHealth < maxHealth) and math.min(totalShield, missingHealth) or totalShield
	local healthBarWidth = healthBar:GetWidth()
	local shieldWidth = math.min((displayedShield / maxHealth) * healthBarWidth, healthBarWidth)

	shieldOverlay:SetWidth(shieldWidth)
	shieldBar:SetWidth(shieldWidth)

    -- Overshield Tick
	overshieldTick:Show()
	if not hasOvershield or (hasMissingHealth and not db.showTickWhenNotFullHealth) then
		overshieldTick:Hide()
	elseif hasMissingHealth then
		ApplyPoints(overshieldTick, healthBar, "OvershieldTick_MissingHealth")
	else
		ApplyPoints(overshieldTick, shieldOverlay, "OvershieldTick_FullHealth")
	end

	if displayedShield <= 0 then
		shieldOverlay:Hide()
		shieldBar:Hide()
		return
	end

	-- Shield Overlay
	shieldOverlay:ClearAllPoints()
	shieldOverlay:SetParent(healthBar)

	local tileSize = shieldOverlay.tileSize or 128
	local tileCount = shieldWidth / tileSize
	shieldOverlay:SetTexCoord(0, tileCount, 0, 1)

	if hasMissingHealth then
		ApplyPoints(shieldOverlay, healthFillBar, "ShieldOverlay_MissingHealth")
		shieldOverlay:Show()
	elseif db.showShieldOverlayAtFullHealth then
		ApplyPoints(shieldOverlay, healthBar, "ShieldOverlay_FullHealth")
		shieldOverlay:Show()
	end

	-- Shield Bar
    shieldBar:ClearAllPoints()

	if hasMissingHealth then
		ApplyPoints(shieldBar, healthFillBar, "ShieldBar_MissingHealth")
		shieldBar:Show()
	elseif db.showShieldBarAtFullHealth then
		ApplyPoints(shieldBar, healthBar, "ShieldBar_FullHealth")
		shieldBar:Show()
	end
end

-- Clear points for already-existing fill bars with unset anchors to avoid circular reference bug (e9f667b)
-- pcall used here to circumvent expensive validation and suppress irrelevant errors
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, _, bar)
	if bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay or bar == frame.overAbsorbGlow then
		pcall(bar.ClearAllPoints, bar)
	end
end)

-- Per-frame batching for CompactUnitFrame updates
batchFrame:SetScript("OnUpdate", function()
	for frame in next, updateQueue do
   		HandleCompactUnitFrameUpdate(frame)
	end
    wipe(updateQueue)
	batchFrame:Hide() -- we only want to update if there are queued frames, so we hide once done to stop iterating
end)

function ns.QueueCompactUnitFrameUpdate(frame)
	if not frame or updateQueue[frame] then return end
	updateQueue[frame] = true
	batchFrame:Show()
end