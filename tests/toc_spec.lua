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

TestEmbedsLoadOrder = {}

--- Returns the library includes of embeds.xml in load order, and the raw text.
local function EmbedOrder()
	local path = load_addon.root .. "/embeds.xml"
	local file = assert(io.open(path), "could not open " .. path)
	local text = file:read("*a")
	file:close()

	local order = {}
	for lib in text:gmatch("Libs\\([%w%-%.]+)\\") do
		order[#order + 1] = lib
	end
	return order, text
end

function TestEmbedsLoadOrder:testAceGuiLoadsBeforeAceConfig()
	-- AceConfigDialog (pulled in by AceConfig) calls LibStub("AceGUI-3.0") at load time
	-- without the silent flag, and LibStub errors on a missing library. Loading AceGUI
	-- afterwards only works when another addon happened to register it first.
	local order = EmbedOrder()
	local gui, config = IndexOf(order, "AceGUI-3.0"), IndexOf(order, "AceConfig-3.0")

	lu.assertNotNil(gui, "AceGUI-3.0 is missing from embeds.xml")
	lu.assertNotNil(config, "AceConfig-3.0 is missing from embeds.xml")
	lu.assertTrue(gui < config,
		"AceGUI-3.0 must load before AceConfig-3.0, or AceConfigDialog errors on a clean install")
end

function TestEmbedsLoadOrder:testAceGuiIsNotAlphaGated()
	-- It was, once. The options panel is built with AceConfigDialog, which *is* AceGUI, so
	-- gating it to alpha builds breaks the options panel for every release user.
	local _, text = EmbedOrder()

	local alphaBlock = text:match("@alpha@.-AceGUI%-3%.0.-@end%-alpha@")
	lu.assertNil(alphaBlock,
		"AceGUI-3.0 must not be alpha-gated: AceConfigDialog needs it in every build")
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
