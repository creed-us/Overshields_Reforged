local _, ns = ...
local ABSORB_GLOW_TICK_OFFSET = -7

ns.HandleUnitFrameUpdate = function(frame)
	local db = OvershieldsReforged.db.profile
	if not db then return end
	if not frame then return end

	local absorbBar      = frame.totalAbsorbBar
	local absorbGlowTick = frame.overAbsorbGlow
	local healthBar      = frame.healthbar
	if (not absorbBar or absorbBar:IsForbidden())
		or (not absorbGlowTick or absorbGlowTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then
		return
	end

	local healthTexture = healthBar:GetStatusBarTexture()
	local currentHealth = healthBar:GetValue()
	local _, maxHealth  = healthBar:GetMinMaxValues()
	if currentHealth <= 0 or maxHealth <= 0 then
		absorbGlowTick:Hide()
		return
	end

	local totalAbsorb = UnitGetTotalAbsorbs(frame.unit) or 0
	if totalAbsorb <= 0 then
		absorbBar:Hide()
		absorbGlowTick:Hide()
		return
	end

	local missingHealth = maxHealth - currentHealth
	local effectiveHealth = currentHealth + totalAbsorb
	local overAbsorb = effectiveHealth > maxHealth
	if missingHealth > 0 and overAbsorb then
		absorbGlowTick:ClearAllPoints()
		absorbGlowTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetAlpha(db.overabsorbTickColor.a)
		if db.showTickWhenNotFullHealth then
			absorbGlowTick:Show()
		else
			absorbGlowTick:Hide()
		end
		return
	end

	local showAbsorb = math.min(totalAbsorb, maxHealth)
	local offsetX    = (maxHealth / effectiveHealth) - 1
	absorbBar:UpdateFillPosition(healthTexture, showAbsorb, offsetX)
	absorbBar:Show()

	if not overAbsorb then
		absorbGlowTick:Hide()
		return
	end

	local mask = absorbBar.FillMask
	absorbGlowTick:ClearAllPoints()
	absorbGlowTick:SetPoint("TOPLEFT", mask, "TOPLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
	absorbGlowTick:SetPoint("BOTTOMLEFT", mask, "BOTTOMLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
	absorbGlowTick:SetAlpha(db.overabsorbTickColor.a)
	absorbGlowTick:SetVertexColor(db.overabsorbTickColor.r, db.overabsorbTickColor.g, db.overabsorbTickColor.b,
		db.overabsorbTickColor.a)
	absorbGlowTick:SetBlendMode(db.overabsorbTickBlendMode)
	absorbGlowTick:SetTexture(db.overabsorbTickTexture or "Interface\\RaidFrame\\Shield-Overshield")
	absorbGlowTick:Show()
end
