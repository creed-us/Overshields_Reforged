--- Tests for the painting layer: how a bar, overlay, or glow gets its colour, texture and
-- blend mode, and — just as importantly — when it *doesn't*.
--
-- The style cache is the reason this file exists. Every one of these setters is called on
-- a hot path, so the module skips redundant calls by remembering what it last applied.
-- That optimisation is invisible when it works and produces stale visuals when it breaks,
-- so most of these tests assert on how many times a setter was called, not just that it
-- was.

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
	"AppearanceManager.lua",
}

local PROFILE = {
	absorbColor = { r = 1, g = 0.5, b = 0.25, a = 0.75 },
	absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
	absorbBlendMode = "ADD",
	overAbsorbColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 },
	overAbsorbTexture = "Warlock-Shard-Spark",
	overAbsorbBlendMode = "MOD",
	overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
	overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
	overlayBlendMode = "BLEND",
	overAbsorbOverlayColor = { r = 0.9, g = 0.8, b = 0.7, a = 0.6 },
	overAbsorbOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
	overAbsorbOverlayBlendMode = "ALPHAKEY",
	overAbsorbGlowColor = { r = 0.2, g = 0.4, b = 0.6, a = 0.8 },
	overAbsorbGlowTexture = "Interface\\RaidFrame\\Shield-Overshield",
	overAbsorbGlowBlendMode = "ADD",
}

local function NewAppearance()
	local ns, stub = load_addon.NewNamespace(FILES)
	stub.InstallAddonStub({ profile = PROFILE })
	return ns, stub
end

local function CountCalls(widget, method)
	return #mock_frame.CallsTo(widget, method)
end

TestApplyAppearanceToBar = {}

function TestApplyAppearanceToBar:setUp()
	self.ns = NewAppearance()
	self.bar = mock_frame.NewStatusBar()
end

function TestApplyAppearanceToBar:testAppliesTheShieldColourWhenNotOvershielded()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)

	local call = mock_frame.LastCall(self.bar, "SetStatusBarColor")
	lu.assertNotNil(call)
	lu.assertEquals(call.args[1], PROFILE.absorbColor.r)
	lu.assertEquals(call.args[4], PROFILE.absorbColor.a)
end

function TestApplyAppearanceToBar:testSwitchesToOvershieldColourWhenGlowing()
	self.ns.ApplyAppearanceToBar(self.bar, true, PROFILE)

	local call = mock_frame.LastCall(self.bar, "SetStatusBarColor")
	lu.assertEquals(call.args[1], PROFILE.overAbsorbColor.r)
	lu.assertEquals(call.args[4], PROFILE.overAbsorbColor.a)
end

function TestApplyAppearanceToBar:testAppliesTextureAndBlendMode()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)

	lu.assertEquals(mock_frame.LastCall(self.bar, "SetStatusBarTexture").args[1], PROFILE.absorbTexture)
	lu.assertEquals(self.bar:GetStatusBarTexture().blendMode, PROFILE.absorbBlendMode)
end

function TestApplyAppearanceToBar:testRepeatedIdenticalCallsDoNotRepaint()
	-- The whole point of the style cache: this runs on every frame update.
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)

	lu.assertEquals(CountCalls(self.bar, "SetStatusBarColor"), 1)
	lu.assertEquals(CountCalls(self.bar, "SetStatusBarTexture"), 1)
end

function TestApplyAppearanceToBar:testAChangedColourIsRepainted()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)

	local changed = {}
	for key, value in pairs(PROFILE) do changed[key] = value end
	changed.absorbColor = { r = 0, g = 0, b = 1, a = 1 }

	self.ns.ApplyAppearanceToBar(self.bar, false, changed)

	lu.assertEquals(CountCalls(self.bar, "SetStatusBarColor"), 2)
	lu.assertEquals(mock_frame.LastCall(self.bar, "SetStatusBarColor").args[3], 1)
end

function TestApplyAppearanceToBar:testSwitchingShieldStateRepaints()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)
	self.ns.ApplyAppearanceToBar(self.bar, true, PROFILE)

	lu.assertEquals(CountCalls(self.bar, "SetStatusBarColor"), 2)
end

function TestApplyAppearanceToBar:testFallsBackWhenTheProfileOmitsTextureAndBlend()
	self.ns.ApplyAppearanceToBar(self.bar, false, { absorbColor = { r = 1, g = 1, b = 1, a = 1 } })

	lu.assertEquals(mock_frame.LastCall(self.bar, "SetStatusBarTexture").args[1],
		"Interface\\RaidFrame\\Shield-Fill")
	lu.assertEquals(self.bar:GetStatusBarTexture().blendMode, "ADD")
end

function TestApplyAppearanceToBar:testIgnoresNilAndNonStatusBars()
	self.ns.ApplyAppearanceToBar(nil, false, PROFILE)
	self.ns.ApplyAppearanceToBar(mock_frame.NewTexture(), false, PROFILE)
end

function TestApplyAppearanceToBar:testFallsBackToTheDatabaseProfileWhenNoneIsPassed()
	-- Callers on the hot path pass the profile explicitly to skip the global lookup, but
	-- the lookup still has to work for callers that don't.
	self.ns.ApplyAppearanceToBar(self.bar, false, nil)

	local call = mock_frame.LastCall(self.bar, "SetStatusBarColor")
	lu.assertNotNil(call, "should have fallen back to OvershieldsReforged.db.profile")
	lu.assertEquals(call.args[1], PROFILE.absorbColor.r)
end

function TestApplyAppearanceToBar:testDoesNothingWhenNoProfileExistsAtAll()
	_G.OvershieldsReforged.db.profile = nil

	self.ns.ApplyAppearanceToBar(self.bar, false, nil)

	lu.assertNil(mock_frame.LastCall(self.bar, "SetStatusBarColor"))
end

TestApplyAppearanceToOverlay = {}

function TestApplyAppearanceToOverlay:setUp()
	self.ns = NewAppearance()
	self.overlay = mock_frame.NewStatusBar()
end

function TestApplyAppearanceToOverlay:testUsesOverlayColoursAndTilesHorizontally()
	self.ns.ApplyAppearanceToOverlay(self.overlay, false, PROFILE)

	local colour = mock_frame.LastCall(self.overlay, "SetStatusBarColor")
	lu.assertEquals(colour.args[4], PROFILE.overlayColor.a)

	-- The overlay is the one element that tiles across the bar.
	local texture = self.overlay:GetStatusBarTexture()
	lu.assertEquals(texture.horizTile, true)
	lu.assertEquals(texture.vertTile, false)
end

function TestApplyAppearanceToOverlay:testSwitchesToOvershieldOverlayWhenGlowing()
	self.ns.ApplyAppearanceToOverlay(self.overlay, true, PROFILE)

	lu.assertEquals(mock_frame.LastCall(self.overlay, "SetStatusBarColor").args[1],
		PROFILE.overAbsorbOverlayColor.r)
	lu.assertEquals(self.overlay:GetStatusBarTexture().blendMode,
		PROFILE.overAbsorbOverlayBlendMode)
end

function TestApplyAppearanceToOverlay:testRepeatedIdenticalCallsDoNotRepaint()
	self.ns.ApplyAppearanceToOverlay(self.overlay, false, PROFILE)
	self.ns.ApplyAppearanceToOverlay(self.overlay, false, PROFILE)

	lu.assertEquals(CountCalls(self.overlay, "SetStatusBarColor"), 1)
end

TestApplyAppearanceToGlow = {}

function TestApplyAppearanceToGlow:setUp()
	self.ns, self.stub = NewAppearance()
	self.glow = mock_frame.NewTexture({ shown = true, visible = true })
end

function TestApplyAppearanceToGlow:testPaintsTheGlowTexture()
	self.ns.ApplyAppearanceToOverAbsorbGlow(self.glow, PROFILE)

	local colour = mock_frame.LastCall(self.glow, "SetVertexColor")
	lu.assertNotNil(colour)
	lu.assertEquals(colour.args[1], PROFILE.overAbsorbGlowColor.r)
	lu.assertEquals(self.glow.texture, PROFILE.overAbsorbGlowTexture)
	lu.assertEquals(self.glow.blendMode, PROFILE.overAbsorbGlowBlendMode)
end

function TestApplyAppearanceToGlow:testUsesSetAtlasForAtlasAssets()
	-- Atlas names and file paths take different setters; using the wrong one leaves the
	-- glow blank rather than erroring.
	self.stub.atlases["Warlock-Shard-Spark"] = true
	local profile = {}
	for key, value in pairs(PROFILE) do profile[key] = value end
	profile.overAbsorbGlowTexture = "Warlock-Shard-Spark"

	self.ns.ApplyAppearanceToOverAbsorbGlow(self.glow, profile)

	lu.assertEquals(self.glow.atlas, "Warlock-Shard-Spark")
	lu.assertNil(mock_frame.LastCall(self.glow, "SetTexture"))
end

function TestApplyAppearanceToGlow:testSkipsAnInvisibleGlow()
	local hidden = mock_frame.NewTexture({ shown = false, visible = false })

	self.ns.ApplyAppearanceToOverAbsorbGlow(hidden, PROFILE)

	lu.assertNil(mock_frame.LastCall(hidden, "SetVertexColor"))
end

function TestApplyAppearanceToGlow:testSkipsForbiddenAndNil()
	local forbidden = mock_frame.NewTexture({ shown = true, visible = true })
	forbidden.forbidden = true

	self.ns.ApplyAppearanceToOverAbsorbGlow(forbidden, PROFILE)
	self.ns.ApplyAppearanceToOverAbsorbGlow(nil, PROFILE)

	lu.assertNil(mock_frame.LastCall(forbidden, "SetVertexColor"))
end

function TestApplyAppearanceToGlow:testRepeatedIdenticalCallsDoNotRepaint()
	self.ns.ApplyAppearanceToOverAbsorbGlow(self.glow, PROFILE)
	self.ns.ApplyAppearanceToOverAbsorbGlow(self.glow, PROFILE)

	lu.assertEquals(CountCalls(self.glow, "SetVertexColor"), 1)
end

TestNativeBarPainting = {}

function TestNativeBarPainting:setUp()
	self.ns = NewAppearance()
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })
end

function TestNativeBarPainting:testAlwaysRepaintsNativeBars()
	-- Blizzard can reset its own bars at any time, so cached state must be discarded
	-- before painting a native one — otherwise our settings silently stop being applied.
	local native = self.frame.totalAbsorb

	self.ns.ApplyAppearanceToNativeBar(native, false, PROFILE)
	self.ns.ApplyAppearanceToNativeBar(native, false, PROFILE)

	lu.assertEquals(CountCalls(native, "SetStatusBarColor"), 2,
		"a native bar must be repainted every time, cache or not")
end

function TestNativeBarPainting:testPaintsTextureRegionsThatAreNotStatusBars()
	-- totalAbsorbOverlay is a Texture in the live client, so it takes the vertex-colour
	-- path rather than the status-bar one.
	local nativeOverlay = self.frame.totalAbsorbOverlay

	self.ns.ApplyAppearanceToNativeOverlay(nativeOverlay, false, PROFILE)

	lu.assertNotNil(mock_frame.LastCall(nativeOverlay, "SetVertexColor"))
	lu.assertEquals(nativeOverlay.texture, PROFILE.overlayTexture)
	lu.assertEquals(nativeOverlay.blendMode, PROFILE.overlayBlendMode)
	lu.assertEquals(nativeOverlay.horizTile, true)
end

function TestNativeBarPainting:testSkipsForbiddenRegions()
	local native = self.frame.totalAbsorb
	native.forbidden = true

	self.ns.ApplyAppearanceToNativeBar(native, false, PROFILE)
	lu.assertNil(mock_frame.LastCall(native, "SetStatusBarColor"))
end

TestStyleCacheLifecycle = {}

function TestStyleCacheLifecycle:setUp()
	self.ns = NewAppearance()
	self.bar = mock_frame.NewStatusBar()
end

function TestStyleCacheLifecycle:testWipingForcesEverythingToBeReapplied()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)
	lu.assertEquals(CountCalls(self.bar, "SetStatusBarColor"), 1)

	self.ns.wipeStyleCache()
	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)

	lu.assertEquals(CountCalls(self.bar, "SetStatusBarColor"), 2)
end

function TestStyleCacheLifecycle:testWipingAlsoClearsTheAtlasCache()
	-- Profile changes wipe both; an atlas result cached against an old profile's asset
	-- would otherwise outlive it.
	local ns, stub = NewAppearance()
	stub.atlases["Warlock-Shard-Spark"] = true
	ns.IsAtlasAsset("Warlock-Shard-Spark")
	lu.assertEquals(stub.atlasLookups, 1)

	ns.wipeStyleCache()
	ns.IsAtlasAsset("Warlock-Shard-Spark")

	lu.assertEquals(stub.atlasLookups, 2)
end

function TestStyleCacheLifecycle:testTracksEntriesPerTarget()
	local other = mock_frame.NewStatusBar()

	self.ns.ApplyAppearanceToBar(self.bar, false, PROFILE)
	self.ns.ApplyAppearanceToBar(other, false, PROFILE)

	-- Separate bars must not share cached state, or the second would skip its first paint.
	lu.assertEquals(CountCalls(other, "SetStatusBarColor"), 1)

	-- GetStyleCacheSize is alpha-only, so it's absent from a stripped release build. The
	-- assertion above is the one that matters; this is a corroborating detail when it's
	-- available.
	if self.ns.GetStyleCacheSize then
		lu.assertEquals(self.ns.GetStyleCacheSize(), 2)
	end
end
