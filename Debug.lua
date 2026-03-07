local _, ns = ...

local AceGUI = LibStub("AceGUI-3.0")

-------------------------------------------------------------------------------
-- Counter storage
-------------------------------------------------------------------------------

local counters = {
	-- Pipeline
	hookFires           = 0,
	queueAttempts       = 0,
	queueAdds           = 0,
	queueSkipsDuplicate = 0,
	queueSkipsDisabled  = 0,
	batchCycles         = 0,
	batchFramesTotal    = 0,
	peakBatchSize       = 0,
	frameUpdates        = 0,
	earlyExits          = 0,
	-- Caches
	barCreates          = 0,
	barReuses           = 0,
	anchorModeChanges   = 0,
	nativeBarsSuppressed = 0,
	-- Styling
	colorApplied        = 0,
	colorSkipped        = 0,
	textureApplied      = 0,
	textureSkipped      = 0,
	blendApplied        = 0,
	blendSkipped        = 0,
	contextDisabled     = 0,
	framesShown         = 0,
	framesHidden        = 0,
	fullRefreshes       = 0,
	lastRefreshTime     = 0,
	poolPath            = "none",
	poolFramesProcessed = 0,
}

-- Window-scoped counters mirror the same keys (reset on window open)
local windowCounters = {}

local function ResetTable(t, source)
	for k in pairs(source) do
		local v = source[k]
		if type(v) == "number" then
			t[k] = 0
		elseif type(v) == "string" then
			t[k] = ""
		end
	end
end

ResetTable(windowCounters, counters)

-------------------------------------------------------------------------------
-- Increment helper — bumps both session and window counters
-------------------------------------------------------------------------------

local function Inc(key, amount)
	amount = amount or 1
	counters[key] = counters[key] + amount
	windowCounters[key] = windowCounters[key] + amount
end

local function Set(key, value)
	counters[key] = value
	windowCounters[key] = value
end

local function Max(key, value)
	if value > counters[key] then counters[key] = value end
	if value > windowCounters[key] then windowCounters[key] = value end
end

-------------------------------------------------------------------------------
-- Public increment API (called from instrumentation sites)
-------------------------------------------------------------------------------

local Debug = {}
ns.Debug = Debug

Debug.Inc = Inc
Debug.Set = Set
Debug.Max = Max
Debug.counters = counters
Debug.windowCounters = windowCounters

-------------------------------------------------------------------------------
-- Snapshot helpers
-------------------------------------------------------------------------------

local function CountTable(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function CountFramesByContext(cache)
	local party, raid, pet, other = 0, 0, 0, 0
	for frame in pairs(cache) do
		local unit = frame.displayedUnit
		if unit then
			if string.find(unit, "pet", 1, true) then
				pet = pet + 1
			elseif string.find(unit, "raid", 1, true) then
				raid = raid + 1
			elseif string.find(unit, "party", 1, true) then
				party = party + 1
			else
				other = other + 1
			end
		end
	end
	return party, raid, pet, other
end

local function FormatDual(sessionVal, windowVal)
	return tostring(sessionVal) .. "  (+" .. tostring(windowVal) .. ")"
end

local function FormatRatio(applied, skipped)
	return tostring(applied) .. " / " .. tostring(skipped)
end

local function FormatTimestamp(t)
	if t == 0 then return "never" end
	return string.format("%.1fs ago", GetTime() - t)
end

-------------------------------------------------------------------------------
-- AceGUI Window
-------------------------------------------------------------------------------

local debugFrame = nil
local refreshTicker = nil

--- Creates a labeled row with tooltip.
-- @param parent AceGUI container to add the label to
-- @param labelText Display label (left side)
-- @param tooltipText Tooltip shown on hover
-- @return AceGUI InteractiveLabel widget (call SetText on .valueLabel to update)
local function AddRow(parent, labelText, tooltipText)
	local row = AceGUI:Create("SimpleGroup")
	row:SetLayout("Flow")
	row:SetFullWidth(true)

	local label = AceGUI:Create("InteractiveLabel")
	label:SetWidth(180)
	label:SetText("|cff888888" .. labelText .. "|r")
	label:SetFontObject(GameFontHighlightSmall)
	if tooltipText then
		label:SetCallback("OnEnter", function(widget)
			GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
			GameTooltip:AddLine(labelText, 1, 0.82, 0)
			GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		label:SetCallback("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
	row:AddChild(label)

	local value = AceGUI:Create("Label")
	value:SetWidth(200)
	value:SetText("")
	value:SetFontObject(GameFontHighlightSmall)
	row:AddChild(value)

	parent:AddChild(row)
	return value
end

local function AddSectionHeader(parent, text)
	local heading = AceGUI:Create("Heading")
	heading:SetText(text)
	heading:SetFullWidth(true)
	parent:AddChild(heading)
end

local function AddButton(parent, text, callback)
	local btn = AceGUI:Create("Button")
	btn:SetText(text)
	btn:SetWidth(160)
	btn:SetCallback("OnClick", callback)
	parent:AddChild(btn)
	return btn
end

-- Persistent widget references for live updates
local widgets = {}

local function BuildWindow()
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("Overshields Reforged — Debug")
	frame:SetStatusText("Alpha build diagnostics")
	frame:SetWidth(440)
	frame:SetHeight(580)
	frame:SetLayout("Fill")
	frame:SetCallback("OnClose", function()
		Debug:Close()
	end)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	frame:AddChild(scroll)

	-- Pipeline section
	AddSectionHeader(scroll, "Pipeline")
	widgets.hookFires           = AddRow(scroll, "Hook Fires",              "CompactUnitFrame_UpdateHealPrediction invocations received by the addon.")
	widgets.queueAttempts       = AddRow(scroll, "Queue Attempts",          "Total calls to QueueCompactUnitFrameUpdate (includes all outcomes).")
	widgets.queueAdds           = AddRow(scroll, "Queue Adds",             "Frames successfully added to the batch queue for processing.")
	widgets.queueSkipsDuplicate = AddRow(scroll, "Queue Skips (Duplicate)", "Skipped because the frame was already in the queue this cycle.")
	widgets.queueSkipsDisabled  = AddRow(scroll, "Queue Skips (Disabled)",  "Skipped because the frame's unit context (party/raid/pet) was disabled.")
	widgets.batchCycles         = AddRow(scroll, "Batch Cycles",           "Number of OnUpdate batch processing cycles that ran.")
	widgets.avgBatchSize        = AddRow(scroll, "Avg Batch Size",         "Average number of frames processed per batch cycle.")
	widgets.peakBatchSize       = AddRow(scroll, "Peak Batch Size",        "Largest single batch of frames processed in one OnUpdate cycle.")
	widgets.frameUpdates        = AddRow(scroll, "Frame Updates",          "HandleCompactUnitFrameUpdate calls that ran to completion (past all guards).")
	widgets.earlyExits          = AddRow(scroll, "Early Exits",            "Updates aborted early (unit missing, glow forbidden, or no healthBar).")

	-- Caches section
	AddSectionHeader(scroll, "Caches")
	widgets.absorbCacheSize  = AddRow(scroll, "Absorb Bar Cache",   "Active entries in the custom absorb StatusBar cache.")
	widgets.overlayCacheSize = AddRow(scroll, "Overlay Bar Cache",  "Active entries in the custom overlay StatusBar cache.")
	widgets.styleCacheSize   = AddRow(scroll, "Style Cache",        "Active entries in the weak-keyed appearance style cache.")
	widgets.barCreates       = AddRow(scroll, "Bar Creates",        "GetOrCreate cache misses — a new StatusBar was created.")
	widgets.barReuses        = AddRow(scroll, "Bar Reuses",         "GetOrCreate cache hits — existing StatusBar returned.")

	-- Styling section
	AddSectionHeader(scroll, "Styling")
	widgets.colorRatio          = AddRow(scroll, "Color Applied / Skipped",   "SetStatusBarColor calls (applied) vs. cache-hit skips. Lower ratio = better caching.")
	widgets.textureRatio        = AddRow(scroll, "Texture Applied / Skipped", "SetStatusBarTexture calls (applied) vs. cache-hit skips.")
	widgets.blendRatio          = AddRow(scroll, "Blend Applied / Skipped",   "SetBlendMode calls (applied) vs. cache-hit skips.")
	widgets.contextDisabled     = AddRow(scroll, "Context Disabled",          "ApplyAppearanceToFrame early returns because IsFrameContextEnabled was false.")
	widgets.anchorModeChanges   = AddRow(scroll, "Anchor Mode Changes",      "Bar _anchorMode transitions (default/health/texture).")
	widgets.nativeBarsSuppressed = AddRow(scroll, "Native Bars Suppressed",   "CompactUnitFrameUtil_UpdateFillBar hook ClearAllPoints calls on Bliz bars.")
	widgets.fullRefreshes       = AddRow(scroll, "Full Refreshes",           "UpdateAllFrameAppearances invocations (triggered by settings changes).")
	widgets.lastRefreshTime     = AddRow(scroll, "Last Refresh",             "Time since the last full appearance refresh.")
	widgets.poolPath            = AddRow(scroll, "Pool Iteration Path",      "Which API path UpdateFramePool used last: pools, frameReservations, or legacy.")

	-- Active Frames section
	AddSectionHeader(scroll, "Active Frames")
	widgets.framesShown   = AddRow(scroll, "Shown / Hidden",   "Frames processed as shown (styled) vs. hidden (bars hidden) by ProcessFrame.")
	widgets.partyFrames   = AddRow(scroll, "Party",             "Frames in absorb cache with a party unit token.")
	widgets.raidFrames    = AddRow(scroll, "Raid",              "Frames in absorb cache with a raid unit token.")
	widgets.petFrames     = AddRow(scroll, "Pet",               "Frames in absorb cache with a pet unit token.")

	-- Controls section
	AddSectionHeader(scroll, "Controls")
	local controlGroup = AceGUI:Create("SimpleGroup")
	controlGroup:SetLayout("Flow")
	controlGroup:SetFullWidth(true)
	scroll:AddChild(controlGroup)

	AddButton(controlGroup, "Clear All", function()
		ResetTable(windowCounters, counters)
		for k, v in pairs(counters) do
			if type(v) == "number" then
				counters[k] = 0
			elseif type(v) == "string" then
				counters[k] = ""
			end
		end
		counters.poolPath = "none"
	end)

	AddButton(controlGroup, "Clear Current", function()
		ResetTable(windowCounters, counters)
	end)

	return frame
end

local function RefreshDisplay()
	if not debugFrame then return end

	local s = counters
	local w = windowCounters

	-- Pipeline
	widgets.hookFires:SetText(FormatDual(s.hookFires, w.hookFires))
	widgets.queueAttempts:SetText(FormatDual(s.queueAttempts, w.queueAttempts))
	widgets.queueAdds:SetText(FormatDual(s.queueAdds, w.queueAdds))
	widgets.queueSkipsDuplicate:SetText(FormatDual(s.queueSkipsDuplicate, w.queueSkipsDuplicate))
	widgets.queueSkipsDisabled:SetText(FormatDual(s.queueSkipsDisabled, w.queueSkipsDisabled))
	widgets.batchCycles:SetText(FormatDual(s.batchCycles, w.batchCycles))

	local avgSession = s.batchCycles > 0 and string.format("%.1f", s.batchFramesTotal / s.batchCycles) or "0"
	local avgWindow = w.batchCycles > 0 and string.format("%.1f", w.batchFramesTotal / w.batchCycles) or "0"
	widgets.avgBatchSize:SetText(avgSession .. "  (+" .. avgWindow .. ")")

	widgets.peakBatchSize:SetText(FormatDual(s.peakBatchSize, w.peakBatchSize))
	widgets.frameUpdates:SetText(FormatDual(s.frameUpdates, w.frameUpdates))
	widgets.earlyExits:SetText(FormatDual(s.earlyExits, w.earlyExits))

	-- Caches
	widgets.absorbCacheSize:SetText(tostring(CountTable(ns.absorbCache)) .. " entries")
	widgets.overlayCacheSize:SetText(tostring(CountTable(ns.overlayCache)) .. " entries")
	-- styleCache is local to AppearanceManager; expose count via ns
	local styleCount = ns.GetStyleCacheSize and ns.GetStyleCacheSize() or "?"
	widgets.styleCacheSize:SetText(tostring(styleCount) .. " entries")
	widgets.barCreates:SetText(FormatDual(s.barCreates, w.barCreates))
	widgets.barReuses:SetText(FormatDual(s.barReuses, w.barReuses))

	-- Styling
	widgets.colorRatio:SetText(FormatRatio(s.colorApplied, s.colorSkipped) .. "  (+" .. FormatRatio(w.colorApplied, w.colorSkipped) .. ")")
	widgets.textureRatio:SetText(FormatRatio(s.textureApplied, s.textureSkipped) .. "  (+" .. FormatRatio(w.textureApplied, w.textureSkipped) .. ")")
	widgets.blendRatio:SetText(FormatRatio(s.blendApplied, s.blendSkipped) .. "  (+" .. FormatRatio(w.blendApplied, w.blendSkipped) .. ")")
	widgets.contextDisabled:SetText(FormatDual(s.contextDisabled, w.contextDisabled))
	widgets.anchorModeChanges:SetText(FormatDual(s.anchorModeChanges, w.anchorModeChanges))
	widgets.nativeBarsSuppressed:SetText(FormatDual(s.nativeBarsSuppressed, w.nativeBarsSuppressed))
	widgets.fullRefreshes:SetText(FormatDual(s.fullRefreshes, w.fullRefreshes))
	widgets.lastRefreshTime:SetText(FormatTimestamp(s.lastRefreshTime))
	widgets.poolPath:SetText(tostring(s.poolPath))

	-- Active Frames
	widgets.framesShown:SetText(FormatDual(s.framesShown, w.framesShown) .. " / " .. FormatDual(s.framesHidden, w.framesHidden))
	local party, raid, pet = CountFramesByContext(ns.absorbCache)
	widgets.partyFrames:SetText(tostring(party))
	widgets.raidFrames:SetText(tostring(raid))
	widgets.petFrames:SetText(tostring(pet))
end

-------------------------------------------------------------------------------
-- Toggle / Open / Close
-------------------------------------------------------------------------------

function Debug:Open()
	if debugFrame then return end
	ResetTable(windowCounters, counters)
	debugFrame = BuildWindow()
	RefreshDisplay()
	refreshTicker = C_Timer.NewTicker(0.5, RefreshDisplay)
end

function Debug:Close()
	if refreshTicker then
		refreshTicker:Cancel()
		refreshTicker = nil
	end
	if debugFrame then
		debugFrame:Release()
		debugFrame = nil
	end
	wipe(widgets)
end

function Debug:Toggle()
	if debugFrame then
		self:Close()
	else
		self:Open()
	end
end
