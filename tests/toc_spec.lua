--- Guards the load-order rules that the addon's structure quietly depends on.
--
-- Most of the codebase is order-independent: files hang functions off a shared `ns` table
-- and those resolve at call time. The exceptions are statements that run *during* load,
-- and they fail in ways that are hard to trace back to a TOC edit — so they're asserted
-- here instead, where a reorder shows up as a failed test rather than a runtime error.

local lu = require("luaunit")
local load_addon = require("load_addon")

local TOC = "Overshields_Reforged.toc"

--- Returns the .lua entries of the TOC in load order, ignoring metadata and directives.
local function LoadOrder()
	local path = load_addon.root .. "/" .. TOC
	local file = assert(io.open(path), "could not open " .. path)

	local order = {}
	for line in file:lines() do
		local entry = line:match("^%s*([%w_]+%.lua)%s*$")
		if entry then
			order[#order + 1] = entry
		end
	end
	file:close()

	return order
end

local function IndexOf(order, name)
	for index, entry in ipairs(order) do
		if entry == name then
			return index
		end
	end
	return nil
end

TestTocLoadOrder = {}

function TestTocLoadOrder:setUp()
	self.order = LoadOrder()
	lu.assertTrue(#self.order > 5, "TOC parse produced suspiciously few files")
end

function TestTocLoadOrder:assertBefore(earlier, later, why)
	local a, b = IndexOf(self.order, earlier), IndexOf(self.order, later)
	lu.assertNotNil(a, earlier .. " is missing from the TOC")
	lu.assertNotNil(b, later .. " is missing from the TOC")
	lu.assertTrue(a < b, earlier .. " must load before " .. later .. ": " .. why)
end

function TestTocLoadOrder:testConstantsLoadsFirst()
	lu.assertEquals(self.order[1], "Constants.lua",
		"other files call ns.CreateFrame at load time to build their frames")
end

function TestTocLoadOrder:testInstrumentationLoadsBeforeDebug()
	self:assertBefore("Instrumentation.lua", "Debug.lua",
		"Debug.lua attaches itself as the instrumentation sink at load time")
end

function TestTocLoadOrder:testCoreLoadsBeforeItsDependants()
	-- Options.lua does `function OvershieldsReforged:InitializeDatabase()` at load time,
	-- indexing a global Core.lua creates. It has no guard and fails hard.
	self:assertBefore("Core.lua", "Options.lua",
		"Options.lua defines methods on the global addon object at load time")
	self:assertBefore("Core.lua", "ChatCommands.lua",
		"ChatCommands.lua reads the global addon object at load time")
end

TestTocCompleteness = {}

function TestTocCompleteness:testEveryListedFileExists()
	for _, entry in ipairs(LoadOrder()) do
		local path = load_addon.root .. "/" .. entry
		local file = io.open(path)
		lu.assertNotNil(file, "TOC lists " .. entry .. " but it isn't on disk")
		if file then file:close() end
	end
end
