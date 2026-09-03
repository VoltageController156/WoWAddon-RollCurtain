local addonName, addon = ...

-- Blizzard can re-add an existing BonusRollFrame to the loot container when
-- the player changes instances. If Roll Curtain already suppressed that exact
-- prompt, keep it hidden until it expires or the player explicitly restores it.

local allowingManualRestore = false
local groupLootHookInstalled = false
local showHookInstalled = false

local function HiddenRollIsActive()
	local hidden = addon.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not frame or frame ~= BonusRollFrame or frame.state ~= "prompt" then
		return false
	end
	if frame.endTime and type(time) == "function" and frame.endTime <= time() then
		addon.hiddenBonusRoll = nil
		return false
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
