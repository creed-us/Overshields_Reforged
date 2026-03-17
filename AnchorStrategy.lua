local _, ns = ...

local anchorHandlers = {
	health_left = function(bar, frame, healthBar, healthTexture)
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(true)
	end,
	health_right = function(bar, frame, healthBar, healthTexture)
		bar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(false)
	end,
	frame_left = function(bar, frame)
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(false)
	end,
	frame_right = function(bar, frame)
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bar:SetReverseFill(true)
	end,
	default = function(bar, frame, healthBar)
		bar:SetAllPoints(healthBar)
		bar:SetReverseFill(true)
	end,
}

function ns.ApplyAnchorStrategy(bar, frame, healthBar, targetMode, healthTexture)
	local handler = anchorHandlers[targetMode] or anchorHandlers.default
	handler(bar, frame, healthBar, healthTexture)
end
