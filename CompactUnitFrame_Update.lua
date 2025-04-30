local _, ns = ...
local OVERSHIELD_TICK_OFFSET = -7

-- Securely hook into the base UI function to clear points before it sets them
hooksecurefunc("CompactUnitFrameUtil_UpdateFillBar", function(frame, previousTexture, bar, amount, barOffsetXPercent)
    -- Clear all points for custom bars before the base UI sets them
    if bar == frame.totalAbsorb or bar == frame.totalAbsorbOverlay then
        bar:ClearAllPoints()
    end
end)

ns.HandleCompactUnitFrame_Update = function(frame)
	local db = OvershieldsReforged.db.profile
	if not db or not frame then return end

	local shieldBar = frame.totalAbsorb
	local shieldOverlay = frame.totalAbsorbOverlay
	local overshieldTick = frame.overAbsorbGlow
	local healthBar = frame.healthBar
	if (not shieldOverlay or shieldOverlay:IsForbidden())
		or (not overshieldTick or overshieldTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then return end

    local totalShield   = UnitGetTotalAbsorbs(frame.displayedUnit) or 0
	local currentHealth = healthBar:GetValue()
    local _, maxHealth  = healthBar:GetMinMaxValues()

    if totalShield <= 0 or maxHealth <= 0 then
        shieldOverlay:Hide()
        shieldBar:Hide()
        overshieldTick:Hide()
        return
    end

    local missingHealth = maxHealth - currentHealth
	local hasMissingHealth = missingHealth > 0
	local effectiveHealth = currentHealth + totalShield
	local hasOvershield = effectiveHealth > maxHealth

	local displayedShield
	if currentHealth < maxHealth then
		displayedShield = math.min(totalShield, missingHealth)
	else
		displayedShield = totalShield
	end

    local healthBarWidth, _ = healthBar:GetSize()
	local healthFillBar = frame.healthBar:GetStatusBarTexture() -- Assuming the first child is the fill bar

	-- Handle overshieldTick prior to shieldOverlay and shieldBar to ensure correct visibility
	if hasOvershield then
		overshieldTick:ClearAllPoints()
		if hasMissingHealth then
			overshieldTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", OVERSHIELD_TICK_OFFSET, 0)
			overshieldTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", OVERSHIELD_TICK_OFFSET, 0)
			if not db.showTickWhenNotFullHealth then
				overshieldTick:Hide()
			end
		else
			overshieldTick:SetPoint("TOPLEFT", shieldOverlay, "TOPLEFT", OVERSHIELD_TICK_OFFSET, 0)
			overshieldTick:SetPoint("BOTTOMLEFT", shieldOverlay, "BOTTOMLEFT", OVERSHIELD_TICK_OFFSET, 0)
			overshieldTick:Show()
		end
		local color = db.overshieldTickColor
		overshieldTick:SetVertexColor(color.r, color.g, color.b, color.a)
		overshieldTick:SetBlendMode(db.overshieldTickBlendMode)

		local tickTexture = db.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield"
		overshieldTick:SetTexture(tickTexture)
	else
		overshieldTick:Hide()
	end

    if displayedShield <= 0 then
        shieldOverlay:Hide()
        shieldBar:Hide()
        return
    end

	-- Handle shieldOverlay visibility and positioning
	shieldOverlay:SetParent(healthBar)
	shieldOverlay:ClearAllPoints()
	-- Calculate the width of the shield overlay as a fraction of the health bar width
	local shieldWidth = math.min((displayedShield / maxHealth) * healthBarWidth, healthBarWidth)
	shieldOverlay:SetWidth(shieldWidth)
	shieldBar:SetWidth(shieldWidth)
	-- Apply the texture and ensure proper tiling
	local tileSize = shieldOverlay.tileSize or 128
	local tileCount = shieldWidth / tileSize
	shieldOverlay:SetTexCoord(0, tileCount, 0, 1)
	-- Apply custom color/alpha, blend mode, and texture to shieldOverlay
	local shieldOverlayColor = db.shieldOverlayColor
	shieldOverlay:SetDesaturated(true)
	shieldOverlay:SetVertexColor(shieldOverlayColor.r, shieldOverlayColor.g, shieldOverlayColor.b, shieldOverlayColor.a)
	shieldOverlay:SetAlpha(shieldOverlayColor.a)
	shieldOverlay:SetBlendMode(db.shieldOverlayBlendMode)
	local shieldOverlayTexture = db.shieldOverlayTexture or "Interface\\RaidFrame\\Shield-Overlay"
	if shieldOverlayTexture ~= "Interface\\RaidFrame\\Shield-Overlay" then
		shieldOverlay:SetTexture(shieldOverlayTexture)
	end
	-- Set anchor points for shieldOverlay based on health bar state and config
	if hasMissingHealth then
		-- Anchor the overlay to the shield bar instead of the health bar
		shieldOverlay:SetPoint("TOPLEFT", healthFillBar, "TOPRIGHT", 0, 0)
		shieldOverlay:SetPoint("BOTTOMLEFT", healthFillBar, "BOTTOMRIGHT", 0, 0)
		shieldOverlay:Show()
	elseif db.showShieldOverlayAtFullHealth then
		-- Anchor the overlay to the right edge of the health bar
		shieldOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
		shieldOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		shieldOverlay:Show()
	end

	-- Handle shieldBar visibility and positioning
	-- Apply custom color/alpha, blend mode, and texture to shieldBar
	local shieldBarColor = db.shieldBarColor
	shieldBar:SetVertexColor(shieldBarColor.r, shieldBarColor.g, shieldBarColor.b, shieldBarColor.a)
	shieldBar:SetAlpha(shieldBarColor.a)
	shieldBar:SetBlendMode(db.shieldBarBlendMode)
	local shieldBarTexture = db.shieldBarTexture or "Interface\\RaidFrame\\Shield-Fill"
    if shieldBarTexture ~= "Interface\\RaidFrame\\Shield-Fill" then
        shieldBar:SetTexture(shieldBarTexture)
    end
	if hasMissingHealth then
		-- Anchor the shieldBar to the healthFillBar for proper alignment
		shieldBar:SetPoint("TOPLEFT", healthFillBar, "TOPRIGHT", 0, 0)
		shieldBar:SetPoint("BOTTOMLEFT", healthFillBar, "BOTTOMRIGHT", 0, 0)
		shieldBar:Show()
	elseif db.showShieldBarAtFullHealth then
		-- Anchor the shieldBar to the healthFillBar for full health scenarios
		shieldBar:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
		shieldBar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		shieldBar:Show()
	end
end
