---@diagnostic disable: duplicate-set-field, lowercase-global
--- Minimal stand-ins for the WoW client globals the addon needs in order to load and run
-- under a plain Lua interpreter.
--
-- IMPORTANT: Constants.lua captures several of these by value (`local CreateFrame =
-- CreateFrame`) at load time, so these must be installed BEFORE any addon file is loaded.
-- A spec that wants to change one mid-test must swap it on the namespace (`ns.IsInRaid`),
-- not here — swapping the global after load has no effect on the captured alias.

local mock_frame = require("mock_frame")

local M = {}

--- Frames created through the stubbed CreateFrame, in creation order.
M.createdFrames = {}

--- Callbacks handed to C_Timer.After, in scheduling order. Nothing runs them
-- automatically; a spec calls M.FlushTimers() when it wants them to fire.
M.scheduledTimers = {}

function M.FlushTimers()
	local pending = M.scheduledTimers
	M.scheduledTimers = {}
	for _, timer in ipairs(pending) do
		timer.callback()
	end
	return #pending
end

local LEGACY_FRAME_PREFIXES = {
	"CompactRaidFrame",
	"CompactPartyFrameMember",
	"CompactRaidFramePet",
	"CompactPartyFramePet",
}

--- Resets the recorded state between tests without reinstalling the globals.
-- The compact frame containers are rebuilt rather than reused: specs attach `flowFrames`
-- and `displayPets` to them, and those would otherwise leak into the next test.
function M.Reset()
	M.createdFrames = {}
	M.scheduledTimers = {}
	M.atlases = {}
	M.atlasLookups = 0
	M.now = 0
	M.inRaid = false
	M.inGroup = false
	M.libs = {}

	_G.UIParent = mock_frame.NewFrame({ name = "UIParent" })
	_G.CompactPartyFrame = mock_frame.NewFrame({ name = "CompactPartyFrame" })
	_G.CompactRaidFrameContainer = mock_frame.NewFrame({ name = "CompactRaidFrameContainer" })

	-- Frames the legacy global-name walk would find.
	for _, prefix in ipairs(LEGACY_FRAME_PREFIXES) do
		for index = 1, 40 do
			_G[prefix .. index] = nil
		end
	end
end

--- Atlas names that C_Texture.GetAtlasInfo should report as real atlases.
M.atlases = {}

--- Libraries LibStub should hand back, keyed by name. Anything not listed falls back to
-- the defaults in Install(). Populated per-test via NewNamespace's `libs` option.
M.libs = {}

--- Number of times C_Texture.GetAtlasInfo has been consulted — lets specs prove the
-- addon's atlas cache is actually avoiding repeat lookups.
M.atlasLookups = 0

local installed = false

function M.Install()
	if installed then
		M.Reset()
		return M
	end
	installed = true

	_G.wipe = function(t)
		for key in pairs(t) do
			t[key] = nil
		end
		return t
	end

	_G.CreateFrame = function(frameType, name, parent)
		local frame
		if frameType == "StatusBar" then
			frame = mock_frame.NewStatusBar({ name = name, parent = parent })
		else
			frame = mock_frame.NewFrame({ name = name, parent = parent })
		end
		frame.frameType = frameType
		M.createdFrames[#M.createdFrames + 1] = frame
		return frame
	end

	-- UIParent and Blizzard's compact frame containers are (re)built in Reset(). They must
	-- be real, distinct objects: the addon identifies its frames partly by comparing a
	-- frame's parent against the containers, so leaving them nil would make every
	-- unparented frame compare equal and be misread as a compact unit frame.

	_G.UnitExists = function(unit) return unit ~= nil end
	_G.UnitGetTotalAbsorbs = function() return 0 end
	_G.GetTime = function() return M.now or 0 end
	_G.IsInRaid = function() return M.inRaid == true end
	_G.IsInGroup = function() return M.inGroup == true end
	_G.hooksecurefunc = function() end

	-- Enough LibStub for Debug.lua and Options.lua to load. The Ace libraries are only
	-- *called* from inside functions (SetupOptions, InitializeDatabase), never at load
	-- time, so an empty table suffices to get those files loaded.
	--
	-- LibSharedMedia is different: it's an optional dependency fetched with the silent
	-- flag, so the honest default is nil (not installed). Returning a table for it would
	-- make the addon think LSM is present and then fail on LSM.RegisterCallback. A spec
	-- that wants the LSM branch passes a fake in via NewNamespace's `libs` option.
	_G.LibStub = function(name)
		if M.libs[name] ~= nil then
			return M.libs[name]
		end
		if name == "LibSharedMedia-3.0" then
			return nil
		end
		return {}
	end

	-- Options.lua registers a reload prompt into this at load time.
	_G.StaticPopupDialogs = {}

	_G.C_Timer = {
		After = function(delay, callback)
			M.scheduledTimers[#M.scheduledTimers + 1] = { delay = delay, callback = callback }
		end,
		NewTicker = function(interval, callback)
			local ticker = { interval = interval, callback = callback, cancelled = false }
			function ticker:Cancel() self.cancelled = true end
			return ticker
		end,
	}

	_G.C_Texture = {
		GetAtlasInfo = function(asset)
			M.atlasLookups = M.atlasLookups + 1
			if M.atlases[asset] then
				return { width = 16, height = 16 }
			end
			return nil
		end,
	}

	M.Reset()
	return M
end

--- Stand-in for the addon object Core.lua normally builds through AceAddon.
-- The pipeline reads OvershieldsReforged.db.profile and asks it whether a frame's unit
-- context is enabled; loading Core.lua for real would drag in the whole of Ace3.
-- @param opts .profile (table), .contextEnabled (boolean, default true)
function M.InstallAddonStub(opts)
	opts = opts or {}

	local addon = {
		db = { profile = opts.profile or {} },
		contextEnabled = opts.contextEnabled ~= false,
		printed = {},
	}

	function addon:IsUnitContextEnabled()
		return self.contextEnabled
	end

	function addon:IsFrameContextEnabled()
		return self.contextEnabled
	end

	function addon:Print(message)
		self.printed[#self.printed + 1] = message
	end

	_G.OvershieldsReforged = addon
	return addon
end

--- Returns the frame carrying an OnUpdate script — the batch driver — so specs can run a
-- cycle by hand instead of waiting on a real frame loop.
function M.FindOnUpdateDriver()
	for _, frame in ipairs(M.createdFrames) do
		if frame.scripts and frame.scripts.OnUpdate then
			return frame
		end
	end
	return nil
end

return M
