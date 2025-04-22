local _, ns = ...
local OVERSHIELD_TICK_OFFSET = -7

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

	local currentHealth = healthBar:GetValue()
	local _, maxHealth  = healthBar:GetMinMaxValues()
	if maxHealth <= 0 then
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local totalShield = UnitGetTotalAbsorbs(frame.displayedUnit) or 0
	if totalShield <= 0 then
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local missingHealth = maxHealth - currentHealth
	local effectiveHealth = currentHealth + totalShield
	local hasOvershield = effectiveHealth > maxHealth

	local showShield
	if currentHealth < maxHealth then
		showShield = math.min(totalShield, missingHealth)
	else
		showShield = totalShield
	end

	local healthBarWidth, healthBarHeight = healthBar:GetSize()
	if showShield > 0 then
		shieldOverlay:SetParent(healthBar)
		shieldOverlay:ClearAllPoints()

		if missingHealth > 0 then
			-- Anchor the overlay to the shield bar instead of the health bar
			shieldOverlay:SetPoint("TOPRIGHT", shieldBar, "TOPRIGHT", 0, 0)
			shieldOverlay:SetPoint("BOTTOMRIGHT", shieldBar, "BOTTOMRIGHT", 0, 0)
		else
			-- Anchor the overlay to the right edge of the health bar
			shieldOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
			shieldOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		end

		-- Calculate the width of the shield overlay as a fraction of the health bar width
		local shieldWidth = math.min((showShield / maxHealth) * healthBarWidth, healthBarWidth)
		shieldOverlay:SetWidth(shieldWidth)

		-- Apply the texture and ensure proper tiling
		local tileSize = shieldOverlay.tileSize or 128
		local tileCount = shieldWidth / tileSize
		shieldOverlay:SetTexCoord(0, tileCount, 0, 1)

		-- Use alpha from shieldOverlayColor
		shieldOverlay:SetAlpha(db.shieldOverlayColor.a)

		-- Apply custom color and blend mode to shieldOverlay
		local color = db.shieldOverlayColor
		shieldOverlay:SetDesaturated(true)
		shieldOverlay:SetVertexColor(color.r, color.g, color.b, color.a)
		shieldOverlay:SetBlendMode(db.shieldOverlayBlendMode)

		local overlayTexture = db.overlayTexture or "Interface\\RaidFrame\\Shield-Overlay"
		if overlayTexture ~= "Interface\\RaidFrame\\Shield-Overlay" then
			shieldOverlay:SetTexture(overlayTexture)
		end

		shieldOverlay:Show()
	else
		shieldOverlay:Hide()
	end

	if totalShield > missingHealth then
		overshieldTick:ClearAllPoints()
		if missingHealth > 0 then
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
end
