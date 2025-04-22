local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

OvershieldsReforged = OvershieldsReforged or {}

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
			showTickWhenNotFullHealth = true,
			shieldOverlayColor = { r = 0, g = 0, b = 1, a = 1 },      -- Default blue
			shieldOverlayBlendMode = "BLEND",                         -- Default blend mode
			overshieldTickColor = { r = 1, g = 1, b = 1, a = 1 },     -- Default white
			overshieldTickBlendMode = "ADD",                          -- Default blend mode
			overshieldTickTexture = "Interface\\RaidFrame\\Shield-Overshield", -- Default overshield tick texture
			overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",  -- Default shield overlay texture
		},
	})
end

function OvershieldsReforged:SetupOptions()
	local function TickTextureDropdownValues(defaultTexture)
		local values = { [defaultTexture] = "|T" .. defaultTexture .. ":16:16|t Default" } -- Add "Default" option

		-- Add specific spark textures
		values["Interface\\RaidFrame\\Shield-Overshield"] = "|TInterface\\RaidFrame\\Shield-Overshield:16:16|t Shield-Overshield"
		values["Interface\\CastingBar\\UI-CastingBar-Spark"] = "|TInterface\\CastingBar\\UI-CastingBar-Spark:16:16|t CastingBar-Spark"
		values["Interface\\Cooldown\\star4"] = "|TInterface\\Cooldown\\star4:16:16|t Star4"
		values["Interface\\Cooldown\\starburst"] = "|TInterface\\Cooldown\\starburst:16:16|t Starburst"
		values["Interface\\Artifacts\\Blizzard_Spark"] = "|TInterface\\Artifacts\\Blizzard_Spark:16:16|t Blizzard Spark"
		values["Interface\\Garrison\\GarrMission_EncounterBar-Spark"] = "|TInterface\\Garrison\\GarrMission_EncounterBar-Spark:16:16|t GarrMission Spark"
		values["Interface\\InsanityBar\\Insanity-Spark"] = "|TInterface\\InsanityBar\\Insanity-Spark:16:16|t Insanity Spark"
		values["Interface\\Legionfall\\Legionfall_BarSpark"] = "|TInterface\\Legionfall\\Legionfall_BarSpark:16:16|t Legionfall Spark"
		values["Interface\\XPBarAnim\\XPBarAnim-OrangeSpark"] = "|TInterface\\XPBarAnim\\XPBarAnim-OrangeSpark:16:16|t XPBar Orange Spark"
		values["Interface\\BonusObjective\\bonusobjective-bar-spark"] = "|TInterface\\BonusObjective\\bonusobjective-bar-spark:16:16|t Bonus Objective Spark"
		values["Interface\\HonorFrame\\honorsystem-bar-spark"] = "|TInterface\\HonorFrame\\honorsystem-bar-spark:16:16|t Honor System Spark"

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

	local function ReloadUIWithConfirmation()
		StaticPopupDialogs["OVERSHIELDS_REFORGED_RELOADUI"] = {
			text = "Texture changes require a UI reload. Reload now?",
			button1 = ACCEPT,
			button2 = CANCEL,
			OnAccept = function() ReloadUI() end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("OVERSHIELDS_REFORGED_RELOADUI")
	end

	local options = {
		type = "group",
		name = "Overshields Reforged",
		args = {
			overshieldTickGroup = {
				type = "group",
				name = "Overshield Tick",
				order = 0,
				inline = true,
				args = {
					showTickWhenNotFullHealth = {
						type = "toggle",
						name = "Always Show",
						desc = "Show the overshield tick even when the unit is not at full health.",
						order = 0,
						get = function() return self.db.profile.showTickWhenNotFullHealth end,
						set = function(_, value) self.db.profile.showTickWhenNotFullHealth = value end,
					},
					overshieldTickColor = {
						type = "color",
						name = "Overshield Tick Color",
						order = 1,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.overshieldTickColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.overshieldTickColor = { r = r, g = g, b = b, a = a }
						end,
					},
					overshieldTickBlendMode = {
						type = "select",
						name = "Overshield Tick Blend Mode",
						order = 2,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.overshieldTickBlendMode end,
						set = function(_, value) self.db.profile.overshieldTickBlendMode = value end,
					},
					resetOvershieldTick = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset Overshield Tick settings to default.",
						order = 3,
						func = function()
							self.db.profile.showTickWhenNotFullHealth = true
							self.db.profile.overshieldTickColor = { r = 1, g = 1, b = 1, a = 1 }
							self.db.profile.overshieldTickBlendMode = "ADD"
							self.db.profile.overshieldTickTexture = "Interface\\RaidFrame\\Shield-Overshield"
						end,
					},
				},
			},
			shieldOverlayGroup = {
				type = "group",
				name = "Shield Overlay",
				order = 1,
				inline = true,
				args = {
					shieldOverlayColor = {
						type = "color",
						name = "Shield Overlay Color",
						order = 0,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.shieldOverlayColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.shieldOverlayColor = { r = r, g = g, b = b, a = a }
						end,
					},
					shieldOverlayBlendMode = {
						type = "select",
						name = "Shield Overlay Blend Mode",
						order = 1,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.shieldOverlayBlendMode end,
						set = function(_, value) self.db.profile.shieldOverlayBlendMode = value end,
					},
					resetShieldOverlay = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset Shield Overlay settings to default.",
						order = 2,
						func = function()
							self.db.profile.shieldOverlayColor = { r = 0, g = 0, b = 1, a = 1 }
							self.db.profile.shieldOverlayBlendMode = "BLEND"
							self.db.profile.overlayTexture = "Interface\\RaidFrame\\Shield-Overlay"
						end,
					},
				},
			},
			textures = {
				type = "group",
				name = "Textures",
				order = 2,
				inline = true,
				args = {
					overshieldTickTexture = {
						type = "select",
						name = "Tick Texture",
						order = 0,
						desc = "Select the texture for the overshield tick.",
						values = function() return TickTextureDropdownValues("Interface\\RaidFrame\\Shield-Overshield") end,
						get = function()
							return self.db.profile.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield"
						end,
						set = function(_, value)
							self.db.profile.overshieldTickTexture = value == "Interface\\RaidFrame\\Shield-Overshield" and
								nil or value
							ReloadUIWithConfirmation()
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
							ReloadUIWithConfirmation()
						end,
					},
					resetTextures = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset all texture settings to default.",
						order = 3,
						func = function()
							self.db.profile.overshieldTickTexture = nil
							self.db.profile.overlayTexture = nil
							ReloadUIWithConfirmation()
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
