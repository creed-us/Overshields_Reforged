--- Characterization tests for UnitContext.lua — unit token classification and the
-- per-context enable check that gates whether the addon touches a frame at all.

local lu = require("luaunit")
local load_addon = require("load_addon")

local FILES = { "Constants.lua", "Utilities.lua", "UnitContext.lua" }

local function NewNs()
	return load_addon.NewNamespace(FILES)
end

TestGetUnitContext = {}

function TestGetUnitContext:setUp()
	self.ns = NewNs()
end

function TestGetUnitContext:testRaidPetIsPet()
	lu.assertEquals(self.ns.GetUnitContext("raidpet3"), "pet")
end

function TestGetUnitContext:testPartyPetIsPet()
	lu.assertEquals(self.ns.GetUnitContext("partypet1"), "pet")
end

function TestGetUnitContext:testRaidIsRaid()
	lu.assertEquals(self.ns.GetUnitContext("raid17"), "raid")
end

function TestGetUnitContext:testPartyIsParty()
	lu.assertEquals(self.ns.GetUnitContext("party2"), "party")
end

function TestGetUnitContext:testPlayerIsOther()
	lu.assertEquals(self.ns.GetUnitContext("player"), "other")
end

function TestGetUnitContext:testTargetIsOther()
	lu.assertEquals(self.ns.GetUnitContext("target"), "other")
end

function TestGetUnitContext:testNilIsOther()
	lu.assertEquals(self.ns.GetUnitContext(nil), "other")
end

function TestGetUnitContext:testPrefixMustMatchAtStart()
	-- "partyraid" style tokens don't exist, but the check is anchored at position 1 and
	-- this pins that: a token merely *containing* "raid" is not a raid unit.
	lu.assertEquals(self.ns.GetUnitContext("nameplate-raid"), "other")
end

TestIsUnitContextEnabledFromProfile = {}

function TestIsUnitContextEnabledFromProfile:setUp()
	self.ns = NewNs()
	self.profile = { enableParty = true, enableRaid = true, enablePets = false }
end

function TestIsUnitContextEnabledFromProfile:testNilProfileIsDisabled()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(nil, "party1"), false)
end

function TestIsUnitContextEnabledFromProfile:testNilUnitIsDisabled()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, nil), false)
end

function TestIsUnitContextEnabledFromProfile:testPartyFollowsEnableParty()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "party1"), true)
	self.profile.enableParty = false
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "party1"), false)
end

function TestIsUnitContextEnabledFromProfile:testRaidFollowsEnableRaid()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "raid5"), true)
	self.profile.enableRaid = false
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "raid5"), false)
end

function TestIsUnitContextEnabledFromProfile:testPetFollowsEnablePets()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "raidpet2"), false)
	self.profile.enablePets = true
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "raidpet2"), true)
end

function TestIsUnitContextEnabledFromProfile:testMissingSettingCountsAsEnabled()
	-- IsSettingEnabled treats anything that isn't literally false as on, so a profile
	-- predating a toggle behaves as if that toggle were enabled.
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile({}, "party1"), true)
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile({}, "raid1"), true)
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile({}, "raidpet1"), true)
end

function TestIsUnitContextEnabledFromProfile:testOtherContextNeedsEitherPartyOrRaid()
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "player"), true)

	self.profile.enableParty = false
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "player"), true)

	self.profile.enableRaid = false
	lu.assertEquals(self.ns.IsUnitContextEnabledFromProfile(self.profile, "player"), false)
end
