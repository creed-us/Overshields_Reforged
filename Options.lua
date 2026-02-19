local _, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

--- Callback invoked whenever appearance settings are modified.
-- Triggers update of appearance for all visible compact unit frames.
local function OnAppearanceChanged()
	ns.UpdateAllFrameAppearances()
end

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", {
		profile = {
			absorbColor = { r = 1, g = 1, b = 1, a = 0.75 },
			absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
			overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
			overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
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

	local function CreateBarGroup(barName, colorKey, textureKey, order)
		return {
			type = "group",
			name = barName,
			order = order,
			inline = true,
			args = {
				color = {
					type = "color",
					name = "Color",
					order = 0,
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
					values = TextureDropdownValues(),
					get = function() return self.db.profile[textureKey] end,
					set = function(_, value)
						self.db.profile[textureKey] = value
						OnAppearanceChanged()
					end,
				},
				reset = {
					type = "execute",
					name = "|TInterface\\Buttons\\UI-RefreshButton:16:16|t Reset",
					desc = "Reset to defaults.",
					order = 2,
					func = function()
                        if textureKey == "absorbTexture" then
							self.db.profile[colorKey] = { r = 1, g = 1, b = 1, a = 0.75 }
                            self.db.profile[textureKey] = "Interface\\RaidFrame\\Shield-Fill"
                        else
							self.db.profile[colorKey] = { r = 1, g = 1, b = 1, a = 0.5 }
                            self.db.profile[textureKey] = "Interface\\RaidFrame\\Shield-Overlay"
                        end

						OnAppearanceChanged()
					end,
				},
			},
		}
	end

	local options = {
		type = "group",
		name = "Overshields Reforged",
		args = {
			absorbGroup = CreateBarGroup("Shield Bar", "absorbColor", "absorbTexture", 0),
			overlayGroup = CreateBarGroup("Overlay Bar", "overlayColor", "overlayTexture", 1),
		},
	}
	AceConfig:RegisterOptionsTable("Overshields Reforged", options)
	AceConfigDialog:AddToBlizOptions("Overshields Reforged", "Overshields Reforged")
end

--- Opens the addon options panel.
function OvershieldsReforged:OpenOptions()
	AceConfigDialog:Open("Overshields Reforged")
end
