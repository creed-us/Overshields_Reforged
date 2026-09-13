--- Characterization tests for the update queue: which frames get queued, how duplicate
-- and disabled frames are handled, and how the batch cycle retries or drops frames whose
-- health bar isn't ready yet.
--
-- These deliberately inject a fake ns.ProcessQueuedFrame. The queue's job is scheduling,
-- not knowing what processing means, so the tests stay independent of the frame-update
-- logic that Stage 4 moves into FrameUpdate.lua.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

-- FrameUpdate.lua supplies ns.IsKnownCompactUnitFrame and the real ns.ProcessQueuedFrame
-- that these tests deliberately replace with a controllable stub.
local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"BarLifecycle.lua",
	"FrameRegistry.lua",
	"UpdateQueue.lua",
	"FrameUpdate.lua",
}

--- A frame the pipeline will recognise — IsKnownCompactUnitFrame matches on name prefix.
local function NewKnownFrame(name)
	return mock_frame.NewCompactFrame({ unit = "party1", name = name or "CompactPartyFrameMember1" })
end

--- Builds the namespace with a controllable stand-in for frame processing.
-- `results` is a list of booleans returned in order; anything past the end returns true.
local function NewQueue(results)
	local ns, stub = load_addon.NewNamespace(FILES)
	ns.StyleCache = {}
	local addon = stub.InstallAddonStub({ profile = { enableParty = true } })

	local processed = {}
	local callIndex = 0
	ns.ProcessQueuedFrame = function(frame)
		callIndex = callIndex + 1
		processed[#processed + 1] = frame
		local result = results and results[callIndex]
		if result == nil then
			return true
		end
		return result
	end

	return ns, stub, addon, processed
end

local function RunBatchCycle(stub)
	local driver = stub.FindOnUpdateDriver()
	lu.assertNotNil(driver, "expected a frame with an OnUpdate script to drive batches")
	driver.scripts.OnUpdate()
	return driver
end

TestQueueCompactUnitFrameUpdate = {}

function TestQueueCompactUnitFrameUpdate:setUp()
	self.ns, self.stub, self.addon, self.processed = NewQueue()
	self.frame = NewKnownFrame()
end

function TestQueueCompactUnitFrameUpdate:testQueuesAKnownFrame()
	self.ns.QueueCompactUnitFrameUpdate(self.frame)

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 1)
	lu.assertIs(self.processed[1], self.frame)
end

function TestQueueCompactUnitFrameUpdate:testQueuingTwiceProcessesOnce()
	self.ns.QueueCompactUnitFrameUpdate(self.frame)
	self.ns.QueueCompactUnitFrameUpdate(self.frame)

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 1)

	lu.assertEquals(self.ns.Debug.counts.queueSkipsDuplicate, 1)
end

function TestQueueCompactUnitFrameUpdate:testSkipsWhileHibernating()
	self.ns.hibernating = true
	self.ns.QueueCompactUnitFrameUpdate(self.frame)

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 0)
end

function TestQueueCompactUnitFrameUpdate:testSkipsUnknownFrames()
	local stranger = mock_frame.NewCompactFrame({ unit = "party1", name = "SomeOtherAddonFrame1" })
	self.ns.QueueCompactUnitFrameUpdate(stranger)

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 0)
end

function TestQueueCompactUnitFrameUpdate:testSkipsForbiddenFrames()
	self.frame.forbidden = true
	self.ns.QueueCompactUnitFrameUpdate(self.frame)

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 0)
end

function TestQueueCompactUnitFrameUpdate:testDisabledContextReleasesInsteadOfQueuing()
	self.addon.contextEnabled = false
	local bar = self.ns.GetOrCreateBar(self.ns.absorbCache, self.frame, 0)
	bar:Show()

	self.ns.QueueCompactUnitFrameUpdate(self.frame)

	lu.assertEquals(bar.shown, false, "a disabled frame should be released, not queued")

	RunBatchCycle(self.stub)
	lu.assertEquals(#self.processed, 0)

	lu.assertEquals(self.ns.Debug.counts.queueSkipsDisabled, 1)
end

TestBatchCycle = {}

function TestBatchCycle:testProcessesEveryQueuedFrame()
	local ns, stub, _, processed = NewQueue()
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame("CompactPartyFrameMember1"))
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame("CompactPartyFrameMember2"))

	RunBatchCycle(stub)

	lu.assertEquals(#processed, 2)
end

function TestBatchCycle:testClearsTheQueueAfterASuccessfulPass()
	local ns, stub, _, processed = NewQueue()
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	RunBatchCycle(stub)
	RunBatchCycle(stub)

	lu.assertEquals(#processed, 1, "a processed frame must not be processed again next cycle")
end

function TestBatchCycle:testStopsTheDriverWhenNothingIsPending()
	local ns, stub = NewQueue()
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	local driver = RunBatchCycle(stub)

	lu.assertEquals(driver.shown, false, "the OnUpdate driver should hide itself when idle")
end

function TestBatchCycle:testRetriesAFrameThatIsNotReady()
	-- false = "health bar wasn't available"; the frame should come back next cycle.
	local ns, stub, _, processed = NewQueue({ false })
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	RunBatchCycle(stub)
	lu.assertEquals(#processed, 1)

	RunBatchCycle(stub)
	lu.assertEquals(#processed, 2, "an unready frame must be retried on the next cycle")

	lu.assertEquals(ns.Debug.counts.retryAttempts, 1)
end

function TestBatchCycle:testDropsAFrameAfterMaxRetries()
	local alwaysFails = {}
	for i = 1, 20 do
		alwaysFails[i] = false
	end
	local ns, stub, _, processed = NewQueue(alwaysFails)
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	for _ = 1, 10 do
		RunBatchCycle(stub)
	end
	local attemptsBeforeGivingUp = #processed

	RunBatchCycle(stub)

	lu.assertEquals(#processed, attemptsBeforeGivingUp,
		"once dropped, the frame must stop being retried")
	lu.assertEquals(ns.Debug.counts.retryDrops, 1)
end

function TestBatchCycle:testSchedulesARecoveryRefreshWhenItDropsAFrame()
	local alwaysFails = {}
	for i = 1, 20 do
		alwaysFails[i] = false
	end
	local ns, stub = NewQueue(alwaysFails)
	ns.UpdateAllFrameAppearances = function() end
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	for _ = 1, 10 do
		RunBatchCycle(stub)
	end

	lu.assertEquals(#stub.scheduledTimers, 1,
		"dropping a frame should schedule a full refresh to recover")
end

function TestBatchCycle:testCountsARetrySuccessWhenALaterPassWorks()
	local ns, stub = NewQueue({ false, true })
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	RunBatchCycle(stub)
	RunBatchCycle(stub)

	lu.assertEquals(ns.Debug.counts.retrySuccesses, 1)
end

function TestBatchCycle:testDoesNothingWithoutAProfile()
	local ns, stub, addon, processed = NewQueue()
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())
	addon.db.profile = nil

	RunBatchCycle(stub)

	lu.assertEquals(#processed, 0)
end

function TestBatchCycle:testPrunesStaleCacheEntriesOnAnInterval()
	local ns, stub = NewQueue()
	local cleanups = 0
	ns.CleanupStaleCacheEntries = function() cleanups = cleanups + 1 end
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	stub.now = 0
	RunBatchCycle(stub)
	local afterFirst = cleanups

	stub.now = 100
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame("CompactPartyFrameMember2"))
	RunBatchCycle(stub)

	lu.assertEquals(cleanups, afterFirst + 1, "cleanup should run again once the interval elapses")
end

TestResetUpdateQueue = {}

function TestResetUpdateQueue:testDropsPendingWorkAndStopsTheDriver()
	local ns, stub, _, processed = NewQueue()
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())

	ns.ResetUpdateQueue()
	RunBatchCycle(stub)

	lu.assertEquals(#processed, 0, "reset must discard queued frames")
	lu.assertEquals(stub.FindOnUpdateDriver().shown, false)
end

function TestResetUpdateQueue:testCancelsAnInFlightRecoveryRefresh()
	local ns, stub = NewQueue()
	local refreshes = 0
	ns.UpdateAllFrameAppearances = function() refreshes = refreshes + 1 end

	ns.ProcessQueuedFrame = function() return false end
	ns.QueueCompactUnitFrameUpdate(NewKnownFrame())
	for _ = 1, 10 do
		RunBatchCycle(stub)
	end
	lu.assertEquals(#stub.scheduledTimers, 1)

	-- Bumping the recovery token invalidates the pending callback.
	ns.ResetUpdateQueue()
	stub.FlushTimers()

	lu.assertEquals(refreshes, 0, "a refresh scheduled before the reset must not fire after it")
end
