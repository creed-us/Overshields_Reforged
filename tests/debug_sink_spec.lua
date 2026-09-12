--- Tests the real instrumentation sink in Debug.lua, not the test harness's recorder.
--
-- This is the safety net for the specific way Stage 6 could go wrong: an event whose name
-- the sink doesn't know about. Debug.Inc does `counters[key] + amount`, so an unrecognised
-- name is a nil-arithmetic error in alpha builds — and one the other specs can't catch,
-- because they record events through the harness instead of through Debug.lua.
--
-- EMITTED_EVENTS below is the full set the pipeline emits. If a stage adds, removes, or
-- renames an event, update this list and Debug.lua's counters table together.

local lu = require("luaunit")
local load_addon = require("load_addon")

local FILES = { "Constants.lua", "Instrumentation.lua", "Debug.lua" }

--- Every event name the pipeline emits, with the semantics the sink must apply.
local EMITTED_EVENTS = {
	accumulating = {
		"anchorModeChanges", "barCreates", "barReuses", "batchCycles", "batchFramesTotal",
		"blendApplied", "blendSkipped", "colorApplied", "colorSkipped",
		"earlyExits", "frameUpdates", "framesHidden", "framesShown", "fullRefreshes",
		"hibernateEvals", "hibernateTransitions", "hookFires", "nativeBarsSuppressed",
		"queueAdds", "queueAttempts", "queueSkipsDisabled", "queueSkipsDuplicate",
		"retryAttempts", "retryDrops", "retrySuccesses", "textureApplied", "textureSkipped",
	},
	snapshot = { "lastRefreshTime", "poolFramesProcessed", "poolPath" },
	peak = { "peakBatchSize" },
}

TestDebugSink = {}

function TestDebugSink:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.counters = self.ns.Debug.counters
end

function TestDebugSink:testEveryEmittedEventIsKnownToTheSink()
	-- An event missing from Debug.lua's counters table would throw here rather than
	-- silently vanishing, which is the whole point of this test.
	for _, name in ipairs(EMITTED_EVENTS.accumulating) do
		local ok, err = pcall(self.ns.Emit, name)
		lu.assertEquals(ok, true, "emitting '" .. name .. "' errored: " .. tostring(err))
		lu.assertEquals(self.counters[name], 1, "'" .. name .. "' did not reach the sink")
	end

	for _, name in ipairs(EMITTED_EVENTS.snapshot) do
		local ok, err = pcall(self.ns.Emit, name, 5)
		lu.assertEquals(ok, true, "emitting '" .. name .. "' errored: " .. tostring(err))
		lu.assertEquals(self.counters[name], 5)
	end

	for _, name in ipairs(EMITTED_EVENTS.peak) do
		local ok, err = pcall(self.ns.Emit, name, 5)
		lu.assertEquals(ok, true, "emitting '" .. name .. "' errored: " .. tostring(err))
		lu.assertEquals(self.counters[name], 5)
	end
end

function TestDebugSink:testAccumulatingEventsAddUp()
	self.ns.Emit("barCreates")
	self.ns.Emit("barCreates")
	lu.assertEquals(self.counters.barCreates, 2)
end

function TestDebugSink:testAccumulatingEventsHonourAnExplicitAmount()
	self.ns.Emit("batchFramesTotal", 7)
	self.ns.Emit("batchFramesTotal", 3)
	lu.assertEquals(self.counters.batchFramesTotal, 10)
end

function TestDebugSink:testSnapshotEventsOverwriteRatherThanAccumulate()
	self.ns.Emit("poolFramesProcessed", 12)
	self.ns.Emit("poolFramesProcessed", 4)
	lu.assertEquals(self.counters.poolFramesProcessed, 4,
		"a snapshot must not accumulate — it reports the last pool walk, not a total")
end

function TestDebugSink:testPoolPathRecordsALabel()
	self.ns.Emit("poolPath", "flowFrames")
	lu.assertEquals(self.counters.poolPath, "flowFrames")

	self.ns.Emit("poolPath", "legacy")
	lu.assertEquals(self.counters.poolPath, "legacy")
end

function TestDebugSink:testPeakEventsKeepTheHighWaterMark()
	self.ns.Emit("peakBatchSize", 9)
	self.ns.Emit("peakBatchSize", 4)
	lu.assertEquals(self.counters.peakBatchSize, 9, "a peak must not be lowered by a later, smaller batch")

	self.ns.Emit("peakBatchSize", 20)
	lu.assertEquals(self.counters.peakBatchSize, 20)
end

function TestDebugSink:testWindowCountersTrackAlongsideSessionCounters()
	self.ns.Emit("barCreates")
	lu.assertEquals(self.ns.Debug.windowCounters.barCreates, 1)
end
