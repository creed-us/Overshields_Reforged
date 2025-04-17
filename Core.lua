local ADDON_NAME = ...
local ABSORB_GLOW_TICK_OFFSET = -7

-- namespace frame
OvershieldsReforged = CreateFrame("Frame")

-- event dispatcher
function OvershieldsReforged:OnEvent(event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

OvershieldsReforged:SetScript("OnEvent", OvershieldsReforged.OnEvent)
OvershieldsReforged:RegisterEvent("ADDON_LOADED")

-- ADDON_LOADED: initialize SavedVariables, apply defaults, hook into Blizzard, and build options
function OvershieldsReforged:ADDON_LOADED(event, addonName)
	if addonName ~= ADDON_NAME then return end

	OvershieldsReforgedDB = OvershieldsReforgedDB or {}
	self.db = OvershieldsReforgedDB

	self.defaults = self.defaults or {}

	-- merge missing defaults
	for key, value in pairs(self.defaults) do
		if self.db[key] == nil then
			self.db[key] = value
		end
	end

	-- hook Blizzard's heal-prediction functions
	hooksecurefunc("UnitFrameHealPredictionBars_Update", function(frame)
		OvershieldsReforged.UnitFrameHealPredictionBars_Update(frame)
	end)
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		OvershieldsReforged.CompactUnitFrame_UpdateHealPrediction(frame)
	end)

	-- build options UI (Options.lua)
	self:InitializeOptions()

	-- no longer need the loader
	self:UnregisterEvent("ADDON_LOADED")
end

-- regular unit frames
function OvershieldsReforged.UnitFrameHealPredictionBars_Update(frame)
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

	local healthTex     = healthBar:GetStatusBarTexture()
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

	if currentHealth < maxHealth and effectiveHealth <= maxHealth then
		absorbGlowTick:Hide()
		return
	end

	if currentHealth < maxHealth then
		absorbGlowTick:ClearAllPoints()
		absorbGlowTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetAlpha(db.overshieldTickAlpha)
		absorbGlowTick:Show()
		return
	end

	local showAbsorb = math.min(totalAbsorb, maxHealth)
	local offsetX    = (maxHealth / effectiveHealth) - 1
	absorbBar:UpdateFillPosition(healthTex, showAbsorb, offsetX)
	absorbBar:Show()

	if effectiveHealth > maxHealth then
		local mask = absorbBar.FillMask
		absorbGlowTick:ClearAllPoints()
		absorbGlowTick:SetPoint("TOPLEFT", mask, "TOPLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetPoint("BOTTOMLEFT", mask, "BOTTOMLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
		absorbGlowTick:SetAlpha(db.overshieldTickAlpha)
		absorbGlowTick:Show()
	else
		absorbGlowTick:Hide()
	end
end

-- compact unit frames
function OvershieldsReforged.CompactUnitFrame_UpdateHealPrediction(frame)
	local db = OvershieldsReforged.db
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
	if totalAbsorb > maxHealth then totalAbsorb = maxHealth end

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

		local absorbOverlayWidth = (showAbsorb / maxHealth) * healthBarWidth
		absorbOverlay:SetWidth(absorbOverlayWidth)
		absorbOverlay:SetTexCoord(0, absorbOverlayWidth / absorbOverlay.tileSize, 0,
			healthBarHeight / absorbOverlay.tileSize)
		absorbOverlay:SetAlpha(db.overshieldOverlayAlpha)
		absorbOverlay:Show()
	else
		absorbOverlay:Hide()
	end

	if totalAbsorb > missingHealth then
		absorbGlowTick:ClearAllPoints()
		if missingHealth > 0 then
			absorbGlowTick:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
			absorbGlowTick:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", ABSORB_GLOW_TICK_OFFSET, 0)
		else
			absorbGlowTick:SetPoint("TOPLEFT", absorbOverlay, "TOPLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
			absorbGlowTick:SetPoint("BOTTOMLEFT", absorbOverlay, "BOTTOMLEFT", ABSORB_GLOW_TICK_OFFSET, 0)
		end
		absorbGlowTick:SetAlpha(db.overshieldTickAlpha)
		absorbGlowTick:Show()
	else
		absorbGlowTick:Hide()
	end
end

-- slash command to open the options panel
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function()
	Settings.OpenToCategory(OvershieldsReforged.panel_main.name)
end
