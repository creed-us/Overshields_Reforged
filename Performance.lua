local _, ns = ...

local addon = OvershieldsReforged
if not addon then
	return
end

ns.perf = ns.perf or {
	enabled = false,
	lastResetTime = 0,
	queueEnqueued = 0,
	queueProcessed = 0,
	queueDroppedDuplicate = 0,
	queueDroppedInvalid = 0,
	queueSkippedContext = 0,
	onUpdateBatches = 0,
	appearanceRefreshRequests = 0,
	appearanceRefreshRuns = 0,
	appearanceRefreshSuperseded = 0,
}

function ns.RecordPerf(counterName, delta)
	local perf = ns.perf
	if not perf or not perf.enabled or not counterName then
		return
	end

	perf[counterName] = (perf[counterName] or 0) + (delta or 1)
end

--- Resets performance counters.
function addon:ResetPerformanceStats()
	local perf = ns.perf
	if not perf then
		return
	end

	perf.queueEnqueued = 0
	perf.queueProcessed = 0
	perf.queueDroppedDuplicate = 0
	perf.queueDroppedInvalid = 0
	perf.queueSkippedContext = 0
	perf.onUpdateBatches = 0
	perf.appearanceRefreshRequests = 0
	perf.appearanceRefreshRuns = 0
	perf.appearanceRefreshSuperseded = 0
	perf.lastResetTime = GetTime() or 0
end

--- Synchronizes runtime diagnostics state with current profile settings.
function addon:RefreshPerformanceDiagnosticsState()
	local profile = self.db and self.db.profile
	local enabled = profile and profile.perfDiagnostics == true or false
	local wasEnabled = ns.perf and ns.perf.enabled == true or false

	if not ns.perf then
		ns.perf = {}
	end

	ns.perf.enabled = enabled
	if enabled and (not wasEnabled or (ns.perf.lastResetTime or 0) == 0) then
		self:ResetPerformanceStats()
	end
end

--- Builds current performance counters and rates.
-- @return table? data
function addon:GetPerformanceSnapshot()
	local profile = self.db and self.db.profile
	local perf = ns.perf
	if not profile or not perf then
		return nil
	end

	local enabled = profile.perfDiagnostics == true
	local elapsed = (GetTime() or 0) - (perf.lastResetTime or 0)
	if elapsed < 0.001 then
		elapsed = 0.001
	end

	return {
		enabled = enabled,
		elapsed = elapsed,
		queueEnqueued = perf.queueEnqueued or 0,
		queueProcessed = perf.queueProcessed or 0,
		queueDroppedInvalid = perf.queueDroppedInvalid or 0,
		queueDroppedDuplicate = perf.queueDroppedDuplicate or 0,
		queueSkippedContext = perf.queueSkippedContext or 0,
		onUpdateBatches = perf.onUpdateBatches or 0,
		appearanceRefreshRequests = perf.appearanceRefreshRequests or 0,
		appearanceRefreshRuns = perf.appearanceRefreshRuns or 0,
		appearanceRefreshSuperseded = perf.appearanceRefreshSuperseded or 0,
	}
end

--- Returns formatted lines matching /osr perf output.
-- @return string[]
function addon:GetPerformanceSummaryLines()
	local snapshot = self:GetPerformanceSnapshot()
	if not snapshot then
		return { "Performance status unavailable." }
	end

	if not snapshot.enabled then
		return {
			"Performance diagnostics: Disabled",
			"Enable diagnostics in the Performance tab to collect counters.",
		}
	end

	return {
		"Performance diagnostics: Enabled",
		string.format("Window: %.1fs", snapshot.elapsed),
		string.format("Queue: enqueued=%d processed=%d droppedInvalid=%d droppedDuplicate=%d", snapshot.queueEnqueued, snapshot.queueProcessed, snapshot.queueDroppedInvalid, snapshot.queueDroppedDuplicate),
		string.format("Queue skips: context=%d batches=%d", snapshot.queueSkippedContext, snapshot.onUpdateBatches),
		string.format("Refresh: requested=%d runs=%d superseded=%d", snapshot.appearanceRefreshRequests, snapshot.appearanceRefreshRuns, snapshot.appearanceRefreshSuperseded),
		string.format("Rates: %.1f queued/s, %.1f processed/s", snapshot.queueEnqueued / snapshot.elapsed, snapshot.queueProcessed / snapshot.elapsed),
	}
end

--- Prints performance diagnostics summary.
function addon:PrintPerformanceStats()
	if not self.db or not self.db.profile then
		self:Print("Performance status unavailable (database not initialized).")
		return
	end

	for _, line in ipairs(self:GetPerformanceSummaryLines()) do
		self:Print(line)
	end
end