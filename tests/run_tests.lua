--- Test suite entry point.
--
-- Run from the repository root:
--     lua tests/run_tests.lua
--
-- Any Lua 5.1+ interpreter works; CI pins 5.1 to match the client's embedded runtime.
-- Specs are listed explicitly rather than discovered, because portable directory listing
-- isn't available in plain Lua. Add new spec files to SPECS below.

local SPECS = {
	"toc_spec",
	"unitcontext_spec",
	"shieldstate_spec",
	"anchorstrategy_spec",
	"utilities_spec",
	"instrumentation_spec",
	"debug_sink_spec",
	"glowtexturecatalog_spec",
	"profilemigration_spec",
	"optionsdropdowns_spec",
	"frameregistry_spec",
	"updatequeue_spec",
	"frameupdate_spec",
	"framediscovery_spec",
	"pipeline_integration_spec",
	"barlifecycle_spec",
}

local script = ((type(arg) == "table" and arg[0]) or "tests/run_tests.lua"):gsub("\\", "/")
local testsDir = script:match("^(.*)/[^/]+$") or "."

package.path = table.concat({
	testsDir .. "/?.lua",
	testsDir .. "/lib/?.lua",
	testsDir .. "/support/?.lua",
	package.path,
}, ";")

local load_addon = require("load_addon")
load_addon.root = load_addon.DetectRoot()

local luaunit = require("luaunit")

for _, spec in ipairs(SPECS) do
	require(spec)
end

os.exit(luaunit.LuaUnit.run())
