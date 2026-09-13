local _, ns = ...
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

StaticPopupDialogs["OVERSHIELDS_REFORGED_RELOAD_ANCHOR"] = {
	text = "It is recommended to reload the UI when changing anchoring behavior. Reload now?",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function ()
		ReloadUI()
	end,
	timeout = 30,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 2,
}

--- Callback invoked whenever appearance settings are modified.
-- Triggers update of appearance for all visible compact unit frames.
local pendingAppearanceRefreshToken = 0

local function OnAppearanceChanged()
	-- Re-evaluate hibernate when frame-scope toggles change.
	if ns.EvaluateHibernation then
		ns.EvaluateHibernation()
	end

	local delay = 0.01 -- >0 to prevent perf. tank while changing appearance in options
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

function OvershieldsReforged:InitializeDatabase()
	self.db = AceDB:New("OvershieldsReforgedDB", ns.ProfileDefaults, true)
	ns.MigrateProfile(self.db.profile)
	ns.NormalizeAnchorModeSettings(self.db and self.db.profile)

	-- Clean up caches and re-apply appearance when the active profile changes.
	local function OnProfileChanged()
		ns.MigrateProfile(self.db.profile)
		ns.NormalizeAnchorModeSettings(self.db and self.db.profile)
		if ns.ReleaseAllBars then
			ns.ReleaseAllBars()
		end
		if ns.wipeStyleCache then
			ns.wipeStyleCache()
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
						local p = ns.ProfileDefaults.profile
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
					absorbGroup  = MakeAppearanceGroup("Shield Bar",         1, "absorbColor",  "absorbTexture",  "absorbBlendMode",  ns.TextureDropdownValues),
					overlayGroup = MakeAppearanceGroup("Shield Bar Overlay", 2, "overlayColor", "overlayTexture", "overlayBlendMode", ns.TextureDropdownValues),
				},
			},
			-- OverAbsorb shield appearance (overAbsorbGlow visible)
			overAbsorbHeader = {
				type = "group",
				name = "Overshields",
				desc = "These settings are used while a unit's current health and combined shields exceed the unit's maximum health.",
				order = 1,
				args = {
					overAbsorbGroup        = MakeAppearanceGroup("Overshield Bar",         0, "overAbsorbColor",        "overAbsorbTexture",        "overAbsorbBlendMode",        ns.TextureDropdownValues),
					overAbsorbOverlayGroup = MakeAppearanceGroup("Overshield Bar Overlay", 1, "overAbsorbOverlayColor", "overAbsorbOverlayTexture", "overAbsorbOverlayBlendMode", ns.TextureDropdownValues),
					overAbsorbGlowGroup    = MakeAppearanceGroup("Overshield Glow",        2, "overAbsorbGlowColor",    "overAbsorbGlowTexture",    "overAbsorbGlowBlendMode",    ns.OverAbsorbGlowTextureDropdownValues),
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
					anchorModeShielded = {
						type = "select",
						name = "Shielded Anchor",
						desc = "Choose where shield bars and overlays are anchored while the unit has absorbs and is not overshielded. Health Bar Right uses Blizzard-style sizing/placement.",
						descStyle = "inline",
						order = 11,
						width = "full",
						values = ns.AnchorModeLabels,
						get = function()
							local value = self.db.profile.anchorModeShielded
							if not ns.IsValidAnchorMode(value) then
								return ns.ProfileDefaults.profile.anchorModeShielded
							end
							return value
						end,
						set = function(_, value)
							self.db.profile.anchorModeShielded = value
							OnAppearanceChanged()
							StaticPopup_Show("OVERSHIELDS_REFORGED_RELOAD_ANCHOR")
						end,
					},
					anchorModeOvershielded = {
						type = "select",
						name = "Overshielded Anchor",
						desc = "Choose where shield bars and overlays are anchored while the unit is overshielded.",
						descStyle = "inline",
						order = 12,
						width = "full",
						values = ns.AnchorModeLabels,
						get = function()
							local value = self.db.profile.anchorModeOvershielded
							if not ns.IsValidAnchorMode(value) then
								return ns.ProfileDefaults.profile.anchorModeOvershielded
							end
							return value
						end,
						set = function(_, value)
							self.db.profile.anchorModeOvershielded = value
							OnAppearanceChanged()
							StaticPopup_Show("OVERSHIELDS_REFORGED_RELOAD_ANCHOR")
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

--- Returns whether the addon is enabled for a unit context.
-- @param unit Unit token (e.g., "party1", "raid3", "partypet1")
-- @return boolean true when updates should run for this unit
function OvershieldsReforged:IsUnitContextEnabled(unit)
	local profile = self.db and self.db.profile
	return ns.IsUnitContextEnabledFromProfile(profile, unit)
end

--- Returns whether the addon should run for the provided compact unit frame.
-- @param frame Compact unit frame
-- @return boolean
function OvershieldsReforged:IsFrameContextEnabled(frame)
	if not frame then
		return false
	end
	return self:IsUnitContextEnabled(frame.displayedUnit)
end
