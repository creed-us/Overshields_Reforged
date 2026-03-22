local _, ns = ...

function ns.ResolveShieldState(frame, glowVisible)
	if glowVisible == nil then
		glowVisible = ns.IsGlowVisible(frame)
	end

	if glowVisible then
		return "overshielded"
	end

	local nativeAbsorb = frame and frame.totalAbsorb
	if not ns.FrameIsForbidden(nativeAbsorb) and nativeAbsorb:IsShown() then
		return "shielded"
	end

	local nativeOverlay = frame and frame.totalAbsorbOverlay
	if not ns.FrameIsForbidden(nativeOverlay) and nativeOverlay:IsShown() then
		return "shielded"
	end

	return "unshielded"
end

function ns.ResolveAnchorMode(profile, shieldState)
	if not profile then
		return "default"
	end

	if shieldState == "overshielded" then
		return profile.anchorModeOvershielded or "frame_right"
	end

	if shieldState == "shielded" then
		return profile.anchorModeShielded or "health_right"
	end

	return "default"
end

function ns.ShouldUseNativeVisualOnly(profile, shieldState)
	return profile
		and shieldState == "shielded"
		and profile.anchorModeShielded == "health_right"
end

function ns.NormalizeAnchorMode(targetMode, healthTexture)
	if targetMode ~= "health_left"
		and targetMode ~= "health_right"
		and targetMode ~= "frame_left"
		and targetMode ~= "frame_right" then
		return "default"
	end

	if (targetMode == "health_left" or targetMode == "health_right") and not healthTexture then
		return "default"
	end

	return targetMode
end
