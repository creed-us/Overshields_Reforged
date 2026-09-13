--- Characterization tests for profile versioning and anchor-mode normalisation — the
-- logic that decides what a saved profile looks like before the options UI reads it.
--
-- Written against this code in its original home (Options.lua) and left unchanged through
-- Stage 8's move to ProfileMigration.lua / ProfileDefaults.lua apart from the FILES list.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"AnchorStrategy.lua",
	"ProfileDefaults.lua",
	"ProfileMigration.lua",
	"GlowTextureCatalog.lua",
	"Options.lua",
}

local function NewProfileNs()
	return load_addon.NewNamespace(FILES, { addon = true })
end

TestMigrateProfile = {}

function TestMigrateProfile:setUp()
	self.ns = NewProfileNs()
end

function TestMigrateProfile:testStampsTheCurrentVersionOnAFreshProfile()
	local profile = {}

	self.ns.MigrateProfile(profile)

	lu.assertEquals(profile.profileVersion, 1)
end

function TestMigrateProfile:testClearsLegacyKeysFromAPreVersionProfile()
	-- A profile last written before the anchoring refactor still carries these. They are
	-- unused now, and leaving them would resurrect stale state on an old SavedVariables
	-- file — which is why this block must not be deleted as "dead".
	local profile = {
		anchorShieldToHealth = true,
		anchorToHealthTexture = true,
		showAbsorbText = true,
		shieldedHealthAnchorOverlap = 4,
		absorbTextFormat = "%d",
	}

	self.ns.MigrateProfile(profile)

	lu.assertNil(profile.anchorShieldToHealth)
	lu.assertNil(profile.anchorToHealthTexture)
	lu.assertNil(profile.showAbsorbText)
	lu.assertNil(profile.shieldedHealthAnchorOverlap)
	lu.assertNil(profile.absorbTextFormat)
	lu.assertEquals(profile.profileVersion, 1)
end

function TestMigrateProfile:testLeavesAnAlreadyMigratedProfileAlone()
	local profile = { profileVersion = 1, anchorModeShielded = "frame_left" }

	self.ns.MigrateProfile(profile)

	lu.assertEquals(profile.anchorModeShielded, "frame_left")
	lu.assertEquals(profile.profileVersion, 1)
end

function TestMigrateProfile:testDoesNotDisturbLiveSettings()
	local profile = { enableParty = false, absorbBlendMode = "MOD" }

	self.ns.MigrateProfile(profile)

	lu.assertEquals(profile.enableParty, false)
	lu.assertEquals(profile.absorbBlendMode, "MOD")
end

TestIsValidAnchorMode = {}

function TestIsValidAnchorMode:setUp()
	self.ns = NewProfileNs()
end

function TestIsValidAnchorMode:testAcceptsEveryOfferedMode()
	for mode in pairs(self.ns.AnchorModeLabels) do
		lu.assertEquals(self.ns.IsValidAnchorMode(mode), true, mode .. " should be valid")
	end
end

function TestIsValidAnchorMode:testRejectsUnknownValues()
	lu.assertEquals(self.ns.IsValidAnchorMode("sideways"), false)
	lu.assertEquals(self.ns.IsValidAnchorMode(nil), false)
	lu.assertEquals(self.ns.IsValidAnchorMode(""), false)
end

function TestIsValidAnchorMode:testRejectsTheInternalDefaultMode()
	-- "default" is a positioning fallback, not something a user can pick.
	lu.assertEquals(self.ns.IsValidAnchorMode("default"), false)
end

TestNormalizeAnchorModeSettings = {}

function TestNormalizeAnchorModeSettings:setUp()
	self.ns = NewProfileNs()
	self.defaults = self.ns.ProfileDefaults.profile
end

function TestNormalizeAnchorModeSettings:testFillsInMissingModes()
	local profile = {}

	self.ns.NormalizeAnchorModeSettings(profile)

	lu.assertEquals(profile.anchorModeShielded, self.defaults.anchorModeShielded)
	lu.assertEquals(profile.anchorModeOvershielded, self.defaults.anchorModeOvershielded)
end

function TestNormalizeAnchorModeSettings:testKeepsValidModes()
	local profile = { anchorModeShielded = "health_left", anchorModeOvershielded = "frame_left" }

	self.ns.NormalizeAnchorModeSettings(profile)

	lu.assertEquals(profile.anchorModeShielded, "health_left")
	lu.assertEquals(profile.anchorModeOvershielded, "frame_left")
end

function TestNormalizeAnchorModeSettings:testRepairsInvalidModes()
	local profile = { anchorModeShielded = "sideways", anchorModeOvershielded = 42 }

	self.ns.NormalizeAnchorModeSettings(profile)

	lu.assertEquals(profile.anchorModeShielded, self.defaults.anchorModeShielded)
	lu.assertEquals(profile.anchorModeOvershielded, self.defaults.anchorModeOvershielded)
end

function TestNormalizeAnchorModeSettings:testToleratesNoProfile()
	self.ns.NormalizeAnchorModeSettings(nil)
end

TestProfileDefaults = {}

function TestProfileDefaults:setUp()
	self.ns = NewProfileNs()
	self.profile = self.ns.ProfileDefaults.profile
end

function TestProfileDefaults:testShipsTheDocumentedFrameScopes()
	lu.assertEquals(self.profile.enableParty, true)
	lu.assertEquals(self.profile.enableRaid, true)
	lu.assertEquals(self.profile.enablePets, false)
end

function TestProfileDefaults:testAnchorDefaultsAreThemselvesValid()
	-- A default that fails validation would be repaired to itself forever, or worse,
	-- silently replaced — so the defaults must satisfy the same rule user input does.
	lu.assertEquals(self.ns.IsValidAnchorMode(self.profile.anchorModeShielded), true)
	lu.assertEquals(self.ns.IsValidAnchorMode(self.profile.anchorModeOvershielded), true)
end

function TestProfileDefaults:testEveryColourIsFullySpecified()
	for _, key in ipairs({
		"absorbColor", "overlayColor", "overAbsorbColor",
		"overAbsorbOverlayColor", "overAbsorbGlowColor",
	}) do
		local colour = self.profile[key]
		lu.assertNotNil(colour, key .. " missing")
		for _, channel in ipairs({ "r", "g", "b", "a" }) do
			lu.assertEquals(type(colour[channel]), "number", key .. "." .. channel .. " must be a number")
		end
	end
end

TestAnchorModeCoverage = {}

--- Every mode offered in the dropdown must have a real positioning handler behind it.
-- The two lists live in different files by design — labels are presentation, handlers are
-- behaviour — but their key sets must not drift. A label without a handler silently falls
-- back to "default" positioning, which looks like a bug in the anchor rather than a
-- missing case. Checked behaviourally so neither file has to export its internals: only
-- the default handler calls SetAllPoints.
function TestAnchorModeCoverage:testEveryOfferedModeHasItsOwnHandler()
	local ns = NewProfileNs()

	for mode in pairs(ns.AnchorModeLabels) do
		local bar = mock_frame.NewStatusBar()
		local frame = mock_frame.NewCompactFrame({ unit = "party1" })
		local healthTexture = frame.healthBar:GetStatusBarTexture()

		ns.ApplyAnchorStrategy(bar, frame, frame.healthBar, mode, healthTexture)

		lu.assertNil(mock_frame.LastCall(bar, "SetAllPoints"),
			"anchor mode '" .. mode .. "' is offered in the options dropdown but has no "
				.. "handler in AnchorStrategy.lua — it silently falls back to default positioning")
	end
end
