local _, ns = ...
local OVERSHIELD_TICK_OFFSET = -7

ns.HandleUnitFrameUpdate = function(frame)
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
	local _, maxHealth = healthBar:GetMinMaxValues()
	if currentHealth <= 0 or maxHealth <= 0 then
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local totalShield = UnitGetTotalAbsorbs(frame.unit) or 0
	if totalShield <= 0 then
		shieldOverlay:Hide()
		overshieldTick:Hide()
		return
	end

	local missingHealth = maxHealth - currentHealth
	local showShield = currentHealth < maxHealth and math.min(totalShield, missingHealth) or totalShield
	local healthBarWidth, _ = healthBar:GetSize()

	if showShield > 0 then
		shieldOverlay:SetParent(healthBar)
		shieldOverlay:ClearAllPoints()
		-- Anchor the overlay to the right of the shield bar if health is missing, otherwise to the right of the health bar
		local anchor = missingHealth > 0 and shieldBar or healthBar
		shieldOverlay:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
		shieldOverlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)

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
		-- Anchor the overshield tick based on missing health - right side if health is missing, left side if not
		local anchor = missingHealth > 0 and healthBar or shieldOverlay
		local anchorTopSide = missingHealth > 0 and "TOPRIGHT" or "TOPLEFT"
		local anchorBottomSide = missingHealth > 0 and "BOTTOMRIGHT" or "BOTTOMLEFT"
		overshieldTick:SetPoint("TOPLEFT", anchor, anchorTopSide, OVERSHIELD_TICK_OFFSET, 0)
		overshieldTick:SetPoint("BOTTOMLEFT", anchor, anchorBottomSide, OVERSHIELD_TICK_OFFSET, 0)

		if missingHealth > 0 and not db.showTickWhenNotFullHealth then
			overshieldTick:Hide()
		else
			local color = db.overshieldTickColor
			overshieldTick:SetVertexColor(color.r, color.g, color.b, color.a)
			overshieldTick:SetBlendMode(db.overshieldTickBlendMode)
			overshieldTick:SetTexture(db.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield")
			overshieldTick:Show()
		end
	else
		overshieldTick:Hide()
	end
end
