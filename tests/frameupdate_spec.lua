--- Characterization tests for per-frame update decisions: whether a frame is one of ours,
-- and which of the three outcomes a queued frame gets (early exit, native-visual-only, or
-- addon-drawn custom bars).
--
-- The appearance functions are replaced with recorders. This file's job is deciding which
-- path to take; what the painting actually does belongs to AppearanceManager's own tests.
--
-- Written against this code in its original home (CompactUnitFrame.lua) and left
-- unchanged through Stage 4's move to FrameUpdate.lua apart from the FILES list.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"BarLifecycle.lua",
	"FrameRegistry.lua",
	"ShieldState.lua",
	"AnchorStrategy.lua",
	"FrameUpdate.lua",
}

--- Namespace with the appearance layer stubbed out as call recorders.
local function NewPipeline(profile)
	local ns, stub = load_addon.NewNamespace(FILES)
	ns.StyleCache = {}
	local addon = stub.InstallAddonStub({ profile = profile or {} })

	local painted = {}
	local function recorder(name)
		return function(target)
			painted[name] = (painted[name] or 0) + 1
			painted[name .. "Target"] = target
		end
	end

	ns.ApplyAppearanceToBar = recorder("bar")
	ns.ApplyAppearanceToOverlay = recorder("overlay")
	ns.ApplyAppearanceToNativeBar = recorder("nativeBar")
	ns.ApplyAppearanceToNativeOverlay = recorder("nativeOverlay")
	ns.ApplyAppearanceToOverAbsorbGlow = recorder("glow")

	return ns, stub, addon, painted
end

TestIsKnownCompactUnitFrame = {}

function TestIsKnownCompactUnitFrame:setUp()
	self.ns = NewPipeline()
end

function TestIsKnownCompactUnitFrame:testMatchesRaidFrameName()
	local frame = mock_frame.NewCompactFrame({ name = "CompactRaidFrame3" })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), true)
end

function TestIsKnownCompactUnitFrame:testMatchesPartyMemberName()
	local frame = mock_frame.NewCompactFrame({ name = "CompactPartyFrameMember2" })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), true)
end

function TestIsKnownCompactUnitFrame:testMatchesPetNames()
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(
		mock_frame.NewCompactFrame({ name = "CompactRaidFramePet1" })), true)
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(
		mock_frame.NewCompactFrame({ name = "CompactPartyFramePet1" })), true)
end

function TestIsKnownCompactUnitFrame:testMatchesByParentContainer()
	local frame = mock_frame.NewCompactFrame({ parent = _G.CompactRaidFrameContainer })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), true)

	local partyChild = mock_frame.NewCompactFrame({ parent = _G.CompactPartyFrame })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(partyChild), true)
end

function TestIsKnownCompactUnitFrame:testMatchesSeparateGroupsNesting()
	-- Under the "Separate Groups" raid display modes frames sit one level deeper.
	local group = mock_frame.NewFrame({ parent = _G.CompactRaidFrameContainer })
	local frame = mock_frame.NewCompactFrame({ parent = group })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), true)
end

function TestIsKnownCompactUnitFrame:testRejectsUnrelatedFrames()
	local frame = mock_frame.NewCompactFrame({ name = "SomeOtherAddonFrame1" })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), false)
end

function TestIsKnownCompactUnitFrame:testRejectsForbiddenAndNil()
	local frame = mock_frame.NewCompactFrame({ name = "CompactRaidFrame1", forbidden = true })
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(frame), false)
	lu.assertEquals(self.ns.IsKnownCompactUnitFrame(nil), false)
end

TestProcessQueuedFrameEarlyExits = {}

function TestProcessQueuedFrameEarlyExits:setUp()
	self.ns, self.stub, self.addon, self.painted = NewPipeline({ anchorModeShielded = "frame_right" })
	self.frame = mock_frame.NewCompactFrame({ unit = "party1", name = "CompactPartyFrameMember1" })
end

function TestProcessQueuedFrameEarlyExits:testForbiddenFrameIsConsideredHandled()
	self.frame.forbidden = true
	lu.assertEquals(self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile), true)
	lu.assertNil(self.painted.bar)
end

function TestProcessQueuedFrameEarlyExits:testDisabledContextReleasesTheFrame()
	self.addon.contextEnabled = false
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)
	bar:Show()

	lu.assertEquals(self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile), true)

	lu.assertEquals(bar.shown, false, "a frame whose context was disabled must be released")
end

function TestProcessQueuedFrameEarlyExits:testMissingUnitExitsEarly()
	self.frame.displayedUnit = nil

	lu.assertEquals(self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile), true)

	lu.assertEquals(self.ns.Debug.counts.earlyExits, 1)
	lu.assertNil(self.painted.bar)
end

function TestProcessQueuedFrameEarlyExits:testNonExistentUnitExitsEarly()
	self.ns.UnitExists = function() return false end

	lu.assertEquals(self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile), true)

	lu.assertEquals(self.ns.Debug.counts.earlyExits, 1)
end

function TestProcessQueuedFrameEarlyExits:testForbiddenGlowExitsEarly()
	self.frame.overAbsorbGlow.forbidden = true

	lu.assertEquals(self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile), true)

	lu.assertEquals(self.ns.Debug.counts.earlyExits, 1)
end

function TestProcessQueuedFrameEarlyExits:testMissingHealthBarAsksForARetry()
	-- This is the one path that returns false: the queue reads that as "not ready yet".
	local pending = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		healthBar = false,
	})

	lu.assertEquals(self.ns.ProcessQueuedFrame(pending, self.addon.db.profile), false)
end

TestProcessQueuedFrameNativeOnly = {}

function TestProcessQueuedFrameNativeOnly:setUp()
	-- Shielded + "health_right" is the one combination that defers to Blizzard's own bars.
	self.ns, self.stub, self.addon, self.painted = NewPipeline({ anchorModeShielded = "health_right" })
	self.frame = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		absorbShown = true,
	})
end

function TestProcessQueuedFrameNativeOnly:testPaintsNativeBarsInsteadOfCustomOnes()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertEquals(self.painted.nativeBar, 1)
	lu.assertEquals(self.painted.nativeOverlay, 1)
	lu.assertNil(self.painted.bar, "custom bars must not be painted on the native-only path")
end

function TestProcessQueuedFrameNativeOnly:testDoesNotBuildCustomBars()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertNil(self.ns.absorbCache[self.frame])
	lu.assertNil(self.ns.overlayCache[self.frame])
end

function TestProcessQueuedFrameNativeOnly:testLeavesNativeAbsorbVisible()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertEquals(self.frame.totalAbsorb.shown, true,
		"the native bar is the visual on this path, so it must not be suppressed")
end

TestProcessQueuedFrameCustomBars = {}

function TestProcessQueuedFrameCustomBars:setUp()
	self.ns, self.stub, self.addon, self.painted = NewPipeline({
		anchorModeShielded = "frame_right",
		anchorModeOvershielded = "frame_right",
	})
	self.ns.UnitGetTotalAbsorbs = function() return 1234 end
	self.frame = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		absorbShown = true,
	})
	self.frame.healthBar:SetMinMaxValues(0, 5000)
end

function TestProcessQueuedFrameCustomBars:testSuppressesNativeVisuals()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertEquals(self.frame.totalAbsorb.shown, false)
	lu.assertEquals(self.frame.totalAbsorbOverlay.shown, false)
end

function TestProcessQueuedFrameCustomBars:testBuildsAndPaintsBothCustomBars()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertNotNil(self.ns.absorbCache[self.frame])
	lu.assertNotNil(self.ns.overlayCache[self.frame])
	lu.assertEquals(self.painted.bar, 1)
	lu.assertEquals(self.painted.overlay, 1)
end

function TestProcessQueuedFrameCustomBars:testScalesBarsToHealthAndAbsorbValue()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	local absorb = self.ns.absorbCache[self.frame]
	lu.assertEquals(absorb.minValue, 0)
	lu.assertEquals(absorb.maxValue, 5000, "bar range must track the health bar's maximum")
	lu.assertEquals(absorb.value, 1234, "bar value must track the unit's absorb amount")
end

function TestProcessQueuedFrameCustomBars:testAppliesTheConfiguredAnchorMode()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertEquals(self.ns.absorbCache[self.frame]._anchorMode, "frame_right")
	lu.assertEquals(self.ns.overlayCache[self.frame]._anchorMode, "frame_right")
end

function TestProcessQueuedFrameCustomBars:testMirrorsFrameVisibilityOntoBars()
	self.frame.visible = false
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)

	lu.assertEquals(self.ns.absorbCache[self.frame].shown, false)
end

function TestProcessQueuedFrameCustomBars:testPaintsGlowWhenOvershielded()
	local overshielded = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		glowVisible = true,
	})

	self.ns.ProcessQueuedFrame(overshielded, self.addon.db.profile)

	lu.assertEquals(self.painted.glow, 1)
	lu.assertIs(self.painted.glowTarget, overshielded.overAbsorbGlow)
end

function TestProcessQueuedFrameCustomBars:testSkipsGlowPaintWhenNotOvershielded()
	self.ns.ProcessQueuedFrame(self.frame, self.addon.db.profile)
	lu.assertNil(self.painted.glow)
end

TestEnforceNativeAbsorbVisibility = {}

function TestEnforceNativeAbsorbVisibility:setUp()
	self.ns, self.stub, self.addon = NewPipeline({ anchorModeShielded = "health_right" })
end

function TestEnforceNativeAbsorbVisibility:testSuppressesNativeWhenOvershielded()
	local frame = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		absorbShown = true,
		glowVisible = true,
	})

	self.ns.EnforceNativeAbsorbVisibility(frame, self.addon.db.profile)

	lu.assertEquals(frame.totalAbsorb.shown, false)
end

function TestEnforceNativeAbsorbVisibility:testLeavesNativeAloneOnTheNativeOnlyPath()
	local frame = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		absorbShown = true,
	})

	self.ns.EnforceNativeAbsorbVisibility(frame, self.addon.db.profile)

	lu.assertEquals(frame.totalAbsorb.shown, true)
end

function TestEnforceNativeAbsorbVisibility:testIgnoresFramesThatArentOurs()
	local stranger = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "SomeOtherAddonFrame1",
		absorbShown = true,
	})

	self.ns.EnforceNativeAbsorbVisibility(stranger, self.addon.db.profile)

	lu.assertEquals(stranger.totalAbsorb.shown, true)
end
