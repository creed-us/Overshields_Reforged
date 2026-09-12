local _, ns = ...

local styleCache = setmetatable({}, { __mode = "k" })
ns.StyleCache = styleCache

local function GetStyleState(target)
	if not target then
		return nil
	end

	local state = styleCache[target]
	if not state then
		state = {}
		styleCache[target] = state
	end

	return state
end

local function SetTextureOrAtlas(textureRegion, asset)
	if ns.IsAtlasAsset(asset) then
		textureRegion:SetAtlas(asset, false, nil, true)
	else
		textureRegion:SetTexture(asset)
	end
	textureRegion:SetTexCoord(0, 1, 0, 1)
end

--- Applies color to a StatusBar only when the cached value has changed.
local function ApplyStatusBarColor(bar, state, colorR, colorG, colorB, colorA)
	if state.colorR ~= colorR or state.colorG ~= colorG or state.colorB ~= colorB or state.colorA ~= colorA then
		bar:SetStatusBarColor(colorR, colorG, colorB, colorA)
		state.colorR, state.colorG, state.colorB, state.colorA = colorR, colorG, colorB, colorA
		--@alpha@
		ns.Emit("colorApplied")
		--@end-alpha@
	--@alpha@
	else
		ns.Emit("colorSkipped")
	--@end-alpha@
	end
end

--- Applies texture and blend mode to a StatusBar only when cached values have changed.
-- @param applyTiling When true, sets horizTile=true and vertTile=false (used by overlay bars)
local function ApplyStatusBarTextureAndBlend(bar, state, textureFile, blendMode, applyTiling)
	if state.textureFile ~= textureFile then
		bar:SetStatusBarTexture(textureFile)
		state.textureFile = textureFile
		--@alpha@
		ns.Emit("textureApplied")
		--@end-alpha@
	--@alpha@
	else
		ns.Emit("textureSkipped")
	--@end-alpha@
	end
	local texture = bar:GetStatusBarTexture()
	if texture then
		if state.textureObject ~= texture or state.textureFileApplied ~= textureFile then
			texture:SetTexture(textureFile, "REPEAT", "CLAMP")
			state.textureFileApplied = textureFile
			state.textureObject = texture
		end
		if applyTiling then
			if state.horizTile ~= true then texture:SetHorizTile(true); state.horizTile = true end
			if state.vertTile ~= false then texture:SetVertTile(false); state.vertTile = false end
		end
		if state.blendMode ~= blendMode then
			texture:SetBlendMode(blendMode)
			state.blendMode = blendMode
			--@alpha@
			ns.Emit("blendApplied")
			--@end-alpha@
		--@alpha@
		else
			ns.Emit("blendSkipped")
		--@end-alpha@
		end
	end
end

local function ApplyTextureRegionStyle(region, state, colorTable, textureFile, blendMode, applyTiling)
	if not region or not state or not colorTable then return end

	local colorR = colorTable.r or 1
	local colorG = colorTable.g or 1
	local colorB = colorTable.b or 1
	local colorA = colorTable.a or 1

	if region.SetVertexColor and (
		state.colorR ~= colorR
		or state.colorG ~= colorG
		or state.colorB ~= colorB
		or state.colorA ~= colorA
	) then
		region:SetVertexColor(colorR, colorG, colorB, colorA)
		state.colorR, state.colorG, state.colorB, state.colorA = colorR, colorG, colorB, colorA
	end

	if region.SetTexture and state.textureFile ~= textureFile then
		SetTextureOrAtlas(region, textureFile)
		state.textureFile = textureFile
	end

	if region.SetTexCoord and state.texCoordReset ~= true then
		region:SetTexCoord(0, 1, 0, 1)
		state.texCoordReset = true
	end

	if region.SetHorizTile and region.SetVertTile then
		local desiredHoriz = applyTiling and true or false
		local desiredVert = false
		if state.horizTile ~= desiredHoriz then
			region:SetHorizTile(desiredHoriz)
			state.horizTile = desiredHoriz
		end
		if state.vertTile ~= desiredVert then
			region:SetVertTile(desiredVert)
			state.vertTile = desiredVert
		end
	end

	if region.SetBlendMode and state.blendMode ~= blendMode then
		region:SetBlendMode(blendMode)
		state.blendMode = blendMode
	end
end

--- Applies appearance settings (color, texture, blend mode, and tiling) to a status bar.
-- Uses SetTexCoord for proper tiling based on frame dimensions (Bliz method).
-- @param bar The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table; when provided, skips the global lookup
function ns.ApplyAppearanceToBar(bar, glowVisible, profile)
	if not bar or not bar.SetStatusBarColor then return end
	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	local colorTable = glowVisible and db.overAbsorbColor or db.absorbColor
	local textureFile = (glowVisible and db.overAbsorbTexture or db.absorbTexture) or "Interface\\RaidFrame\\Shield-Fill"
	local blendMode = (glowVisible and db.overAbsorbBlendMode or db.absorbBlendMode) or "ADD"
	local state = GetStyleState(bar)
	if not state or not colorTable then return end

	ApplyStatusBarColor(bar, state, colorTable.r or 1, colorTable.g or 1, colorTable.b or 1, colorTable.a or 1)
	ApplyStatusBarTextureAndBlend(bar, state, textureFile, blendMode, false)
end

--- Applies appearance settings to a native Bliz-owned bar.
-- Native bars can have their appearance reset by Blizzard at any time,
-- so we clear cached state before applying to ensure our settings take effect.
-- @param bar The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeBar(bar, glowVisible, profile)
	if not bar or bar:IsForbidden() then
		return
	end

	styleCache[bar] = nil

	if bar.SetStatusBarColor then
		ns.ApplyAppearanceToBar(bar, glowVisible, profile)
		return
	end

	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	local colorTable = glowVisible and db.overAbsorbColor or db.absorbColor
	local textureFile = (glowVisible and db.overAbsorbTexture or db.absorbTexture) or "Interface\\RaidFrame\\Shield-Fill"
	local blendMode = (glowVisible and db.overAbsorbBlendMode or db.absorbBlendMode) or "ADD"
	local state = GetStyleState(bar)
	ApplyTextureRegionStyle(bar, state, colorTable, textureFile, blendMode, false)

	-- Some native absorb implementations expose the visual texture via .fill
	if not ns.FrameIsForbidden(bar.fill) then
		styleCache[bar.fill] = nil
		local fillState = GetStyleState(bar.fill)
		ApplyTextureRegionStyle(bar.fill, fillState, colorTable, textureFile, blendMode, false)
	end
end

--- Applies appearance settings (color, texture, blend mode, and tiling) to a overlay bar.
-- Tiles horizontally and clamps vertically so the texture spans the full bar height.
-- @param overlay The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table; when provided, skips the global lookup
function ns.ApplyAppearanceToOverlay(overlay, glowVisible, profile)
	if not overlay or not overlay.SetStatusBarColor then return end
	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	local colorTable = glowVisible and db.overAbsorbOverlayColor or db.overlayColor
	local textureFile = (glowVisible and db.overAbsorbOverlayTexture or db.overlayTexture) or "Interface\\RaidFrame\\Shield-Overlay"
	local blendMode = (glowVisible and db.overAbsorbOverlayBlendMode or db.overlayBlendMode) or "BLEND"
	local state = GetStyleState(overlay)
	if not state or not colorTable then return end

	ApplyStatusBarColor(overlay, state, colorTable.r or 1, colorTable.g or 1, colorTable.b or 1, colorTable.a or 1)
	ApplyStatusBarTextureAndBlend(overlay, state, textureFile, blendMode, true)
end

--- Applies appearance settings to a native Bliz-owned overlay, guarded against forbidden frames.
-- Native overlays can have their appearance reset by Blizzard at any time,
-- so we clear cached state before applying to ensure our settings take effect.
-- @param overlay The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeOverlay(overlay, glowVisible, profile)
	if ns.FrameIsForbidden(overlay) then
		return
	end

	styleCache[overlay] = nil

	if overlay.SetStatusBarColor then
		ns.ApplyAppearanceToOverlay(overlay, glowVisible, profile)
		return
	end

	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end

	local colorTable = glowVisible and db.overAbsorbOverlayColor or db.overlayColor
	local textureFile = (glowVisible and db.overAbsorbOverlayTexture or db.overlayTexture) or "Interface\\RaidFrame\\Shield-Overlay"
	local blendMode = (glowVisible and db.overAbsorbOverlayBlendMode or db.overlayBlendMode) or "BLEND"
	local state = GetStyleState(overlay)
	ApplyTextureRegionStyle(overlay, state, colorTable, textureFile, blendMode, true)
end

--- Applies appearance settings (color, texture, blend mode) to the overAbsorb glow texture.
-- @param glow The Texture (or Texture-like Frame) representing the overAbsorb glow
-- @param profile Optional db.profile table; when provided, skips the global lookup
function ns.ApplyAppearanceToOverAbsorbGlow(glow, profile)
	if ns.FrameIsForbidden(glow) or not glow:IsVisible() then return end
	local db = profile or OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not db then return end
	local state = GetStyleState(glow)
	local glowColor = db.overAbsorbGlowColor
	if not state or not glowColor then return end

	local colorR = glowColor.r or 1
	local colorG = glowColor.g or 1
	local colorB = glowColor.b or 1
	local colorA = glowColor.a or 1
	local textureFile = db.overAbsorbGlowTexture or "Interface\\RaidFrame\\Shield-Overshield"
	local blendMode = db.overAbsorbGlowBlendMode or "ADD"

	if state.colorR ~= colorR
		or state.colorG ~= colorG
		or state.colorB ~= colorB
		or state.colorA ~= colorA then
		glow:SetVertexColor(colorR, colorG, colorB, colorA)
		state.colorR = colorR
		state.colorG = colorG
		state.colorB = colorB
		state.colorA = colorA
	end

	if state.textureFile ~= textureFile then
		SetTextureOrAtlas(glow, textureFile)
		state.textureFile = textureFile
	end

	if state.blendMode ~= blendMode then
		glow:SetBlendMode(blendMode)
		state.blendMode = blendMode
	end
end

--- Applies appearance settings to a native Bliz-owned glow, guarded against forbidden frames.
-- Native glows can have their appearance reset by Blizzard at any time,
-- so we clear cached state before applying to ensure our settings take effect.
-- @param glow The Texture representing the overAbsorb glow (may be Bliz-owned)
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeOverAbsorbGlow(glow, profile)
	if not ns.FrameIsForbidden(glow) then
		styleCache[glow] = nil
		ns.ApplyAppearanceToOverAbsorbGlow(glow, profile)
	end
end

local function IsNativeVisualOnlyShielded(frame, glowVisible, profile)
	if not frame or not profile or glowVisible then
		return false
	end

	if profile.anchorModeShielded ~= "health_right" then
		return false
	end

	return ns.ResolveShieldState(frame, glowVisible) == "shielded"
end

--- Applies all appearance settings to a single compact unit frame.
-- @param frame The compact unit frame
-- @param glowVisible true when overAbsorb glow is active
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToFrame(frame, glowVisible, profile)
	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		ns.ReleaseFrame(frame, styleCache)
		--@alpha@
		ns.Emit("contextDisabled")
		--@end-alpha@
		return
	end

	if not profile then return end

	if IsNativeVisualOnlyShielded(frame, glowVisible, profile) then
		ns.HideCustomBars(frame, styleCache)
		ns.ApplyAppearanceToNativeBar(frame.totalAbsorb, glowVisible, profile)
		ns.ApplyAppearanceToNativeOverlay(frame.totalAbsorbOverlay, glowVisible, profile)
		ns.ApplyAppearanceToNativeOverAbsorbGlow(frame.overAbsorbGlow, profile)
		return
	end

	ns.ApplyAppearanceToBar(ns.absorbCache[frame], glowVisible, profile)
	ns.ApplyAppearanceToOverlay(ns.overlayCache[frame], glowVisible, profile)
	ns.ApplyAppearanceToNativeOverAbsorbGlow(frame.overAbsorbGlow, profile)
end

--- ns.wipes the style cache so all appearance values are re-applied on ns.next update.
-- Called on profile change to prevent stale cached appearance from persisting.
function ns.wipeStyleCache()
	ns.wipe(styleCache)
	ns.WipeAtlasCache()
end

--@alpha@
function ns.GetStyleCacheSize()
	local n = 0
	for _ in ns.pairs(styleCache) do n = n + 1 end
	return n
end
--@end-alpha@
