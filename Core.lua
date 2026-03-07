local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

local string_sub = string.sub

local function IsSettingEnabled(value)
	return value ~= false
end
ns.IsSettingEnabled = IsSettingEnabled

function OvershieldsReforged:OnInitialize()
	self:InitializeDatabase()
	self:SetupOptions()
end

function OvershieldsReforged:OnEnable()
	-- Register chat commands via AceConsole.
	self:RegisterChatCommand("overshieldsreforged", "HandleSlashCommand")
	self:RegisterChatCommand("osr", "HandleSlashCommand")

	-- Hook Bliz's heal-prediction.
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		--@alpha@
		if ns.Debug then ns.Debug.Inc("hookFires") end
		--@end-alpha@
		ns.QueueCompactUnitFrameUpdate(frame)
	end)
end

--- Returns whether the addon is enabled for a unit context.
-- @param unit Unit token (e.g., "party1", "raid3", "partypet1")
-- @return boolean true when updates should run for this unit
function OvershieldsReforged:IsUnitContextEnabled(unit)
	local profile = self.db and self.db.profile
	if not profile or not unit then
		return false
	end

	local frameTypePrefix = string_sub(unit, 1, 4)

	if frameTypePrefix == "raid" then
		-- "raidpet" starts with "raid" too, so check for pet first
		if string_sub(unit, 5, 7) == "pet" then
			return IsSettingEnabled(profile.enablePets)
		end
		return IsSettingEnabled(profile.enableRaid)
	end

	if frameTypePrefix == "part" then
		-- "partypet" starts with "part" too
		if string_sub(unit, 6, 8) == "pet" then
			return IsSettingEnabled(profile.enablePets)
		end
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
