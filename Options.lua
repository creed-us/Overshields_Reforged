local ADDON_NAME, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

--- Callback invoked whenever appearance settings are modified.
-- Triggers update of appearance for all visible compact unit frames.
local function OnAppearanceChanged()
    ns.UpdateAllFrameAppearances()
end

local defaultOptions = {
	-- Normal shield appearance (when overAbsorbGlow is not visible)
	absorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
    absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
	absorbBlendMode = "ADD",
	overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
    overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
	overlayBlendMode = "BLEND",
	-- OverAbsorb shield appearance (when overAbsorbGlow is visible)
	overAbsorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
    overAbsorbTexture = "Interface\\RaidFrame\\Shield-Fill",
	overAbsorbBlendMode = "ADD",
	overAbsorbOverlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
    overAbsorbOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
    overAbsorbOverlayBlendMode = "BLEND",
    -- OverAbsorb Glow appearance
    overAbsorbGlowColor = { r = 1, g = 1, b = 1, a = 1 },
    overAbsorbGlowTexture = "Interface\\RaidFrame\\Shield-Overshield",
	overAbsorbGlowBlendMode = "ADD",
	-- Health bar appearance (non-overabsorb)
	healthBarColor = { r = 1, g = 1, b = 1, a = 1 },
	healthBarTexture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
	healthBarBlendMode = "BLEND",
	healthBarUseClassColor = true,
	-- Health bar appearance (overabsorb)
	overAbsorbHealthBarColor = { r = 1, g = 1, b = 1, a = 1 },
	overAbsorbHealthBarTexture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
	overAbsorbHealthBarBlendMode = "BLEND",
	overAbsorbHealthBarUseClassColor = true,
}

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
            -- Normal shield appearance
			absorbColor = defaultOptions.absorbColor,
            absorbTexture = defaultOptions.absorbTexture,
			absorbBlendMode = defaultOptions.absorbBlendMode,
			overlayColor = defaultOptions.overlayColor,
            overlayTexture = defaultOptions.overlayTexture,
			overlayBlendMode = defaultOptions.overlayBlendMode,
			-- OverAbsorb shield appearance
			overAbsorbColor = defaultOptions.overAbsorbColor,
            overAbsorbTexture = defaultOptions.overAbsorbTexture,
			overAbsorbBlendMode = defaultOptions.overAbsorbBlendMode,
			overAbsorbOverlayColor = defaultOptions.overAbsorbOverlayColor,
            overAbsorbOverlayTexture = defaultOptions.overAbsorbOverlayTexture,
            overAbsorbOverlayBlendMode = defaultOptions.overAbsorbOverlayBlendMode,
            -- OverAbsorb Glow appearance
			overAbsorbGlowColor = defaultOptions.overAbsorbGlowColor,
			overAbsorbGlowTexture = defaultOptions.overAbsorbGlowTexture,
			overAbsorbGlowBlendMode = defaultOptions.overAbsorbGlowBlendMode,
			-- Health bar appearance (non-overabsorb)
			healthBarColor = defaultOptions.healthBarColor,
			healthBarTexture = defaultOptions.healthBarTexture,
			healthBarBlendMode = defaultOptions.healthBarBlendMode,
			healthBarUseClassColor = defaultOptions.healthBarUseClassColor,
			-- Health bar appearance (overabsorb)
			overAbsorbHealthBarColor = defaultOptions.overAbsorbHealthBarColor,
			overAbsorbHealthBarTexture = defaultOptions.overAbsorbHealthBarTexture,
			overAbsorbHealthBarBlendMode = defaultOptions.overAbsorbHealthBarBlendMode,
			overAbsorbHealthBarUseClassColor = defaultOptions.overAbsorbHealthBarUseClassColor,
		},
	})
end

--- Sets up the Ace3 options interface and registers it with Blizzard's settings.
function OvershieldsReforged:SetupOptions()
    local function TextureDropdownValues()
        local values = {
            ["Interface\\RaidFrame\\Shield-Overlay"] = "|TInterface\\RaidFrame\\Shield-Overlay:16:32|t Default Overlay",
            ["Interface\\RaidFrame\\Shield-Fill"] = "|TInterface\\RaidFrame\\Shield-Fill:16:32|t Default Fill",
        }
        for name, path in pairs(LSM:HashTable("statusbar")) do
            values[path] = string.format("|T%s:16:32|t %s", path, name)
        end
        return values
    end

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
        for name, path in pairs(LSM:HashTable("statusbar")) do
            if name:lower():find("spark") then
                values[path] = string.format("|T%s:16:16|t %s", path, name)
            end
        end
        return values
    end

	local function BlendModeDropdownValues()
        local values = {
            ["ADD"] = "Add",
			["ALPHAKEY"] = "Alphakey",
			["BLEND"] = "Blend",
            ["DISABLE"] = "Disable",
			["MOD"] = "Mod"
        }
		return values
	end

	local options = {
		type = "group",
        name = "Overshields Reforged",
		childGroups = "tab",
        args = {
			-- Non-OverAbsorb Shield Group
			absorbHeader = {
				type = "group",
				name = "Shields",
				desc = "These settings are used while a unit's current health and combined shields *do not* exceed the unit's maximum health.",
                order = 0,
                args = {
					--- Non-OverAbsorb Shield Bar
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
								values = TextureDropdownValues(),
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
								values = BlendModeDropdownValues(),
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
									self.db.profile.absorbColor = defaultOptions.absorbColor
									self.db.profile.absorbTexture = defaultOptions.absorbTexture
									self.db.profile.absorbBlendMode = defaultOptions.absorbBlendMode

									OnAppearanceChanged()
								end,
							},
						},
					},
					--- Non-OverAbsorb Shield Bar Overlay
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
								values = TextureDropdownValues(),
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
								values = BlendModeDropdownValues(),
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
									self.db.profile.overlayColor = defaultOptions.overlayColor
									self.db.profile.overlayTexture = defaultOptions.overlayTexture
									self.db.profile.overlayBlendMode = defaultOptions.overlayBlendMode

									OnAppearanceChanged()
								end,
							},
						},
					},
				},
			},
			-- OverAbsorb Shield Group
			overAbsorbHeader = {
				type = "group",
                name = "Overshields",
				desc = "These settings are used while a unit's current health and combined shields exceed the unit's maximum health.",
                order = 1,
				args = {
					--- OverAbsorb Shield Bar
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
								values = TextureDropdownValues(),
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
								values = BlendModeDropdownValues(),
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
									self.db.profile.overAbsorbColor = defaultOptions.overAbsorbColor
									self.db.profile.overAbsorbTexture = defaultOptions.overAbsorbTexture
									self.db.profile.overAbsorbBlendMode = defaultOptions.overAbsorbBlendMode

									OnAppearanceChanged()
								end,
							},
						},
					},
					--- OverAbsorb Shield Bar Overlay
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
								values = TextureDropdownValues(),
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
								values = BlendModeDropdownValues(),
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
									self.db.profile.overAbsorbOverlayColor = defaultOptions.overAbsorbOverlayColor
									self.db.profile.overAbsorbOverlayTexture = defaultOptions.overAbsorbOverlayTexture
									self.db.profile.overAbsorbOverlayBlendMode = defaultOptions.overAbsorbOverlayBlendMode

									OnAppearanceChanged()
								end,
							},
						},
					},
					--- Overabsorb Shield Glow
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
								values = OverAbsorbGlowTextureDropdownValues(),
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
								values = BlendModeDropdownValues(),
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
									self.db.profile.overAbsorbGlowColor = defaultOptions.overAbsorbGlowColor
									self.db.profile.overAbsorbGlowTexture = defaultOptions.overAbsorbGlowTexture
									self.db.profile.overAbsorbGlowBlendMode = defaultOptions.overAbsorbGlowBlendMode

									OnAppearanceChanged()
								end,
							},
						},
					},
				}
            },
            healthBarHeader = {
				type = "group",
                name = "Health Bars",
                desc = "Settings for health bar appearance on Blizzard compact unit frames.",
                order = 2,
                args = {
					--- Non-OverAbsorb Health Bar
					healthBarGroup = {
						type = "group",
						name = "Health Bar",
						desc = "Settings used when a unit's health and shields do not exceed maximum health.",
						order = 0,
						inline = false,
						args = {
							useClassColor = {
								type = "toggle",
								name = "Use Class Color",
								desc = "Use Blizzard's default class color for health bars.",
								order = 0,
								width = "full",
								get = function() return self.db.profile.healthBarUseClassColor end,
								set = function(_, value)
									self.db.profile.healthBarUseClassColor = value
									OnAppearanceChanged()
								end,
							},
							color = {
								type = "color",
								name = "Color",
								order = 1,
								hasAlpha = true,
								disabled = function() return self.db.profile.healthBarUseClassColor end,
								get = function()
									local c = self.db.profile.healthBarColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.healthBarColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 2,
								values = TextureDropdownValues(),
								get = function() return self.db.profile.healthBarTexture end,
								set = function(_, value)
									self.db.profile.healthBarTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 3,
								values = BlendModeDropdownValues(),
								get = function() return self.db.profile.healthBarBlendMode end,
								set = function(_, value)
									self.db.profile.healthBarBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset to Blizzard default values.",
								order = -1,
								func = function()
									self.db.profile.healthBarColor = defaultOptions.healthBarColor
									self.db.profile.healthBarTexture = defaultOptions.healthBarTexture
									self.db.profile.healthBarBlendMode = defaultOptions.healthBarBlendMode
									self.db.profile.healthBarUseClassColor = defaultOptions.healthBarUseClassColor
									OnAppearanceChanged()
								end,
							},
						},
					},
					--- OverAbsorb Health Bar
					overAbsorbHealthBarGroup = {
						type = "group",
						name = "Overshield Health Bar",
						desc = "Settings used when a unit's health and shields exceed maximum health.",
						order = 1,
						inline = false,
						args = {
							useClassColor = {
								type = "toggle",
								name = "Use Class Color",
								desc = "Use Blizzard's default class color for health bars.",
								order = 0,
								width = "full",
								get = function() return self.db.profile.overAbsorbHealthBarUseClassColor end,
								set = function(_, value)
									self.db.profile.overAbsorbHealthBarUseClassColor = value
									OnAppearanceChanged()
								end,
							},
							color = {
								type = "color",
								name = "Color",
								order = 1,
								hasAlpha = true,
								disabled = function() return self.db.profile.overAbsorbHealthBarUseClassColor end,
								get = function()
									local c = self.db.profile.overAbsorbHealthBarColor
									return c.r, c.g, c.b, c.a
								end,
								set = function(_, r, g, b, a)
									self.db.profile.overAbsorbHealthBarColor = { r = r, g = g, b = b, a = a }
									OnAppearanceChanged()
								end,
							},
							texture = {
								type = "select",
								name = "Texture",
								order = 2,
								values = TextureDropdownValues(),
								get = function() return self.db.profile.overAbsorbHealthBarTexture end,
								set = function(_, value)
									self.db.profile.overAbsorbHealthBarTexture = value
									OnAppearanceChanged()
								end,
							},
							blendMode = {
								type = "select",
								name = "Blend Mode",
								order = 3,
								values = BlendModeDropdownValues(),
								get = function() return self.db.profile.overAbsorbHealthBarBlendMode end,
								set = function(_, value)
									self.db.profile.overAbsorbHealthBarBlendMode = value
									OnAppearanceChanged()
								end,
							},
							reset = {
								type = "execute",
								name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
								desc = "Reset to Blizzard default values.",
								order = -1,
								func = function()
									self.db.profile.overAbsorbHealthBarColor = defaultOptions.overAbsorbHealthBarColor
									self.db.profile.overAbsorbHealthBarTexture = defaultOptions.overAbsorbHealthBarTexture
									self.db.profile.overAbsorbHealthBarBlendMode = defaultOptions.overAbsorbHealthBarBlendMode
									self.db.profile.overAbsorbHealthBarUseClassColor = defaultOptions.overAbsorbHealthBarUseClassColor
									OnAppearanceChanged()
								end,
							},
						},
					},
				},
			}
		},
	}

	-- Ace3 Profile management
	local AceDBOptions = LibStub("AceDBOptions-3.0")
	if AceDBOptions then
		local dbOptions = AceDBOptions:GetOptionsTable(self.db)
		options.args.profiles = dbOptions
	end

	AceConfig:RegisterOptionsTable("Overshields Reforged", options)
	AceConfigDialog:AddToBlizOptions("Overshields Reforged", "Overshields Reforged")
end

--- Opens the addon options panel.
function OvershieldsReforged:OpenOptions()
    AceConfigDialog:Open("Overshields Reforged")
end
