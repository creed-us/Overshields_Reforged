local _, ns = ...
local OVERSHIELD_TICK_OFFSET = -7

ns.HandleUnitFrameUpdate = function(frame)
	local db = OvershieldsReforged.db.profile
	if not db or not frame then return end

	local shieldBar = frame.totalAbsorbBar
	local overshieldTick = frame.overAbsorbGlow
	local healthBar = frame.healthbar
	if (not shieldBar or shieldBar:IsForbidden())
		or (not overshieldTick or overshieldTick:IsForbidden())
		or (not healthBar or healthBar:IsForbidden())
	then return end

	local healthTexture = healthBar:GetStatusBarTexture()
	local currentHealth = healthBar:GetValue()
	local _, maxHealth = healthBar:GetMinMaxValues()
	if currentHealth <= 0 or maxHealth <= 0 then
		shieldBar:Hide()
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

	local showShield = math.min(totalShield, maxHealth)
	local offsetX = (maxHealth / effectiveHealth) - 1
	shieldBar:UpdateFillPosition(healthTexture, showShield, offsetX)
	shieldBar:Show()

	local color = db.overshieldTickColor
	overshieldTick:ClearAllPoints()
	overshieldTick:SetAlpha(color.a)

	local shouldHideTick = missingHealth > 0 and not db.showTickWhenNotFullHealth
	if hasOvershield and not shouldHideTick then
		-- Set the anchor point based on missing health - right side if health is missing, left side if not
		local anchor = missingHealth > 0 and healthBar or shieldBar.FillMask
		overshieldTick:SetPoint("TOPLEFT", anchor, "TOPRIGHT", OVERSHIELD_TICK_OFFSET, 0)
		overshieldTick:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", OVERSHIELD_TICK_OFFSET, 0)
		overshieldTick:SetVertexColor(color.r, color.g, color.b, color.a)
		overshieldTick:SetBlendMode(db.overshieldTickBlendMode)
		overshieldTick:SetTexture(db.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield")
		overshieldTick:Show()
	else
		overshieldTick:Hide()
	end
end
