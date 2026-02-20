local ADDON_NAME, ns = ...
-- LibSharedMedia-3.0 optional
local LSM = LibStub("LibSharedMedia-3.0", true)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Used by both AceDB and the per-group reset buttons in the options UI.
local defaults = {
	profile = {
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
local function OnAppearanceChanged()
	ns.UpdateAllFrameAppearances()
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

--- Lazy builds the texture dropdown value table for the overAbsorb glow selector so that late-registered LSM spark textures appear.
local function OverAbsorbGlowTextureDropdownValues()
	local values = {
		["Interface\\RaidFrame\\Shield-Overshield"] = "|TInterface\\RaidFrame\\Shield-Overshield:16:16|t Default Glow",
		["Interface\\CastingBar\\UI-CastingBar-Spark"] = "|TInterface\\CastingBar\\UI-CastingBar-Spark:16:16|t CastingBar-Spark",
		["Interface\\Cooldown\\star4"] = "|TInterface\\Cooldown\\star4:16:16|t Star4",
		["Interface\\Cooldown\\starburst"] = "|TInterface\\Cooldown\\starburst:16:16|t Starburst",
		["Interface\\Artifacts\\Blizzard_Spark"] = "|TInterface\\Artifacts\\Blizzard_Spark:16:16|t Blizzard Spark",
		["Interface\\Garrison\\GarrMission_EncounterBar-Spark"] = "|TInterface\\Garrison\\GarrMission_EncounterBar-Spark:16:16|t GarrMission Spark",
		["Interface\\InsanityBar\\Insanity-Spark"] = "|TInterface\\InsanityBar\\Insanity-Spark:16:16|t Insanity Spark",
		["Interface\\Legionfall\\Legionfall_BarSpark"] = "|TInterface\\Legionfall\\Legionfall_BarSpark:16:16|t Legionfall Spark",
		["Interface\\XPBarAnim\\XPBarAnim-OrangeSpark"] = "|TInterface\\XPBarAnim\\XPBarAnim-OrangeSpark:16:16|t XPBar Orange Spark",
		["Interface\\BonusObjective\\bonusobjective-bar-spark"] = "|TInterface\\BonusObjective\\bonusobjective-bar-spark:16:16|t Bonus Objective Spark",
		["Interface\\HonorFrame\\honorsystem-bar-spark"] = "|TInterface\\HonorFrame\\honorsystem-bar-spark:16:16|t Honor System Spark",
	}
	if LSM then
		for name, path in pairs(LSM:HashTable("statusbar")) do
			if name:lower():find("spark") then
				values[path] = string.format("|T%s:16:16|t %s", path, name)
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
