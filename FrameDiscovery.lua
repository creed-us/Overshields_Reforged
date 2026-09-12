local _, ns = ...

--- Processes a single frame for appearance updates.
-- @param frame The compact unit frame to process
-- @param profile The active db.profile table
local function ProcessFrame(frame, profile)
	if ns.FrameIsForbidden(frame) or not frame.displayedUnit or not ns.IsKnownCompactUnitFrame(frame) then return end

	if frame:IsShown() then
		ns.QueueCompactUnitFrameUpdate(frame)
		--@alpha@
		ns.Emit("framesShown")
		--@end-alpha@
	else
		ns.ReleaseFrame(frame, styleCache)
		--@alpha@
		ns.Emit("framesHidden")
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
	local frames = {}
	for frame in ns.pairs(ns.absorbCache) do
		if predicate(frame) then
			frames[frame] = true
		end
	end
	for frame in ns.pairs(ns.overlayCache) do
		if predicate(frame) then
			frames[frame] = true
		end
	end

	for frame in ns.pairs(frames) do
		ns.ReleaseFrame(frame, styleCache)
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
		ns.Emit("poolPath", "flowFrames")
		local flowProcessed = 0
		--@end-alpha@
		for _, frame in ns.ipairs(container.flowFrames) do
			ProcessFrame(frame, profile)
			--@alpha@
			flowProcessed = flowProcessed + 1
			--@end-alpha@
		end
		--@alpha@
		ns.Emit("poolFramesProcessed", flowProcessed)
		--@end-alpha@
		return
	end

	-- Fallback: walk global table by name prefix
	--@alpha@
	ns.Emit("poolPath", "legacy")
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
	ns.Emit("poolFramesProcessed", legacyProcessed)
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
	ns.Emit("fullRefreshes")
	ns.Emit("lastRefreshTime", ns.GetTime())
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
