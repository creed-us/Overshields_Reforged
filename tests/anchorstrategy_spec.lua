--- Characterization tests for AnchorStrategy.lua — pins the exact anchor points and fill
-- direction each mode applies, since these are what actually position the shield bar.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = { "Constants.lua", "AnchorStrategy.lua" }

--- Asserts one recorded SetPoint call matches the expected anchor tuple.
local function AssertPoint(call, point, relativeTo, relativePoint, x, y)
	lu.assertNotNil(call, "expected a SetPoint call, found none")
	lu.assertEquals(call.args[1], point)
	lu.assertIs(call.args[2], relativeTo)
	lu.assertEquals(call.args[3], relativePoint)
	lu.assertEquals(call.args[4], x)
	lu.assertEquals(call.args[5], y)
end

TestApplyAnchorStrategy = {}

function TestApplyAnchorStrategy:setUp()
	self.ns = load_addon.NewNamespace(FILES)
	self.bar = mock_frame.NewStatusBar()
	self.frame = mock_frame.NewCompactFrame({ unit = "party1" })
	self.healthBar = self.frame.healthBar
	self.healthTexture = self.healthBar:GetStatusBarTexture()
end

function TestApplyAnchorStrategy:apply(mode)
	self.ns.ApplyAnchorStrategy(self.bar, self.frame, self.healthBar, mode, self.healthTexture)
	return mock_frame.CallsTo(self.bar, "SetPoint")
end

function TestApplyAnchorStrategy:testHealthLeftFillsFromHealthTextureBackwards()
	local points = self:apply("health_left")
	lu.assertEquals(#points, 2)
	AssertPoint(points[1], "TOPLEFT", self.frame, "TOPLEFT", 0, 0)
	AssertPoint(points[2], "BOTTOMRIGHT", self.healthTexture, "BOTTOMRIGHT", 0, 0)
	lu.assertEquals(self.bar.reverseFill, true)
end

function TestApplyAnchorStrategy:testHealthRightStartsAtHealthTextureEdge()
	local points = self:apply("health_right")
	lu.assertEquals(#points, 2)
	AssertPoint(points[1], "TOPLEFT", self.healthTexture, "TOPRIGHT", 0, 0)
	AssertPoint(points[2], "BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
	lu.assertEquals(self.bar.reverseFill, false)
end

function TestApplyAnchorStrategy:testFrameLeftSpansFrameWidthAtHealthBarHeight()
	local points = self:apply("frame_left")
	lu.assertEquals(#points, 4)
	AssertPoint(points[1], "LEFT", self.frame, "LEFT", 0, 0)
	AssertPoint(points[2], "RIGHT", self.frame, "RIGHT", 0, 0)
	AssertPoint(points[3], "TOP", self.healthBar, "TOP", 0, 0)
	AssertPoint(points[4], "BOTTOM", self.healthBar, "BOTTOM", 0, 0)
	lu.assertEquals(self.bar.reverseFill, false)
end

function TestApplyAnchorStrategy:testFrameRightUsesSamePointsButReverseFill()
	local points = self:apply("frame_right")
	lu.assertEquals(#points, 4)
	AssertPoint(points[1], "LEFT", self.frame, "LEFT", 0, 0)
	AssertPoint(points[4], "BOTTOM", self.healthBar, "BOTTOM", 0, 0)
	lu.assertEquals(self.bar.reverseFill, true)
end

function TestApplyAnchorStrategy:testDefaultCoversHealthBar()
	local points = self:apply("default")
	lu.assertEquals(#points, 0)

	local setAllPoints = mock_frame.LastCall(self.bar, "SetAllPoints")
	lu.assertNotNil(setAllPoints)
	lu.assertIs(setAllPoints.args[1], self.healthBar)
	lu.assertEquals(self.bar.reverseFill, true)
end

function TestApplyAnchorStrategy:testUnknownModeFallsBackToDefault()
	self:apply("sideways")

	local setAllPoints = mock_frame.LastCall(self.bar, "SetAllPoints")
	lu.assertNotNil(setAllPoints, "unknown modes must fall back to the default handler")
	lu.assertIs(setAllPoints.args[1], self.healthBar)
	lu.assertEquals(self.bar.reverseFill, true)
end
