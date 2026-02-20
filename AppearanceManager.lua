local _, ns = ...

--- Applies appearance settings (color, texture, blend mode, and tiling) to a status bar.
-- Uses SetTexCoord for proper tiling based on frame dimensions (Bliz method).
-- @param bar The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToBar(bar, glowVisible)
    if not bar or not bar.SetStatusBarColor then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable = glowVisible and db.overAbsorbColor or db.absorbColor
    local textureFile = glowVisible and db.overAbsorbTexture or db.absorbTexture
    local blendMode   = glowVisible and db.overAbsorbBlendMode or db.absorbBlendMode

    bar:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    bar:SetStatusBarTexture(textureFile)

    local texture = bar:GetStatusBarTexture()
    if texture then
        texture:SetTexture(textureFile, "REPEAT", "CLAMP")
        -- Bliz uses tileSize = 32 for Shield-Overlay tiling
        bar.tileSize = 32
        texture:SetBlendMode(blendMode)
    end
end

--- Applies appearance settings to a native Bliz-owned bar.
-- @param bar The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToNativeBar(bar, glowVisible)
    if bar and not bar:IsForbidden() then
        ApplyAppearanceToBar(bar, glowVisible)
    end
end

--- Applies appearance settings (color, texture, blend mode, and tiling) to a  overlay bar.
-- Tiles horizontally and clamps vertically so the texture spans the full bar height.
-- @param overlay The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToOverlay(overlay, glowVisible)
    if not overlay or not overlay.SetStatusBarColor then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    local colorTable = glowVisible and db.overAbsorbOverlayColor or db.overlayColor
    local textureFile = glowVisible and db.overAbsorbOverlayTexture or db.overlayTexture
    local blendMode   = glowVisible and db.overAbsorbOverlayBlendMode or db.overlayBlendMode

    overlay:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    overlay:SetStatusBarTexture(textureFile)

    local texture = overlay:GetStatusBarTexture()
    if texture then
        texture:SetTexture(textureFile, "REPEAT", "CLAMP")
        texture:SetHorizTile(true)
        texture:SetVertTile(false)
        texture:SetBlendMode(blendMode)
    end
end

--- Applies appearance settings to a native Bliz-owned overlay, guarded against forbidden frames.
-- @param overlay The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToNativeOverlay(overlay, glowVisible)
    if overlay and not overlay:IsForbidden() then
        ApplyAppearanceToOverlay(overlay, glowVisible)
    end
end

--- Applies appearance settings (color, texture, blend mode) to the overAbsorb glow texture.
-- @param glow The Texture (or Texture-like Frame) representing the overAbsorb glow
local function ApplyAppearanceToOverAbsorbGlow(glow)
    if not glow or glow:IsForbidden() or not glow:IsVisible() then return end
    local db = OvershieldsReforged.db.profile
    if not db then return end

    glow:SetVertexColor(db.overAbsorbGlowColor.r, db.overAbsorbGlowColor.g, db.overAbsorbGlowColor.b, db.overAbsorbGlowColor.a)
    glow:SetTexture(db.overAbsorbGlowTexture)
    glow:SetBlendMode(db.overAbsorbGlowBlendMode)
end

--- Applies appearance settings to a native Bliz-owned glow, guarded against forbidden frames.
-- @param glow The Texture representing the overAbsorb glow (may be Bliz-owned)
local function ApplyAppearanceToNativeOverAbsorbGlow(glow)
    if glow and not glow:IsForbidden() then
        ApplyAppearanceToOverAbsorbGlow(glow)
    end
end

--- Applies all appearance settings to a single compact unit frame.
-- @param frame The compact unit frame
-- @param glowVisible true when overAbsorb glow is active
local function ApplyAppearanceToFrame(frame, glowVisible)
    ApplyAppearanceToBar(ns.absorbCache[frame], glowVisible)
    ApplyAppearanceToOverlay(ns.overlayCache[frame], glowVisible)
    ApplyAppearanceToNativeBar(frame.totalAbsorb, glowVisible)
    ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, glowVisible)
    ApplyAppearanceToNativeOverAbsorbGlow(frame.overAbsorbGlow)
end

--- Resolves visible glow state for a frame, guarding against forbidden access.
-- @param frame The compact unit frame
-- @return boolean true if the overAbsorb glow is visible
local function IsGlowVisible(frame)
    local glow = frame.overAbsorbGlow
    if not glow or glow:IsForbidden() then return false end
    return glow:IsVisible()
end

--- Iterates a pool of compact unit frames by global name prefix and applies appearance updates.
-- @param prefix Global name prefix (e.g. "CompactRaidFrame")
-- @param count Maximum frame index to check
local function UpdateFramePool(prefix, count)
    for i = 1, count do
        local frame = _G[prefix .. i]
        if frame and frame:IsShown() and frame.displayedUnit then
            ApplyAppearanceToFrame(frame, IsGlowVisible(frame))
        end
    end
end

--- Iterates all visible compact unit frames and applies current appearance settings.
-- Called after any appearance setting changes.
local function UpdateAllFrameAppearances()
    -- Party frames (1–5)
    UpdateFramePool("CompactPartyFrameMember", 5)

    -- Raid frames (1–40)
    if IsInRaid() then
        UpdateFramePool("CompactRaidFrame", 40)
    end

    -- Pet frames
    if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
        local petPrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
        UpdateFramePool(petPrefix, 40)
    end
end

ns.ApplyAppearanceToBar = ApplyAppearanceToBar
ns.ApplyAppearanceToOverlay = ApplyAppearanceToOverlay
ns.ApplyAppearanceToOverAbsorbGlow = ApplyAppearanceToOverAbsorbGlow
ns.UpdateAllFrameAppearances = UpdateAllFrameAppearances
