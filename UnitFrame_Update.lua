local _, ns = ...
local absorbGlowTickOffset = ns.absorbGlowTickOffset

ns.HandleUnitFrameUpdate = function(frame)
	local db = OvershieldsReforged.db
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
		absorbGlowTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", absorbGlowTickOffset, 0)
		absorbGlowTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", absorbGlowTickOffset, 0)
		absorbGlowTick:SetAlpha(db.overshieldTickAlpha)
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
	absorbGlowTick:SetPoint("TOPLEFT", mask, "TOPLEFT", absorbGlowTickOffset, 0)
	absorbGlowTick:SetPoint("BOTTOMLEFT", mask, "BOTTOMLEFT", absorbGlowTickOffset, 0)
	absorbGlowTick:SetAlpha(db.overshieldTickAlpha)
	absorbGlowTick:Show()
end
