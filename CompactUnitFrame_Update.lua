local _, ns = ...
local LSM = LibStub("LibSharedMedia-3.0") -- Load LibSharedMedia-3.0
local ABSORB_GLOW_TICK_OFFSET = -7

ns.HandleCompactUnitFrame_Update = function(frame)
	local db = OvershieldsReforged.db.profile
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
		absorbOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
		absorbOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)

		local absorbOverlayWidth = math.min((showAbsorb / maxHealth) * healthBarWidth, healthBarWidth)
		absorbOverlay:SetWidth(absorbOverlayWidth)
		absorbOverlay:SetTexCoord(0, absorbOverlayWidth / absorbOverlay.tileSize, 0,
			healthBarHeight / absorbOverlay.tileSize)

		-- Use alpha from absorbOverlayColor
		absorbOverlay:SetAlpha(db.absorbOverlayColor.a)

		-- Apply custom color and blend mode to absorbOverlay
		local color = db.absorbOverlayColor
		absorbOverlay:SetDesaturated(true)
		absorbOverlay:SetVertexColor(color.r, color.g, color.b, color.a)
		absorbOverlay:SetBlendMode(db.absorbOverlayBlendMode)

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
		absorbGlowTick:SetBlendMode(db.overabsorbTickBlendMode) -- Apply blend mode
	else
		absorbGlowTick:Hide()
	end
end
