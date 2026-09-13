--- Characterization tests for the texture dropdown builders: what the options panel
-- offers, how LibSharedMedia entries get merged in, and how the memoised tables are
-- invalidated when LSM registers new media after login.
--
-- Both LSM states matter here and both are covered. LSM is an optional dependency, so
-- "absent" is the common case; "present" is the branch that had never been exercised by
-- anything until the harness learned to inject a fake.
--
-- Written against this code in its original home (Options.lua) and left unchanged through
-- Stage 9's move to OptionsDropdowns.lua apart from the FILES list.

local lu = require("luaunit")
local load_addon = require("load_addon")

-- Only what the dropdown builders actually need: the catalog they read, the atlas check
-- they call, and the module itself. Options.lua is no longer involved.
local FILES = {
	"Constants.lua",
	"Utilities.lua",
	"GlowTextureCatalog.lua",
	"OptionsDropdowns.lua",
}

--- A stand-in for LibSharedMedia. `media` maps media type -> { name = path }.
local function NewFakeLSM(media)
	local lsm = { media = media or {}, callbacks = {}, hashCalls = 0 }

	function lsm.RegisterCallback(owner, event, handler)
		lsm.callbacks[#lsm.callbacks + 1] = { owner = owner, event = event, handler = handler }
	end

	function lsm:HashTable(mediaType)
		self.hashCalls = self.hashCalls + 1
		return self.media[mediaType] or {}
	end

	--- Simulates another addon registering media after login, then firing LSM's callback.
	function lsm:Register(mediaType, name, path)
		self.media[mediaType] = self.media[mediaType] or {}
		self.media[mediaType][name] = path
		for _, entry in ipairs(self.callbacks) do
			entry.handler()
		end
	end

	return lsm
end

local function NewDropdowns(lsm)
	local libs = lsm and { ["LibSharedMedia-3.0"] = lsm } or nil
	return load_addon.NewNamespace(FILES, { libs = libs })
end

local function CountKeys(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

TestTextureDropdownWithoutLSM = {}

function TestTextureDropdownWithoutLSM:setUp()
	self.ns = NewDropdowns()
end

function TestTextureDropdownWithoutLSM:testOffersTheTwoBuiltInTextures()
	local values = self.ns.TextureDropdownValues()

	lu.assertEquals(CountKeys(values), 2)
	lu.assertNotNil(values["Interface\\RaidFrame\\Shield-Overlay"])
	lu.assertNotNil(values["Interface\\RaidFrame\\Shield-Fill"])
end

function TestTextureDropdownWithoutLSM:testLabelsCarryAnInlineTexturePreview()
	local values = self.ns.TextureDropdownValues()
	lu.assertStrContains(values["Interface\\RaidFrame\\Shield-Fill"], "|T")
	lu.assertStrContains(values["Interface\\RaidFrame\\Shield-Fill"], "Default Fill")
end

function TestTextureDropdownWithoutLSM:testResultIsMemoised()
	local first = self.ns.TextureDropdownValues()
	local second = self.ns.TextureDropdownValues()
	lu.assertIs(second, first, "the dropdown table should be built once and reused")
end

TestTextureDropdownWithLSM = {}

function TestTextureDropdownWithLSM:setUp()
	self.lsm = NewFakeLSM({ statusbar = { ["Smooth"] = "Interface\\Addons\\Media\\Smooth" } })
	self.ns = NewDropdowns(self.lsm)
end

function TestTextureDropdownWithLSM:testMergesRegisteredStatusbarTextures()
	local values = self.ns.TextureDropdownValues()

	lu.assertEquals(CountKeys(values), 3)
	lu.assertStrContains(values["Interface\\Addons\\Media\\Smooth"], "Smooth")
end

function TestTextureDropdownWithLSM:testRegistersForLateMediaNotifications()
	lu.assertEquals(#self.lsm.callbacks, 1)
	lu.assertEquals(self.lsm.callbacks[1].event, "LibSharedMedia_Registered")
end

function TestTextureDropdownWithLSM:testLateRegisteredMediaAppearsAfterInvalidation()
	lu.assertEquals(CountKeys(self.ns.TextureDropdownValues()), 3)

	-- Registering fires LSM's callback, which is what clears the memoised table.
	self.lsm:Register("statusbar", "Latecomer", "Interface\\Addons\\Media\\Latecomer")

	local refreshed = self.ns.TextureDropdownValues()
	lu.assertEquals(CountKeys(refreshed), 4)
	lu.assertNotNil(refreshed["Interface\\Addons\\Media\\Latecomer"])
end

function TestTextureDropdownWithLSM:testInvalidationIsWhatForcesTheRebuild()
	local before = self.ns.TextureDropdownValues()
	self.ns.InvalidateDropdownCaches()
	local after = self.ns.TextureDropdownValues()

	lu.assertNotIs(after, before, "invalidating should discard the memoised table")
end

TestGlowDropdown = {}

function TestGlowDropdown:setUp()
	self.ns, self.stub = NewDropdowns()
end

function TestGlowDropdown:testOffersEveryCatalogEntry()
	local values = self.ns.OverAbsorbGlowTextureDropdownValues()

	lu.assertEquals(CountKeys(values), #self.ns.GlowTextureCatalog)
	for _, entry in ipairs(self.ns.GlowTextureCatalog) do
		lu.assertNotNil(values[entry[1]], "catalog entry missing from dropdown: " .. entry[1])
	end
end

function TestGlowDropdown:testUsesTheTexturePrefixForFilePaths()
	local values = self.ns.OverAbsorbGlowTextureDropdownValues()
	lu.assertStrContains(values["Interface\\RaidFrame\\Shield-Overshield"], "|T")
end

function TestGlowDropdown:testUsesTheAtlasPrefixForAtlasAssets()
	-- Atlases need |A, file paths need |T; getting it wrong renders a broken icon.
	self.stub.atlases["Warlock-Shard-Spark"] = true

	local values = self.ns.OverAbsorbGlowTextureDropdownValues()

	lu.assertStrContains(values["Warlock-Shard-Spark"], "|A:")
	lu.assertStrContains(values["Interface\\RaidFrame\\Shield-Overshield"], "|T")
end

function TestGlowDropdown:testResultIsMemoised()
	local first = self.ns.OverAbsorbGlowTextureDropdownValues()
	lu.assertIs(self.ns.OverAbsorbGlowTextureDropdownValues(), first)
end

TestGlowDropdownWithLSM = {}

function TestGlowDropdownWithLSM:testMergesOnlySparkAndPipMedia()
	-- The glow selector deliberately filters LSM media by name: a plain statusbar texture
	-- is not a useful glow, but anything named like a spark or pip is.
	local lsm = NewFakeLSM({
		statusbar = {
			["Fancy Spark"] = "Interface\\Addons\\Media\\FancySpark",
			["Plain Bar"] = "Interface\\Addons\\Media\\PlainBar",
		},
		pip = { ["Round Pip"] = "Interface\\Addons\\Media\\RoundPip" },
	})
	local ns = NewDropdowns(lsm)

	local values = ns.OverAbsorbGlowTextureDropdownValues()

	lu.assertNotNil(values["Interface\\Addons\\Media\\FancySpark"], "spark media should be offered")
	lu.assertNotNil(values["Interface\\Addons\\Media\\RoundPip"], "pip media should be offered")
	lu.assertNil(values["Interface\\Addons\\Media\\PlainBar"],
		"a plain statusbar texture is not a glow and must not be offered here")
end

function TestGlowDropdownWithLSM:testMatchesNamesCaseInsensitively()
	local lsm = NewFakeLSM({ spark = { ["LOUD SPARK"] = "Interface\\Addons\\Media\\Loud" } })
	local ns = NewDropdowns(lsm)

	lu.assertNotNil(ns.OverAbsorbGlowTextureDropdownValues()["Interface\\Addons\\Media\\Loud"])
end
