--- Characterization tests for the parts of Utilities.lua that stay put in Stage 1:
-- the forbidden-frame guard, the setting-enabled guard, and the atlas-detection cache.
--
-- The bar/frame restoration helpers and VanillaDefaults are covered by
-- barlifecycle_spec.lua, since Stage 1 moves them out to BarLifecycle.lua.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = { "Constants.lua", "Utilities.lua" }

TestFrameIsForbidden = {}

function TestFrameIsForbidden:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestFrameIsForbidden:testNilIsForbidden()
	lu.assertEquals(self.ns.FrameIsForbidden(nil), true)
end

function TestFrameIsForbidden:testNonWidgetValuesAreForbidden()
	lu.assertEquals(self.ns.FrameIsForbidden("CompactRaidFrame1"), true)
	lu.assertEquals(self.ns.FrameIsForbidden(42), true)
	lu.assertEquals(self.ns.FrameIsForbidden(true), true)
end

function TestFrameIsForbidden:testPlainTableIsAllowed()
	lu.assertEquals(self.ns.FrameIsForbidden({}), false)
end

function TestFrameIsForbidden:testWidgetReportingForbiddenIsForbidden()
	local frame = mock_frame.NewFrame({ forbidden = true })
	lu.assertEquals(self.ns.FrameIsForbidden(frame), true)
end

function TestFrameIsForbidden:testNormalWidgetIsAllowed()
	local frame = mock_frame.NewFrame()
	lu.assertEquals(self.ns.FrameIsForbidden(frame), false)
end

TestIsSettingEnabled = {}

function TestIsSettingEnabled:setUp()
	self.ns = load_addon.NewNamespace(FILES)
end

function TestIsSettingEnabled:testOnlyLiteralFalseIsDisabled()
	lu.assertEquals(self.ns.IsSettingEnabled(false), false)
	lu.assertEquals(self.ns.IsSettingEnabled(true), true)
	lu.assertEquals(self.ns.IsSettingEnabled(nil), true)
	lu.assertEquals(self.ns.IsSettingEnabled(0), true)
	lu.assertEquals(self.ns.IsSettingEnabled("off"), true)
end

TestAtlasCache = {}

function TestAtlasCache:setUp()
	self.ns, self.stub = load_addon.NewNamespace(FILES)
	self.stub.atlases["Warlock-Shard-Spark"] = true
end

function TestAtlasCache:testDetectsAtlasAssets()
	lu.assertEquals(self.ns.IsAtlasAsset("Warlock-Shard-Spark"), true)
end

function TestAtlasCache:testDetectsFilePathsAsNonAtlas()
	lu.assertEquals(self.ns.IsAtlasAsset("Interface\\RaidFrame\\Shield-Fill"), false)
end

function TestAtlasCache:testRepeatLookupsAreCached()
	self.ns.IsAtlasAsset("Warlock-Shard-Spark")
	lu.assertEquals(self.stub.atlasLookups, 1)

	self.ns.IsAtlasAsset("Warlock-Shard-Spark")
	lu.assertEquals(self.stub.atlasLookups, 1, "second lookup should come from the cache")
end

function TestAtlasCache:testNegativeResultsAreAlsoCached()
	self.ns.IsAtlasAsset("Interface\\RaidFrame\\Shield-Fill")
	self.ns.IsAtlasAsset("Interface\\RaidFrame\\Shield-Fill")
	lu.assertEquals(self.stub.atlasLookups, 1, "a false result must be cached, not re-queried")
end

function TestAtlasCache:testWipeForcesRelookup()
	self.ns.IsAtlasAsset("Warlock-Shard-Spark")
	lu.assertEquals(self.stub.atlasLookups, 1)

	self.ns.WipeAtlasCache()

	lu.assertEquals(self.ns.IsAtlasAsset("Warlock-Shard-Spark"), true)
	lu.assertEquals(self.stub.atlasLookups, 2)
end

