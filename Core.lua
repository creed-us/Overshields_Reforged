local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")

OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

--[[TODO: find a way to check if the "Display Incoming Heals" option is enabled in the game settings that actually works
local function CheckIncomingHealsOption()
	local scriptErrorsEnabled = GetCVar("scriptErrors") == "1"
	local showingPredictedHealth = GetCVar("predictedHealth") ~= "1"
	if scriptErrorsEnabled and not showingPredictedHealth then
		print("|cffff0000[Overshields Reforged]|r Warning: The 'Display Incoming Heals' option is disabled. This addon requires it to function properly. Please enable it in Game Menu > Options > Interface > Raid Frames > Display Incoming Heals. It is recommended to disable this addon if you do not want to see extra shield bars.")
	end
end]]

function OvershieldsReforged:OnInitialize()
	-- Initialize database and options
	self:InitializeDatabase()
	self:SetupOptions()

	-- Hook Blizzard's heal-prediction functions
	hooksecurefunc("UnitFrameHealPredictionBars_Update", function(frame)
		ns.HandleUnitFrameUpdate(frame)
	end)
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		ns.HandleCompactUnitFrame_Update(frame)
	end)
end

--[[TODO: line 6 cont. (working incoming heal opt. check)
function OvershieldsReforged:OnEnable()
	-- Periodically check the "Display Incoming Heals" option
	self.incomingHealsCheckTicker = C_Timer.NewTicker(30, CheckIncomingHealsOption)
end]]

function OvershieldsReforged:OnDisable()
	-- Cancel the periodic check when the addon is disabled
	if self.incomingHealsCheckTicker then
		self.incomingHealsCheckTicker:Cancel()
		self.incomingHealsCheckTicker = nil
	end
end

-- Slash command handler
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function(input)
	local args = { strsplit(" ", input) }
	local command = args[1] and args[1]:lower() or nil

	if command == "version" or command == "v" then
		print("Overshields Reforged version: " .. C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
	elseif command == "options" or command == "o" then
        OvershieldsReforged:OpenOptions()
	elseif command == "reset" or command == "r" then
		StaticPopupDialogs["OVERSHIELDS_REFORGED_RESET"] = {
			text = "This will reset all Overshields Reforged settings to default and reload the UI. Proceed?",
			button1 = ACCEPT,
			button2 = CANCEL,
			OnAccept = function()
				OvershieldsReforgedDB = nil
				ReloadUI()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("OVERSHIELDS_REFORGED_RESET")
	else
		print("Usage:")
		print("/osr version (v) - Display the addon version.")
		print("/osr options (o) - Open the addon options.")
		print("/osr reset (r) - Reset all settings to default and reload the UI.")
	end
end
