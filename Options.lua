local _, ns = ...
-- LibSharedMedia-3.0 optional
local LSM = LibStub("LibSharedMedia-3.0", true)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Used by both AceDB and the per-group reset buttons in the options UI.
local defaults = {
	profile = {
		enableParty = true,
		enableRaid = true,
		enablePets = false,
		-- Normal shield appearance (overAbsorbGlow not visible)
		absorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
		absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
		absorbBlendMode = "ADD",
		overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
		overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
		overlayBlendMode = "BLEND",
		-- OverAbsorb shield appearance (overAbsorbGlow visible)
		overAbsorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
		overAbsorbTexture = "Interface\\RaidFrame\\Shield-Fill",
		overAbsorbBlendMode = "ADD",
		overAbsorbOverlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
		overAbsorbOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
		overAbsorbOverlayBlendMode = "BLEND",
		-- OverAbsorb glow appearance
		overAbsorbGlowColor = { r = 1, g = 1, b = 1, a = 1 },
		overAbsorbGlowTexture = "Interface\\RaidFrame\\Shield-Overshield",
		overAbsorbGlowBlendMode = "ADD",
		-- Non-overshield anchor behavior
		anchorShieldToHealth = false,
		anchorToHealthTexture = false,
	},
}

function ns.IsSettingEnabled(value)
	return value ~= false
end

--- Callback invoked whenever appearance settings are modified.
-- Triggers update of appearance for all visible compact unit frames.
local pendingAppearanceRefreshToken = 0

local function OnAppearanceChanged()
	local delay = 0.01 -- >0 to prevent perf. tank while changing appearance in options
	if not C_Timer or not C_Timer.After then
		ns.UpdateAllFrameAppearances()
		return
	end

	pendingAppearanceRefreshToken = pendingAppearanceRefreshToken + 1
	local refreshToken = pendingAppearanceRefreshToken

	C_Timer.After(delay, function()
		if refreshToken ~= pendingAppearanceRefreshToken then
			return
		end
		ns.UpdateAllFrameAppearances()
	end)
end


--- Static blend mode map.
local BLEND_MODES = {
	["ADD"] = "Add",
	["ALPHAKEY"] = "Alphakey",
	["BLEND"] = "Blend",
	["DISABLE"] = "Disable",
	["MOD"] = "Mod",
}

--- Lazily builds the texture dropdown value table for bar/overlay selectors to catch late-registered LSM textures.
local cachedTextureValues = nil
local cachedGlowTextureValues = nil

local function InvalidateDropdownCaches()
	cachedTextureValues = nil
	cachedGlowTextureValues = nil
end

if LSM then
	LSM.RegisterCallback("OvershieldsReforged", "LibSharedMedia_Registered", InvalidateDropdownCaches)
end

local function TextureDropdownValues()
	if cachedTextureValues then return cachedTextureValues end
	local values = {
		["Interface\\RaidFrame\\Shield-Overlay"] = "|TInterface\\RaidFrame\\Shield-Overlay:16:32|t Default Overlay",
		["Interface\\RaidFrame\\Shield-Fill"] = "|TInterface\\RaidFrame\\Shield-Fill:16:32|t Default Fill",
	}
	if LSM then
		for name, path in pairs(LSM:HashTable("statusbar")) do
			values[path] = string.format("|T%s:16:32|t %s", path, name)
		end
	end
	cachedTextureValues = values
	return values
end

--- Lazy builds the texture dropdown value table for the overAbsorb glow selector so that late-registered LSM spark/pip textures appear.
local function BuildGlowTextureOptionLabel(asset, displayName)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset) then
		return string.format("|A:%s:16:16|a %s", asset, displayName)
	end

	return string.format("|T%s:16:16|t %s", asset, displayName)
end

local function BuildGlowTextureValues(textureEntries)
	local values = {}
	for _, textureEntry in ipairs(textureEntries) do
		local textureAsset = textureEntry[1]
		local displayName = textureEntry[2]
		if textureAsset ~= "__PLACEHOLDER" then
			values[textureAsset] = BuildGlowTextureOptionLabel(textureAsset, displayName)
		end
	end
	return values
end

local function OverAbsorbGlowTextureDropdownValues()
	if cachedGlowTextureValues then return cachedGlowTextureValues end
	local values = BuildGlowTextureValues({
		{ "Interface\\RaidFrame\\Shield-Overshield", "Default Glow" },
		{ "Interface\\CastingBar\\UI-CastingBar-Spark", "Cast Bar Spark" },
		{ "Interface\\Cooldown\\star4", "Star4" },
		{ "Interface\\Cooldown\\starburst", "Starburst" },
		{ "Warlock-Shard-Spark", "Warlock Spark" },
		{ "cosmic-bar-spark", "Cosmic Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Kyrian", "Kyrian Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Glow-Kyrian", "Kyrian Glow Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Necrolord", "Necrolord Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Glow-Necrolord", "Necrolord Glow Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Nightfae", "Night Fae Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Glow-Nightfae", "Night Fae Glow Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Venthyr", "Venthyr Spark" },
		{ "CovenantSanctum-Reservoir-Spark-Glow-Venthyr", "Venthyr Glow Spark" },
		{ "UI-Frame-DastardlyDuos-ProgressBar-Spark", "Dastardly Duos Spark" },
		{ "Garr_MissionFX-Glow", "Mission Glow" },
		{ "Garr_MissionFX-Lines", "Mission Lines" },
		{ "GenericWidgetBar-Spark-Line", "Widget Spark Line" },
		{ "gradientbar-marker-diamond", "Diamond Marker" },
		{ "gradientbar-marker-plain", "Plain Marker" },
		{ "gradientbar-Spark-arrows", "Spark Arrows" },
		{ "islands-queue-progressbar-spark", "Islands Queue Spark" },
		{ "Legionfall_BarSpark", "Legionfall Spark" },
		{ "Mage-ArcaneCharge-Spark", "Arcane Charge Spark" },
		{ "Mage-ArcaneCharge-SmallSpark", "Small Arcane Spark" },
		{ "objectivewidget-bar-spark-left", "Objective Left Spark" },
		{ "objectivewidget-bar-spark-neutral", "Objective Neutral Spark" },
		{ "objectivewidget-bar-spark-right", "Objective Right Spark" },
		{ "Insanity-Spark", "Insanity Spark" },
		{ "honorsystem-bar-spark", "Honor Bar Spark" },
		{ "UI-World-Quest-spark", "World Quest Spark" },
		{ "stormcapture-spark-air", "Air Capture Spark" },
		{ "stormcapture-spark-earth", "Earth Capture Spark" },
		{ "stormcapture-spark-water", "Water Capture Spark" },
		{ "ui-castingbar-pip-red", "Red Pip" },
		{ "cast-empowered-pipflare", "Empowered Pip Flare" },
		{ "UI-Frame-Bar-Spark", "Frame Bar Spark" },
		{ "plunderstorm-stormbar-spark", "Plunderstorm Spark" },
		{ "BastionAnima-Horizontal-Spark", "Bastion Anima Spark" },
		{ "widgetstatusbar-spark", "Status Bar Spark" },
		{ "machinebar-spark", "Machine Bar Spark" },
		{ "worldstate-capturebar-spark-boss", "Boss Capture Spark" },
		{ "worldstate-capturebar-spark-factions", "Faction Capture Spark" },
		{ "worldstate-capturebar-spark-lfd", "LFD Capture Spark" },
		{ "worldstate-capturebar-spark-target", "Target Capture Spark" },
		{ "worldstate-capturebar-spark-white", "White Capture Spark" },
		{ "worldstate-capturebar-spark-bastionarmor", "Bastion Armor Spark" },
		{ "worldstate-capturebar-spark-neutral-bastionarmor", "Neutral Bastion Spark" },
		{ "worldstate-capturebar-spark-casualformal-embercourt", "Ember Court Spark" },
		{ "XPBarAnim-OrangeSpark", "Orange XP Spark" },
	})
	if LSM then
		local mediaTypes = {
			"statusbar",
			"spark",
			"pip",
		}
		for _, mediaType in ipairs(mediaTypes) do
			for name, path in pairs(LSM:HashTable(mediaType) or {}) do
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

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", defaults)

	-- Clean up caches and re-apply appearance when the active profile changes.
	local function OnProfileChanged()
		if ns.ReleaseAllBars then
			ns.ReleaseAllBars()
		end
		if ns.WipeStyleCache then
			ns.WipeStyleCache()
		end
		if ns.UpdateAllFrameAppearances then
			ns.UpdateAllFrameAppearances()
		end
	end

	self.db.RegisterCallback(self, "OnProfileChanged", OnProfileChanged)
	self.db.RegisterCallback(self, "OnProfileCopied", OnProfileChanged)
	self.db.RegisterCallback(self, "OnProfileReset", OnProfileChanged)
end

--- Sets up the Ace3 options interface and registers it.
function OvershieldsReforged:SetupOptions()
	--- Factory: builds a standard color/texture/blendMode/reset appearance group.
	-- @param name          Display name for the group header
	-- @param order         Order index within the parent args table
	-- @param colorKey      db key for the color table (e.g. "absorbColor")
	-- @param textureKey    db key for the texture path string
	-- @param blendModeKey  db key for the blend mode string
	-- @param textureValuesFn  Function returning the texture dropdown values table
	local function MakeAppearanceGroup(name, order, colorKey, textureKey, blendModeKey, textureValuesFn)
		return {
			type = "group",
			name = name,
			order = order,
			inline = true,
			args = {
				color = {
					type = "color",
					name = "Color",
					order = 0,
					width = 0.5,
					hasAlpha = true,
					get = function()
						local c = self.db.profile[colorKey]
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						self.db.profile[colorKey] = { r = r, g = g, b = b, a = a }
						OnAppearanceChanged()
					end,
				},
				texture = {
					type = "select",
					name = "Texture",
					order = 1,
					values = textureValuesFn,
					get = function() return self.db.profile[textureKey] end,
					set = function(_, value)
						self.db.profile[textureKey] = value
						OnAppearanceChanged()
					end,
				},
				blendMode = {
					type = "select",
					name = "Blend Mode",
					order = 2,
					width = 0.5,
					values = BLEND_MODES,
					get = function() return self.db.profile[blendModeKey] end,
					set = function(_, value)
						self.db.profile[blendModeKey] = value
						OnAppearanceChanged()
					end,
				},
				reset = {
					type = "execute",
					name = "|TInterface\\Buttons\\UI-RefreshButton:20:20|tReset",
					desc = "Reset this group to the default configuration.",
					order = -1,
					width = 0.5,
					func = function()
						local p = defaults.profile
						self.db.profile[colorKey]     = p[colorKey]
						self.db.profile[textureKey]   = p[textureKey]
						self.db.profile[blendModeKey] = p[blendModeKey]
						OnAppearanceChanged()
					end,
				},
			},
		}
	end

	local options = {
		type = "group",
		name = "Overshields Reforged",
		childGroups = "tab",
		args = {
			-- Normal shield appearance (overAbsorbGlow not visible)
			absorbHeader = {
				type = "group",
				name = "Shields",
				desc = "These settings are used while a unit's current health and combined shields *do not* exceed the unit's maximum health.",
				order = 0,
				args = {
					absorbGroup  = MakeAppearanceGroup("Shield Bar",         1, "absorbColor",  "absorbTexture",  "absorbBlendMode",  TextureDropdownValues),
					overlayGroup = MakeAppearanceGroup("Shield Bar Overlay", 2, "overlayColor", "overlayTexture", "overlayBlendMode", TextureDropdownValues),
				},
			},
			-- OverAbsorb shield appearance (overAbsorbGlow visible)
			overAbsorbHeader = {
				type = "group",
				name = "Overshields",
				desc = "These settings are used while a unit's current health and combined shields exceed the unit's maximum health.",
				order = 1,
				args = {
					overAbsorbGroup        = MakeAppearanceGroup("Overshield Bar",         0, "overAbsorbColor",        "overAbsorbTexture",        "overAbsorbBlendMode",        TextureDropdownValues),
					overAbsorbOverlayGroup = MakeAppearanceGroup("Overshield Bar Overlay", 1, "overAbsorbOverlayColor", "overAbsorbOverlayTexture", "overAbsorbOverlayBlendMode", TextureDropdownValues),
					overAbsorbGlowGroup    = MakeAppearanceGroup("Overshield Glow",        2, "overAbsorbGlowColor",    "overAbsorbGlowTexture",    "overAbsorbGlowBlendMode",    OverAbsorbGlowTextureDropdownValues),
				},
			},
			behavior = {
				type = "group",
				name = "Behavior",
				order = 2,
				args = {
					modifyHeader = {
						type = "header",
						name = "Modify Compact Frames",
						order = 0,
					},
					enableParty = {
						type = "toggle",
						name = "Party",
						desc = "While enabled, raid-style party frames will be modified.",
						order = 1,
						get = function() return self.db.profile.enableParty ~= false end,
						set = function(_, value)
							self.db.profile.enableParty = value
							OnAppearanceChanged()
						end,
					},
					enableRaid = {
						type = "toggle",
						name = "Raid",
						desc = "While enabled, raid frames will be modified.",
						order = 2,
						get = function() return self.db.profile.enableRaid ~= false end,
						set = function(_, value)
							self.db.profile.enableRaid = value
							OnAppearanceChanged()
						end,
					},
					enablePets = {
						type = "toggle",
						name = "Pets",
						desc = "While enabled, raid-style pet frames will be modified.",
						order = 3,
						get = function() return self.db.profile.enablePets ~= false end,
						set = function(_, value)
							self.db.profile.enablePets = value
							OnAppearanceChanged()
						end,
					},
					anchorHeader = {
						type = "header",
						name = "Shield Positioning",
						order = 10,
					},
					anchorShieldToHealth = {
						type = "toggle",
						name = "Dynamic Anchoring",
						desc = "Switch anchoring behavior depending on whether a unit is overshielded.",
						descStyle = "inline",
						order = 11,
						width = "full",
						get = function() return self.db.profile.anchorShieldToHealth end,
						set = function(_, value)
							self.db.profile.anchorShieldToHealth = value
							OnAppearanceChanged()
						end,
					},
					anchorToHealthTexture = {
						type = "toggle",
						name = "Fill Missing Health",
						desc = "Shields will appear to fill missing health while a unit is not overshielded. This display method is not precise in determining actual shielding value while a unit does not have overshields.",
						descStyle = "inline",
						order = 12,
						width = "full",
						hidden = function() return not self.db.profile.anchorShieldToHealth end,
						get = function()
							if not self.db.profile.anchorShieldToHealth then
								return false
							end

							return self.db.profile.anchorToHealthTexture
						end,
						set = function(_, value)
							self.db.profile.anchorToHealthTexture = value
							OnAppearanceChanged()
						end,
					},
				},
			},
		},
	}

	-- Ace3 Profile management
	local AceDBOptions = LibStub("AceDBOptions-3.0")
	if AceDBOptions then
		options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
	end

	AceConfig:RegisterOptionsTable("Overshields Reforged", options)
	AceConfigDialog:AddToBlizOptions("Overshields Reforged", "Overshields Reforged")
end

--- Opens the addon options panel.
function OvershieldsReforged:OpenOptions()
	AceConfigDialog:Open("Overshields Reforged")
end
