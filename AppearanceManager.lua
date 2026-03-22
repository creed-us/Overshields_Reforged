local _, ns = ...

local styleCache = setmetatable({}, { __mode = "k" })
ns.StyleCache = styleCache

local atlasCache = {}

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
	local isAtlas = atlasCache[asset]
	if isAtlas == nil then
		isAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset) and true or false
		atlasCache[asset] = isAtlas
	end

	if isAtlas then
		textureRegion:SetAtlas(asset, false, nil, true)
		textureRegion:SetTexCoord(0, 1, 0, 1)
		return
	end

	textureRegion:SetTexture(asset)
	textureRegion:SetTexCoord(0, 1, 0, 1)
end

--- Applies color to a StatusBar only when the cached value has changed.
local function ApplyStatusBarColor(bar, state, colorR, colorG, colorB, colorA)
	if state.colorR ~= colorR or state.colorG ~= colorG or state.colorB ~= colorB or state.colorA ~= colorA then
		bar:SetStatusBarColor(colorR, colorG, colorB, colorA)
		state.colorR, state.colorG, state.colorB, state.colorA = colorR, colorG, colorB, colorA
		--@alpha@
		ns.Debug.Inc("colorApplied")
		--@end-alpha@
	--@alpha@
	else
		ns.Debug.Inc("colorSkipped")
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
		ns.Debug.Inc("textureApplied")
		--@end-alpha@
	--@alpha@
	else
		ns.Debug.Inc("textureSkipped")
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
			ns.Debug.Inc("blendApplied")
			--@end-alpha@
		--@alpha@
		else
			ns.Debug.Inc("blendSkipped")
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
-- @param bar The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeBar(bar, glowVisible, profile)
	if not bar or bar:IsForbidden() then
		return
	end

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
-- @param overlay The status bar frame to style (may be Bliz-owned)
-- @param glowVisible true when overAbsorb glow is active on the parent frame
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeOverlay(overlay, glowVisible, profile)
	if ns.FrameIsForbidden(overlay) then
		return
	end

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
	local db = profile or OvershieldsReforged.db.profile
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
-- @param glow The Texture representing the overAbsorb glow (may be Bliz-owned)
-- @param profile Optional db.profile table
function ns.ApplyAppearanceToNativeOverAbsorbGlow(glow, profile)
	if not ns.FrameIsForbidden(glow) then
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
		ns.HideCustomBars(frame, styleCache)
		--@alpha@
		ns.Debug.Inc("contextDisabled")
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

--- Processes a single frame for appearance updates.
-- @param frame The compact unit frame to process
-- @param profile The active db.profile table
local function ProcessFrame(frame, profile)
	if ns.FrameIsForbidden(frame) or not frame.displayedUnit then return end

	if frame:IsShown() then
		ns.QueueCompactUnitFrameUpdate(frame)
		--@alpha@
		ns.Debug.Inc("framesShown")
		--@end-alpha@
	else
		ns.HideCustomBars(frame, styleCache)
		--@alpha@
		ns.Debug.Inc("framesHidden")
		--@end-alpha@
	end
end

local function IsPartyUnit(frame)
	return frame and ns.GetUnitContext(frame.displayedUnit) == "party"
end

local function IsRaidUnit(frame)
	return frame and ns.GetUnitContext(frame.displayedUnit) == "raid"
end

local function IsPetUnit(frame)
	return frame and ns.GetUnitContext(frame.displayedUnit) == "pet"
end

local function HideCachedBarsByPredicate(predicate)
	for frame in ns.pairs(ns.absorbCache) do
		if predicate(frame) then
			ns.HideCustomBars(frame, styleCache)
			ns.RestoreNativeAbsorbVisuals(frame)
		end
	end
	for frame in ns.pairs(ns.overlayCache) do
		if predicate(frame) and not ns.absorbCache[frame] then
			ns.HideCustomBars(frame, styleCache)
			ns.RestoreNativeAbsorbVisuals(frame)
		end
	end
end

--- Iterates frames from a container's pool or falls back to global name walking.
-- Modern WoW (10.0+) should use frame pools; older clients have to use global names.
-- @param container The frame container (e.g., CompactRaidFrameContainer)
-- @param prefix Global name prefix for fallback (e.g., "CompactRaidFrame")
-- @param maxCount Maximum frame index for fallback
local function UpdateFramePool(container, prefix, maxCount, profile)
	-- Modern: iterate the container's active flow layout children (10.0+)
	if container and container.flowFrames then
		--@alpha@
		ns.Debug.Set("poolPath", "flowFrames")
		local flowProcessed = 0
		--@end-alpha@
		for _, frame in ns.ipairs(container.flowFrames) do
			ProcessFrame(frame, profile)
			--@alpha@
			flowProcessed = flowProcessed + 1
			--@end-alpha@
		end
		--@alpha@
		ns.Debug.Set("poolFramesProcessed", flowProcessed)
		--@end-alpha@
		return
	end

	-- Fallback: walk global table by name prefix
	--@alpha@
	ns.Debug.Set("poolPath", "legacy")
	local legacyProcessed = 0
	--@end-alpha@
	for i = 1, maxCount do
		local frame = _G[prefix .. i]
		ProcessFrame(frame, profile)
		--@alpha@
		legacyProcessed = legacyProcessed + 1
		--@end-alpha@
	end
	--@alpha@
	ns.Debug.Set("poolFramesProcessed", legacyProcessed)
	--@end-alpha@
end

--- Iterates all visible compact unit frames and applies current appearance settings.
-- Called after any appearance setting changes.
function ns.UpdateAllFrameAppearances()
	if ns.hibernating then return end

	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then
		return
	end

	--@alpha@
	ns.Debug.Inc("fullRefreshes")
	ns.Debug.Set("lastRefreshTime", ns.GetTime())
	--@end-alpha@

	-- Party frames (1–5)
	if ns.IsSettingEnabled(profile.enableParty) then
		UpdateFramePool(CompactPartyFrame, "CompactPartyFrameMember", 5, profile)
	else
		HideCachedBarsByPredicate(IsPartyUnit)
	end

	-- Raid frames (1–40)
	if ns.IsInRaid() and ns.IsSettingEnabled(profile.enableRaid) then
		UpdateFramePool(CompactRaidFrameContainer, "CompactRaidFrame", 40, profile)
	elseif ns.IsInRaid() then
		HideCachedBarsByPredicate(IsRaidUnit)
	end

	-- Pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets and ns.IsSettingEnabled(profile.enablePets) then
		local petPrefix = ns.IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
		UpdateFramePool(CompactRaidFrameContainer, petPrefix, 40, profile)
	elseif CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		HideCachedBarsByPredicate(IsPetUnit)
	end
end

--- ns.wipes the style cache so all appearance values are re-applied on ns.next update.
-- Called on profile change to prevent stale cached appearance from persisting.
function ns.wipeStyleCache()
	ns.wipe(styleCache)
	ns.wipe(atlasCache)
end

--@alpha@
function ns.GetStyleCacheSize()
	local n = 0
	for _ in ns.pairs(styleCache) do n = n + 1 end
	return n
end
--@end-alpha@
