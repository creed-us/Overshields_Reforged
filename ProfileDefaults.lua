local _, ns = ...

--- The shape of a fresh profile.
-- Consumed by AceDB when creating the database, by the options UI for its per-group
-- reset buttons and fallback values, and by ProfileMigration when repairing a saved
-- profile. It lives on its own because all three are equal consumers -- none of them
-- owns it.
ns.ProfileDefaults = {
	profile = {
		-- Frames for modification
		enableParty = true,
		enableRaid = true,
		enablePets = false,
		-- Normal shield appearance (overAbsorbGlow not visible)
		absorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
		absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
		absorbBlendMode = "ADD",
		overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
		overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
		overlayBlendMode = "BLEND",
		-- OverAbsorb shield appearance (overAbsorbGlow visible)
		overAbsorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
		overAbsorbTexture = "Interface\\RaidFrame\\Shield-Fill",
		overAbsorbBlendMode = "ADD",
		overAbsorbOverlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
		overAbsorbOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
		overAbsorbOverlayBlendMode = "BLEND",
		-- OverAbsorb glow appearance
		overAbsorbGlowColor = { r = 1, g = 1, b = 1, a = 1 },
		overAbsorbGlowTexture = "Interface\\RaidFrame\\Shield-Overshield",
		overAbsorbGlowBlendMode = "ADD",
		-- Conditional anchor behavior
		anchorModeShielded = "health_right",
		anchorModeOvershielded = "frame_right",
	},
}
