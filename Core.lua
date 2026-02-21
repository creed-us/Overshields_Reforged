local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

local function IsSettingEnabled(value)
	return value ~= false
end

function OvershieldsReforged:OnInitialize()
	self:InitializeDatabase()
	self:SetupOptions()
	self:RefreshPerformanceDiagnosticsState()
end

function OvershieldsReforged:OnEnable()
    -- Register chat commands via AceConsole.
    self:RegisterChatCommand("overshieldsreforged", "HandleSlashCommand")
    self:RegisterChatCommand("osr", "HandleSlashCommand")

    -- Hook Bliz's heal-prediction.
    hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
        ns.QueueCompactUnitFrameUpdate(frame)
    end)
end

--- Returns whether the addon is enabled for a unit context.
-- @param unit Unit token (e.g., "party1", "raid3", "partypet1")
-- @return boolean true when updates should run for this unit
function OvershieldsReforged:IsUnitContextEnabled(unit)
	local profile = self.db and self.db.profile
	if not profile then
		return false
	end

	if not unit then
		return false
	end

	if string.find(unit, "pet", 1, true) then
		return IsSettingEnabled(profile.enablePets)
	end

	if string.find(unit, "raid", 1, true) then
		return IsSettingEnabled(profile.enableRaid)
	end

	if string.find(unit, "party", 1, true) then
		return IsSettingEnabled(profile.enableParty)
	end

	return IsSettingEnabled(profile.enableParty) or IsSettingEnabled(profile.enableRaid)
end

--- Returns whether the addon should run for the provided compact unit frame.
-- @param frame Compact unit frame
-- @return boolean
function OvershieldsReforged:IsFrameContextEnabled(frame)
	if not frame then
		return false
	end
	return self:IsUnitContextEnabled(frame.displayedUnit)
end
