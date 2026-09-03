local addon = {}
local currentTime = 1000
local closeCount = 0
local groupAddHook
local showHook

function time() return currentTime end

local bonusRollShown = false
BonusRollFrame = {
	state = "prompt",
	endTime = currentTime + 60,
}
function BonusRollFrame:IsShown() return bonusRollShown end
function BonusRollFrame:Show()
	bonusRollShown = true
	if showHook then showHook(self) end
end

function BonusRollFrame_CloseBonusRoll()
	closeCount = closeCount + 1
	bonusRollShown = false
end

GroupLootContainer = {}
function GroupLootContainer_AddFrame(container, frame)
	bonusRollShown = true
	if groupAddHook then groupAddHook(container, frame) end
end

function hooksecurefunc(target, methodName, callback)
	if type(target) == "string" then
		assert(target == "GroupLootContainer_AddFrame")
		groupAddHook = methodName
		return
	end
	assert(target == BonusRollFrame)
	assert(methodName == "Show")
	showHook = callback
end

local frames = {}
function CreateFrame()
	local frame = { events = {}, scripts = {} }
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:SetScript(name, callback) self.scripts[name] = callback end
	table.insert(frames, frame)
	return frame
end

addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonNormal" }
function addon:ShowHiddenBonusRoll()
	if not self.hiddenBonusRoll then return false end
	GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
	self.hiddenBonusRoll = nil
	return true
end

assert(loadfile("RollCurtain/TransitionGuard.lua"))("RollCurtain", addon)
assert(groupAddHook, "Expected GroupLootContainer_AddFrame hook")
assert(showHook, "Expected BonusRollFrame Show hook")

-- Blizzard re-adding a previously suppressed prompt after an instance change
-- must not make it visible again.
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(bonusRollShown == false, "Re-added suppressed bonus roll should remain hidden")
assert(closeCount == 1, "Re-added suppressed roll should be closed once")
assert(addon.hiddenBonusRoll and addon.hiddenBonusRoll.frame == BonusRollFrame, "Suppressed roll should remain recoverable")

-- Direct frame Show calls are guarded too.
BonusRollFrame:Show()
assert(bonusRollShown == false, "Directly resurfaced suppressed bonus roll should remain hidden")
assert(closeCount == 2)

-- Explicit player restoration must bypass the transition guard.
assert(addon:ShowHiddenBonusRoll() == true)
assert(bonusRollShown == true, "Manual restore should be allowed to show the bonus roll")
assert(addon.hiddenBonusRoll == nil)
assert(closeCount == 2, "Manual restore should not immediately re-close the prompt")

-- Expired hidden rolls should be discarded rather than guarded forever.
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonNormal" }
BonusRollFrame.endTime = currentTime - 1
bonusRollShown = false
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(addon.hiddenBonusRoll == nil, "Expired hidden roll should be cleared")
assert(bonusRollShown == true, "Expired stale frame should not be force-closed by Roll Curtain")

print("Roll Curtain transition guard tests passed")
