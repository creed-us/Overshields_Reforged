local _, ns = ...

local pairs = pairs
local string_find = string.find
local ipairs = ipairs
local IsInRaid = IsInRaid
local GetTime = GetTime

local styleCache = setmetatable({}, { __mode = "k" })

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

local function ResetStyleState(target)
	if target then
		styleCache[target] = nil
	end
end

local atlasCache = {}

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

local function HideCustomBars(frame)
	local absorb = ns.absorbCache[frame]
	if absorb then
		ResetStyleState(absorb)
		absorb:Hide()
	end

	local overlay = ns.overlayCache[frame]
	if overlay then
		ResetStyleState(overlay)
		overlay:Hide()
	end
end

local function HideCachedBarsByPredicate(predicate)
	for frame in pairs(ns.absorbCache) do
		if predicate(frame) then
			HideCustomBars(frame)
		end
	end
	for frame in pairs(ns.overlayCache) do
		if predicate(frame) and not ns.absorbCache[frame] then
			HideCustomBars(frame)
		end
	end
end

--- Applies color to a StatusBar only when the cached value has changed.
local function ApplyStatusBarColor(bar, state, colorR, colorG, colorB, colorA)
	if state.colorR ~= colorR or state.colorG ~= colorG or state.colorB ~= colorB or state.colorA ~= colorA then
		bar:SetStatusBarColor(colorR, colorG, colorB, colorA)
		state.colorR, state.colorG, state.colorB, state.colorA = colorR, colorG, colorB, colorA
		--@alpha@
		if ns.Debug then ns.Debug.Inc("colorApplied") end
		--@end-alpha@
	--@alpha@
	else
		if ns.Debug then ns.Debug.Inc("colorSkipped") end
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
		if ns.Debug then ns.Debug.Inc("textureApplied") end
		--@end-alpha@
	--@alpha@
	else
		if ns.Debug then ns.Debug.Inc("textureSkipped") end
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
			if ns.Debug then ns.Debug.Inc("blendApplied") end
			--@end-alpha@
		--@alpha@
		else
			if ns.Debug then ns.Debug.Inc("blendSkipped") end
		--@end-alpha@
		end
	end
end

--- Applies appearance settings (color, texture, blend mode, and tiling) to a status bar.
-- Uses SetTexCoord for proper tiling based on frame dimensions (Bliz method).
-- @param bar The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToBar(bar, glowVisible)
	if not bar or not bar.SetStatusBarColor then return end
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
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
local function ApplyAppearanceToNativeBar(bar, glowVisible)
	if bar and not bar:IsForbidden() then
		ApplyAppearanceToBar(bar, glowVisible)
	end
end

--- Applies appearance settings (color, texture, blend mode, and tiling) to a overlay bar.
-- Tiles horizontally and clamps vertically so the texture spans the full bar height.
-- @param overlay The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToOverlay(overlay, glowVisible)
	if not overlay or not overlay.SetStatusBarColor then return end
	local db = OvershieldsReforged.db and OvershieldsReforged.db.profile
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
local function ApplyAppearanceToNativeOverAbsorbGlow(glow)
	if glow and not glow:IsForbidden() then
		ApplyAppearanceToOverAbsorbGlow(glow)
	end
end

--- Applies all appearance settings to a single compact unit frame.
-- @param frame The compact unit frame
-- @param glowVisible true when overAbsorb glow is active
local function ApplyAppearanceToFrame(frame, glowVisible)
	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		HideCustomBars(frame)
		--@alpha@
		if ns.Debug then ns.Debug.Inc("contextDisabled") end
		--@end-alpha@
		return
	end

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

--- Processes a single frame for appearance updates.
-- @param frame The compact unit frame to process
local function ProcessFrame(frame)
	if frame and frame.displayedUnit then
		if frame:IsShown() then
			ApplyAppearanceToFrame(frame, IsGlowVisible(frame))
			--@alpha@
			if ns.Debug then ns.Debug.Inc("framesShown") end
			--@end-alpha@
		else
			HideCustomBars(frame)
			--@alpha@
			if ns.Debug then ns.Debug.Inc("framesHidden") end
			--@end-alpha@
		end
	end
end

--- Iterates frames from a container's pool or falls back to global name walking.
-- Modern WoW (10.0+) should use frame pools; older clients have to use global names.
-- @param container The frame container (e.g., CompactRaidFrameContainer)
-- @param prefix Global name prefix for fallback (e.g., "CompactRaidFrame")
-- @param maxCount Maximum frame index for fallback
local function UpdateFramePool(container, prefix, maxCount)
	-- Modern: iterate the container's active flow layout children (10.0+)
	if container and container.flowFrames then
		--@alpha@
		if ns.Debug then ns.Debug.Set("poolPath", "flowFrames") end
		local flowProcessed = 0
		--@end-alpha@
		for _, frame in ipairs(container.flowFrames) do
			ProcessFrame(frame)
			--@alpha@
			flowProcessed = flowProcessed + 1
			--@end-alpha@
		end
		--@alpha@
		if ns.Debug then ns.Debug.Set("poolFramesProcessed", flowProcessed) end
		--@end-alpha@
		return
	end

	-- Fallback: walk global table by name prefix
	--@alpha@
	if ns.Debug then ns.Debug.Set("poolPath", "legacy") end
	local legacyProcessed = 0
	--@end-alpha@
	for i = 1, maxCount do
		local frame = _G[prefix .. i]
		ProcessFrame(frame)
		--@alpha@
		legacyProcessed = legacyProcessed + 1
		--@end-alpha@
	end
	--@alpha@
	if ns.Debug then ns.Debug.Set("poolFramesProcessed", legacyProcessed) end
	--@end-alpha@
end

local function IsPartyUnit(frame)
	return frame and frame.displayedUnit and string_find(frame.displayedUnit, "party", 1, true) and not string_find(frame.displayedUnit, "pet", 1, true)
end

local function IsRaidUnit(frame)
	return frame and frame.displayedUnit and string_find(frame.displayedUnit, "raid", 1, true) and not string_find(frame.displayedUnit, "pet", 1, true)
end

local function IsPetUnit(frame)
	return frame and frame.displayedUnit and string_find(frame.displayedUnit, "pet", 1, true)
end

--- Iterates all visible compact unit frames and applies current appearance settings.
-- Called after any appearance setting changes.
local function UpdateAllFrameAppearances()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then
		return
	end

	--@alpha@
	if ns.Debug then
		ns.Debug.Inc("fullRefreshes")
		ns.Debug.Set("lastRefreshTime", GetTime())
	end
	--@end-alpha@

	-- Party frames (1–5)
	if profile.enableParty ~= false then
		UpdateFramePool(CompactPartyFrame, "CompactPartyFrameMember", 5)
	else
		HideCachedBarsByPredicate(IsPartyUnit)
	end

	-- Raid frames (1–40)
	local inRaid = IsInRaid()
	if inRaid and profile.enableRaid ~= false then
		UpdateFramePool(CompactRaidFrameContainer, "CompactRaidFrame", 40)
	elseif inRaid then
		HideCachedBarsByPredicate(IsRaidUnit)
	end

	-- Pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets and profile.enablePets ~= false then
		local petPrefix = inRaid and "CompactRaidFramePet" or "CompactPartyFramePet"
		UpdateFramePool(CompactRaidFrameContainer, petPrefix, 40)
	elseif CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		HideCachedBarsByPredicate(IsPetUnit)
	end
end

ns.ApplyAppearanceToBar = ApplyAppearanceToBar
ns.ApplyAppearanceToOverlay = ApplyAppearanceToOverlay
ns.ApplyAppearanceToOverAbsorbGlow = ApplyAppearanceToOverAbsorbGlow
ns.UpdateAllFrameAppearances = UpdateAllFrameAppearances

--- Wipes the style cache so all appearance values are re-applied on next update.
-- Called on profile change to prevent stale cached appearance from persisting.
function ns.WipeStyleCache()
	wipe(styleCache)
end

--@alpha@
function ns.GetStyleCacheSize()
	local n = 0
	for _ in pairs(styleCache) do n = n + 1 end
	return n
end
--@end-alpha@
