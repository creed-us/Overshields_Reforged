--- End-to-end check across the seams the unit specs deliberately stub out.
--
-- updatequeue_spec injects a fake ns.ProcessQueuedFrame and frameupdate_spec fakes the
-- appearance layer — each is the right call for a unit test, but it means no other spec
-- ever runs the real queue against the real frame update against the real painting. This
-- file does exactly one pass of that, so a broken seam can't hide behind two green
-- test files.

local lu = require("luaunit")
local load_addon = require("load_addon")
local mock_frame = require("mock_frame")

local FILES = {
	"Constants.lua",
	"Instrumentation.lua",
	"Utilities.lua",
	"BarLifecycle.lua",
	"FrameRegistry.lua",
	"UpdateQueue.lua",
	"ShieldState.lua",
	"AnchorStrategy.lua",
	"FrameUpdate.lua",
	"AppearanceManager.lua",
}

local PROFILE = {
	enableParty = true,
	anchorModeShielded = "frame_right",
	anchorModeOvershielded = "frame_right",
	absorbColor = { r = 1, g = 0.5, b = 0.25, a = 0.75 },
	absorbTexture = "Interface\\RaidFrame\\Shield-Fill",
	absorbBlendMode = "ADD",
	overlayColor = { r = 1, g = 1, b = 1, a = 0.5 },
	overlayTexture = "Interface\\RaidFrame\\Shield-Overlay",
	overlayBlendMode = "BLEND",
}

TestPipelineEndToEnd = {}

function TestPipelineEndToEnd:setUp()
	self.ns, self.stub = load_addon.NewNamespace(FILES)
	self.addon = self.stub.InstallAddonStub({ profile = PROFILE })
	self.ns.UnitGetTotalAbsorbs = function() return 4200 end

	self.frame = mock_frame.NewCompactFrame({
		unit = "party1",
		name = "CompactPartyFrameMember1",
		absorbShown = true,
	})
	self.frame.healthBar:SetMinMaxValues(0, 10000)
end

function TestPipelineEndToEnd:runOneCycle()
	local driver = self.stub.FindOnUpdateDriver()
	lu.assertNotNil(driver)
	driver.scripts.OnUpdate()
end

function TestPipelineEndToEnd:testQueuedFrameEndsUpWithAPaintedBar()
	self.ns.QueueCompactUnitFrameUpdate(self.frame)
	self:runOneCycle()

	local absorb = self.ns.absorbCache[self.frame]
	lu.assertNotNil(absorb, "the real queue should have driven the real frame update")
	lu.assertEquals(absorb.value, 4200)
	lu.assertEquals(absorb.maxValue, 10000)

	-- Proves the appearance layer actually ran, rather than being stubbed away.
	local color = mock_frame.LastCall(absorb, "SetStatusBarColor")
	lu.assertNotNil(color, "the real appearance layer should have painted the bar")
	lu.assertEquals(color.args[1], PROFILE.absorbColor.r)
	lu.assertEquals(color.args[4], PROFILE.absorbColor.a)
end

function TestPipelineEndToEnd:testNativeVisualsAreSuppressedWhenWeDrawOurOwn()
	self.ns.QueueCompactUnitFrameUpdate(self.frame)
	self:runOneCycle()

	lu.assertEquals(self.frame.totalAbsorb.shown, false)
end

function TestPipelineEndToEnd:testReleasingEverythingRestoresTheFrame()
	self.ns.QueueCompactUnitFrameUpdate(self.frame)
	self:runOneCycle()
	lu.assertNotNil(self.ns.absorbCache[self.frame])

	self.ns.ReleaseAllBars()

	lu.assertNil(next(self.ns.absorbCache), "release should clear tracking")
	lu.assertEquals(self.frame.overAbsorbGlow.texture, self.ns.VanillaDefaults.glowTexture,
		"release should hand the frame back to Blizzard's defaults")
end
