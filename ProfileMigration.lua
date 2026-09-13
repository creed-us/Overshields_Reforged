local _, ns = ...

--- Anchor modes offered in the options dropdowns, mapped to their display labels.
-- The key set must stay in step with the handlers in AnchorStrategy.lua; a label with
-- no handler silently falls back to default positioning. profilemigration_spec has a
-- test that fails if the two drift apart.
ns.AnchorModeLabels = {
	["health_left"] = "Health Bar Left",
	["health_right"] = "Health Bar Right (Vanilla Default)",
	["frame_left"] = "Unit Frame Left",
	["frame_right"] = "Unit Frame Right (Overshield Default)",
}

function ns.IsValidAnchorMode(value)
	return ns.AnchorModeLabels[value] ~= nil
end

--- Repairs anchor settings on a loaded profile: fills in anything missing and replaces
-- anything the current build no longer recognises.
function ns.NormalizeAnchorModeSettings(profile)
	if not profile then
		return
	end

	if profile.anchorModeShielded == nil then
		profile.anchorModeShielded = ns.ProfileDefaults.profile.anchorModeShielded
	end

	if profile.anchorModeOvershielded == nil then
		profile.anchorModeOvershielded = ns.ProfileDefaults.profile.anchorModeOvershielded
	end

	if not ns.IsValidAnchorMode(profile.anchorModeShielded) then
		profile.anchorModeShielded = ns.ProfileDefaults.profile.anchorModeShielded
	end

	if not ns.IsValidAnchorMode(profile.anchorModeOvershielded) then
		profile.anchorModeOvershielded = ns.ProfileDefaults.profile.anchorModeOvershielded
	end
end

local CURRENT_DB_VERSION = 1

--- Brings a saved profile up to the current schema version.
-- The pre-v1 block still matters: SavedVariables persist indefinitely, so a profile
-- last written before the anchoring refactor can still carry those legacy keys.
function ns.MigrateProfile(profile)
	-- Get current or update to 0 if nil/NaNs
	local currentProfileVersion = profile.profileVersion or 0

	if currentProfileVersion < 1 then
		profile.anchorShieldToHealth = nil
		profile.anchorToHealthTexture = nil
		profile.showAbsorbText = nil
		profile.shieldedHealthAnchorOverlap = nil
		profile.absorbTextFormat = nil
	end

	-- Version of the current profile
	profile.profileVersion = CURRENT_DB_VERSION
end
