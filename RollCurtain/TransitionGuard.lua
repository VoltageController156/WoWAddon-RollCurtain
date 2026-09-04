local addonName, addon = ...

-- Blizzard can rebuild an active BonusRollFrame when the player changes zones
-- or enters another instance. If Roll Curtain already suppressed that same
-- underlying prompt, keep it hidden until it expires or the player explicitly
-- restores it. BonusRollFrame itself is reused for every roll, so compare the
-- roll's stable identity instead of treating every StartBonusRoll call as new.

local END_TIME_TOLERANCE_SECONDS = 5
local allowingManualRestore = false
local groupLootHookInstalled = false
local showHookInstalled = false
local startRollHookInstalled = false
local rollGeneration = 0

local function ClearHiddenRoll()
	addon.hiddenBonusRoll = nil
	if type(addon.RefreshMinimapRecoveryGlow) == "function" then
		addon:RefreshMinimapRecoveryGlow()
	end
end

local function CaptureHiddenRollIdentity(hidden, frame, generation)
	if not hidden or not frame then return end
	hidden.rollGeneration = generation
	hidden.rollSpellID = frame.spellID
	hidden.rollEndTime = frame.endTime
	hidden.rollDifficultyID = frame.difficultyID
	hidden.rollInstanceID = frame.instanceID
	hidden.rollEncounterID = frame.encounterID
end

local function ValuesConflict(a, b)
	return a ~= nil and b ~= nil and a ~= b
end

local function EndTimesConflict(a, b)
	if type(a) ~= "number" or type(b) ~= "number" then return false end
	return math.abs(a - b) > END_TIME_TOLERANCE_SECONDS
end

local function HiddenRollIdentityMatches(hidden, frame)
	if not hidden or not frame then return false end
	if ValuesConflict(hidden.rollSpellID, frame.spellID) then return false end
	if EndTimesConflict(hidden.rollEndTime, frame.endTime) then return false end
	if ValuesConflict(hidden.rollDifficultyID, frame.difficultyID) then return false end
	if ValuesConflict(hidden.rollInstanceID, frame.instanceID) then return false end
	if ValuesConflict(hidden.rollEncounterID, frame.encounterID) then return false end
	return true
end

local function HiddenRollIsActive()
	local hidden = addon.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not frame or frame ~= BonusRollFrame or frame.state ~= "prompt" then
		return false
	end

	if not HiddenRollIdentityMatches(hidden, frame) then
		ClearHiddenRoll()
		return false
	end

	if frame.endTime and type(time) == "function" and frame.endTime <= time() then
		ClearHiddenRoll()
		return false
	end

	-- A freshly suppressed roll is created without identity fields. Capture them
	-- lazily so a zone transition can be guarded even before the deferred
	-- StartBonusRoll observer has run.
	if hidden.rollSpellID == nil and hidden.rollEndTime == nil then
		CaptureHiddenRollIdentity(hidden, frame, rollGeneration)
	end
	return true
end

local function ResuppressHiddenRoll(frame)
	if allowingManualRestore then return end
	local hidden = addon.hiddenBonusRoll
	if not hidden or hidden.frame ~= frame then return end
	if not HiddenRollIsActive() then return end
	if frame.IsShown and frame:IsShown() and type(BonusRollFrame_CloseBonusRoll) == "function" then
		BonusRollFrame_CloseBonusRoll()
	end
end

local function SyncHiddenRollIdentity(generation)
	-- Ignore a deferred callback if another StartBonusRoll call happened first.
	if generation ~= rollGeneration then return end

	local hidden = addon.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not hidden or frame ~= BonusRollFrame then return end

	-- A zone/instance transition can invoke BonusRollFrame_StartBonusRoll again for
	-- the same active prompt. Blizzard rebuilds frame.endTime from the remaining
	-- duration, so allow a small deadline drift and refresh the captured identity.
	-- A genuinely new roll changes the stable identity or has a meaningfully later
	-- deadline and must not inherit the old suppression state.
	if HiddenRollIdentityMatches(hidden, frame) then
		CaptureHiddenRollIdentity(hidden, frame, generation)
		ResuppressHiddenRoll(frame)
	else
		ClearHiddenRoll()
	end
end

local function ObserveStartedRoll()
	rollGeneration = rollGeneration + 1
	local generation = rollGeneration

	-- Core.lua also hooks BonusRollFrame_StartBonusRoll. Defer one frame so all
	-- post-hooks have finished and the rebuilt frame contains its final identity.
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			SyncHiddenRollIdentity(generation)
		end)
	else
		SyncHiddenRollIdentity(generation)
	end
end

local function InstallTransitionHooks()
	if type(hooksecurefunc) ~= "function" then return end

	if not groupLootHookInstalled and type(GroupLootContainer_AddFrame) == "function" then
		hooksecurefunc("GroupLootContainer_AddFrame", function(_, frame)
			if frame == BonusRollFrame then
				ResuppressHiddenRoll(frame)
			end
		end)
		groupLootHookInstalled = true
	end

	if not showHookInstalled and BonusRollFrame and type(BonusRollFrame.Show) == "function" then
		hooksecurefunc(BonusRollFrame, "Show", function(frame)
			ResuppressHiddenRoll(frame)
		end)
		showHookInstalled = true
	end

	if not startRollHookInstalled and type(BonusRollFrame_StartBonusRoll) == "function" then
		hooksecurefunc("BonusRollFrame_StartBonusRoll", ObserveStartedRoll)
		startRollHookInstalled = true
	end
end

local originalShowHiddenBonusRoll = addon.ShowHiddenBonusRoll
if type(originalShowHiddenBonusRoll) == "function" then
	addon.ShowHiddenBonusRoll = function(self, ...)
		allowingManualRestore = true
		local ok, result = pcall(originalShowHiddenBonusRoll, self, ...)
		allowingManualRestore = false
		if not ok then error(result) end
		return result
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
	if event == "ADDON_LOADED" then
		if loadedAddonName ~= addonName and loadedAddonName ~= "Blizzard_UIPanels_Game" then return end
		InstallTransitionHooks()
	elseif event == "PLAYER_LOGIN" then
		InstallTransitionHooks()
	elseif event == "PLAYER_ENTERING_WORLD" then
		InstallTransitionHooks()
		if BonusRollFrame then
			ResuppressHiddenRoll(BonusRollFrame)
		end
	end
end)

InstallTransitionHooks()
