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
local currentTime = 1000
local bonusRollShown = true
local timerValue
local chatMessages = {}
local createdCheckboxes = {}
local createdFontStrings = {}

SlashCmdList = {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, message)
		table.insert(chatMessages, message)
	end,
}
UIParent = {}

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		if field == "Version" then
			return "0.0.3"
		elseif field == "Author" then
			return "VoltageController156"
		end
	end,
}

function strtrim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function time()
	return currentTime
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

function CreateFrame(frameType, _, _, template)
	local frame = {
		frameType = frameType,
		template = template,
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
assert(chatLinkHook, "Chat-link hook was not installed")
assert(addon.settingsControls, "Custom settings controls were not created")
assert(SLASH_ROLLCURTAIN1 == "/rollcurtain", "Primary slash command missing")
assert(SLASH_ROLLCURTAIN2 == "/rcurtain", "Secondary slash command missing")
assert(SLASH_ROLLCURTAIN3 == "/rc", "Short /rc alias missing")
assert(SLASH_ROLLCURTAIN4 == "/rollc", "Short /rollc alias missing")

for _, checkbox in ipairs(createdCheckboxes) do
	assert(checkbox.template == "SettingsCheckboxTemplate", "Settings checkbox should use SettingsCheckboxTemplate")
end

for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	assert(addon.settingsControls[key].shown == false, key .. " should be hidden while Raids is disabled")
	assert(addon.settingsControls[key].label.shown == false, key .. " label should be hidden while Raids is disabled")
end
assert(addon.settingsControls.scenarios.point[3] == -316, "Other scenarios should move up while raid children are hidden")

local foundMetadata = false
for _, fontString in ipairs(createdFontStrings) do
	if fontString.text:find("0.0.3", 1, true) and fontString.text:find("VoltageController156", 1, true) then
		foundMetadata = true
		break
	end
end
assert(foundMetadata, "Settings should display version 0.0.3 and author")

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
	assert(checkbox.point[3] == -324, key .. " should share the raid-row Y position")
	local x = checkbox.point[2]
	if previousX then
		assert(x > previousX, "Raid difficulty checkboxes should be laid out left-to-right")
	end
	previousX = x
end
assert(addon.settingsControls.scenarios.point[3] == -376, "Other scenarios should move down while raid children are visible")

local story = addon.settingsControls.raidStory
local lfr = addon.settingsControls.raidLFR
local heroic = addon.settingsControls.raidHeroic
lfr:SetChecked(true)
lfr.scripts.OnClick(lfr)
heroic:SetChecked(true)
heroic.scripts.OnClick(heroic)
assert(RollCurtainDB.raidLFR == true, "LFR checkbox did not update the database")
assert(RollCurtainDB.raidHeroic == true, "Heroic checkbox did not update the database")

story:SetChecked(false)
story.scripts.OnClick(story)
assert(RollCurtainDB.raidsEnabled == true, "Raids should remain enabled while another child is selected")
lfr:SetChecked(false)
lfr.scripts.OnClick(lfr)
assert(RollCurtainDB.raidsEnabled == true, "Raids should remain enabled while Heroic is selected")
heroic:SetChecked(false)
heroic.scripts.OnClick(heroic)
assert(RollCurtainDB.raidsEnabled == false, "Raids should auto-disable when the last difficulty is deselected")
assert(raids:GetChecked() == false, "Raids checkbox should visually auto-deselect")
assert(addon.settingsControls.scenarios.point[3] == -316, "Other scenarios should move up when Raids auto-disables")

raids:SetChecked(true)
raids.scripts.OnClick(raids)
assert(RollCurtainDB.raidStory == true, "Re-enabling Raids should select Story Mode again")
lfr:SetChecked(true)
lfr.scripts.OnClick(lfr)
raids:SetChecked(false)
raids.scripts.OnClick(raids)
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
FireBonusRoll()
assert(closeCount == 1, "Enabled Delve suppression did not close the prompt")
assert(not bonusRollShown, "Suppressed bonus roll should be hidden")
assert(addon.hiddenBonusRoll, "Suppressed bonus roll was not recorded for recovery")
assert(chatMessages[#chatMessages]:find("Bonus roll hidden ", 1, true), "Concise hidden-roll message was not printed")
assert(chatMessages[#chatMessages]:find("Show Bonus Roll Prompt", 1, true), "Recovery chat link was not printed")
assert(not chatMessages[#chatMessages]:find("hidden in", 1, true), "Hidden-roll message should not include activity context")

currentTime = currentTime + 15
SlashCmdList.ROLLCURTAIN("show")
assert(restoreCount == 1, "Slash command did not restore the hidden prompt")
assert(bonusRollShown, "Restored bonus roll should be visible")
assert(addon.hiddenBonusRoll == nil, "Recovered bonus-roll state was not cleared")
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
RollCurtainDB.raidsEnabled = false
RollCurtainDB.raidLFR = true
FireBonusRoll()
assert(closeCount == 4, "Disabled Raids master switch should fail open")

RollCurtainDB.raidsEnabled = true
FireBonusRoll()
assert(closeCount == 5, "Enabled raid master + LFR child did not suppress the prompt")

RollCurtainDB = { raidLFR = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidsEnabled == true, "0.0.2 raid choices should enable the new Raids master switch")
assert(RollCurtainDB.raidLFR == true, "0.0.2 LFR preference was not preserved")
assert(RollCurtainDB.raidStory == false, "Migration should not invent a Story Mode choice")
assert(RollCurtainDB.raidMythic == false, "Existing Mythic preference was overwritten")

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
