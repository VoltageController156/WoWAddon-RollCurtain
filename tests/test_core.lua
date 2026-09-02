local addon = {}
local eventHandler
local bonusRollHook
local activePreyQuest
local activeDelve = false
local instanceType = "none"
local difficultyID
local closeCount = 0
local createdCheckboxes = {}
local createdFontStrings = {}

SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UIParent = {}

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

local function NewFontString()
	local fontString = { shown = true, text = "" }

	function fontString:SetPoint(...)
		self.point = { ... }
	end

	function fontString:SetText(text)
		self.text = text
	end

	function fontString:Show()
		self.shown = true
	end

	function fontString:Hide()
		self.shown = false
	end

	table.insert(createdFontStrings, fontString)
	return fontString
end

function CreateFrame(frameType)
	local frame = {
		frameType = frameType,
		scripts = {},
		shown = true,
		checked = false,
	}

	function frame:RegisterEvent() end

	function frame:SetScript(scriptName, callback)
		self.scripts[scriptName] = callback
		if scriptName == "OnEvent" and not eventHandler then
			eventHandler = callback
		end
	end

	function frame:SetSize(width, height)
		self.width = width
		self.height = height
	end

	function frame:SetPoint(...)
		self.point = { ... }
	end

	function frame:ClearAllPoints()
		self.point = nil
	end

	function frame:SetText(text)
		self.text = text
	end

	function frame:CreateFontString()
		return NewFontString()
	end

	function frame:SetChecked(value)
		self.checked = value == true
	end

	function frame:GetChecked()
		return self.checked
	end

	function frame:Show()
		self.shown = true
	end

	function frame:Hide()
		self.shown = false
	end

	function frame:IsShown()
		return self.shown
	end

	if frameType == "CheckButton" then
		table.insert(createdCheckboxes, frame)
	end

	return frame
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
	RegisterCanvasLayoutCategory = function()
		return { GetID = function() return 1 end }
	end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
	GetSetting = function() return nil end,
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
assert(#createdCheckboxes == 11, "Expected eleven custom settings checkboxes")
assert(bonusRollHook, "Bonus-roll hook was not installed")
assert(addon.settingsControls, "Custom settings controls were not created")

-- Raid children start hidden when the master switch is disabled.
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	assert(addon.settingsControls[key].shown == false, key .. " should be hidden while Raids is disabled")
	assert(addon.settingsControls[key].label.shown == false, key .. " label should be hidden while Raids is disabled")
end
assert(addon.settingsControls.scenarios.point[3] == -240, "Other scenarios should move up while raid children are hidden")

-- Version and author are visible somewhere on the custom canvas.
local foundMetadata = false
for _, fontString in ipairs(createdFontStrings) do
	if fontString.text:find("0.0.2", 1, true) and fontString.text:find("VoltageController156", 1, true) then
		foundMetadata = true
		break
	end
end
assert(foundMetadata, "Settings should display the add-on version and author")

-- Enabling Raids shows a horizontal row and selects Story Mode only.
local raids = addon.settingsControls.raidsEnabled
raids:SetChecked(true)
raids.scripts.OnClick(raids)
assert(RollCurtainDB.raidsEnabled == true, "Raids master switch was not enabled")
assert(RollCurtainDB.raidStory == true, "Story Mode should be selected when Raids is enabled")
assert(RollCurtainDB.raidLFR == false, "LFR should remain opt-in")
assert(RollCurtainDB.raidNormal == false, "Normal should remain opt-in")
assert(RollCurtainDB.raidHeroic == false, "Heroic should remain opt-in")
assert(RollCurtainDB.raidMythic == false, "Mythic should remain opt-in")

local previousX
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	local checkbox = addon.settingsControls[key]
	assert(checkbox.shown == true, key .. " should be visible while Raids is enabled")
	assert(checkbox.point[3] == -270, key .. " should share the horizontal raid-row Y position")
	local x = checkbox.point[2]
	if previousX then
		assert(x > previousX, "Raid difficulty checkboxes should be laid out left-to-right")
	end
	previousX = x
end
assert(addon.settingsControls.scenarios.point[3] == -280, "Other scenarios should move down while raid children are visible")

-- Child choices persist while the master remains enabled.
local lfr = addon.settingsControls.raidLFR
local heroic = addon.settingsControls.raidHeroic
lfr:SetChecked(true)
lfr.scripts.OnClick(lfr)
heroic:SetChecked(true)
heroic.scripts.OnClick(heroic)
assert(RollCurtainDB.raidLFR == true, "LFR checkbox did not update the saved database")
assert(RollCurtainDB.raidHeroic == true, "Heroic checkbox did not update the saved database")

-- Disabling Raids clears every child and hides the horizontal row.
raids:SetChecked(false)
raids.scripts.OnClick(raids)
assert(RollCurtainDB.raidsEnabled == false, "Raids master switch was not disabled")
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	assert(RollCurtainDB[key] == false, key .. " should be cleared when Raids is disabled")
	assert(addon.settingsControls[key].shown == false, key .. " should hide when Raids is disabled")
end

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
