local _, ns = ...

-- Anchor layouts for overshield tick
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
		{ "BOTTOMRIGHT", "BOTTOMRIGHT" },
	},
	ShieldBar_MissingHealth = {
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
	},
	ShieldBar_FullHealth = {
		{ "TOPRIGHT", "TOPRIGHT" },
		{ "BOTTOMRIGHT", "BOTTOMRIGHT" },
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

function ns.HandleUnitFrameUpdate(frame)
	local db = OvershieldsReforged.db.profile
	if not db or not frame then return end

	-- These are the standard Blizzard unit frame regions
	local shieldBar = frame.totalAbsorbBar
	local shieldOverlay = frame.totalAbsorbOverlay
	local overshieldTick = frame.overAbsorbGlow
	local healthBar = frame.healthbar

	if (not shieldBar or shieldBar:IsForbidden())
		or (not shieldOverlay or shieldOverlay:IsForbidden())
		or (not overshieldTick or overshieldTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then
		return
	end

	local unit = frame.unit or frame.displayedUnit
	if not unit or not UnitExists(unit) then
		shieldBar:Hide()
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local currentHealth = healthBar:GetValue()
	local _, maxHealth = healthBar:GetMinMaxValues()
	if currentHealth <= 0 or maxHealth <= 0 then
		shieldBar:Hide()
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local totalShield = ns.GetTotalAbsorbs(unit) or 0
	if totalShield <= 0 then
		shieldBar:Hide()
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local healthFillBar = healthBar:GetStatusBarTexture()
	local missingHealth = maxHealth - currentHealth
	local effectiveHealth = currentHealth + totalShield
	local hasOvershield = effectiveHealth > maxHealth
	local hasMissingHealth = missingHealth > 0
	local displayedShield = (currentHealth < maxHealth) and math.min(totalShield, missingHealth) or totalShield
	local healthBarWidth = healthBar:GetWidth()
	local shieldWidth = math.min((displayedShield / maxHealth) * healthBarWidth, healthBarWidth)

	-- Shield Overlay
	shieldOverlay:SetWidth(shieldWidth)
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
	else
		shieldOverlay:Hide()
	end

	-- Shield Bar
	shieldBar:SetWidth(shieldWidth)
	shieldBar:ClearAllPoints()
	if hasMissingHealth then
		ApplyPoints(shieldBar, healthFillBar, "ShieldBar_MissingHealth")
		shieldBar:Show()
	elseif db.showShieldBarAtFullHealth then
		ApplyPoints(shieldBar, healthBar, "ShieldBar_FullHealth")
		shieldBar:Show()
	else
		shieldBar:Hide()
	end

	-- Overshield Tick
	overshieldTick:Hide()
	if hasOvershield then
		if hasMissingHealth then
			ApplyPoints(overshieldTick, healthBar, "OvershieldTick_MissingHealth")
			if db.showTickWhenNotFullHealth then
				overshieldTick:Show()
			end
		else
			ApplyPoints(overshieldTick, shieldOverlay, "OvershieldTick_FullHealth")
			overshieldTick:Show()
		end
	end
end
