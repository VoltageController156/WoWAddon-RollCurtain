local addon = {}
local eventHandler
local bonusRollHook
local activePreyQuest
local activeDelve = false
local instanceType = "none"
local difficultyID
local closeCount = 0
local registeredCheckboxes = 0
local settingsByVariable = {}
local initializersByKey = {}
local layoutInitializers = {}

SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
CreateSettingsListSectionHeaderInitializer = function(label)
	return { label = label }
end

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		if field == "Version" then
			return "0.0.2"
		elseif field == "Author" then
			return "VoltageController156"
		end
	end,
}

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
		local layout = {
			AddInitializer = function(_, initializer)
				table.insert(layoutInitializers, initializer)
			end,
		}
		return category, layout
	end,
	RegisterAddOnSetting = function(_, variable, key, database, _, _, defaultValue)
		if database[key] == nil then
			database[key] = defaultValue
		end

		local setting = {
			variable = variable,
			key = key,
			database = database,
		}

		function setting:GetValue()
			return self.database[self.key]
		end

		function setting:SetValue(value)
			self.database[self.key] = value
			if self.callback then
				self.callback(nil, self, value)
			end
		end

		settingsByVariable[variable] = setting
		return setting
	end,
	CreateCheckbox = function(_, setting)
		registeredCheckboxes = registeredCheckboxes + 1
		local initializer = { setting = setting }

		function initializer:SetParentInitializer(parentInitializer, predicate)
			self.parentInitializer = parentInitializer
			self.parentPredicate = predicate
		end

		function initializer:AddShownPredicate(predicate)
			self.shownPredicate = predicate
		end

		initializersByKey[setting.key] = initializer
		return initializer
	end,
	SetOnValueChangedCallback = function(variable, callback)
		assert(settingsByVariable[variable], "Unknown settings variable: " .. tostring(variable))
		settingsByVariable[variable].callback = callback
	end,
	SetValue = function(variable, value)
		assert(settingsByVariable[variable], "Unknown settings variable: " .. tostring(variable))
		settingsByVariable[variable]:SetValue(value)
	end,
	GetSetting = function(variable)
		return settingsByVariable[variable]
	end,
	RegisterAddOnCategory = function() end,
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
assert(RollCurtainDB.raidsEnabled == false, "Raids master switch should be disabled by default")
assert(RollCurtainDB.raidStory == false, "Story Mode raids should remain visible by default")
assert(RollCurtainDB.raidLFR == false, "LFR raids should remain visible by default")
assert(RollCurtainDB.raidNormal == false, "Normal raids should remain visible by default")
assert(RollCurtainDB.raidHeroic == false, "Heroic raids should remain visible by default")
assert(RollCurtainDB.raidMythic == false, "Mythic raids should remain visible by default")
assert(RollCurtainDB.raids == nil, "Legacy raid setting should not remain in the database")
assert(RollCurtainDB.scenarios == false, "Other scenarios should remain visible by default")
assert(registeredCheckboxes == 11, "Expected eleven settings checkboxes")
assert(bonusRollHook, "Bonus-roll hook was not installed")

local raidParentInitializer = initializersByKey.raidsEnabled
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	local initializer = initializersByKey[key]
	assert(initializer.parentInitializer == raidParentInitializer, key .. " should be nested under Raids")
	assert(type(initializer.shownPredicate) == "function", key .. " should have a shown predicate")
	assert(initializer.shownPredicate() == false, key .. " should be hidden while Raids is disabled")
end

local aboutHeader = layoutInitializers[#layoutInitializers]
assert(aboutHeader and aboutHeader.label:find("0.0.2", 1, true), "Settings should display the add-on version")
assert(aboutHeader.label:find("VoltageController156", 1, true), "Settings should display the author")

-- Enabling the raid group automatically selects Story Mode only.
Settings.SetValue(addon.settingVariables.raidsEnabled, true)
assert(RollCurtainDB.raidsEnabled == true, "Raids master switch was not enabled")
assert(RollCurtainDB.raidStory == true, "Story Mode should be selected when Raids is enabled")
assert(RollCurtainDB.raidLFR == false, "LFR should remain opt-in")
assert(RollCurtainDB.raidNormal == false, "Normal should remain opt-in")
assert(RollCurtainDB.raidHeroic == false, "Heroic should remain opt-in")
assert(RollCurtainDB.raidMythic == false, "Mythic should remain opt-in")
assert(initializersByKey.raidStory.shownPredicate() == true, "Raid children should appear while Raids is enabled")

-- Child choices are cleared when the master raid switch is disabled.
Settings.SetValue(addon.settingVariables.raidLFR, true)
Settings.SetValue(addon.settingVariables.raidHeroic, true)
Settings.SetValue(addon.settingVariables.raidsEnabled, false)
assert(RollCurtainDB.raidsEnabled == false, "Raids master switch was not disabled")
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	assert(RollCurtainDB[key] == false, key .. " should be cleared when Raids is disabled")
end
assert(initializersByKey.raidStory.shownPredicate() == false, "Raid children should hide while Raids is disabled")

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

-- A child raid setting alone must not suppress while the master switch is off.
instanceType = "raid"
difficultyID = 17
RollCurtainDB.raidsEnabled = false
RollCurtainDB.raidLFR = true
bonusRollHook()
assert(closeCount == 2, "Disabled Raids master switch should fail open")

RollCurtainDB.raidsEnabled = true
bonusRollHook()
assert(closeCount == 3, "Enabled raid master + LFR child did not suppress the prompt")

-- Upgrade from 0.0.2: preserve existing per-difficulty choices and derive the
-- new master switch from them.
RollCurtainDB = { raidLFR = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidsEnabled == true, "0.0.2 raid choices should enable the new Raids master switch")
assert(RollCurtainDB.raidLFR == true, "0.0.2 LFR preference was not preserved")
assert(RollCurtainDB.raidStory == false, "Migration should not invent a Story Mode choice for existing 0.0.2 users")
assert(RollCurtainDB.raidMythic == false, "Existing Mythic preference was overwritten")

-- Upgrade directly from 0.0.1: preserve the old all-raids behavior.
RollCurtainDB = { raids = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidsEnabled == true, "Legacy raid setting was not migrated to the Raids master switch")
assert(RollCurtainDB.raidStory == true, "Legacy raid setting was not migrated to Story Mode")
assert(RollCurtainDB.raidLFR == true, "Legacy raid setting was not migrated to LFR")
assert(RollCurtainDB.raidNormal == true, "Legacy raid setting was not migrated to Normal")
assert(RollCurtainDB.raidHeroic == true, "Legacy raid setting was not migrated to Heroic")
assert(RollCurtainDB.raidMythic == false, "Existing per-difficulty setting was overwritten")
assert(RollCurtainDB.raids == nil, "Legacy raid setting was not removed after migration")

print("Roll Curtain tests passed")
