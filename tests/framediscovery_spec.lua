--- Characterization tests for frame discovery: walking Blizzard's compact frame
-- containers, deciding which frames to process, and honouring the party/raid/pet scope
-- toggles on a full refresh.
--
-- Driven through the public entry point, ns.UpdateAllFrameAppearances, rather than the
-- file-local helpers it delegates to — that keeps the tests pointed at behaviour that
-- survives the Stage 5 move rather than at internals.
--
-- Written against this code in its original home (AppearanceManager.lua) and left
-- unchanged through Stage 5's move to FrameDiscovery.lua apart from the FILES list.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"BarLifecycle.lua",
	"FrameRegistry.lua",
	"UnitContext.lua",
	"ShieldState.lua",
	"AnchorStrategy.lua",
	"FrameUpdate.lua",
	"FrameDiscovery.lua",
	"AppearanceManager.lua",
}

local function NewDiscovery(profile)
	local ns, stub = load_addon.NewNamespace(FILES)
	ns.StyleCache = {}
	local addon = stub.InstallAddonStub({
		profile = profile or { enableParty = true, enableRaid = true, enablePets = true },
	})

	local queued = {}
	ns.QueueCompactUnitFrameUpdate = function(frame)
		queued[#queued + 1] = frame
	end

	return ns, stub, addon, queued
end

local function NewMemberFrame(index, opts)
	opts = opts or {}
	return mock_frame.NewCompactFrame({
		name = opts.name or ("CompactPartyFrameMember" .. index),
		unit = opts.unit or ("party" .. index),
		shown = opts.shown,
	})
end

TestModernPoolWalk = {}

function TestModernPoolWalk:setUp()
	self.ns, self.stub, self.addon, self.queued = NewDiscovery()
end

function TestModernPoolWalk:testProcessesEveryFrameInTheFlowLayout()
	_G.CompactPartyFrame.flowFrames = { NewMemberFrame(1), NewMemberFrame(2) }

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 2)
end

function TestModernPoolWalk:testRecordsTheModernPathItTook()
	_G.CompactPartyFrame.flowFrames = { NewMemberFrame(1) }

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(self.ns.Debug.values.poolPath, "flowFrames")
end

function TestModernPoolWalk:testReleasesHiddenFramesInsteadOfQueuingThem()
	local hidden = NewMemberFrame(1, { shown = false })
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, hidden, 0)
	bar:Show()
	_G.CompactPartyFrame.flowFrames = { hidden }

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 0)
	lu.assertEquals(bar.shown, false, "a hidden frame should have its bars released")
end

function TestModernPoolWalk:testSkipsFramesWithoutAUnit()
	local empty = NewMemberFrame(1)
	empty.displayedUnit = nil
	_G.CompactPartyFrame.flowFrames = { empty }

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 0)
end

function TestModernPoolWalk:testSkipsFramesThatArentOurs()
	local stranger = NewMemberFrame(1, { name = "SomeOtherAddonFrame1" })
	_G.CompactPartyFrame.flowFrames = { stranger }

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 0)
end

TestLegacyPoolWalk = {}

function TestLegacyPoolWalk:setUp()
	self.ns, self.stub, self.addon, self.queued = NewDiscovery()
end

function TestLegacyPoolWalk:testFallsBackToWalkingGlobalNames()
	-- No flowFrames on the container: the addon walks CompactPartyFrameMember1..5.
	_G.CompactPartyFrameMember1 = NewMemberFrame(1)
	_G.CompactPartyFrameMember3 = NewMemberFrame(3)

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 2)
end

function TestLegacyPoolWalk:testRecordsTheLegacyPathItTook()
	_G.CompactPartyFrameMember1 = NewMemberFrame(1)

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(self.ns.Debug.values.poolPath, "legacy")
end

function TestLegacyPoolWalk:testToleratesMissingGlobals()
	self.ns.UpdateAllFrameAppearances()
	lu.assertEquals(#self.queued, 0)
end

TestScopeToggles = {}

function TestScopeToggles:setUp()
	self.ns, self.stub, self.addon, self.queued = NewDiscovery()
end

function TestScopeToggles:testDisablingPartyReleasesCachedPartyBars()
	local frame = NewMemberFrame(1)
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, frame, 0)
	bar:Show()
	self.addon.db.profile.enableParty = false

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(#self.queued, 0, "party frames must not be processed while disabled")
	lu.assertEquals(bar.shown, false, "cached party bars must be released when disabled")
end

function TestScopeToggles:testRaidFramesAreOnlyWalkedInARaid()
	_G.CompactRaidFrameContainer.flowFrames = {
		NewMemberFrame(1, { name = "CompactRaidFrame1", unit = "raid1" }),
	}

	self.stub.inRaid = false
	self.ns.UpdateAllFrameAppearances()
	lu.assertEquals(#self.queued, 0, "raid frames shouldn't be walked outside a raid")

	self.stub.inRaid = true
	self.ns.UpdateAllFrameAppearances()
	lu.assertEquals(#self.queued, 1)
end

function TestScopeToggles:testDisablingRaidReleasesCachedRaidBarsInARaid()
	local frame = NewMemberFrame(1, { name = "CompactRaidFrame1", unit = "raid1" })
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, frame, 0)
	bar:Show()
	self.stub.inRaid = true
	self.addon.db.profile.enableRaid = false

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(bar.shown, false)
end

function TestScopeToggles:testPetFramesOnlyWalkedWhenTheContainerShowsPets()
	_G.CompactRaidFrameContainer.flowFrames = {
		NewMemberFrame(1, { name = "CompactPartyFramePet1", unit = "partypet1" }),
	}

	_G.CompactRaidFrameContainer.displayPets = nil
	self.ns.UpdateAllFrameAppearances()
	lu.assertEquals(#self.queued, 0)

	_G.CompactRaidFrameContainer.displayPets = true
	self.ns.UpdateAllFrameAppearances()
	lu.assertEquals(#self.queued, 1)
end

function TestScopeToggles:testDisablingPetsReleasesCachedPetBars()
	local frame = NewMemberFrame(1, { name = "CompactPartyFramePet1", unit = "partypet1" })
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, frame, 0)
	bar:Show()
	_G.CompactRaidFrameContainer.displayPets = true
	self.addon.db.profile.enablePets = false

	self.ns.UpdateAllFrameAppearances()

	lu.assertEquals(bar.shown, false)
end

TestRefreshGuards = {}

function TestRefreshGuards:testDoesNothingWhileHibernating()
	local ns, _, _, queued = NewDiscovery()
	_G.CompactPartyFrame.flowFrames = { NewMemberFrame(1) }
	ns.hibernating = true

	ns.UpdateAllFrameAppearances()

	lu.assertEquals(#queued, 0)
	lu.assertNil(ns.Debug.counts.fullRefreshes)
end

function TestRefreshGuards:testDoesNothingWithoutAProfile()
	local ns, _, addon, queued = NewDiscovery()
	_G.CompactPartyFrame.flowFrames = { NewMemberFrame(1) }
	addon.db.profile = nil

	ns.UpdateAllFrameAppearances()

	lu.assertEquals(#queued, 0)
end

function TestRefreshGuards:testCountsFullRefreshes()
	local ns = NewDiscovery()

	ns.UpdateAllFrameAppearances()

	lu.assertEquals(ns.Debug.counts.fullRefreshes, 1)
end
