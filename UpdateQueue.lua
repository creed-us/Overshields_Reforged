local _, ns = ...

--- Batch update frame used to defer frame updates until OnUpdate cycle
local batchFrame = ns.CreateFrame("Frame", nil, UIParent)
batchFrame:Hide()

--- Queue of frames pending updates in current batch
local updateQueue = {}

--- Tracks how many batch cycles each unready frame has been retried
local retryCount = {}

--- Maximum OnUpdate cycles to retry an unready frame before dropping it
local MAX_RETRIES = 10
local CACHE_CLEANUP_INTERVAL = 5
local FULL_REFRESH_RECOVERY_DELAY = 0.25
local lastCleanupAt = 0
local pendingRecoveryRefreshToken = 0

local function ScheduleRecoveryRefresh()
	if not ns.UpdateAllFrameAppearances then
		return
	end

	pendingRecoveryRefreshToken = pendingRecoveryRefreshToken + 1
	local refreshToken = pendingRecoveryRefreshToken
	C_Timer.After(FULL_REFRESH_RECOVERY_DELAY, function()
		if refreshToken ~= pendingRecoveryRefreshToken then
			return
		end
		ns.UpdateAllFrameAppearances()
	end)
end

--- Process queued frame updates once per cycle.
-- Frames whose healthBar is not yet available are retried on subsequent cycles
-- up to MAX_RETRIES times before being dropped.
batchFrame:SetScript("OnUpdate", function()
	local profile = OvershieldsReforged.db and OvershieldsReforged.db.profile
	if not profile then return end

	local now = ns.GetTime()
	if now - lastCleanupAt >= CACHE_CLEANUP_INTERVAL then
		ns.CleanupStaleCacheEntries()
		lastCleanupAt = now
	end

	--@alpha@
	local batchSize = 0
	--@end-alpha@

	local hasRetries = false

	for frame in ns.next, updateQueue do
		local success = ns.ProcessQueuedFrame(frame, profile)
		--@alpha@
		batchSize = batchSize + 1
		--@end-alpha@

		if success then
			--@alpha@
			if retryCount[frame] then ns.Emit("retrySuccesses") end
			--@end-alpha@
			updateQueue[frame] = nil
			retryCount[frame] = nil
		else
			local count = (retryCount[frame] or 0) + 1
			--@alpha@
			ns.Emit("retryAttempts")
			--@end-alpha@
			if count >= MAX_RETRIES then
				updateQueue[frame] = nil
				retryCount[frame] = nil
				ScheduleRecoveryRefresh()
				--@alpha@
				ns.Emit("retryDrops")
				--@end-alpha@
			else
				retryCount[frame] = count
				hasRetries = true
			end
		end
	end

	--@alpha@
	ns.Emit("batchCycles")
	ns.Emit("batchFramesTotal", batchSize)
	ns.Emit("peakBatchSize", batchSize)
	--@end-alpha@

	if not hasRetries then
		ns.wipe(updateQueue)
		batchFrame:Hide()
	end
end)

--- Queues a compact unit frame for appearance update.
-- Frames are batched and processed during the next OnUpdate cycle for efficiency.
-- @param frame The compact unit frame to queue for update
function ns.QueueCompactUnitFrameUpdate(frame)
	if ns.hibernating then return end

	if ns.FrameIsForbidden(frame) or not ns.IsKnownCompactUnitFrame(frame) then
		return
	end

	--@alpha@
	ns.Emit("queueAttempts")
	--@end-alpha@

	if not OvershieldsReforged:IsFrameContextEnabled(frame) then
		updateQueue[frame] = nil
		retryCount[frame] = nil
		ns.ReleaseFrame(frame, ns.StyleCache)
		--@alpha@
		ns.Emit("queueSkipsDisabled")
		--@end-alpha@
		return
	end

	if updateQueue[frame] then
		--@alpha@
		ns.Emit("queueSkipsDuplicate")
		--@end-alpha@
		return
	end

	--@alpha@
	ns.Emit("queueAdds")
	--@end-alpha@

	updateQueue[frame] = true
	batchFrame:Show()
end

--- Drops all pending batch work and stops the OnUpdate driver.
-- Owned by the queue, not the bar caches: ReleaseAllBars calls it so that releasing bars
-- can't leave queued work pointing at frames that are no longer tracked.
function ns.ResetUpdateQueue()
	ns.wipe(updateQueue)
	ns.wipe(retryCount)
	pendingRecoveryRefreshToken = pendingRecoveryRefreshToken + 1
	batchFrame:Hide()
end

