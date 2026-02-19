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
    if glowVisible then
        colorTable = db.overAbsorbColor
        textureFile = db.overAbsorbTexture
    end

    -- Apply color and transparency
    absorb:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

    -- Apply texture
    absorb:SetStatusBarTexture(textureFile)

    -- Configure tiling using SetTexCoord for proper vertical/horizontal tiling
    -- This matches Blizzard's approach in CompactUnitFrame
    local texture = absorb:GetStatusBarTexture()
    if texture then
        texture:SetTexture(textureFile, "REPEAT", "REPEAT")
        -- Set tileSize (Blizzard uses 32 for Shield-Overlay)
        absorb.tileSize = 32
        -- Calculate proper texture coordinates based on frame size
        local _, height = absorb:GetSize()
        if height then
            -- Use full width, scale height based on tileSize
            texture:SetTexCoord(0, 1, 0, height / absorb.tileSize)
        end
    end
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
    if glowVisible then
        colorTable = db.overAbsorbOverlayColor
        textureFile = db.overAbsorbOverlayTexture
    end

    -- Apply color and transparency
    overlay:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

    -- Apply texture with basic tiling
    overlay:SetStatusBarTexture(textureFile)
    local texture = overlay:GetStatusBarTexture()
    if texture then
        texture:SetTexture(textureFile, "REPEAT", "REPEAT")
        texture:SetHorizTile(true)
        texture:SetVertTile(true)
    end
end

local function ApplyAppearanceToNativeOverlay(overlay, glowVisible)
	pcall(ApplyAppearanceToOverlay, overlay, glowVisible)
end

ns.ApplyAppearanceToBar = ApplyAppearanceToBar
ns.ApplyAppearanceToOverlay = ApplyAppearanceToOverlay
ns.UpdateAllFrameAppearances = function()
	local function ApplyAppearanceToFrame(frame, glowVisible)
		ApplyAppearanceToBar(ns.absorbCache[frame], glowVisible)
        ApplyAppearanceToOverlay(ns.overlayCache[frame], glowVisible)
        ApplyAppearanceToNativeBar(frame.totalAbsorb, glowVisible)
		ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, glowVisible)
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
