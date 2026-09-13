--- Guards the built-in glow texture catalog.
--
-- This is pure data, so these tests aren't checking logic — they're a tripwire for
-- accidental edits: a dropped row, a swapped pair, a duplicate asset. The catalog is the
-- list users pick from, and a silent loss here is invisible until someone notices their
-- texture is gone from the dropdown.

local lu = require("luaunit")
local load_addon = require("load_addon")

local FILES = { "Constants.lua", "GlowTextureCatalog.lua" }

TestGlowTextureCatalog = {}

function TestGlowTextureCatalog:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.catalog = self.ns.GlowTextureCatalog
end

function TestGlowTextureCatalog:testHasTheExpectedNumberOfEntries()
	-- Deliberately exact. Adding a texture should be a conscious change to this number.
	lu.assertEquals(#self.catalog, 50)
end

function TestGlowTextureCatalog:testStartsWithTheBlizzardDefaultGlow()
	lu.assertEquals(self.catalog[1][1], "Interface\\RaidFrame\\Shield-Overshield")
	lu.assertEquals(self.catalog[1][2], "Default Glow")
end

function TestGlowTextureCatalog:testEndsWithTheLastKnownEntry()
	local last = self.catalog[#self.catalog]
	lu.assertEquals(last[1], "XPBarAnim-OrangeSpark")
	lu.assertEquals(last[2], "Orange XP Spark")
end

function TestGlowTextureCatalog:testEveryEntryIsAnAssetLabelPair()
	for index, entry in ipairs(self.catalog) do
		lu.assertEquals(type(entry[1]), "string", "entry " .. index .. " has no asset")
		lu.assertEquals(type(entry[2]), "string", "entry " .. index .. " has no display name")
		lu.assertNotEquals(entry[1], "", "entry " .. index .. " has an empty asset")
		lu.assertNotEquals(entry[2], "", "entry " .. index .. " has an empty display name")
	end
end

function TestGlowTextureCatalog:testAssetsAreUnique()
	-- Duplicates would silently collapse: the dropdown is keyed by asset, so a repeated
	-- asset means one of the two display names simply never appears.
	local seen = {}
	for index, entry in ipairs(self.catalog) do
		lu.assertNil(seen[entry[1]],
			"duplicate asset at entry " .. index .. ": " .. entry[1])
		seen[entry[1]] = index
	end
end

function TestGlowTextureCatalog:testDisplayNamesAreUnique()
	local seen = {}
	for index, entry in ipairs(self.catalog) do
		lu.assertNil(seen[entry[2]],
			"duplicate display name at entry " .. index .. ": " .. entry[2])
		seen[entry[2]] = index
	end
end
