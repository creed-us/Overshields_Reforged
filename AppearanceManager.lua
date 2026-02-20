local _, ns = ...

--- Applies appearance settings (color, texture, and tiling) to a status bar.
-- Uses SetTexCoord for proper tiling based on frame dimensions (Blizzard method).
-- @param bar The status bar frame to style
-- @param colorTable Table with r, g, b, a keys for color
-- @param textureFile Path to texture file for the bar
local function ApplyAppearanceToBar(absorb, glowVisible)
    if not absorb then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable = db.absorbColor
    local textureFile = db.absorbTexture
	local blendMode = db.absorbBlendMode
    if glowVisible then
        colorTable = db.overAbsorbColor
        textureFile = db.overAbsorbTexture
		blendMode = db.overAbsorbBlendMode
    end

    -- Apply color and transparency
    absorb:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

    -- Apply texture
    absorb:SetStatusBarTexture(textureFile)

    -- Configure tiling using SetTexCoord for proper vertical/horizontal tiling
    -- This matches Blizzard's approach in CompactUnitFrame
    local texture = absorb:GetStatusBarTexture()
    if texture then
        texture:SetTexture(textureFile, "REPEAT", "CLAMP")
        -- Set tileSize (Blizzard uses 32 for Shield-Overlay)
        absorb.tileSize = 32
    end

	texture:SetBlendMode(blendMode)
end

local function ApplyAppearanceToNativeBar(bar, glowVisible)
	pcall(ApplyAppearanceToBar, bar, glowVisible)
end

local function ApplyAppearanceToOverlay(overlay, glowVisible)
    if not overlay then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable = db.overlayColor
    local textureFile = db.overlayTexture
	local blendMode = db.overlayBlendMode
    if glowVisible then
        colorTable = db.overAbsorbOverlayColor
        textureFile = db.overAbsorbOverlayTexture
		blendMode = db.overAbsorbOverlayBlendMode
    end

    -- Apply color and transparency
    overlay:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

    -- Apply texture with basic tiling
    overlay:SetStatusBarTexture(textureFile)
    local texture = overlay:GetStatusBarTexture()
    if texture == "Interface\\RaidFrame\\Shield-Overlay" then
        texture:SetTexture(textureFile, "REPEAT", "REPEAT")
        texture:SetHorizTile(true)
        texture:SetVertTile(true)
    else
        texture:SetTexture(textureFile, "REPEAT", "CLAMP")
        texture:SetHorizTile(true)
        texture:SetVertTile(false)
    end

	texture:SetBlendMode(blendMode)
end

local function ApplyAppearanceToNativeOverlay(overlay, glowVisible)
	pcall(ApplyAppearanceToOverlay, overlay, glowVisible)
end

local function ApplyAppearanceToOverAbsorbGlow(glow)
    if not glow or not glow:IsVisible() then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable = db.overAbsorbGlowColor
    local textureFile = db.overAbsorbGlowTexture

    -- Apply color and transparency
    glow:SetVertexColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

    -- Apply texture
    --glow:SetStatusBarTexture(textureFile)
    --local texture = glow:GetStatusBarTexture()
	glow:SetTexture(textureFile)

    glow:SetBlendMode(db.overAbsorbGlowBlendMode)
end

local function ApplyAppearanceToNativeOverAbsorbGlow(glow)
    pcall(ApplyAppearanceToOverAbsorbGlow, glow)
end

local function ApplyAppearanceToHealthBar(healthBar, unit, glowVisible)
    if not healthBar then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable, textureFile, blendMode, useClassColor
    if glowVisible then
        colorTable = db.overAbsorbHealthBarColor
        textureFile = db.overAbsorbHealthBarTexture
        blendMode = db.overAbsorbHealthBarBlendMode
        useClassColor = db.overAbsorbHealthBarUseClassColor
    else
        colorTable = db.healthBarColor
        textureFile = db.healthBarTexture
        blendMode = db.healthBarBlendMode
        useClassColor = db.healthBarUseClassColor
    end

    -- Apply color (class color or custom)
    if useClassColor and unit then
        local _, class = UnitClass(unit)
        if class then
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, colorTable.a)
            end
        end
    else
        healthBar:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    end

    -- Apply texture
    healthBar:SetStatusBarTexture(textureFile)
    local texture = healthBar:GetStatusBarTexture()
    if texture then
        texture:SetBlendMode(blendMode)
    end
end

local function ApplyAppearanceToNativeHealthBar(healthBar, unit, glowVisible)
    pcall(ApplyAppearanceToHealthBar, healthBar, unit, glowVisible)
end

local function UpdateAllFrameAppearances()
	local function ApplyAppearanceToFrame(frame, glowVisible)
		ApplyAppearanceToBar(ns.absorbCache[frame], glowVisible)
        ApplyAppearanceToOverlay(ns.overlayCache[frame], glowVisible)
        --ApplyAppearanceToOverAbsorbGlow(ns.overAbsorbGlowCache[frame])
        ApplyAppearanceToNativeBar(frame.totalAbsorb, glowVisible)
        ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, glowVisible)
        ApplyAppearanceToNativeOverAbsorbGlow(frame.overAbsorbGlow)
		-- Apply health bar appearance
		if frame.healthBar then
			ApplyAppearanceToNativeHealthBar(frame.healthBar, frame.displayedUnit, glowVisible)
		end
	end

	-- Update party frames
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsShown() and frame.displayedUnit then
			ApplyAppearanceToFrame(frame, frame.overAbsorbGlow:IsVisible())
		end
	end

	-- Update raid frames
	if IsInRaid() then
		for i = 1, 40 do
			local frame = _G["CompactRaidFrame" .. i]
			if frame and frame:IsShown() and frame.displayedUnit then
				ApplyAppearanceToFrame(frame, frame.overAbsorbGlow:IsVisible())
			end
		end
	end

	-- Update pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		local petFramePrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
		for i = 1, 40 do
			local frame = _G[petFramePrefix .. i]
			if frame and frame:IsShown() and frame.displayedUnit then
				ApplyAppearanceToFrame(frame, frame.overAbsorbGlow:IsVisible())
			end
		end
	end
end

ns.ApplyAppearanceToBar = ApplyAppearanceToBar
ns.ApplyAppearanceToOverlay = ApplyAppearanceToOverlay
ns.ApplyAppearanceToOverAbsorbGlow = ApplyAppearanceToOverAbsorbGlow
ns.ApplyAppearanceToHealthBar = ApplyAppearanceToHealthBar
ns.UpdateAllFrameAppearances = UpdateAllFrameAppearances