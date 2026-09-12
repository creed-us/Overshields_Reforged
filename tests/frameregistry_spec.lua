--- Characterization tests for the frame/bar registry: which frames have custom bars,
-- how those bars get created and reused, and how tracking is torn down in bulk or
-- pruned when frames go stale.
--
-- Written against this code in its original home (CompactUnitFrame.lua) and left
-- unchanged through Stage 2's move to FrameRegistry.lua apart from the FILES list.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

-- UpdateQueue.lua owns ns.ResetUpdateQueue, which ReleaseAllBars delegates queue teardown
-- to; CompactUnitFrame.lua is not needed here any more.
local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"BarLifecycle.lua",
	"FrameRegistry.lua",
	"UpdateQueue.lua",
}

--- Builds a namespace plus a frame that is already tracked in both bar caches.
local function NewTrackedFrame(ns, unit)
	local frame = mock_frame.NewCompactFrame({ unit = unit or "party1" })
	local absorb = ns.GetOrCreateBar(ns.absorbCache, frame, 0)
	local overlay = ns.GetOrCreateBar(ns.overlayCache, frame, 1)
	return frame, absorb, overlay
end

TestGetOrCreateBar = {}

function TestGetOrCreateBar:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.ns.StyleCache = {}
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })
end

function TestGetOrCreateBar:testCreatesABarParentedToTheHealthBar()
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)

	lu.assertNotNil(bar)
	lu.assertIs(bar.parent, self.frame.healthBar)
	lu.assertEquals(bar.frameType, "StatusBar")
end

function TestGetOrCreateBar:testNewBarsStartHiddenAndReversed()
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)

	lu.assertEquals(bar.shown, false)
	lu.assertEquals(bar.reverseFill, true)
	lu.assertEquals(bar._anchorMode, "default")
end

function TestGetOrCreateBar:testLevelOffsetStacksOverlayAboveAbsorb()
	self.frame.healthBar.frameLevel = 5

	local absorb = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)
	local overlay = self.ns.GetOrCreateBar(self.ns.overlayCache, self.frame, 1)

	lu.assertEquals(absorb.frameLevel, 5)
	lu.assertEquals(overlay.frameLevel, 6)
end

function TestGetOrCreateBar:testReusesTheCachedBar()
	local first = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)
	local second = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)

	lu.assertIs(second, first, "a second call must reuse the cached bar, not build a new one")
	lu.assertEquals(self.ns.Debug.counts.barCreates, 1)
	lu.assertEquals(self.ns.Debug.counts.barReuses, 1)
end

function TestGetOrCreateBar:testRegistersTheBarInTheCache()
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)
	lu.assertIs(self.ns.absorbCache[self.frame], bar)
end

function TestGetOrCreateBar:testReturnsNilWhenHealthBarIsNotReadyYet()
	local pending = mock_frame.NewCompactFrame({ unit = "party2", healthBar = false })

	lu.assertNil(self.ns.GetOrCreateBar(self.ns.absorbCache, pending, 0))
	lu.assertNil(self.ns.absorbCache[pending], "an unready frame must not be cached")
end

TestReleaseAllBars = {}

function TestReleaseAllBars:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.ns.StyleCache = {}
	self.frame, self.absorb, self.overlay = NewTrackedFrame(self.ns)
end

function TestReleaseAllBars:testEmptiesBothCaches()
	self.ns.ReleaseAllBars()

	lu.assertNil(next(self.ns.absorbCache))
	lu.assertNil(next(self.ns.overlayCache))
end

function TestReleaseAllBars:testHidesTrackedBars()
	self.ns.ReleaseAllBars()

	lu.assertEquals(self.absorb.shown, false)
	lu.assertEquals(self.overlay.shown, false)
end

function TestReleaseAllBars:testRestoresFramesToVanilla()
	self.ns.ReleaseAllBars()

	lu.assertEquals(self.frame.overAbsorbGlow.texture, self.ns.VanillaDefaults.glowTexture)
	lu.assertEquals(self.frame.totalAbsorbOverlay.texture, self.ns.VanillaDefaults.overlayTexture)
end

function TestReleaseAllBars:testDelegatesQueueTeardownToTheQueue()
	-- Releasing every bar must not leave the batch queue holding frames that are no
	-- longer tracked. The registry doesn't own queue state, so it delegates — this pins
	-- that contract, which Stage 3 relies on when the queue moves to its own file.
	local resetCalls = 0
	self.ns.ResetUpdateQueue = function() resetCalls = resetCalls + 1 end

	self.ns.ReleaseAllBars()

	lu.assertEquals(resetCalls, 1)
end

function TestReleaseAllBars:testToleratesEmptyCaches()
	self.ns.ReleaseAllBars()
	self.ns.ReleaseAllBars()
end

TestCleanupStaleCacheEntries = {}

function TestCleanupStaleCacheEntries:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.ns.StyleCache = {}
end

function TestCleanupStaleCacheEntries:testDropsFramesThatNoLongerDisplayAUnit()
	local frame = NewTrackedFrame(self.ns)
	frame.displayedUnit = nil

	self.ns.CleanupStaleCacheEntries()

	lu.assertNil(self.ns.absorbCache[frame])
	lu.assertNil(self.ns.overlayCache[frame])
end

function TestCleanupStaleCacheEntries:testDropsHiddenFrames()
	local frame = NewTrackedFrame(self.ns)
	frame.shown = false

	self.ns.CleanupStaleCacheEntries()

	lu.assertNil(self.ns.absorbCache[frame])
end

function TestCleanupStaleCacheEntries:testDropsForbiddenFrames()
	local frame = NewTrackedFrame(self.ns)
	frame.forbidden = true

	self.ns.CleanupStaleCacheEntries()

	lu.assertNil(self.ns.absorbCache[frame])
end

function TestCleanupStaleCacheEntries:testKeepsLiveFrames()
	local frame, absorb = NewTrackedFrame(self.ns)

	self.ns.CleanupStaleCacheEntries()

	lu.assertIs(self.ns.absorbCache[frame], absorb, "a shown frame with a unit must stay tracked")
end

function TestCleanupStaleCacheEntries:testReleasesTheFramesItDrops()
	local frame, absorb = NewTrackedFrame(self.ns)
	frame.shown = false

	self.ns.CleanupStaleCacheEntries()

	lu.assertEquals(absorb.shown, false)
	lu.assertEquals(frame.overAbsorbGlow.texture, self.ns.VanillaDefaults.glowTexture)
end

function TestCleanupStaleCacheEntries:testKeepsLiveFramesWhileDroppingStaleOnes()
	local stale = NewTrackedFrame(self.ns, "party1")
	local live, liveAbsorb = NewTrackedFrame(self.ns, "party2")
	stale.shown = false

	self.ns.CleanupStaleCacheEntries()

	lu.assertNil(self.ns.absorbCache[stale])
	lu.assertIs(self.ns.absorbCache[live], liveAbsorb)
end
