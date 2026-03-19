local _, ns = ...

function ns.FrameIsForbidden(frame)
	if not frame then return true end
	if frame.IsForbidden and frame:IsForbidden() then return true end
	return false
end

function ns.IsSettingEnabled(value)
	return value ~= false
end

function ns.HideCustomBars(frame, styleCache)
	local absorb = ns.absorbCache[frame]
	if absorb then
		-- Delete from style cache
		if absorb and styleCache then
			styleCache[absorb] = nil
		end
		absorb:Hide()
	end

	local overlay = ns.overlayCache[frame]
	if overlay then
		-- Delete from style cache
		if overlay and styleCache then
			styleCache[overlay] = nil
		end
		overlay:Hide()
	end
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