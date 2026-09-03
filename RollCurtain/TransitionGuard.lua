local addonName, addon = ...

-- Blizzard can re-add an existing BonusRollFrame to the loot container when
-- the player changes instances. If Roll Curtain already suppressed that exact
-- prompt, keep it hidden until it expires or the player explicitly restores it.
-- BonusRollFrame itself is reused, so also track the identity/generation of the
-- actual roll to avoid suppressing a later, unrelated roll on the same frame.

local allowingManualRestore = false
local groupLootHookInstalled = false
local showHookInstalled = false
local startRollHookInstalled = false
local rollGeneration = 0

local function ClearHiddenRoll()
	addon.hiddenBonusRoll = nil
end

local function CaptureHiddenRollIdentity(hidden, frame, generation)
	if not hidden or not frame then return end
	hidden.rollGeneration = generation
	hidden.rollSpellID = frame.spellID
	hidden.rollEndTime = frame.endTime
end

local function HiddenRollIdentityMatches(hidden, frame)
	if not hidden or not frame then return false end
	if hidden.rollGeneration ~= nil and hidden.rollGeneration ~= rollGeneration then
		return false
	end
	if hidden.rollSpellID ~= nil and hidden.rollSpellID ~= frame.spellID then
		return false
	end
	if hidden.rollEndTime ~= nil and hidden.rollEndTime ~= frame.endTime then
		return false
	end
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

	-- A freshly suppressed roll is created by Core.lua without identity fields.
	-- Capture them lazily as a fallback in case Blizzard shows/re-adds the frame
	-- before the deferred StartBonusRoll observer runs.
	if hidden.rollGeneration == nil then
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
	-- Ignore a deferred callback if another roll started before it ran.
	if generation ~= rollGeneration then return end

	local hidden = addon.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not hidden or frame ~= BonusRollFrame then return end

	-- If the hidden record already belongs to an older generation, a new roll
	-- has started without Core.lua replacing the record. That means the new roll
	-- is not supposed to inherit the old suppression state.
	if hidden.rollGeneration ~= nil and hidden.rollGeneration ~= generation then
		ClearHiddenRoll()
		return
	end

	if hidden.rollGeneration == nil then
		CaptureHiddenRollIdentity(hidden, frame, generation)
		return
	end

	if not HiddenRollIdentityMatches(hidden, frame) then
		ClearHiddenRoll()
	end
end

local function ObserveStartedRoll()
	rollGeneration = rollGeneration + 1
	local generation = rollGeneration

	-- Core.lua also hooks BonusRollFrame_StartBonusRoll. Defer one frame so all
	-- post-hooks have finished and we can tell whether Core created a fresh
	-- hidden-roll record for this new roll or left an older record behind.
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
