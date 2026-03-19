local _, ns = ...

function ns.GetUnitContext(unit)
	if not unit then
		return "other"
	end

	if ns.string_find(unit, "raidpet", 1, true) == 1
		or ns.string_find(unit, "partypet", 1, true) == 1 then
		return "pet"
	end

	if ns.string_find(unit, "raid", 1, true) == 1 then
		return "raid"
	end

	if ns.string_find(unit, "party", 1, true) == 1 then
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
		return ns.IsSettingEnabled(profile.enablePets)
	end

	if context == "raid" then
		return ns.IsSettingEnabled(profile.enableRaid)
	end

	if context == "party" then
		return ns.IsSettingEnabled(profile.enableParty)
	end

	return ns.IsSettingEnabled(profile.enableParty) or ns.IsSettingEnabled(profile.enableRaid)
end
