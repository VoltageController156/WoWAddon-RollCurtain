local addon = {}
local eventHandler
local bonusRollHook
local chatLinkHook
local activePreyQuest
local activeDelve = false
local instanceType = "none"
local difficultyID
local closeCount = 0
local restoreCount = 0
local registeredCheckboxes = 0
local currentTime = 1000
local bonusRollShown = true
local timerValue
local chatMessages = {}

SlashCmdList = {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, message)
		table.insert(chatMessages, message)
	end,
}
CreateSettingsListSectionHeaderInitializer = function() return {} end

function strtrim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function time()
	return currentTime
end

function CreateFrame()
	return {
		RegisterEvent = function() end,
		SetScript = function(_, scriptName, callback)
			if scriptName == "OnEvent" then
				eventHandler = callback
			end
		end,
	}
end

function hooksecurefunc(name, callback)
	if name == "BonusRollFrame_StartBonusRoll" then
		bonusRollHook = callback
	elseif name == "SetItemRef" then
		chatLinkHook = callback
	end
end

function BonusRollFrame_StartBonusRoll() end
function BonusRollFrame_CloseBonusRoll()
	closeCount = closeCount + 1
	bonusRollShown = false
end

function SetItemRef() end

GroupLootContainer = {}
function GroupLootContainer_AddFrame(_, frame)
	restoreCount = restoreCount + 1
	bonusRollShown = true
	assert(frame == BonusRollFrame, "Unexpected frame restored")
end

BonusRollFrame = {
	state = "prompt",
	endTime = currentTime + 60,
	remaining = 60,
	PromptFrame = {
		Timer = {
			SetValue = function(_, value)
				timerValue = value
			end,
		},
	},
	IsShown = function() return bonusRollShown end,
}

local function FireBonusRoll()
	bonusRollShown = true
	BonusRollFrame.state = "prompt"
	BonusRollFrame.endTime = currentTime + 60
	BonusRollFrame.remaining = 60
	timerValue = 60
	bonusRollHook()
end

C_QuestLog = {
	GetActivePreyQuest = function() return activePreyQuest end,
}

C_DelvesUI = {
	HasActiveDelve = function() return activeDelve end,
}

C_PartyInfo = {
	IsDelveInProgress = function() return false end,
}

function GetInstanceInfo()
	return "Test Instance", instanceType, difficultyID
end

Settings = {
	VarType = { Boolean = "boolean" },
	RegisterVerticalLayoutCategory = function()
		local category = { GetID = function() return 1 end }
		local layout = { AddInitializer = function() end }
		return category, layout
	end,
	RegisterAddOnSetting = function(_, _, key, database, _, _, defaultValue)
		if database[key] == nil then
			database[key] = defaultValue
		end
		return {}
	end,
	CreateCheckbox = function()
		registeredCheckboxes = registeredCheckboxes + 1
	end,
	RegisterAddOnCategory = function() end,
	GetSetting = function() return nil end,
	OpenToCategory = function() end,
}

assert(loadfile("RollCurtain/Core.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/Settings.lua"))("RollCurtain", addon)
assert(eventHandler, "Core did not register an event handler")

eventHandler(nil, "ADDON_LOADED", "RollCurtain")

assert(RollCurtainDB.delves == true, "Delves should be hidden by default")
assert(RollCurtainDB.prey == true, "Prey should be hidden by default")
assert(RollCurtainDB.world == true, "Outdoor prompts should be hidden by default")
assert(RollCurtainDB.dungeons == false, "Dungeons should remain visible by default")
assert(RollCurtainDB.raidStory == false, "Story Mode raids should remain visible by default")
assert(RollCurtainDB.raidLFR == false, "LFR raids should remain visible by default")
assert(RollCurtainDB.raidNormal == false, "Normal raids should remain visible by default")
assert(RollCurtainDB.raidHeroic == false, "Heroic raids should remain visible by default")
assert(RollCurtainDB.raidMythic == false, "Mythic raids should remain visible by default")
assert(RollCurtainDB.raids == nil, "Legacy raid setting should not remain in the database")
assert(RollCurtainDB.scenarios == false, "Other scenarios should remain visible by default")
assert(registeredCheckboxes == 10, "Expected ten settings checkboxes")
assert(bonusRollHook, "Bonus-roll hook was not installed")
assert(chatLinkHook, "Chat-link hook was not installed")

activePreyQuest = 12345
activeDelve = true
instanceType = "raid"
assert(addon:GetCurrentContentType() == "prey", "Prey should have classification priority")

activePreyQuest = nil
assert(addon:GetCurrentContentType() == "delves", "Active Delve was not detected")

activeDelve = false
instanceType = "party"
assert(addon:GetCurrentContentType() == "dungeons", "Dungeon was not detected")

instanceType = "raid"
difficultyID = 220
assert(addon:GetCurrentContentType() == "raidStory", "Story Mode raid was not detected")
difficultyID = 17
assert(addon:GetCurrentContentType() == "raidLFR", "LFR raid was not detected")
difficultyID = 14
assert(addon:GetCurrentContentType() == "raidNormal", "Normal raid was not detected")
difficultyID = 15
assert(addon:GetCurrentContentType() == "raidHeroic", "Heroic raid was not detected")
difficultyID = 16
assert(addon:GetCurrentContentType() == "raidMythic", "Mythic raid was not detected")
difficultyID = nil
assert(addon:GetCurrentContentType() == "raids", "Unknown raid difficulty should fail open")

instanceType = "scenario"
assert(addon:GetCurrentContentType() == "scenarios", "Scenario was not detected")

instanceType = "none"
assert(addon:GetCurrentContentType() == "world", "Outdoor content was not detected")

instanceType = "pvp"
assert(addon:GetCurrentContentType() == "unknown", "Unknown content should fail open")

activeDelve = true
FireBonusRoll()
assert(closeCount == 1, "Enabled Delve suppression did not close the prompt")
assert(not bonusRollShown, "Suppressed bonus roll should be hidden")
assert(addon.hiddenBonusRoll, "Suppressed bonus roll was not recorded for recovery")
assert(chatMessages[#chatMessages]:find("Bonus roll hidden ", 1, true), "Concise hidden-roll message was not printed")
assert(chatMessages[#chatMessages]:find("Show Bonus Roll Prompt", 1, true), "Recovery chat link was not printed")
assert(not chatMessages[#chatMessages]:find("hidden in", 1, true), "Hidden-roll message should not include activity context")

-- Time spent hidden still counts down. Restore should synchronize Blizzard's
-- remaining field and timer before the original frame is re-added.
currentTime = currentTime + 15
SlashCmdList.ROLLCURTAIN("show")
assert(restoreCount == 1, "Slash command did not restore the hidden prompt")
assert(bonusRollShown, "Restored bonus roll should be visible")
assert(addon.hiddenBonusRoll == nil, "Recovered bonus roll state was not cleared")
assert(BonusRollFrame.remaining == 45, "Restored roll did not synchronize its remaining time")
assert(timerValue == 45, "Restored roll timer did not synchronize its displayed value")

FireBonusRoll()
assert(closeCount == 2, "Second Delve suppression did not close the prompt")
chatLinkHook("rollcurtain:show")
assert(restoreCount == 2, "Clickable chat link did not restore the hidden prompt")
assert(bonusRollShown, "Chat-link recovery should show the bonus roll")

FireBonusRoll()
assert(closeCount == 3, "Third Delve suppression did not close the prompt")
currentTime = BonusRollFrame.endTime + 1
SlashCmdList.ROLLCURTAIN("show")
assert(restoreCount == 2, "Expired bonus roll should not be restored")
assert(addon.hiddenBonusRoll == nil, "Expired recovery state was not cleared")
assert(chatMessages[#chatMessages]:find("no longer available", 1, true), "Expired roll did not report a clean failure")

currentTime = 1000
activeDelve = false
instanceType = "party"
FireBonusRoll()
assert(closeCount == 3, "Disabled dungeon suppression closed the prompt")

RollCurtainDB.dungeons = true
FireBonusRoll()
assert(closeCount == 4, "Enabled dungeon suppression did not close the prompt")

instanceType = "raid"
difficultyID = 17
RollCurtainDB.raidLFR = false
FireBonusRoll()
assert(closeCount == 4, "Disabled LFR suppression closed the prompt")

RollCurtainDB.raidLFR = true
FireBonusRoll()
assert(closeCount == 5, "Enabled LFR suppression did not close the prompt")

RollCurtainDB = { raids = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidStory == true, "Legacy raid setting was not migrated to Story Mode")
assert(RollCurtainDB.raidLFR == true, "Legacy raid setting was not migrated to LFR")
assert(RollCurtainDB.raidNormal == true, "Legacy raid setting was not migrated to Normal")
assert(RollCurtainDB.raidHeroic == true, "Legacy raid setting was not migrated to Heroic")
assert(RollCurtainDB.raidMythic == false, "Existing per-difficulty setting was overwritten")
assert(RollCurtainDB.raids == nil, "Legacy raid setting was not removed after migration")

print("Roll Curtain tests passed")
