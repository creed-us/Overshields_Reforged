local _, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

local function OnAppearanceChanged()
	ns.UpdateAllCompactUnitFrames()
end

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
			overshieldTickColor = { r = 1, g = 1, b = 1, a = 0.7 },
			overshieldTickBlendMode = "ADD",
			overshieldTickTexture = "Interface\\RaidFrame\\Shield-Overshield",
			shieldBarTexture = "Interface\\RaidFrame\\Shield-Fill",
			showTickWhenNotFullHealth = true,
			showShieldOverlayAtFullHealth = true,
			showShieldBarAtFullHealth = false,
			shieldOverlayColor = { r = 0, g = 0, b = 1, a = 0.7 },
			shieldOverlayBlendMode = "BLEND",
			shieldOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
			shieldBarColor = { r = 1, g = 1, b = 1, a = 1 },
			shieldBarBlendMode = "ADD",
		},
	})
end

function OvershieldsReforged:SetupOptions()
	local function ReloadUIWithConfirmation()
		StaticPopupDialogs["OVERSHIELDS_REFORGED_RELOADUI"] = {
			text = "Changes require a UI reload. Reload now?",
			button1 = ACCEPT,
			button2 = CANCEL,
            OnAccept = function()
                ReloadUI()
			end,
			timeout = 30,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("OVERSHIELDS_REFORGED_RELOADUI")
	end

	local function TickTextureDropdownValues()
		local values = {
			["Interface\\RaidFrame\\Shield-Overshield"] = "|TInterface\\RaidFrame\\Shield-Overshield:16:16|t Default",
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

	local function ShieldTextureDropdownValues(defaultTexture)
		local values = { [defaultTexture] = "|T" .. defaultTexture .. ":16:16|t Default" }
		for name, path in pairs(LSM:HashTable("statusbar")) do
			values[path] = string.format("|T%s:16:16|t %s", path, name)
		end
		return values
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
						name = "When Missing Health",
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
							OnAppearanceChanged()
						end,
					},
					overshieldTickBlendMode = {
						type = "select",
						name = "Overshield Tick Blend Mode",
						order = 2,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.overshieldTickBlendMode end,
                        set = function(_, value)
							self.db.profile.overshieldTickBlendMode = value
							OnAppearanceChanged()
						end,
					},
					overshieldTickTexture = {
						type = "select",
						name = "Tick Texture",
						order = 3,
						values = TickTextureDropdownValues(),
						get = function() return self.db.profile.overshieldTickTexture end,
                        set = function(_, value)
							self.db.profile.overshieldTickTexture = value
							OnAppearanceChanged()
						end,
					},
					resetOvershieldTick = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset Overshield Tick settings to default.",
						order = 4,
						func = function()
							self.db.profile.showTickWhenNotFullHealth = true
							self.db.profile.overshieldTickColor = { r = 1, g = 1, b = 1, a = 1 }
							self.db.profile.overshieldTickBlendMode = "ADD"
                            self.db.profile.overshieldTickTexture = "Interface\\RaidFrame\\Shield-Overshield"
							OnAppearanceChanged()
							ReloadUIWithConfirmation()
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
					showShieldOverlayAtFullHealth = {
						type = "toggle",
						name = "When Overshielded",
						desc = "Allow the shield overlay to display over the health bar when the unit is at full health.",
						order = 0,
						get = function() return self.db.profile.showShieldOverlayAtFullHealth end,
                        set = function(_, value)
                        	self.db.profile.showShieldOverlayAtFullHealth = value
						end,
					},
					shieldOverlayColor = {
						type = "color",
						name = "Shield Overlay Color",
						order = 1,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.shieldOverlayColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.shieldOverlayColor = { r = r, g = g, b = b, a = a }
							OnAppearanceChanged()
						end,
					},
					shieldOverlayBlendMode = {
						type = "select",
						name = "Shield Overlay Blend Mode",
						order = 2,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.shieldOverlayBlendMode end,
                        set = function(_, value)
                            self.db.profile.shieldOverlayBlendMode = value
							OnAppearanceChanged()
						end,
					},
					shieldOverlayTexture = {
						type = "select",
						name = "Overlay Texture",
						order = 3,
						values = ShieldTextureDropdownValues("Interface\\RaidFrame\\Shield-Overlay"),
						get = function() return self.db.profile.shieldOverlayTexture end,
                        set = function(_, value)
                            self.db.profile.shieldOverlayTexture = value
                            OnAppearanceChanged()
						end,
					},
					resetShieldOverlay = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset Shield Overlay settings to default.",
						order = 4,
						func = function()
							self.db.profile.showShieldOverlayAtFullHealth = true
							self.db.profile.shieldOverlayColor = { r = 0, g = 0, b = 1, a = 1 }
							self.db.profile.shieldOverlayBlendMode = "BLEND"
							self.db.profile.shieldOverlayTexture = "Interface\\RaidFrame\\Shield-Overlay"
							OnAppearanceChanged()
							ReloadUIWithConfirmation()
						end,
					},
				},
			},
			shieldBarGroup = {
				type = "group",
				name = "Shield Bar",
				order = 2,
				inline = true,
				args = {
					showShieldBarAtFullHealth = {
						type = "toggle",
						name = "When at Full Health",
						desc = "Allow the shield bar to display over the health bar when the unit is at full health.",
						order = 0,
						get = function() return self.db.profile.showShieldBarAtFullHealth end,
                        set = function(_, value)
                            self.db.profile.showShieldBarAtFullHealth = value
						end,
					},
					shieldBarColor = {
						type = "color",
						name = "Shield Bar Color",
						order = 1,
						hasAlpha = true,
						get = function()
							local c = self.db.profile.shieldBarColor
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							self.db.profile.shieldBarColor = { r = r, g = g, b = b, a = a }
							OnAppearanceChanged()
						end,
					},
					shieldBarBlendMode = {
						type = "select",
						name = "Shield Bar Blend Mode",
						order = 2,
						values = { DISABLE = "DISABLE", BLEND = "BLEND", ALPHAKEY = "ALPHAKEY", ADD = "ADD", MOD = "MOD" },
						get = function() return self.db.profile.shieldBarBlendMode end,
                        set = function(_, value)
                            self.db.profile.shieldBarBlendMode = value
                            OnAppearanceChanged()
						end,
					},
					shieldBarTexture = {
						type = "select",
						name = "Bar Texture",
						order = 3,
						values = ShieldTextureDropdownValues("Interface\\RaidFrame\\Shield-Fill"),
						get = function() return self.db.profile.shieldBarTexture end,
                        set = function(_, value)
							self.db.profile.shieldBarTexture = value
                            OnAppearanceChanged()
						end,
					},
					resetShieldBar = {
						type = "execute",
						name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
						desc = "Reset Shield Bar settings to default.",
						order = 4,
						func = function()
							self.db.profile.showShieldBarAtFullHealth = false
							self.db.profile.shieldBarColor = { r = 1, g = 1, b = 1, a = 1 }
							self.db.profile.shieldBarBlendMode = "ADD"
                            self.db.profile.shieldBarTexture = "Interface\\RaidFrame\\Shield-Fill"
							OnAppearanceChanged()
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