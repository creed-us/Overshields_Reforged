local ADDON_NAME = ...

OvershieldsReforged.defaults = {
	overshieldTickAlpha       = 0.6,                         -- edge‑of‑bar tick glow alpha
	overshieldOverlayAlpha    = 0.6,                         -- full‑bar overlay alpha
	showTickWhenNotFullHealth = true,                        -- show tick when unit is not at full health
	absorbOverlayColor        = { r = 0, g = 0, b = 1, a = 1 }, -- default color
	absorbOverlayBlendMode    = "BLEND",                     -- default blend mode
}

local function RegisterCanvas(frame)
	local cat = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
	cat.ID = frame.name
	Settings.RegisterAddOnCategory(cat)
end

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

function OvershieldsReforged:CreateCheckbox(option, label, parent)
	local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	cb.Text:SetText(label)

	local function Update(value)
		self.db[option] = value
		cb:SetChecked(value)
	end

	-- Initialize and live update
	Update(self.db[option])
	cb:SetScript("OnClick", function()
		Update(cb:GetChecked())
	end)

	-- Reset callback
	EventRegistry:RegisterCallback(ADDON_NAME .. ".OnReset", function()
		Update(self.defaults[option])
	end, cb)

	return cb
end

local function ShowColorPicker(option, label, parent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetText(label)
	btn:SetWidth(200)

	local function UpdateColor(r, g, b, a)
		OvershieldsReforged.db[option] = { r = r, g = g, b = b, a = a }
		btn:SetText(string.format("%s: %.2f, %.2f, %.2f", label, r, g, b))
	end

	btn:SetScript("OnClick", function()
		local color = OvershieldsReforged.db[option]
		local options = {
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame:GetColorAlpha()
				UpdateColor(r, g, b, a)
			end,
			opacityFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = ColorPickerFrame:GetColorAlpha()
				UpdateColor(r, g, b, a)
			end,
			cancelFunc = function(previousValues)
				UpdateColor(previousValues.r, previousValues.g, previousValues.b, previousValues.a)
			end,
			hasOpacity = true,
			opacity = color.a,
			r = color.r,
			g = color.g,
			b = color.b,
		}
		ColorPickerFrame:SetupColorPickerAndShow(options)
	end)

	-- Initialize button text
	local color = OvershieldsReforged.db[option]
	btn:SetText(string.format("%s: %.2f, %.2f, %.2f", label, color.r, color.g, color.b))

	-- Reset callback
	EventRegistry:RegisterCallback(ADDON_NAME .. ".OnReset", function()
		local default = OvershieldsReforged.defaults[option]
		UpdateColor(default.r, default.g, default.b, default.a)
	end, btn)

	return btn
end

function OvershieldsReforged:CreateDropdown(option, label, parent, values)
	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetText(label)
	text:SetPoint("LEFT", dropdown, "RIGHT", -10, 0)

	UIDropDownMenu_SetWidth(dropdown, 150)
	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for _, value in ipairs(values) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = value
			info.value = value
			info.func = function()
				OvershieldsReforged.db[option] = value
				UIDropDownMenu_SetText(dropdown, value)
			end
			info.checked = (OvershieldsReforged.db[option] == value)
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	UIDropDownMenu_SetText(dropdown, OvershieldsReforged.db[option])

	-- Reset callback
	EventRegistry:RegisterCallback(ADDON_NAME .. ".OnReset", function()
		local default = OvershieldsReforged.defaults[option]
		OvershieldsReforged.db[option] = default
		UIDropDownMenu_SetText(dropdown, default)
	end, dropdown)

	return dropdown
end

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

	-- Show tick when not full health checkbox
	local showTickCheckbox = self:CreateCheckbox("showTickWhenNotFullHealth", "Show Tick When Not Full Health",
		self.panel_main)
	showTickCheckbox:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", 0, -30)

	-- Absorb overlay color picker
	local colorPicker = ShowColorPicker("absorbOverlayColor", "Absorb Overlay Color", self.panel_main)
	colorPicker:SetPoint("TOPLEFT", showTickCheckbox, "BOTTOMLEFT", 0, -30)

	-- Absorb overlay blend mode dropdown
	local blendModeDropdown = self:CreateDropdown("absorbOverlayBlendMode", "Absorb Overlay Blend Mode", self.panel_main,
		{
			"DISABLE", "BLEND", "ALPHAKEY", "ADD", "MOD"
		})
	blendModeDropdown:SetPoint("TOPLEFT", colorPicker, "BOTTOMLEFT", 0, -30)

	-- Reset button
	local btn = CreateFrame("Button", nil, self.panel_main, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", blendModeDropdown, "BOTTOMLEFT", 0, -40)
	btn:SetText(RESET)
	btn:SetWidth(100)
	btn:SetScript("OnClick", function()
		OvershieldsReforgedDB = CopyTable(OvershieldsReforged.defaults)
		self.db               = OvershieldsReforgedDB
		EventRegistry:TriggerEvent(ADDON_NAME .. ".OnReset")
	end)

	RegisterCanvas(self.panel_main)
end
