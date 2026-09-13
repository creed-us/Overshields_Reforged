--- Loads real addon source files into a throwaway namespace table, the same way the WoW
-- client does: each file is a chunk called with (addonName, ns).
--
-- Specs load only the files the module under test actually needs, and get a fresh `ns`
-- (and therefore fresh upvalues — caches, queues, state tables) on every call, so tests
-- stay isolated from each other.

local wow_stub = require("wow_stub")

local M = {}

local ADDON_NAME = "Overshields_Reforged"

--- Repository root, relative to the current working directory.
-- Set explicitly by the runner; the fallback covers being invoked from the repo root.
M.root = "."

--- Works out the repo root from the running script's path, so the suite can be started
-- either from the repo root (`lua tests/run_tests.lua`) or from inside tests/.
function M.DetectRoot()
	local script = (type(arg) == "table" and arg[0]) or ""
	script = script:gsub("\\", "/")

	local parentOfTests = script:match("^(.*)/tests/[^/]+$")
	if parentOfTests and parentOfTests ~= "" then
		return parentOfTests
	end

	if script:match("^tests/[^/]+$") then
		return "."
	end

	-- Started from inside tests/ (e.g. `lua run_tests.lua`).
	if script ~= "" and not script:match("/") then
		return ".."
	end

	return "."
end

--- Loads one addon file into `ns`.
function M.LoadIntoNamespace(ns, path)
	local fullPath = M.root .. "/" .. path
	local chunk, err = loadfile(fullPath)
	if not chunk then
		error("could not load addon file '" .. fullPath .. "': " .. tostring(err), 2)
	end
	return chunk(ADDON_NAME, ns)
end

--- Recording sink for instrumentation events, standing in for Debug.lua.
-- The `--@alpha@` markers around instrumentation calls are only stripped when the addon
-- is packaged, so in raw source those calls are live and specs need somewhere for them to
-- land. Specs assert on `ns.Debug.counts` / `ns.Debug.values`.
--
-- Deliberately records both ways rather than mirroring Debug.lua's event-kind table: a
-- numeric event accumulates into `counts` AND lands in `values`, so this harness never
-- needs to be kept in sync with how the real sink classifies an event.
local function NewDebugStub()
	local debug = { counts = {}, values = {} }

	function debug.Record(name, amount)
		if amount == nil or type(amount) == "number" then
			debug.counts[name] = (debug.counts[name] or 0) + (amount or 1)
		end
		if amount ~= nil then
			debug.values[name] = amount
		end
	end

	return debug
end

--- Installs the WoW stubs, then loads `files` (in order) into a fresh namespace.
-- @param files Array of repo-relative paths, e.g. { "Constants.lua", "ShieldState.lua" }
-- @param opts Optional. `opts.libs` maps library names to stubs for LibStub to return —
--             it has to be applied before the files load, because Options.lua asks for
--             LibSharedMedia at load time.
-- @return the namespace table, and the wow_stub module for convenience
function M.NewNamespace(files, opts)
	wow_stub.Install()

	if opts and opts.libs then
		for name, lib in pairs(opts.libs) do
			wow_stub.libs[name] = lib
		end
	end

	-- Options.lua defines methods directly on the global OvershieldsReforged at load time
	-- (`function OvershieldsReforged:InitializeDatabase()`), so the addon object has to
	-- exist before it loads — exactly as Core.lua guarantees in the real TOC order.
	if opts and opts.addon then
		wow_stub.InstallAddonStub(opts.addon == true and {} or opts.addon)
	end

	local ns = { Debug = NewDebugStub() }
	for _, path in ipairs(files or {}) do
		M.LoadIntoNamespace(ns, path)
	end

	-- Attach the recorder the way Debug.lua does in an alpha build, so specs can assert
	-- that instrumentation still fires from the real call sites.
	--
	-- Skipped when the spec loaded the real Debug.lua: that replaces ns.Debug with its own
	-- table and registers its own handler, and attaching here would detach it again.
	if ns.SetInstrumentationHandler and ns.Debug and ns.Debug.Record then
		ns.SetInstrumentationHandler(ns.Debug.Record)
	end

	return ns, wow_stub
end

return M
