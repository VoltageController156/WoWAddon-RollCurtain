local addon = {}
local currentTime = 1000
local closeCount = 0
local groupAddHook
local showHook
local startRollHook
local deferredCallbacks = {}

function time() return currentTime end

C_Timer = {
	After = function(_, callback)
		table.insert(deferredCallbacks, callback)
	end,
}

local function RunDeferredCallbacks()
	local callbacks = deferredCallbacks
	deferredCallbacks = {}
	for _, callback in ipairs(callbacks) do
		callback()
	end
end

local bonusRollShown = false
BonusRollFrame = {
	state = "prompt",
	spellID = 123,
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

function BonusRollFrame_StartBonusRoll()
	if startRollHook then startRollHook() end
end

function hooksecurefunc(target, methodName, callback)
	if type(target) == "string" then
		if target == "GroupLootContainer_AddFrame" then
			groupAddHook = methodName
			return
		elseif target == "BonusRollFrame_StartBonusRoll" then
			startRollHook = methodName
			return
		end
		error("Unexpected global hook target: " .. tostring(target))
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
assert(startRollHook, "Expected BonusRollFrame_StartBonusRoll hook")

-- A newly suppressed roll gets a generation plus spell/end-time identity after
-- Blizzard and Core.lua finish handling BonusRollFrame_StartBonusRoll.
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll.rollGeneration == 1, "Hidden roll should capture its roll generation")
assert(addon.hiddenBonusRoll.rollSpellID == 123, "Hidden roll should capture spellID")
assert(addon.hiddenBonusRoll.rollEndTime == currentTime + 60, "Hidden roll should capture endTime")

-- Blizzard re-adding a previously suppressed prompt after an instance change
-- must not make that same roll visible again.
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(bonusRollShown == false, "Re-added suppressed bonus roll should remain hidden")
assert(closeCount == 1, "Re-added suppressed roll should be closed once")
assert(addon.hiddenBonusRoll and addon.hiddenBonusRoll.frame == BonusRollFrame, "Suppressed roll should remain recoverable")

-- Direct frame Show calls are guarded too while the roll identity still matches.
BonusRollFrame:Show()
assert(bonusRollShown == false, "Directly resurfaced suppressed bonus roll should remain hidden")
assert(closeCount == 2)

-- Blizzard reuses the same BonusRollFrame for later rolls. If the frame's roll
-- identity changes before the StartBonusRoll post-hook runs, the old hidden
-- record must be invalidated instead of suppressing the new roll.
BonusRollFrame.spellID = 456
BonusRollFrame.endTime = currentTime + 120
BonusRollFrame:Show()
assert(addon.hiddenBonusRoll == nil, "Different roll identity should invalidate stale hidden-roll state")
assert(bonusRollShown == true, "A new roll reusing BonusRollFrame must not inherit old suppression")
assert(closeCount == 2, "New unrelated roll should not be force-closed")

-- Generation tracking also protects the case where Blizzard starts another roll
-- whose visible identity values happen to match the prior roll.
bonusRollShown = false
BonusRollFrame.spellID = 789
BonusRollFrame.endTime = currentTime + 90
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonNormal" }
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll and addon.hiddenBonusRoll.rollGeneration == 2)
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll == nil, "A later StartBonusRoll generation should clear stale suppression even with matching frame fields")

-- Explicit player restoration must bypass the transition guard.
bonusRollShown = false
BonusRollFrame.spellID = 900
BonusRollFrame.endTime = currentTime + 45
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonNormal" }
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
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
