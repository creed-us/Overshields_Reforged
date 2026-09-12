--- Recorder-style stand-ins for the WoW widget objects the addon touches.
-- Every setter appends to `.calls` so specs can assert on what was called, in order.
-- Only the methods the addon actually calls are implemented; add more as later stages
-- need them rather than mirroring the whole widget API up front.

local M = {}

local function Record(widget, method, ...)
	widget.calls[#widget.calls + 1] = { method = method, args = { ... }, n = select("#", ...) }
end

--- Returns every recorded call with the given method name, in call order.
function M.CallsTo(widget, method)
	local matches = {}
	for _, call in ipairs(widget.calls) do
		if call.method == method then
			matches[#matches + 1] = call
		end
	end
	return matches
end

--- Returns the arguments of the last call to `method`, or nil if it was never called.
function M.LastCall(widget, method)
	local matches = M.CallsTo(widget, method)
	return matches[#matches]
end

local function AddFrameMethods(widget)
	function widget:IsForbidden() return self.forbidden == true end
	function widget:GetName() return self.name end
	function widget:GetParent() return self.parent end
	function widget:IsShown() return self.shown == true end
	function widget:IsVisible() return self.visible == true end

	function widget:Show() Record(self, "Show"); self.shown = true; self.visible = true end
	function widget:Hide() Record(self, "Hide"); self.shown = false; self.visible = false end
	function widget:SetShown(value) Record(self, "SetShown", value); self.shown = value; self.visible = value end

	function widget:SetPoint(...) Record(self, "SetPoint", ...) end
	function widget:SetAllPoints(...) Record(self, "SetAllPoints", ...) end
	function widget:ClearAllPoints() Record(self, "ClearAllPoints") end

	function widget:GetFrameLevel() return self.frameLevel or 1 end
	function widget:SetFrameLevel(level) Record(self, "SetFrameLevel", level); self.frameLevel = level end

	function widget:SetScript(event, handler) Record(self, "SetScript", event, handler); self.scripts[event] = handler end
	function widget:RegisterEvent(event) Record(self, "RegisterEvent", event); self.events[event] = true end
end

--- A plain Frame.
function M.NewFrame(opts)
	opts = opts or {}
	local frame = {
		calls = {},
		scripts = {},
		events = {},
		name = opts.name,
		parent = opts.parent,
		forbidden = opts.forbidden == true,
		shown = opts.shown ~= false,
		visible = opts.visible ~= false and opts.shown ~= false,
		frameLevel = opts.frameLevel or 1,
	}
	AddFrameMethods(frame)
	return frame
end

--- A Texture / texture-like region (SetVertexColor, no SetStatusBarColor).
function M.NewTexture(opts)
	opts = opts or {}
	local texture = M.NewFrame(opts)

	function texture:SetTexture(...) Record(self, "SetTexture", ...); self.texture = (...) end
	function texture:SetAtlas(...) Record(self, "SetAtlas", ...); self.atlas = (...) end
	function texture:SetTexCoord(...) Record(self, "SetTexCoord", ...) end
	function texture:SetBlendMode(mode) Record(self, "SetBlendMode", mode); self.blendMode = mode end
	function texture:SetVertexColor(...) Record(self, "SetVertexColor", ...) end
	function texture:SetHorizTile(value) Record(self, "SetHorizTile", value); self.horizTile = value end
	function texture:SetVertTile(value) Record(self, "SetVertTile", value); self.vertTile = value end

	return texture
end

--- A StatusBar. Carries its own status bar texture so GetStatusBarTexture() is meaningful.
function M.NewStatusBar(opts)
	opts = opts or {}
	local bar = M.NewFrame(opts)
	bar.statusBarTexture = opts.statusBarTexture or M.NewTexture()
	bar.minValue, bar.maxValue = 0, opts.maxValue or 100
	bar.value = opts.value or 0

	function bar:SetStatusBarColor(...) Record(self, "SetStatusBarColor", ...) end
	function bar:SetStatusBarTexture(...) Record(self, "SetStatusBarTexture", ...) end
	function bar:GetStatusBarTexture() return self.statusBarTexture end
	function bar:SetReverseFill(value) Record(self, "SetReverseFill", value); self.reverseFill = value end
	function bar:SetMinMaxValues(minValue, maxValue)
		Record(self, "SetMinMaxValues", minValue, maxValue)
		self.minValue, self.maxValue = minValue, maxValue
	end
	function bar:GetMinMaxValues() return self.minValue, self.maxValue end
	function bar:SetValue(value) Record(self, "SetValue", value); self.value = value end
	function bar:GetValue() return self.value end

	return bar
end

--- A compact unit frame, shaped like the Blizzard frames the addon hooks.
-- opts.unit sets displayedUnit; opts.absorbShown / opts.overlayShown / opts.glowVisible
-- set the native absorb visuals that ShieldState reads.
function M.NewCompactFrame(opts)
	opts = opts or {}
	local frame = M.NewFrame(opts)

	frame.displayedUnit = opts.unit
	frame.healthBar = opts.healthBar ~= false and M.NewStatusBar() or nil
	frame.totalAbsorb = M.NewStatusBar({ shown = opts.absorbShown == true })
	frame.totalAbsorb.fill = M.NewTexture()
	frame.totalAbsorb.overlay = M.NewTexture()
	frame.totalAbsorbOverlay = M.NewTexture({ shown = opts.overlayShown == true })
	frame.overAbsorbGlow = M.NewTexture({
		shown = opts.glowVisible == true,
		visible = opts.glowVisible == true,
	})

	return frame
end

return M
