--- Characterization tests for the bar/frame lifecycle helpers: hiding the addon's own
-- bars, restoring Blizzard's native absorb visuals to vanilla, and releasing a frame
-- entirely.
--
-- Written against these functions in their original home (Utilities.lua) and left
-- unchanged through Stage 1's move to BarLifecycle.lua apart from the FILES list below —
-- that they still pass is what shows the move preserved behaviour.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = { "Constants.lua", "Utilities.lua", "BarLifecycle.lua" }

TestIsGlowVisible = {}

function TestIsGlowVisible:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestIsGlowVisible:testVisibleGlow()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", glowVisible = true })
	lu.assertEquals(self.ns.IsGlowVisible(frame), true)
end

function TestIsGlowVisible:testHiddenGlow()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", glowVisible = false })
	lu.assertEquals(self.ns.IsGlowVisible(frame), false)
end

function TestIsGlowVisible:testForbiddenFrame()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", glowVisible = true })
	frame.forbidden = true
	lu.assertEquals(self.ns.IsGlowVisible(frame), false)
end

function TestIsGlowVisible:testForbiddenGlow()
	local frame = mock_frame.NewCompactFrame({ unit = "party1", glowVisible = true })
	frame.overAbsorbGlow.forbidden = true
	lu.assertEquals(self.ns.IsGlowVisible(frame), false)
end

function TestIsGlowVisible:testNilFrame()
	lu.assertEquals(self.ns.IsGlowVisible(nil), false)
end

TestHideCustomBars = {}

function TestHideCustomBars:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })

	-- The caches normally live in CompactUnitFrame.lua; the lifecycle helpers only ever
	-- read them off the namespace, so plain tables stand in fine here.
	self.absorb = mock_frame.NewStatusBar()
	self.overlay = mock_frame.NewStatusBar()
	self.absorb._anchorMode = "frame_right"
	self.overlay._anchorMode = "frame_right"
	self.ns.absorbCache = { [self.frame] = self.absorb }
	self.ns.overlayCache = { [self.frame] = self.overlay }

	self.styleCache = {}
end

function TestHideCustomBars:testHidesBothBars()
	self.ns.HideCustomBars(self.frame, self.styleCache)

	lu.assertEquals(self.absorb.shown, false)
	lu.assertEquals(self.overlay.shown, false)
end

function TestHideCustomBars:testResetsAnchorModeSoNextUpdateRepositions()
	self.ns.HideCustomBars(self.frame, self.styleCache)

	lu.assertNil(self.absorb._anchorMode)
	lu.assertNil(self.overlay._anchorMode)
end

function TestHideCustomBars:testClearsAnchorsAndValue()
	self.ns.HideCustomBars(self.frame, self.styleCache)

	lu.assertNotNil(mock_frame.LastCall(self.absorb, "ClearAllPoints"))
	lu.assertEquals(self.absorb.minValue, 0)
	lu.assertEquals(self.absorb.maxValue, 1)
	lu.assertEquals(self.absorb.value, 0)
end

function TestHideCustomBars:testDropsStyleCacheEntries()
	self.styleCache[self.absorb] = { colorR = 1 }
	self.styleCache[self.overlay] = { colorR = 1 }

	self.ns.HideCustomBars(self.frame, self.styleCache)

	lu.assertNil(self.styleCache[self.absorb])
	lu.assertNil(self.styleCache[self.overlay])
end

function TestHideCustomBars:testToleratesMissingStyleCache()
	self.ns.HideCustomBars(self.frame, nil)
	lu.assertEquals(self.absorb.shown, false)
end

function TestHideCustomBars:testToleratesUncachedFrame()
	local stranger = mock_frame.NewCompactFrame({ unit = "party2" })
	self.ns.HideCustomBars(stranger, self.styleCache)
	lu.assertEquals(self.absorb.shown, true, "an unrelated frame must not touch cached bars")
end

TestRestoreNativeAbsorbVisuals = {}

function TestRestoreNativeAbsorbVisuals:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })
	self.styleCache = {}
	self.defaults = self.ns.VanillaDefaults
end

function TestRestoreNativeAbsorbVisuals:testRestoresAbsorbBarAppearance()
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	local absorb = self.frame.totalAbsorb
	local color = mock_frame.LastCall(absorb, "SetStatusBarColor")
	lu.assertNotNil(color)
	lu.assertEquals(color.args[1], self.defaults.absorbColor.r)
	lu.assertEquals(color.args[4], self.defaults.absorbColor.a)

	local texture = mock_frame.LastCall(absorb, "SetStatusBarTexture")
	lu.assertEquals(texture.args[1], self.defaults.absorbTexture)
	lu.assertEquals(absorb:GetStatusBarTexture().blendMode, self.defaults.absorbBlendMode)
end

function TestRestoreNativeAbsorbVisuals:testRestoresNestedFillAndOverlayRegions()
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	local fill = self.frame.totalAbsorb.fill
	lu.assertEquals(fill.texture, self.defaults.absorbTexture)
	lu.assertEquals(fill.blendMode, self.defaults.absorbBlendMode)

	local nested = self.frame.totalAbsorb.overlay
	lu.assertEquals(nested.texture, self.defaults.overlayTexture)
	lu.assertEquals(nested.blendMode, self.defaults.overlayBlendMode)
end

function TestRestoreNativeAbsorbVisuals:testRestoresOverlayAndGlow()
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	lu.assertEquals(self.frame.totalAbsorbOverlay.texture, self.defaults.overlayTexture)
	lu.assertEquals(self.frame.totalAbsorbOverlay.blendMode, self.defaults.overlayBlendMode)
	lu.assertEquals(self.frame.overAbsorbGlow.texture, self.defaults.glowTexture)
	lu.assertEquals(self.frame.overAbsorbGlow.blendMode, self.defaults.glowBlendMode)
end

function TestRestoreNativeAbsorbVisuals:testOnlyOverlayRegionsTileHorizontally()
	-- Blizzard tiles the overlay horizontally but not the fill or the glow; getting this
	-- backwards is a visible artifact, so it's pinned explicitly.
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	lu.assertEquals(self.frame.totalAbsorbOverlay.horizTile, true)
	lu.assertEquals(self.frame.totalAbsorb.overlay.horizTile, true)
	lu.assertEquals(self.frame.totalAbsorb.fill.horizTile, false)
	lu.assertEquals(self.frame.overAbsorbGlow.horizTile, false)
	lu.assertEquals(self.frame.totalAbsorbOverlay.vertTile, false)
end

function TestRestoreNativeAbsorbVisuals:testDropsStyleCacheEntriesForEveryRestoredRegion()
	local absorb = self.frame.totalAbsorb
	self.styleCache[absorb] = { colorR = 0.5 }
	self.styleCache[absorb.fill] = { colorR = 0.5 }
	self.styleCache[absorb.overlay] = { colorR = 0.5 }
	self.styleCache[self.frame.totalAbsorbOverlay] = { colorR = 0.5 }
	self.styleCache[self.frame.overAbsorbGlow] = { colorR = 0.5 }

	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	lu.assertNil(self.styleCache[absorb])
	lu.assertNil(self.styleCache[absorb.fill])
	lu.assertNil(self.styleCache[absorb.overlay])
	lu.assertNil(self.styleCache[self.frame.totalAbsorbOverlay])
	lu.assertNil(self.styleCache[self.frame.overAbsorbGlow])
end

function TestRestoreNativeAbsorbVisuals:testSkipsForbiddenFrame()
	self.frame.forbidden = true
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	lu.assertNil(mock_frame.LastCall(self.frame.totalAbsorb, "SetStatusBarColor"))
end

function TestRestoreNativeAbsorbVisuals:testSkipsForbiddenRegions()
	self.frame.totalAbsorb.forbidden = true
	self.ns.RestoreNativeAbsorbVisuals(self.frame, self.styleCache)

	lu.assertNil(mock_frame.LastCall(self.frame.totalAbsorb, "SetStatusBarColor"))
	lu.assertEquals(self.frame.overAbsorbGlow.texture, self.defaults.glowTexture,
		"a forbidden absorb bar must not stop the glow from being restored")
end

function TestRestoreNativeAbsorbVisuals:testToleratesNilFrame()
	self.ns.RestoreNativeAbsorbVisuals(nil, self.styleCache)
end

TestReleaseFrame = {}

function TestReleaseFrame:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })
	self.absorb = mock_frame.NewStatusBar()
	self.ns.absorbCache = { [self.frame] = self.absorb }
	self.ns.overlayCache = {}
	self.styleCache = {}
end

function TestReleaseFrame:testHidesCustomBarsAndRestoresNativeVisuals()
	self.ns.ReleaseFrame(self.frame, self.styleCache)

	lu.assertEquals(self.absorb.shown, false, "custom bar should be hidden")
	lu.assertEquals(self.frame.overAbsorbGlow.texture, self.ns.VanillaDefaults.glowTexture,
		"native visuals should be restored to vanilla")
end

function TestReleaseFrame:testSkipsForbiddenFrame()
	self.frame.forbidden = true
	self.ns.ReleaseFrame(self.frame, self.styleCache)

	lu.assertEquals(self.absorb.shown, true)
end

function TestReleaseFrame:testToleratesNilFrame()
	self.ns.ReleaseFrame(nil, self.styleCache)
end

TestVanillaDefaults = {}

function TestVanillaDefaults:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestVanillaDefaults:testMatchesBlizzardsOwnAbsorbVisuals()
	local defaults = self.ns.VanillaDefaults
	lu.assertEquals(defaults.absorbTexture, "Interface\\RaidFrame\\Shield-Fill")
	lu.assertEquals(defaults.absorbBlendMode, "ADD")
	lu.assertEquals(defaults.overlayTexture, "Interface\\RaidFrame\\Shield-Overlay")
	lu.assertEquals(defaults.overlayBlendMode, "BLEND")
	lu.assertEquals(defaults.glowTexture, "Interface\\RaidFrame\\Shield-Overshield")
	lu.assertEquals(defaults.glowBlendMode, "ADD")
end

function TestVanillaDefaults:testOnlyTheOverlayTilesHorizontally()
	local defaults = self.ns.VanillaDefaults
	lu.assertEquals(defaults.overlayHorizTile, true)
	lu.assertEquals(defaults.absorbHorizTile, false)
	lu.assertEquals(defaults.glowHorizTile, false)
	lu.assertEquals(defaults.overlayVertTile, false)
end
