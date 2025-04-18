local _, ns = ...
local ABSORB_GLOW_TICK_OFFSET = -7

ns.HandleCompactUnitFrame_Update = function(frame)
	local db = OvershieldsReforged.db.profile
	if not db then return end
	if not frame then return end

	local absorbOverlay  = frame.totalAbsorbOverlay
	local absorbGlowTick = frame.overAbsorbGlow
	local healthBar      = frame.healthBar
	if (not absorbOverlay or absorbOverlay:IsForbidden())
		or (not absorbGlowTick or absorbGlowTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then
		return
	end

	local currentHealth = healthBar:GetValue()
	local _, maxHealth  = healthBar:GetMinMaxValues()
	if maxHealth <= 0 then
		absorbOverlay:Hide()
		absorbGlowTick:Hide()
		return
	end

	local totalAbsorb = UnitGetTotalAbsorbs(frame.displayedUnit) or 0
	if totalAbsorb <= 0 then
		absorbOverlay:Hide()
		absorbGlowTick:Hide()
		return
	end

	local missingHealth = maxHealth - currentHealth
	local effectiveHealth = currentHealth + totalAbsorb
	local overAbsorb = effectiveHealth > maxHealth

	local showAbsorb
	if currentHealth < maxHealth then
		showAbsorb = math.min(totalAbsorb, missingHealth)
	else
		showAbsorb = totalAbsorb
	end

	local healthBarWidth, healthBarHeight = healthBar:GetSize()
	if showAbsorb > 0 then
		absorbOverlay:SetParent(healthBar)
		absorbOverlay:ClearAllPoints()

		-- Anchor the overlay to the right side of the health bar
		if missingHealth > 0 then
			-- Grow to the right of the health bar, respecting missing health
			absorbOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
			absorbOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		else
			-- Grow left from the right edge of the health bar
			absorbOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
			absorbOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		end

		-- Calculate the width of the absorb overlay as a fraction of the health bar width
		local absorbWidth = math.min((showAbsorb / maxHealth) * healthBarWidth, healthBarWidth)
		absorbOverlay:SetWidth(absorbWidth)

		-- Apply the texture and ensure proper tiling
		local tileSize = absorbOverlay.tileSize or 128
		local tileCount = absorbWidth / tileSize
		absorbOverlay:SetTexCoord(0, tileCount, 0, 1)

		-- Use alpha from absorbOverlayColor
		absorbOverlay:SetAlpha(db.absorbOverlayColor.a)

		-- Apply custom color and blend mode to absorbOverlay
		local color = db.absorbOverlayColor
		absorbOverlay:SetDesaturated(true)
		absorbOverlay:SetVertexColor(color.r, color.g, color.b, color.a)
		absorbOverlay:SetBlendMode(db.absorbOverlayBlendMode)

		local overlayTexture = db.overlayTexture or "Interface\\RaidFrame\\Shield-Overlay"
		if overlayTexture ~= "Interface\\RaidFrame\\Shield-Overlay" then
			absorbOverlay:SetTexture(overlayTexture)
		end

		-- TODO: Fix the tiling issue with the overlay texture
		-- Enable tiling for "Shield-Overlay"
		--absorbOverlay:SetHorizTile(true)
		--absorbOverlay:SetVertTile(false)

		absorbOverlay:Show()
	else
		absorbOverlay:Hide()
	end

	if totalAbsorb > missingHealth then
		absorbGlowTick:ClearAllPoints()
		if missingHealth > 0 then
			absorbGlowTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
			absorbGlowTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
			if not db.showTickWhenNotFullHealth then
				absorbGlowTick:Hide()
			end
		else
			absorbGlowTick:SetPoint("TOPLEFT", absorbOverlay, "TOPLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
			absorbGlowTick:SetPoint("BOTTOMLEFT", absorbOverlay, "BOTTOMLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
			absorbGlowTick:Show()
		end
		local color = db.overabsorbTickColor
		absorbGlowTick:SetVertexColor(color.r, color.g, color.b, color.a)
		absorbGlowTick:SetBlendMode(db.overabsorbTickBlendMode)

		local tickTexture = db.overabsorbTickTexture or "Interface\\RaidFrame\\Shield-Overshield"
		absorbGlowTick:SetTexture(tickTexture)
	else
		absorbGlowTick:Hide()
	end
end
