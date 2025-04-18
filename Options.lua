local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

OvershieldsReforged = OvershieldsReforged or {}

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
			showTickWhenNotFullHealth = true,
			absorbOverlayColor = { r = 0, g = 0, b = 1, a = 1 },      -- Default blue
			absorbOverlayBlendMode = "BLEND",                         -- Default blend mode
			overabsorbTickColor = { r = 1, g = 1, b = 1, a = 1 },     -- Default white
			overabsorbTickBlendMode = "ADD",                          -- Default blend mode
			overabsorbTickTexture = "Interface\\RaidFrame\\Shield-Overshield", -- Default absorb glow tick texture
			overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",  -- Default absorb overlay texture
		},
	})
end

function OvershieldsReforged:SetupOptions()
	local function TickTextureDropdownValues(defaultTexture)
		local values = { [defaultTexture] = "|T" .. defaultTexture .. ":16:16|t Default" } -- Add "Default" option

		-- Add specific spark textures
		values["Interface\\RaidFrame\\Shield-Overshield"] =
		"|TInterface\\RaidFrame\\Shield-Overshield:16:16|t Shield-Overshield"
		values["Interface\\CastingBar\\UI-CastingBar-Spark"] =
		"|TInterface\\CastingBar\\UI-CastingBar-Spark:16:16|t CastingBar-Spark"
		values["Interface\\Cooldown\\star4"] = "|TInterface\\Cooldown\\star4:16:16|t Star4"
		values["Interface\\Cooldown\\starburst"] = "|TInterface\\Cooldown\\starburst:16:16|t Starburst"
		values["Interface\\Artifacts\\Blizzard_Spark"] = "|TInterface\\Artifacts\\Blizzard_Spark:16:16|t Blizzard Spark"
		values["Interface\\Garrison\\GarrMission_EncounterBar-Spark"] =
		"|TInterface\\Garrison\\GarrMission_EncounterBar-Spark:16:16|t GarrMission Spark"
		values["Interface\\InsanityBar\\Insanity-Spark"] =
		"|TInterface\\InsanityBar\\Insanity-Spark:16:16|t Insanity Spark"
		values["Interface\\Legionfall\\Legionfall_BarSpark"] =
		"|TInterface\\Legionfall\\Legionfall_BarSpark:16:16|t Legionfall Spark"
		values["Interface\\XPBarAnim\\XPBarAnim-OrangeSpark"] =
		"|TInterface\\XPBarAnim\\XPBarAnim-OrangeSpark:16:16|t XPBar Orange Spark"
		values["Interface\\BonusObjective\\bonusobjective-bar-spark"] =
		"|TInterface\\BonusObjective\\bonusobjective-bar-spark:16:16|t Bonus Objective Spark"
		values["Interface\\HonorFrame\\honorsystem-bar-spark"] =
		"|TInterface\\HonorFrame\\honorsystem-bar-spark:16:16|t Honor System Spark"

		-- Dynamically add spark textures from LibSharedMedia
		for name, path in pairs(LSM:HashTable("statusbar")) do
			if name:lower():find("spark") then
				values[path] = string.format("|T%s:16:16|t %s", path, name)
			end
		end

		return values
	end

	local function OverlayTextureDropdownValues(defaultTexture)
		local textures = LSM:HashTable("statusbar")
		local values = { [defaultTexture] = "|T" .. defaultTexture .. ":16:16|t Default" } -- Add "Default" option

		-- Add RaidFrame overlay textures
		values["Interface\\RaidFrame\\Shield-Overlay"] = "|TInterface\\RaidFrame\\Shield-Overlay:16:16|t Shield-Overlay"

		for name, path in pairs(textures) do
			values[path] = string.format("|T%s:16:16|t %s", path, name) -- Add texture preview
		end
		return values
	end

	local options = {
		type = "group",
		name = "Overshields Reforged",
		args = {
			overabsorbTickGroup = {
				type = "group",
				name = "Overabsorb Tick",
				order = 0,
				inline = true,
				args = {
					showTickWhenNotFullHealth = {
						type = "toggle",
						name = "Always Show",
						desc = "Show the overabsorb tick even when the unit is not at full health.",
						order = 0,
						get = function() return self.db.profile.showTickWhenNotFullHealth end,
						set = function(_, value) self.db.profile.showTickWhenNotFullHealth = value end,
					},
					overabsorbTickColor = {
						type = "color",
						name = "Overabsorb Tick Color",
						order = 1,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.overabsorbTickColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.overabsorbTickColor = { r = r, g = g, b = b, a = a }
						end,
					},
					overabsorbTickBlendMode = {
						type = "select",
						name = "Overabsorb Tick Blend Mode",
						order = 2,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.overabsorbTickBlendMode end,
						set = function(_, value) self.db.profile.overabsorbTickBlendMode = value end,
					},
				},
			},
			absorbOverlayGroup = {
				type = "group",
				name = "Absorb Overlay",
				order = 1,
				inline = true,
				args = {
					absorbOverlayColor = {
						type = "color",
						name = "Absorb Overlay Color",
						order = 0,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.absorbOverlayColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.absorbOverlayColor = { r = r, g = g, b = b, a = a }
						end,
					},
					absorbOverlayBlendMode = {
						type = "select",
						name = "Absorb Overlay Blend Mode",
						order = 1,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.absorbOverlayBlendMode end,
						set = function(_, value) self.db.profile.absorbOverlayBlendMode = value end,
					},
				},
			},
			textures = {
				type = "group",
				name = "Textures",
				order = 2,
				inline = true,
				args = {
					overabsorbTickTexture = {
						type = "select",
						name = "Tick Texture",
						order = 0,
						desc = "Select the texture for the overabsorb tick.",
						values = function() return TickTextureDropdownValues("Interface\\RaidFrame\\Shield-Overshield") end,
						get = function()
							return self.db.profile.overabsorbTickTexture or "Interface\\RaidFrame\\Shield-Overshield"
						end,
						set = function(_, value)
							self.db.profile.overabsorbTickTexture = value == "Interface\\RaidFrame\\Shield-Overshield" and
								nil or value
						end,
					},
					overlayTexture = {
						type = "select",
						name = "Overlay Texture",
						order = 1,
						desc = "Select the texture for the overlay.",
						values = function() return OverlayTextureDropdownValues("Interface\\RaidFrame\\Shield-Overlay") end,
						get = function()
							return self.db.profile.overlayTexture or "Interface\\RaidFrame\\Shield-Overlay"
						end,
						set = function(_, value)
							self.db.profile.overlayTexture = value == "Interface\\RaidFrame\\Shield-Overlay" and nil or
								value
						end,
					},
					resetTextures = {
						type = "execute",
						name = "Reset Textures",
						order = 2,
						desc = "Reset textures to default.",
						func = function()
							self.db.profile.overabsorbTickTexture = nil
							self.db.profile.overlayTexture = nil
						end,
					},
				},
			},
		},
	}

	AceConfig:RegisterOptionsTable("Overshields Reforged", options)
	AceConfigDialog:AddToBlizOptions("Overshields Reforged", "Overshields Reforged")
end

function OvershieldsReforged:OpenOptions()
	Settings.OpenToCategory("Overshields Reforged")
end
