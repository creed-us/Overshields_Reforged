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
	},
}

--- Callback invoked whenever appearance settings are modified.
-- Triggers update of appearance for all visible compact unit frames.
local pendingAppearanceRefreshToken = 0

local function OnAppearanceChanged()
	local delay = 0.01 -- >0 to prevent perf. tank while changing appearance in options
	if delay <= 0 or not C_Timer or not C_Timer.After then
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

--- Lazily uilds the texture dropdown value table for bar/overlay selectors to catch late-registered LSM textures.
local function TextureDropdownValues()
	local values = {
		["Interface\\RaidFrame\\Shield-Overlay"] = "|TInterface\\RaidFrame\\Shield-Overlay:16:32|t Default Overlay",
		["Interface\\RaidFrame\\Shield-Fill"] = "|TInterface\\RaidFrame\\Shield-Fill:16:32|t Default Fill",
	}
	if LSM then
		for name, path in pairs(LSM:HashTable("statusbar")) do
			values[path] = string.format("|T%s:16:32|t %s", path, name)
		end
	end
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
	return values
end

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", defaults)
end

--- Sets up the Ace3 options interface and registers it.
function OvershieldsReforged:SetupOptions()
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
					--- Shield Bar
					absorbGroup = {
						type = "group",
						name = "Shield Bar",
						order = 1,
						inline = false,
						args = {
							color = {
								type = "color",
								name = "Color",
								order = 0,
								hasAlpha = true,
								get = function()
									local c = self.db.profile.absorbColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.absorbColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 1,
								values = TextureDropdownValues,
								get = function() return self.db.profile.absorbTexture end,
								set = function(_, value)
									self.db.profile.absorbTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 2,
								values = BLEND_MODES,
								get = function() return self.db.profile.absorbBlendMode end,
								set = function(_, value)
									self.db.profile.absorbBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset this group to the default configuration.",
								order = -1,
								func = function()
									local p = defaults.profile
									self.db.profile.absorbColor = p.absorbColor
									self.db.profile.absorbTexture = p.absorbTexture
									self.db.profile.absorbBlendMode = p.absorbBlendMode
									OnAppearanceChanged()
								end,
							},
						},
					},
					--- Shield Bar Overlay
					overlayGroup = {
						type = "group",
						name = "Shield Bar Overlay",
						order = 2,
						inline = false,
						args = {
							color = {
								type = "color",
								name = "Color",
								order = 0,
								hasAlpha = true,
								get = function()
									local c = self.db.profile.overlayColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.overlayColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 1,
								values = TextureDropdownValues,
								get = function() return self.db.profile.overlayTexture end,
								set = function(_, value)
									self.db.profile.overlayTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 2,
								values = BLEND_MODES,
								get = function() return self.db.profile.overlayBlendMode end,
								set = function(_, value)
									self.db.profile.overlayBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset this group to the default configuration.",
								order = -1,
								func = function()
									local p = defaults.profile
									self.db.profile.overlayColor = p.overlayColor
									self.db.profile.overlayTexture = p.overlayTexture
									self.db.profile.overlayBlendMode = p.overlayBlendMode
									OnAppearanceChanged()
								end,
							},
						},
					},
				},
			},
			-- OverAbsorb shield appearance (overAbsorbGlow visible)
			overAbsorbHeader = {
				type = "group",
				name = "Overshields",
				desc = "These settings are used while a unit's current health and combined shields exceed the unit's maximum health.",
				order = 1,
				args = {
					--- Overshield Bar
					overAbsorbGroup = {
						type = "group",
						name = "Overshield Bar",
						order = 0,
						inline = false,
						args = {
							color = {
								type = "color",
								name = "Color",
								order = 0,
								hasAlpha = true,
								get = function()
									local c = self.db.profile.overAbsorbColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.overAbsorbColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 1,
								values = TextureDropdownValues,
								get = function() return self.db.profile.overAbsorbTexture end,
								set = function(_, value)
									self.db.profile.overAbsorbTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 2,
								values = BLEND_MODES,
								get = function() return self.db.profile.overAbsorbBlendMode end,
								set = function(_, value)
									self.db.profile.overAbsorbBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset this group to the default configuration.",
								order = -1,
								func = function()
									local p = defaults.profile
									self.db.profile.overAbsorbColor = p.overAbsorbColor
									self.db.profile.overAbsorbTexture = p.overAbsorbTexture
									self.db.profile.overAbsorbBlendMode = p.overAbsorbBlendMode
									OnAppearanceChanged()
								end,
							},
						},
					},
					--- Overshield Bar Overlay
					overAbsorbOverlayGroup = {
						type = "group",
						name = "Overshield Bar Overlay",
						order = 1,
						inline = false,
						args = {
							color = {
								type = "color",
								name = "Color",
								order = 0,
								hasAlpha = true,
								get = function()
									local c = self.db.profile.overAbsorbOverlayColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.overAbsorbOverlayColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 1,
								values = TextureDropdownValues,
								get = function() return self.db.profile.overAbsorbOverlayTexture end,
								set = function(_, value)
									self.db.profile.overAbsorbOverlayTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 2,
								values = BLEND_MODES,
								get = function() return self.db.profile.overAbsorbOverlayBlendMode end,
								set = function(_, value)
									self.db.profile.overAbsorbOverlayBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset this group to the default configuration.",
								order = -1,
								func = function()
									local p = defaults.profile
									self.db.profile.overAbsorbOverlayColor = p.overAbsorbOverlayColor
									self.db.profile.overAbsorbOverlayTexture = p.overAbsorbOverlayTexture
									self.db.profile.overAbsorbOverlayBlendMode = p.overAbsorbOverlayBlendMode
									OnAppearanceChanged()
								end,
							},
						},
					},
					--- Overshield Glow
					overAbsorbGlowGroup = {
						type = "group",
						name = "Overshield Glow",
						order = 2,
						inline = false,
						args = {
							color = {
								type = "color",
								name = "Color",
								order = 0,
								hasAlpha = true,
								get = function()
									local c = self.db.profile.overAbsorbGlowColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.overAbsorbGlowColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 1,
								values = OverAbsorbGlowTextureDropdownValues,
								get = function() return self.db.profile.overAbsorbGlowTexture end,
								set = function(_, value)
									self.db.profile.overAbsorbGlowTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 2,
								values = BLEND_MODES,
								get = function() return self.db.profile.overAbsorbGlowBlendMode end,
								set = function(_, value)
									self.db.profile.overAbsorbGlowBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset this group to the default configuration.",
								order = -1,
								func = function()
									local p = defaults.profile
									self.db.profile.overAbsorbGlowColor = p.overAbsorbGlowColor
									self.db.profile.overAbsorbGlowTexture = p.overAbsorbGlowTexture
									self.db.profile.overAbsorbGlowBlendMode = p.overAbsorbGlowBlendMode
									OnAppearanceChanged()
								end,
							},
						},
					},
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
						order = 3,
						get = function() return self.db.profile.enablePets ~= false end,
						set = function(_, value)
							self.db.profile.enablePets = value
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
