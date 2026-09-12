--- Tests for the instrumentation seam.
--
-- Pipeline code announces that something happened; it doesn't know whether anything is
-- listening or how the listener records it. That's the whole point of the indirection —
-- so the interesting cases here are "no listener attached" (the shipping configuration)
-- and "listener gets exactly what was emitted".

local lu = require("luaunit")
local load_addon = require("load_addon")

local FILES = { "Constants.lua", "Instrumentation.lua" }

TestEmit = {}

function TestEmit:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	-- NewNamespace attaches a recording handler by default; these tests drive the seam
	-- directly, so start from the unlistened state the addon actually ships with.
	self.ns.SetInstrumentationHandler(nil)
end

function TestEmit:testIsHarmlessWithNoHandler()
	self.ns.Emit("barCreates")
	self.ns.Emit("poolPath", "flowFrames")
	self.ns.Emit("batchFramesTotal", 7)
end

function TestEmit:testDeliversNameAndAmountToTheHandler()
	local seen = {}
	self.ns.SetInstrumentationHandler(function(name, amount)
		seen[#seen + 1] = { name = name, amount = amount }
	end)

	self.ns.Emit("barCreates")
	self.ns.Emit("batchFramesTotal", 7)
	self.ns.Emit("poolPath", "legacy")

	lu.assertEquals(#seen, 3)
	lu.assertEquals(seen[1].name, "barCreates")
	lu.assertNil(seen[1].amount, "an event with no amount must not invent one")
	lu.assertEquals(seen[2].amount, 7)
	lu.assertEquals(seen[3].amount, "legacy")
end

function TestEmit:testCallsTheHandlerExactlyOncePerEvent()
	local calls = 0
	self.ns.SetInstrumentationHandler(function() calls = calls + 1 end)

	self.ns.Emit("barCreates")

	lu.assertEquals(calls, 1)
end

function TestEmit:testHandlerCanBeReplaced()
	local first, second = 0, 0
	self.ns.SetInstrumentationHandler(function() first = first + 1 end)
	self.ns.SetInstrumentationHandler(function() second = second + 1 end)

	self.ns.Emit("barCreates")

	lu.assertEquals(first, 0, "the replaced handler must stop receiving events")
	lu.assertEquals(second, 1)
end

function TestEmit:testHandlerCanBeDetached()
	local calls = 0
	self.ns.SetInstrumentationHandler(function() calls = calls + 1 end)
	self.ns.Emit("barCreates")

	self.ns.SetInstrumentationHandler(nil)
	self.ns.Emit("barCreates")

	lu.assertEquals(calls, 1, "detaching must return the seam to a no-op")
end
