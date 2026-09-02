local addon = {}
local eventHandler
local bonusRollHook
local activePreyQuest
local activeDelve = false
local instanceType = "none"
local difficultyID
local closeCount = 0
local registeredCheckboxes = 0

SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
CreateSettingsListSectionHeaderInitializer = function() return {} end

function strtrim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
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

function hooksecurefunc(_, callback)
	bonusRollHook = callback
end

function BonusRollFrame_StartBonusRoll() end
function BonusRollFrame_CloseBonusRoll()
	closeCount = closeCount + 1
end

BonusRollFrame = {
	state = "prompt",
	IsShown = function() return true end,
}

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
bonusRollHook()
assert(closeCount == 1, "Enabled Delve suppression did not close the prompt")

activeDelve = false
instanceType = "party"
bonusRollHook()
assert(closeCount == 1, "Disabled dungeon suppression closed the prompt")

RollCurtainDB.dungeons = true
bonusRollHook()
assert(closeCount == 2, "Enabled dungeon suppression did not close the prompt")

instanceType = "raid"
difficultyID = 17
bonusRollHook()
assert(closeCount == 2, "Disabled LFR suppression closed the prompt")

RollCurtainDB.raidLFR = true
bonusRollHook()
assert(closeCount == 3, "Enabled LFR suppression did not close the prompt")

RollCurtainDB = { raids = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidStory == true, "Legacy raid setting was not migrated to Story Mode")
assert(RollCurtainDB.raidLFR == true, "Legacy raid setting was not migrated to LFR")
assert(RollCurtainDB.raidNormal == true, "Legacy raid setting was not migrated to Normal")
assert(RollCurtainDB.raidHeroic == true, "Legacy raid setting was not migrated to Heroic")
assert(RollCurtainDB.raidMythic == false, "Existing per-difficulty setting was overwritten")
assert(RollCurtainDB.raids == nil, "Legacy raid setting was not removed after migration")

print("Roll Curtain tests passed")
