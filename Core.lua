local ADDON_NAME, ns = ...
ns.absorbGlowTickOffset = -7

-- namespace frame
OvershieldsReforged = CreateFrame("Frame")

-- event dispatcher
function OvershieldsReforged:OnEvent(event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

OvershieldsReforged:SetScript("OnEvent", OvershieldsReforged.OnEvent)
OvershieldsReforged:RegisterEvent("ADDON_LOADED")

-- ADDON_LOADED: initialize SavedVariables, apply defaults, hook into Blizzard, and build options
function OvershieldsReforged:ADDON_LOADED(_, addonName)
	if addonName ~= ADDON_NAME then return end

	OvershieldsReforgedDB = OvershieldsReforgedDB or {}
	self.db = OvershieldsReforgedDB

	self.defaults = self.defaults or {}

	-- merge missing defaults
	for key, value in pairs(self.defaults) do
		if self.db[key] == nil then
			self.db[key] = value
		end
	end

	-- hook Blizzard's heal-prediction functions
	hooksecurefunc("UnitFrameHealPredictionBars_Update", function(frame)
		ns.HandleUnitFrameUpdate(frame)
	end)
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		ns.HandleCompactUnitFrame_Update(frame)
	end)

	-- build options UI (Options.lua)
	self:InitializeOptions()

	-- no longer need the loader
	self:UnregisterEvent("ADDON_LOADED")
end

-- slash command to open the options
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function()
	Settings.OpenToCategory(OvershieldsReforged.panel_main.name)
end
