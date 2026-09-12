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

--- Resets the recorded state between tests without reinstalling the globals.
function M.Reset()
	M.createdFrames = {}
	M.scheduledTimers = {}
	M.atlases = {}
	M.atlasLookups = 0
	M.now = 0
	M.inRaid = false
	M.inGroup = false
end

--- Atlas names that C_Texture.GetAtlasInfo should report as real atlases.
M.atlases = {}

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

	_G.UnitExists = function(unit) return unit ~= nil end
	_G.UnitGetTotalAbsorbs = function() return 0 end
	_G.GetTime = function() return M.now or 0 end
	_G.IsInRaid = function() return M.inRaid == true end
	_G.IsInGroup = function() return M.inGroup == true end
	_G.hooksecurefunc = function() end

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

return M
