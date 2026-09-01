local addon = {}
local eventHandler
local bonusRollHook
local activePreyQuest
local activeDelve = false
local instanceType = "none"
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
	return "Test Instance", instanceType
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
assert(RollCurtainDB.raids == false, "Raids should remain visible by default")
assert(RollCurtainDB.scenarios == false, "Other scenarios should remain visible by default")
assert(registeredCheckboxes == 6, "Expected six settings checkboxes")
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
assert(addon:GetCurrentContentType() == "raids", "Raid was not detected")

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

print("Roll Curtain tests passed")
