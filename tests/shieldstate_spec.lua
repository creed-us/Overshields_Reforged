--- Characterization tests for ShieldState.lua — the shield/overshield state machine and
-- the anchor-mode resolution that depends on it.
--
-- ResolveShieldState deliberately reads Blizzard's native bar visibility instead of
-- UnitGetTotalAbsorbs (which can't be compared in a tainted call stack), so these tests
-- drive it through the mock frames' shown/visible flags.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

-- BarLifecycle.lua supplies ns.IsGlowVisible, which ResolveShieldState falls back to when
-- the caller doesn't pass a glow state.
local FILES = { "Constants.lua", "Utilities.lua", "BarLifecycle.lua", "ShieldState.lua" }

TestResolveShieldState = {}

function TestResolveShieldState:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestResolveShieldState:testExplicitGlowIsOvershielded()
	local frame = mock_frame.NewCompactFrame({ unit = "party1" })
	lu.assertEquals(self.ns.ResolveShieldState(frame, true), "overshielded")
end

function TestResolveShieldState:testGlowIsDerivedWhenNotPassed()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", glowVisible = true })
	lu.assertEquals(self.ns.ResolveShieldState(frame), "overshielded")
end

function TestResolveShieldState:testNativeAbsorbShownIsShielded()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", absorbShown = true })
	lu.assertEquals(self.ns.ResolveShieldState(frame, false), "shielded")
end

function TestResolveShieldState:testNativeOverlayAloneIsShielded()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", overlayShown = true })
	lu.assertEquals(self.ns.ResolveShieldState(frame, false), "shielded")
end

function TestResolveShieldState:testNoVisibleAbsorbIsUnshielded()
	local frame = mock_frame.NewCompactFrame({ unit = "party1" })
	lu.assertEquals(self.ns.ResolveShieldState(frame, false), "unshielded")
end

function TestResolveShieldState:testForbiddenAbsorbIsIgnored()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", absorbShown = true })
	frame.totalAbsorb.forbidden = true
	lu.assertEquals(self.ns.ResolveShieldState(frame, false), "unshielded")
end

function TestResolveShieldState:testNilFrameIsUnshielded()
	lu.assertEquals(self.ns.ResolveShieldState(nil), "unshielded")
end

TestResolveAnchorMode = {}

function TestResolveAnchorMode:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.profile = { anchorModeShielded = "health_right", anchorModeOvershielded = "frame_right" }
end

function TestResolveAnchorMode:testNilProfileIsDefault()
	lu.assertEquals(self.ns.ResolveAnchorMode(nil, "shielded"), "default")
end

function TestResolveAnchorMode:testShieldedUsesShieldedSetting()
	self.profile.anchorModeShielded = "health_left"
	lu.assertEquals(self.ns.ResolveAnchorMode(self.profile, "shielded"), "health_left")
end

function TestResolveAnchorMode:testOvershieldedUsesOvershieldedSetting()
	self.profile.anchorModeOvershielded = "frame_left"
	lu.assertEquals(self.ns.ResolveAnchorMode(self.profile, "overshielded"), "frame_left")
end

function TestResolveAnchorMode:testMissingSettingsFallBackToBuiltInDefaults()
	lu.assertEquals(self.ns.ResolveAnchorMode({}, "shielded"), "health_right")
	lu.assertEquals(self.ns.ResolveAnchorMode({}, "overshielded"), "frame_right")
end

function TestResolveAnchorMode:testUnshieldedIsDefault()
	lu.assertEquals(self.ns.ResolveAnchorMode(self.profile, "unshielded"), "default")
end

TestShouldUseNativeVisualOnly = {}

function TestShouldUseNativeVisualOnly:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestShouldUseNativeVisualOnly:testShieldedWithHealthRightUsesNative()
	local profile = { anchorModeShielded = "health_right" }
	lu.assertEquals(not not self.ns.ShouldUseNativeVisualOnly(profile, "shielded"), true)
end

function TestShouldUseNativeVisualOnly:testOtherAnchorModesDoNot()
	local profile = { anchorModeShielded = "frame_right" }
	lu.assertEquals(not not self.ns.ShouldUseNativeVisualOnly(profile, "shielded"), false)
end

function TestShouldUseNativeVisualOnly:testOvershieldedDoesNot()
	local profile = { anchorModeShielded = "health_right" }
	lu.assertEquals(not not self.ns.ShouldUseNativeVisualOnly(profile, "overshielded"), false)
end

function TestShouldUseNativeVisualOnly:testNilProfileDoesNot()
	lu.assertEquals(not not self.ns.ShouldUseNativeVisualOnly(nil, "shielded"), false)
end

TestNormalizeAnchorMode = {}

function TestNormalizeAnchorMode:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.healthTexture = mock_frame.NewTexture()
end

function TestNormalizeAnchorMode:testHealthModesPassThroughWithTexture()
	lu.assertEquals(self.ns.NormalizeAnchorMode("health_left", self.healthTexture), "health_left")
	lu.assertEquals(self.ns.NormalizeAnchorMode("health_right", self.healthTexture), "health_right")
end

function TestNormalizeAnchorMode:testHealthModesDegradeWithoutTexture()
	lu.assertEquals(self.ns.NormalizeAnchorMode("health_left", nil), "default")
	lu.assertEquals(self.ns.NormalizeAnchorMode("health_right", nil), "default")
end

function TestNormalizeAnchorMode:testFrameModesDoNotNeedTexture()
	lu.assertEquals(self.ns.NormalizeAnchorMode("frame_left", nil), "frame_left")
	lu.assertEquals(self.ns.NormalizeAnchorMode("frame_right", nil), "frame_right")
end

function TestNormalizeAnchorMode:testUnknownModeIsDefault()
	lu.assertEquals(self.ns.NormalizeAnchorMode("sideways", self.healthTexture), "default")
	lu.assertEquals(self.ns.NormalizeAnchorMode(nil, self.healthTexture), "default")
	lu.assertEquals(self.ns.NormalizeAnchorMode("default", self.healthTexture), "default")
end
