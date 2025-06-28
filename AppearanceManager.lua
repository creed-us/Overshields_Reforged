local _, ns = ...

local function ApplyAppearance(frame)
	local db = OvershieldsReforged.db.profile
    if not db or not frame then
        return
    end

	local shieldBar = frame.totalAbsorb
	local shieldOverlay = frame.totalAbsorbOverlay
	local overshieldTick = frame.overAbsorbGlow

	-- Overshield Tick
	if overshieldTick and not overshieldTick:IsForbidden() then
		local color = db.overshieldTickColor
		overshieldTick:SetVertexColor(color.r, color.g, color.b, color.a)
		overshieldTick:SetBlendMode(db.overshieldTickBlendMode)
		overshieldTick:SetTexture(db.overshieldTickTexture or "Interface\\RaidFrame\\Shield-Overshield")
	elseif not overshieldTick then
		print("Overshield Tick is unavailable or does not exist: ".. frame:GetName())
	else
		print("Overshield Tick is forbidden.")
	end

	-- Shield Overlay
	if shieldOverlay and not shieldOverlay:IsForbidden() then
		local shieldOverlayColor = db.shieldOverlayColor
		shieldOverlay:SetDesaturated(true)
		shieldOverlay:SetVertexColor(shieldOverlayColor.r, shieldOverlayColor.g, shieldOverlayColor.b, shieldOverlayColor.a)
		shieldOverlay:SetAlpha(shieldOverlayColor.a)
		shieldOverlay:SetBlendMode(db.shieldOverlayBlendMode)
		if db.shieldOverlayTexture ~= "Interface\\RaidFrame\\Shield-Overlay" then
			shieldOverlay:SetTexture(db.shieldOverlayTexture)
		end
	else
		print("Shield Overlay is unavailable or does not exist.")
	end

    -- Shield Bar
	if shieldBar and not shieldBar:IsForbidden() then
		local shieldBarColor = db.shieldBarColor
		shieldBar:SetVertexColor(shieldBarColor.r, shieldBarColor.g, shieldBarColor.b, shieldBarColor.a)
		shieldBar:SetAlpha(shieldBarColor.a)
		shieldBar:SetBlendMode(db.shieldBarBlendMode)
		if db.shieldBarTexture ~= "Interface\\RaidFrame\\Shield-Fill" then
			shieldBar:SetTexture(db.shieldBarTexture)
		end
	end
end

local function UpdatePartyFrames()
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsShown() and frame.displayedUnit and UnitExists(frame.displayedUnit) then
			ApplyAppearance(frame)
		end
	end
end

local function UpdateRaidFrames()
	for i = 1, 40 do
		local frame = _G["CompactRaidFrame" .. i]
		if frame and frame:IsShown() and frame.displayedUnit and UnitExists(frame.displayedUnit) then
			ApplyAppearance(frame)
		end
	end
end

local function UpdatePetFrames()
	local petFramePrefix = IsInRaid() and "CompactRaidFramePet" or "CompactPartyFramePet"
	for i = 1, 40 do
		local frame = _G[petFramePrefix .. i]
		if frame and frame:IsShown() and frame.displayedUnit and UnitExists(frame.displayedUnit) then
			ApplyAppearance(frame)
		end
	end
end

function ns.UpdateAllCompactUnitFrames()
    local isInRaid = IsInRaid()
	if not isInRaid then
		UpdatePartyFrames()
    else
		UpdateRaidFrames()
	end

	if CompactRaidFrameContainer.displayPets then
		UpdatePetFrames()
	end
end

local eventFrame = CreateFrame("Frame", nil, UIParent)
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
eventFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE" or event == "UNIT_PET" or event == "UNIT_NAME_UPDATE" then
		ns.UpdateAllCompactUnitFrames()
	end
end)
