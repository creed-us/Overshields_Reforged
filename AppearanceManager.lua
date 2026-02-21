local _, ns = ...

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

local function SetTextureOrAtlas(textureRegion, asset)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset) then
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
		if predicate(frame) then
			HideCustomBars(frame)
		end
	end
end

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
	local blendMode = glowVisible and db.overAbsorbBlendMode or db.absorbBlendMode
	local state = GetStyleState(bar)
	if not state or not colorTable then return end

	local colorR = colorTable.r or 1
	local colorG = colorTable.g or 1
	local colorB = colorTable.b or 1
	local colorA = colorTable.a or 1
	textureFile = textureFile or "Interface\\RaidFrame\\Shield-Fill"
	blendMode = blendMode or "ADD"

	if state.colorR ~= colorR or state.colorG ~= colorG or state.colorB ~= colorB or state.colorA ~= colorA then
		bar:SetStatusBarColor(colorR, colorG, colorB, colorA)
		state.colorR = colorR
		state.colorG = colorG
		state.colorB = colorB
		state.colorA = colorA
	end

	if state.textureFile ~= textureFile then
		bar:SetStatusBarTexture(textureFile)
		state.textureFile = textureFile
	end

	local texture = bar:GetStatusBarTexture()
	if texture then
		if state.textureObject ~= texture or state.textureFileApplied ~= textureFile then
			texture:SetTexture(textureFile, "REPEAT", "CLAMP")
			state.textureFileApplied = textureFile
			state.textureObject = texture
		end

		if state.tileSize ~= 32 then
			bar.tileSize = 32
			state.tileSize = 32
		end

		if state.blendMode ~= blendMode then
			texture:SetBlendMode(blendMode)
			state.blendMode = blendMode
		end
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

--- Applies appearance settings (color, texture, blend mode, and tiling) to a overlay bar.
-- Tiles horizontally and clamps vertically so the texture spans the full bar height.
-- @param overlay The status bar frame to style
-- @param glowVisible true when overAbsorb glow is active on the parent frame
local function ApplyAppearanceToOverlay(overlay, glowVisible)
	if not overlay or not overlay.SetStatusBarColor then return end
	local db = OvershieldsReforged.db.profile
	if not db then return end

	local colorTable = glowVisible and db.overAbsorbOverlayColor or db.overlayColor
	local textureFile = glowVisible and db.overAbsorbOverlayTexture or db.overlayTexture
	local blendMode = glowVisible and db.overAbsorbOverlayBlendMode or db.overlayBlendMode
	local state = GetStyleState(overlay)
	if not state or not colorTable then return end

	local colorR = colorTable.r or 1
	local colorG = colorTable.g or 1
	local colorB = colorTable.b or 1
	local colorA = colorTable.a or 1
	textureFile = textureFile or "Interface\\RaidFrame\\Shield-Overlay"
	blendMode = blendMode or "BLEND"

	if state.colorR ~= colorR or state.colorG ~= colorG or state.colorB ~= colorB or state.colorA ~= colorA then
		overlay:SetStatusBarColor(colorR, colorG, colorB, colorA)
		state.colorR = colorR
		state.colorG = colorG
		state.colorB = colorB
		state.colorA = colorA
	end

	if state.textureFile ~= textureFile then
		overlay:SetStatusBarTexture(textureFile)
		state.textureFile = textureFile
	end

	local texture = overlay:GetStatusBarTexture()
	if texture then
		if state.textureObject ~= texture or state.textureFileApplied ~= textureFile then
			texture:SetTexture(textureFile, "REPEAT", "CLAMP")
			state.textureFileApplied = textureFile
			state.textureObject = texture
		end

		if state.horizTile ~= true then
			texture:SetHorizTile(true)
			state.horizTile = true
		end

		if state.vertTile ~= false then
			texture:SetVertTile(false)
			state.vertTile = false
		end

		if state.blendMode ~= blendMode then
			texture:SetBlendMode(blendMode)
			state.blendMode = blendMode
		end
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

--- Iterates a pool of compact unit frames by global name prefix and applies appearance updates.
-- @param prefix Global name prefix (e.g. "CompactRaidFrame")
-- @param count Maximum frame index to check
local function UpdateFramePool(prefix, count)
	for i = 1, count do
		local frame = _G[prefix .. i]
		if frame and frame.displayedUnit then
			if frame:IsShown() then
				ApplyAppearanceToFrame(frame, IsGlowVisible(frame))
			else
				HideCustomBars(frame)
			end
		end
	end
end

--- Iterates all visible compact unit frames and applies current appearance settings.
-- Called after any appearance setting changes.
local function UpdateAllFrameAppearances()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then
		return
	end

	-- Party frames (1–5)
	if profile.enableParty ~= false then
		UpdateFramePool("CompactPartyFrameMember", 5)
	else
		HideCachedBarsByPredicate(function(frame)
			return frame and frame.displayedUnit and string.find(frame.displayedUnit, "party", 1, true) and not string.find(frame.displayedUnit, "pet", 1, true)
		end)
	end

	-- Raid frames (1–40)
	if IsInRaid() and profile.enableRaid ~= false then
		UpdateFramePool("CompactRaidFrame", 40)
	elseif IsInRaid() then
		HideCachedBarsByPredicate(function(frame)
			return frame and frame.displayedUnit and string.find(frame.displayedUnit, "raid", 1, true) and not string.find(frame.displayedUnit, "pet", 1, true)
		end)
	end

	-- Pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets and profile.enablePets ~= false then
		local petPrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
		UpdateFramePool(petPrefix, 40)
	elseif CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		HideCachedBarsByPredicate(function(frame)
			return frame and frame.displayedUnit and string.find(frame.displayedUnit, "pet", 1, true)
		end)
	end
end

ns.ApplyAppearanceToBar = ApplyAppearanceToBar
ns.ApplyAppearanceToOverlay = ApplyAppearanceToOverlay
ns.ApplyAppearanceToOverAbsorbGlow = ApplyAppearanceToOverAbsorbGlow
ns.UpdateAllFrameAppearances = UpdateAllFrameAppearances
