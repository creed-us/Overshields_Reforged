local _, ns = ...

--- Vanilla Blizzard default values for absorb visuals.
-- Used when releasing frames to restore them to vanilla behavior.
-- Tiling: horizTile/vertTile match Blizzard's default for each element type.
ns.VanillaDefaults = {
	absorbColor = { r = 1, g = 1, b = 1, a = 1 },
	absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
	absorbBlendMode = "ADD",
	absorbHorizTile = false,
	absorbVertTile = false,
	overlayColor = { r = 1, g = 1, b = 1, a = 1 },
	overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
	overlayBlendMode = "BLEND",
	overlayHorizTile = true,  -- Blizzard tiles overlay horizontally
	overlayVertTile = false,
	glowColor = { r = 1, g = 1, b = 1, a = 1 },
	glowTexture = "Interface\\RaidFrame\\Shield-Overshield",
	glowBlendMode = "ADD",
	glowHorizTile = false,
	glowVertTile = false,
}

function ns.FrameIsForbidden(frame)
	local frameType = type(frame)
	if not frame or (frameType ~= "table" and frameType ~= "userdata") then return true end
	if type(frame.IsForbidden) == "function" and frame:IsForbidden() then return true end
	return false
end

function ns.IsSettingEnabled(value)
	return value ~= false
end

local atlasCache = {}

--- Returns whether an asset name is a texture atlas (vs. a plain file path), caching the lookup.
-- @param asset The texture path or atlas name to check
-- @return boolean true if the asset is a known atlas
function ns.IsAtlasAsset(asset)
	local isAtlas = atlasCache[asset]
	if isAtlas == nil then
		isAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset) and true or false
		atlasCache[asset] = isAtlas
	end
	return isAtlas
end

--- Resets a custom bar to its default state.
-- Clears anchor mode, resets anchor points, and hides the bar.
-- @param bar The custom StatusBar to reset
-- @param styleCache Optional style cache to clear entry from
local function ResetCustomBar(bar, styleCache)
	if not bar then return end

	-- Clear style cache entry
	if styleCache then
		styleCache[bar] = nil
	end

	-- Reset anchor mode so next update will reposition
	bar._anchorMode = nil

	-- Clear all anchor points and reset to default detached state
	bar:ClearAllPoints()

	-- Reset value to prevent visual artifacts
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	-- Hide the bar
	bar:Hide()
end

function ns.HideCustomBars(frame, styleCache)
	local absorb = ns.absorbCache[frame]
	if absorb then
		ResetCustomBar(absorb, styleCache)
	end

	local overlay = ns.overlayCache[frame]
	if overlay then
		ResetCustomBar(overlay, styleCache)
	end
end

--- Restores a single texture region to vanilla Blizzard defaults.
-- @param region The texture region (Texture or StatusBar) to restore
-- @param colorTable Table with r, g, b, a fields for the color
-- @param textureFile Texture path to restore
-- @param blendMode Blend mode to restore
-- @param horizTile Horizontal tiling setting (true/false)
-- @param vertTile Vertical tiling setting (true/false)
local function RestoreRegionToVanilla(region, colorTable, textureFile, blendMode, horizTile, vertTile)
	if ns.FrameIsForbidden(region) then return end

	local r, g, b, a = colorTable.r, colorTable.g, colorTable.b, colorTable.a

	-- Determine wrap modes based on tiling
	local horizWrap = horizTile and "REPEAT" or "CLAMP"
	local vertWrap = vertTile and "REPEAT" or "CLAMP"

	-- Restore color and texture for StatusBars
	if region.SetStatusBarColor then
		region:SetStatusBarColor(r, g, b, a)
		-- Set the status bar texture with proper wrap modes
		region:SetStatusBarTexture(textureFile, horizWrap, vertWrap)
		local texture = region:GetStatusBarTexture()
		if texture then
			texture:SetBlendMode(blendMode)
			texture:SetTexCoord(0, 1, 0, 1)
			if texture.SetHorizTile then
				texture:SetHorizTile(horizTile or false)
			end
			if texture.SetVertTile then
				texture:SetVertTile(vertTile or false)
			end
		end
	elseif region.SetVertexColor then
		region:SetVertexColor(r, g, b, a)
	end

	-- Restore texture with proper wrap modes for Texture regions
	if region.SetTexture then
		region:SetTexture(textureFile, horizWrap, vertWrap)
		region:SetTexCoord(0, 1, 0, 1)
	end

	-- Restore blend mode
	if region.SetBlendMode then
		region:SetBlendMode(blendMode)
	end

	-- Restore tiling settings
	if region.SetHorizTile then
		region:SetHorizTile(horizTile or false)
	end
	if region.SetVertTile then
		region:SetVertTile(vertTile or false)
	end
end

--- Restores native Blizzard absorb bar visibility and appearance for a frame.
-- Resets appearance to vanilla defaults and lets Blizzard control visibility.
-- Called when the addon stops managing a frame so Blizzard visuals behave normally.
-- @param frame The compact unit frame
-- @param styleCache Optional style cache to clear entries from
function ns.RestoreNativeAbsorbVisuals(frame, styleCache)
	if not frame or ns.FrameIsForbidden(frame) then return end

	local defaults = ns.VanillaDefaults

	-- Restore native absorb bar appearance (don't force visibility - let Blizzard control it)
	local nativeAbsorb = frame.totalAbsorb
	if not ns.FrameIsForbidden(nativeAbsorb) then
		RestoreRegionToVanilla(nativeAbsorb, defaults.absorbColor, defaults.absorbTexture, defaults.absorbBlendMode, defaults.absorbHorizTile, defaults.absorbVertTile)

		-- Also restore the .fill sub-texture if present
		if not ns.FrameIsForbidden(nativeAbsorb.fill) then
			RestoreRegionToVanilla(nativeAbsorb.fill, defaults.absorbColor, defaults.absorbTexture, defaults.absorbBlendMode, defaults.absorbHorizTile, defaults.absorbVertTile)
		end

		-- Restore the nested overlay (uses overlay tiling - horizontal)
		if not ns.FrameIsForbidden(nativeAbsorb.overlay) then
			RestoreRegionToVanilla(nativeAbsorb.overlay, defaults.overlayColor, defaults.overlayTexture, defaults.overlayBlendMode, defaults.overlayHorizTile, defaults.overlayVertTile)
		end

		-- Clear style cache entries
		if styleCache then
			styleCache[nativeAbsorb] = nil
			if nativeAbsorb.fill then styleCache[nativeAbsorb.fill] = nil end
			if nativeAbsorb.overlay then styleCache[nativeAbsorb.overlay] = nil end
		end
	end

	-- Restore native overlay bar appearance (uses overlay tiling - horizontal)
	local nativeOverlay = frame.totalAbsorbOverlay
	if not ns.FrameIsForbidden(nativeOverlay) then
		RestoreRegionToVanilla(nativeOverlay, defaults.overlayColor, defaults.overlayTexture, defaults.overlayBlendMode, defaults.overlayHorizTile, defaults.overlayVertTile)

		if styleCache then
			styleCache[nativeOverlay] = nil
		end
	end

	-- Restore overAbsorb glow appearance
	local glow = frame.overAbsorbGlow
	if not ns.FrameIsForbidden(glow) then
		RestoreRegionToVanilla(glow, defaults.glowColor, defaults.glowTexture, defaults.glowBlendMode, defaults.glowHorizTile, defaults.glowVertTile)

		if styleCache then
			styleCache[glow] = nil
		end
	end
end

--- Releases a single frame from addon management.
-- Hides custom bars, removes cache entries, and restores native visuals to vanilla.
-- @param frame The compact unit frame to release
-- @param styleCache The style cache to clear entries from
function ns.ReleaseFrame(frame, styleCache)
	if not frame or ns.FrameIsForbidden(frame) then return end

	-- Hide and clear custom bars
	ns.HideCustomBars(frame, styleCache)

	-- Remove from bar caches (but don't destroy - can be reused later)
	-- Note: We keep the bars in the cache for potential reuse; they're just hidden

	-- Restore native visuals to vanilla Blizzard behavior
	ns.RestoreNativeAbsorbVisuals(frame, styleCache)
end

--- Resolves visible glow state for a frame, guarding against forbidden access.
-- @param frame The compact unit frame
-- @return boolean true if the overAbsorb glow is visible
function ns.IsGlowVisible(frame)
	if ns.FrameIsForbidden(frame) then return false end
	local glow = frame.overAbsorbGlow
	if ns.FrameIsForbidden(glow) then return false end
	return glow:IsVisible()
end