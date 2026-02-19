local _, ns = ...

--- Applies appearance settings (color, texture, and tiling) to a status bar.
-- Uses SetTexCoord for proper tiling based on frame dimensions (Blizzard method).
-- @param bar The status bar frame to style
-- @param colorTable Table with r, g, b, a keys for color
-- @param textureFile Path to texture file for the bar
local function ApplyAppearanceToBar(bar, colorTable, textureFile)
	if not bar then return end

	-- Apply color and transparency
	bar:SetStatusBarColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)

	-- Apply texture
	bar:SetStatusBarTexture(textureFile)

	-- Configure tiling using SetTexCoord for proper vertical/horizontal tiling
	-- This matches Blizzard's approach in CompactUnitFrame
	local texture = bar:GetStatusBarTexture()
	if texture then
		texture:SetTexture(textureFile, "REPEAT", "REPEAT")
		-- Set tileSize (Blizzard uses 32 for Shield-Overlay)
		bar.tileSize = 32
		-- Calculate proper texture coordinates based on frame size
		local _, height = bar:GetSize()
		if height then
			-- Use full width, scale height based on tileSize
			texture:SetTexCoord(0, 1, 0, height / bar.tileSize)
		end
	end
end

--- Applies shield bar appearance to a custom absorb bar.
-- @param absorb The custom shield bar StatusBar frame
function ns.ApplyShieldBarAppearance(absorb)
	local db = OvershieldsReforged.db.profile
	if not db then return end
	ApplyAppearanceToBar(absorb, db.absorbColor, db.absorbTexture)
end

--- Applies overlay bar appearance to a custom overlay bar.
-- Uses basic tiling without SetTexCoord adjustments.
-- @param overlay The custom overlay bar StatusBar frame
function ns.ApplyOverlayBarAppearance(overlay)
    local db = OvershieldsReforged.db.profile
    if not db then return end

	-- Apply color and transparency
	overlay:SetStatusBarColor(db.overlayColor.r, db.overlayColor.g, db.overlayColor.b, db.overlayColor.a)

	-- Apply texture with basic tiling
	overlay:SetStatusBarTexture(db.overlayTexture)
	local texture = overlay:GetStatusBarTexture()
	if texture then
		texture:SetTexture(db.overlayTexture, "REPEAT", "REPEAT")
		texture:SetHorizTile(true)
		texture:SetVertTile(true)
	end
end

--- Applies shield bar appearance to Blizzard's native totalAbsorb frame.
-- @param totalAbsorb The native absorb bar frame
function ns.ApplyNativeShieldAppearance(totalAbsorb)
	local db = OvershieldsReforged.db.profile
	if not db or not totalAbsorb or totalAbsorb:IsForbidden() then return end
	pcall(ApplyAppearanceToBar, totalAbsorb, db.absorbColor, db.absorbTexture)
end

--- Applies overlay appearance to Blizzard's native totalAbsorbOverlay frame.
-- @param totalAbsorbOverlay The native overlay bar frame
function ns.ApplyNativeOverlayAppearance(totalAbsorbOverlay)
	local db = OvershieldsReforged.db.profile
	if not db or not totalAbsorbOverlay or totalAbsorbOverlay:IsForbidden() then return end
	pcall(ApplyAppearanceToBar, totalAbsorbOverlay, db.overlayColor, db.overlayTexture)
end

--- Updates appearance for all visible compact unit frames and their custom bars.
-- Called when appearance settings change in options.
function ns.UpdateAllFrameAppearances()
	local function ApplyAppearanceToFrame(frame)
		ns.ApplyShieldBarAppearance(ns.absorbBarCache[frame])
		ns.ApplyOverlayBarAppearance(ns.overlayBarCache[frame])
		ns.ApplyNativeShieldAppearance(frame.totalAbsorb)
		ns.ApplyNativeOverlayAppearance(frame.totalAbsorbOverlay)
	end

	-- Update party frames
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsShown() and frame.displayedUnit then
			ApplyAppearanceToFrame(frame)
		end
	end

	-- Update raid frames
	if IsInRaid() then
		for i = 1, 40 do
			local frame = _G["CompactRaidFrame" .. i]
			if frame and frame:IsShown() and frame.displayedUnit then
				ApplyAppearanceToFrame(frame)
			end
		end
	end

	-- Update pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		local petFramePrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
		for i = 1, 40 do
			local frame = _G[petFramePrefix .. i]
			if frame and frame:IsShown() and frame.displayedUnit then
				ApplyAppearanceToFrame(frame)
			end
		end
	end
end

--- Queues updates for all visible compact unit frames
-- Batches frames for efficient processing via CompactUnitFrame update system.
function ns.UpdateAllCompactUnitFrames()
	local function QueueFrameUpdates(framePrefix, count)
		for i = 1, count do
			local frame = _G[framePrefix .. i]
			if frame and frame:IsShown() and frame.displayedUnit and UnitExists(frame.displayedUnit) then
				ns.QueueCompactUnitFrameUpdate(frame)
			end
		end
	end

	-- Queue party frames
	QueueFrameUpdates("CompactPartyFrameMember", 5)

	-- Queue raid frames
	if IsInRaid() then
		QueueFrameUpdates("CompactRaidFrame", 40)
	end

	-- Queue pet frames
	if CompactRaidFrameContainer and CompactRaidFrameContainer.displayPets then
		local petFramePrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
		QueueFrameUpdates(petFramePrefix, 40)
	end
end
