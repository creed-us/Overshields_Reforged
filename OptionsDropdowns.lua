local _, ns = ...

-- LibSharedMedia-3.0 is optional; nil here simply means no extra media is offered.
local LSM = LibStub("LibSharedMedia-3.0", true)

--- Cached dropdown value tables; invalidated when LSM registers new media (see InvalidateDropdownCaches below).
local cachedTextureValues = nil
local cachedGlowTextureValues = nil

local function InvalidateDropdownCaches()
	cachedTextureValues = nil
	cachedGlowTextureValues = nil
end

if LSM then
	LSM.RegisterCallback("OvershieldsReforged", "LibSharedMedia_Registered", InvalidateDropdownCaches)
end

--- Lazy-builds the texture dropdown value table for bar/overlay selectors to catch late-registered LSM textures.
local function TextureDropdownValues()
	if cachedTextureValues then return cachedTextureValues end
	local values = {
		["Interface\\RaidFrame\\Shield-Overlay"] = "|TInterface\\RaidFrame\\Shield-Overlay:16:32|t Default Overlay",
		["Interface\\RaidFrame\\Shield-Fill"] = "|TInterface\\RaidFrame\\Shield-Fill:16:32|t Default Fill",
	}
	if LSM then
		for name, path in ns.pairs(LSM:HashTable("statusbar")) do
			values[path] = string.format("|T%s:16:32|t %s", path, name)
		end
	end
	cachedTextureValues = values
	return values
end

--- Formats a single dropdown option label, using an atlas icon prefix (|A) or a texture icon prefix (|T) as appropriate.
local function BuildGlowTextureOptionLabel(asset, displayName)
	if ns.IsAtlasAsset(asset) then
		return string.format("|A:%s:16:16|a %s", asset, displayName)
	end

	return string.format("|T%s:16:16|t %s", asset, displayName)
end

local function BuildGlowTextureValues(textureEntries)
	local values = {}
	for _, textureEntry in ns.ipairs(textureEntries) do
		local textureAsset = textureEntry[1]
		local displayName = textureEntry[2]
		values[textureAsset] = BuildGlowTextureOptionLabel(textureAsset, displayName)
	end
	return values
end

--- Lazy-builds the texture dropdown value table for the overAbsorb glow selector so that late-registered LSM spark/pip textures appear.
local function OverAbsorbGlowTextureDropdownValues()
	if cachedGlowTextureValues then return cachedGlowTextureValues end
	local values = BuildGlowTextureValues(ns.GlowTextureCatalog)
	if LSM then
		local mediaTypes = {
			"statusbar",
			"spark",
			"pip",
		}
		for _, mediaType in ns.ipairs(mediaTypes) do
			for name, path in ns.pairs(LSM:HashTable(mediaType) or {}) do
				local lowerName = name:lower()
				if lowerName:find("spark") or lowerName:find("pip") then
					values[path] = BuildGlowTextureOptionLabel(path, name)
				end
			end
		end
	end
	cachedGlowTextureValues = values
	return values
end

ns.TextureDropdownValues = TextureDropdownValues
ns.OverAbsorbGlowTextureDropdownValues = OverAbsorbGlowTextureDropdownValues
ns.InvalidateDropdownCaches = InvalidateDropdownCaches
