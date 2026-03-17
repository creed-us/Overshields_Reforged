local _, ns = ...

local string_find = string.find

local function IsEnabled(value)
	return value ~= false
end

function ns.GetUnitContext(unit)
	if not unit then
		return "other"
	end

	if string_find(unit, "raidpet", 1, true) == 1
		or string_find(unit, "partypet", 1, true) == 1 then
		return "pet"
	end

	if string_find(unit, "raid", 1, true) == 1 then
		return "raid"
	end

	if string_find(unit, "party", 1, true) == 1 then
		return "party"
	end

	return "other"
end

function ns.IsUnitContextEnabledFromProfile(profile, unit)
	if not profile or not unit then
		return false
	end

	local context = ns.GetUnitContext(unit)
	if context == "pet" then
		return IsEnabled(profile.enablePets)
	end

	if context == "raid" then
		return IsEnabled(profile.enableRaid)
	end

	if context == "party" then
		return IsEnabled(profile.enableParty)
	end

	return IsEnabled(profile.enableParty) or IsEnabled(profile.enableRaid)
end
