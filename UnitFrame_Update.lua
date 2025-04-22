local _, ns = ...
local OVERSHIELD_TICK_OFFSET = -7

ns.HandleUnitFrameUpdate = function(frame)
	local db = OvershieldsReforged.db.profile
	if not db then return end
	if not frame then return end

	local shieldBar = frame.totalAbsorbBar
	local overshieldTick = frame.overAbsorbGlow
	local healthBar = frame.healthbar
	if (not shieldBar or shieldBar:IsForbidden())
		or (not overshieldTick or overshieldTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then
		return
	end

	local healthTexture = healthBar:GetStatusBarTexture()
	local currentHealth = healthBar:GetValue()
	local _, maxHealth = healthBar:GetMinMaxValues()
	if currentHealth <= 0 or maxHealth <= 0 then
		overshieldTick:Hide()
		return
	end

	local totalShield = UnitGetTotalAbsorbs(frame.unit) or 0
	if totalShield <= 0 then
		shieldBar:Hide()
		overshieldTick:Hide()
		return
	end

	local missingHealth = maxHealth - currentHealth
	local effectiveHealth = currentHealth + totalShield
	local hasOvershield = effectiveHealth > maxHealth
	if missingHealth > 0 and hasOvershield then
		overshieldTick:ClearAllPoints()
		overshieldTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", OVERSHIELD_TICK_OFFSET, 0)
		overshieldTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", OVERSHIELD_TICK_OFFSET, 0)
		overshieldTick:SetAlpha(db.overshieldTickColor.a)
		if db.showTickWhenNotFullHealth then
			overshieldTick:Show()
		else
			overshieldTick:Hide()
		end
		return
	end

	local showShield = math.min(totalShield, maxHealth)
	local offsetX = (maxHealth / effectiveHealth) - 1
	shieldBar:UpdateFillPosition(healthTexture, showShield, offsetX)
	shieldBar:Show()

	if not hasOvershield then
		overshieldTick:Hide()
		return
	end

	local mask = shieldBar.FillMask
	overshieldTick:ClearAllPoints()
	overshieldTick:SetPoint("TOPLEFT", mask, "TOPLEFT", OVERSHIELD_TICK_OFFSET, 0)
	overshieldTick:SetPoint("BOTTOMLEFT", mask, "BOTTOMLEFT", OVERSHIELD_TICK_OFFSET, 0)
	overshieldTick:SetAlpha(db.overshieldTickColor.a)
	overshieldTick:SetVertexColor(db.overshieldTickColor.r, db.overshieldTickColor.g, db.overshieldTickColor.b, db.overshieldTickColor.a)
	overshieldTick:SetBlendMode(db.overshieldTickBlendMode)
	overshieldTick:SetTexture(db.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield")
	overshieldTick:Show()
end
