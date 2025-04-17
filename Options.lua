-- SavedVariables: OvershieldsDB
-- Defines defaults & builds the Blizzard Options panel

local ADDON_NAME = ...

-- Default values (merged in Core.lua)
OvershieldsReforged.defaults = {
	overshieldTickAlpha    = 0.6, -- edge‑of‑bar tick glow alpha
	overshieldOverlayAlpha = 0.6, -- full‑bar overlay alpha
}

-- Helper to register our panel
local function RegisterCanvas(frame)
	local cat = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
	cat.ID = frame.name
	Settings.RegisterAddOnCategory(cat)
end

-- Slider factory (mirrors CreateCheckbox pattern)
function OvershieldsReforged:CreateSlider(option, label, parent)
	local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	s.Text:SetText(label)
	s.Low:SetText("0.00")
	s.High:SetText("1.00")
	s:SetMinMaxValues(0, 1)
	s:SetValueStep(0.05)
	s:SetObeyStepOnDrag(true)
	s:SetWidth(200)

	local function Update(v)
		self.db[option] = v
		s:SetValue(v)
		s.Text:SetText(string.format("%s: %.2f", label, v))
	end

	-- init & live update
	Update(self.db[option])
	s:HookScript("OnValueChanged", function(_, v) Update(v) end)

	-- reset callback
	EventRegistry:RegisterCallback(ADDON_NAME .. ".OnReset", function()
		Update(self.defaults[option])
	end, s)

	return s
end

-- Build the “Overshields” options panel
function OvershieldsReforged:InitializeOptions()
	self.panel_main = CreateFrame("Frame")
	self.panel_main.name = "OvershieldsReforged"

	local title = self.panel_main:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Overshields Reforged Options")

	-- Tick alpha slider
	local tick = self:CreateSlider("overshieldTickAlpha", "Overshield Tick Alpha", self.panel_main)
	tick:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -30)

	-- Overlay alpha slider
	local overlay = self:CreateSlider("overshieldOverlayAlpha", "Overshield Overlay Alpha", self.panel_main)
	overlay:SetPoint("TOPLEFT", tick, "BOTTOMLEFT", 0, -30)

	-- Reset button
	local btn = CreateFrame("Button", nil, self.panel_main, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", 0, -40)
	btn:SetText(RESET)
	btn:SetWidth(100)
	btn:SetScript("OnClick", function()
		OvershieldsReforgedDB = CopyTable(OvershieldsReforged.defaults)
		self.db               = OvershieldsReforgedDB
		EventRegistry:TriggerEvent(ADDON_NAME .. ".OnReset")
	end)

	RegisterCanvas(self.panel_main)
end
