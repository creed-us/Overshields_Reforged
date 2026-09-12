local _, ns = ...

function ns.FrameIsForbidden(frame)
	local frameType = type(frame)
	if not frame or (frameType ~= "table" and frameType ~= "userdata") then return true end
	if type(frame.IsForbidden) == "function" and frame:IsForbidden() then return true end
	return false
end

function ns.IsSettingEnabled(value)
	return value ~= false
end

local atlasCache = {}

--- Returns whether an asset name is a texture atlas (vs. a plain file path), caching the lookup.
-- @param asset The texture path or atlas name to check
-- @return boolean true if the asset is a known atlas
function ns.IsAtlasAsset(asset)
	local isAtlas = atlasCache[asset]
	if isAtlas == nil then
		isAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset) and true or false
		atlasCache[asset] = isAtlas
	end
	return isAtlas
end

--- Wipes the atlas-detection cache. Called alongside the style cache on profile change
function ns.WipeAtlasCache()
	ns.wipe(atlasCache)
end
