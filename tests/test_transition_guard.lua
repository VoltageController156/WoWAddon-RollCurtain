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
	difficultyID = 23,
	instanceID = 100,
	encounterID = 200,
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

addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonMythic" }
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

-- A newly suppressed roll gets a stable identity after Blizzard and Core.lua
-- finish handling BonusRollFrame_StartBonusRoll.
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll.rollGeneration == 1, "Hidden roll should capture its roll generation")
assert(addon.hiddenBonusRoll.rollSpellID == 123, "Hidden roll should capture spellID")
assert(addon.hiddenBonusRoll.rollEndTime == currentTime + 60, "Hidden roll should capture endTime")
assert(addon.hiddenBonusRoll.rollDifficultyID == 23, "Hidden roll should capture difficultyID")

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

-- Real instance transitions can cause Blizzard to reconstruct the SAME active
-- bonus-roll prompt by calling StartBonusRoll again. The reconstructed deadline
-- can drift slightly because Blizzard computes endTime from the remaining
-- duration. That must refresh the hidden identity, not invalidate suppression.
BonusRollFrame.endTime = currentTime + 62 -- two-second reconstruction drift
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(bonusRollShown == false, "Reconstructed same roll should be immediately re-suppressed")
assert(closeCount == 3)
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll ~= nil, "Repeated StartBonusRoll for the same active roll must stay suppressed")
assert(addon.hiddenBonusRoll.rollGeneration == 2, "Same-roll reconstruction should refresh generation")
assert(addon.hiddenBonusRoll.rollEndTime == currentTime + 62, "Same-roll reconstruction should refresh deadline")

-- A materially different deadline is a genuinely new roll even when Blizzard
-- reuses the same frame and spellID. It must not inherit the old suppression.
BonusRollFrame.endTime = currentTime + 120
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(addon.hiddenBonusRoll == nil, "A new roll with a later deadline should invalidate stale hidden-roll state")
assert(bonusRollShown == true, "A new roll must remain visible until Core evaluates its own suppression settings")
assert(closeCount == 3)

-- A different spell identity is also always a new roll.
bonusRollShown = false
BonusRollFrame.spellID = 456
BonusRollFrame.endTime = currentTime + 90
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonMythic" }
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
assert(addon.hiddenBonusRoll and addon.hiddenBonusRoll.rollSpellID == 456)
BonusRollFrame.spellID = 789
BonusRollFrame:Show()
assert(addon.hiddenBonusRoll == nil, "Different spell identity should invalidate stale hidden-roll state")
assert(bonusRollShown == true)

-- Explicit player restoration must bypass the transition guard.
bonusRollShown = false
BonusRollFrame.spellID = 900
BonusRollFrame.endTime = currentTime + 45
BonusRollFrame.difficultyID = 23
BonusRollFrame.instanceID = 100
BonusRollFrame.encounterID = 200
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonMythic" }
BonusRollFrame_StartBonusRoll()
RunDeferredCallbacks()
local closeCountBeforeRestore = closeCount
assert(addon:ShowHiddenBonusRoll() == true)
assert(bonusRollShown == true, "Manual restore should be allowed to show the bonus roll")
assert(addon.hiddenBonusRoll == nil)
assert(closeCount == closeCountBeforeRestore, "Manual restore should not immediately re-close the prompt")

-- Expired hidden rolls should be discarded rather than guarded forever.
addon.hiddenBonusRoll = { frame = BonusRollFrame, contentType = "dungeonMythic" }
BonusRollFrame.endTime = currentTime - 1
bonusRollShown = false
GroupLootContainer_AddFrame(GroupLootContainer, BonusRollFrame)
assert(addon.hiddenBonusRoll == nil, "Expired hidden roll should be cleared")
assert(bonusRollShown == true, "Expired stale frame should not be force-closed by Roll Curtain")

print("Roll Curtain transition guard tests passed")
