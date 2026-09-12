local _, ns = ...

--- Instrumentation seam.
-- Pipeline code calls ns.Emit to announce that something happened, without knowing
-- whether anything is listening or how a listener would record it. Debug.lua attaches
-- itself as the handler when it loads; in builds where Debug.lua is stripped, nothing
-- attaches and every Emit is a no-op.
--
-- The call sites stay wrapped in --@alpha@ markers, so in non-alpha packages the calls
-- are stripped at build time and this costs nothing at runtime either way.

local handler = nil

--- Announces an instrumentation event.
-- @param name Event name, e.g. "barCreates"
-- @param amount Optional value; meaning is the handler's business (an increment, a
--               gauge reading, a label...)
function ns.Emit(name, amount)
	if handler then
		handler(name, amount)
	end
end

--- Attaches the sink that records events, or nil to detach.
function ns.SetInstrumentationHandler(fn)
	handler = fn
end
