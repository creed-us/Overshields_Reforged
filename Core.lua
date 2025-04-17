local ADDON_NAME, ns = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

OvershieldsReforged = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")

function OvershieldsReforged:OnInitialize()
	-- Initialize database with defaults
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
			showTickWhenNotFullHealth = true,
			absorbOverlayColor = { r = 0, g = 0, b = 1, a = 1 }, -- Default blue
			absorbOverlayBlendMode = "BLEND",            -- Default blend mode
			overabsorbTickColor = { r = 1, g = 1, b = 1, a = 1 }, -- Default white
			overabsorbTickBlendMode = "ADD",             -- Default blend mode
		},
	})

	-- Register options table
	self:SetupOptions()

	-- Hook Blizzard's heal-prediction functions
	hooksecurefunc("UnitFrameHealPredictionBars_Update", function(frame)
		ns.HandleUnitFrameUpdate(frame)
	end)
	hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
		ns.HandleCompactUnitFrame_Update(frame)
	end)
end

function OvershieldsReforged:SetupOptions()
	local AceConfig = LibStub("AceConfig-3.0")
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")

	local options = {
		type = "group",
		name = "Overshields Reforged",
		args = {
			overabsorbTickGroup = {
				type = "group",
				name = "Overabsorb Tick",
				inline = true,
				args = {
					showTickWhenNotFullHealth = {
						type = "toggle",
						name = "Always Show",
						desc =
						"Show the overabsorb (unit's health and total absorb exceeds its maximum health) tick even when the unit is not at full health.",
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
				}
			},
		},
	}

	AceConfig:RegisterOptionsTable(ADDON_NAME, options)
	AceConfigDialog:AddToBlizOptions(ADDON_NAME, "Overshields Reforged")
end

-- slash command to open the options
SLASH_OVERSHIELDSR1 = "/overshieldsreforged"
SLASH_OVERSHIELDSR2 = "/osr"
SlashCmdList["OVERSHIELDSR"] = function()
	Settings.OpenToCategory("Overshields Reforged")
end
