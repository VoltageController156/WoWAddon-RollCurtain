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
local acceptCount = 0
local currentTime = 1000
local bonusRollShown = true
local timerValue
local chatMessages = {}
local createdCheckboxes = {}
local createdFontStrings = {}
local popupShown

SlashCmdList = {}
StaticPopupDialogs = {}
CANCEL = "Cancel"
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(chatMessages, message) end }
UIParent = {}

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		if field == "Version" then return "0.0.5" end
		if field == "Author" then return "VoltageController156" end
	end,
}

C_CurrencyInfo = {
	GetCurrencyInfo = function() return { quantity = 3, iconFileID = 1 } end,
}

function GetLootSpecialization() return 270 end
function GetSpecializationInfoByID(id) return id, "Mistweaver" end
function GetSpecialization() return 1 end
function GetSpecializationInfo(index) return 270, "Mistweaver" end
function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
function time() return currentTime end

function StaticPopup_Show(key, textArg1, _, data)
	popupShown = { key = key, text = textArg1, data = data }
	return popupShown
end

local function NewFontString()
	local fontString = { shown = true, text = "" }
	function fontString:SetPoint(...) self.point = { ... } end
	function fontString:SetText(text) self.text = text end
	function fontString:Show() self.shown = true end
	function fontString:Hide() self.shown = false end
	table.insert(createdFontStrings, fontString)
	return fontString
end

function CreateFrame(frameType, _, _, template)
	local frame = { frameType = frameType, template = template, scripts = {}, shown = true, checked = false }
	function frame:RegisterEvent() end
	function frame:SetScript(scriptName, callback)
		self.scripts[scriptName] = callback
		if scriptName == "OnEvent" and not eventHandler then eventHandler = callback end
	end
	function frame:GetScript(scriptName) return self.scripts[scriptName] end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:SetPoint(...) self.point = { ... } end
	function frame:ClearAllPoints() self.point = nil end
	function frame:SetText(text) self.text = text end
	function frame:CreateFontString() return NewFontString() end
	function frame:SetChecked(value) self.checked = value == true end
	function frame:GetChecked() return self.checked end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:IsShown() return self.shown end
	if frameType == "CheckButton" then table.insert(createdCheckboxes, frame) end
	return frame
end

function hooksecurefunc(name, callback)
	if name == "BonusRollFrame_StartBonusRoll" then bonusRollHook = callback
	elseif name == "SetItemRef" then chatLinkHook = callback end
end

function BonusRollFrame_StartBonusRoll() end
function BonusRollFrame_CloseBonusRoll()
	closeCount = closeCount + 1
	bonusRollShown = false
end
function SetItemRef() end

local rollButton = { scripts = {}, enabled = true }
rollButton.scripts.OnClick = function()
	acceptCount = acceptCount + 1
end
function rollButton:GetScript(name) return self.scripts[name] end
function rollButton:SetScript(name, callback) self.scripts[name] = callback end
function rollButton:Enable() self.enabled = true end
function rollButton:Disable() self.enabled = false end

GroupLootContainer = {}
function GroupLootContainer_AddFrame(_, frame)
	restoreCount = restoreCount + 1
	bonusRollShown = true
	assert(frame == BonusRollFrame, "Unexpected frame restored")
end

BonusRollFrame = {
	state = "prompt",
	spellID = 123,
	endTime = currentTime + 60,
	remaining = 60,
	CurrentCountFrame = { currencyID = 777 },
	PromptFrame = {
		RollButton = rollButton,
		Timer = { SetValue = function(_, value) timerValue = value end },
	},
	IsShown = function() return bonusRollShown end,
}

local function FireBonusRoll(cost)
	bonusRollShown = true
	BonusRollFrame.state = "prompt"
	BonusRollFrame.spellID = 123
	BonusRollFrame.endTime = currentTime + 60
	BonusRollFrame.remaining = 60
	BonusRollFrame.CurrentCountFrame.currencyID = 777
	timerValue = 60
	bonusRollHook(123, "", 60, 777, cost or 1, difficultyID)
end

C_QuestLog = { GetActivePreyQuest = function() return activePreyQuest end }
C_DelvesUI = { HasActiveDelve = function() return activeDelve end }
C_PartyInfo = { IsDelveInProgress = function() return false end }
function GetInstanceInfo() return "Test Instance", instanceType, difficultyID end

Settings = {
	RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
	GetSetting = function() return nil end,
}

assert(loadfile("RollCurtain/Core.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/Settings.lua"))("RollCurtain", addon)
assert(eventHandler, "Core did not register an event handler")
eventHandler(nil, "ADDON_LOADED", "RollCurtain")

-- Fresh 0.0.5 defaults.
assert(RollCurtainDB.delves == true)
assert(RollCurtainDB.prey == true)
assert(RollCurtainDB.world == true)
assert(RollCurtainDB.dungeonsEnabled == true, "Dungeons should be enabled by default")
assert(RollCurtainDB.dungeonNormal == true, "Normal dungeons should be hidden by default")
assert(RollCurtainDB.dungeonHeroic == true, "Heroic dungeons should be hidden by default")
assert(RollCurtainDB.dungeonMythic == true, "Mythic dungeons should be hidden by default")
assert(RollCurtainDB.dungeonMythicPlus == false, "Mythic+ should remain visible by default")
assert(RollCurtainDB.raidsEnabled == false)
assert(RollCurtainDB.raidStory == false)
assert(RollCurtainDB.raidLFR == false)
assert(RollCurtainDB.raidNormal == false)
assert(RollCurtainDB.raidHeroic == false)
assert(RollCurtainDB.raidMythic == false)
assert(RollCurtainDB.scenarios == false)
assert(RollCurtainDB.confirmBonusRoll == true, "Bonus-roll confirmation should be enabled by default")
assert(RollCurtainDB.dungeons == nil)
assert(RollCurtainDB.raids == nil)
assert(#createdCheckboxes == 16, "Expected sixteen custom settings checkboxes")
assert(bonusRollHook and chatLinkHook, "Required hooks were not installed")
assert(addon.confirmBonusRollHookInstalled, "Bonus-roll confirmation hook was not installed")

for _, checkbox in ipairs(createdCheckboxes) do
	assert(checkbox.template == "SettingsCheckboxTemplate")
end

for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }) do
	assert(addon.settingsControls[key].shown == true, key .. " should show while Dungeons is enabled")
end
for _, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
	assert(addon.settingsControls[key].shown == false, key .. " should hide while Raids is disabled")
end
assert(addon.settingsControls.confirmBonusRoll:GetChecked() == true)

local foundMetadata = false
for _, fontString in ipairs(createdFontStrings) do
	if fontString.text:find("0.0.5", 1, true) and fontString.text:find("VoltageController156", 1, true) then foundMetadata = true end
end
assert(foundMetadata, "Settings should display version 0.0.5 and author")

-- Dungeon parent/child layout and behavior.
local dungeons = addon.settingsControls.dungeonsEnabled
local dungeonNormal = addon.settingsControls.dungeonNormal
local dungeonHeroic = addon.settingsControls.dungeonHeroic
local dungeonMythic = addon.settingsControls.dungeonMythic
local dungeonMythicPlus = addon.settingsControls.dungeonMythicPlus
local previousX
for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }) do
	local checkbox = addon.settingsControls[key]
	if previousX then assert(checkbox.point[2] > previousX, "Dungeon difficulties should be horizontal") end
	previousX = checkbox.point[2]
end

dungeons:SetChecked(false)
dungeons.scripts.OnClick(dungeons)
assert(RollCurtainDB.dungeonsEnabled == false)
for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }) do
	assert(RollCurtainDB[key] == false)
	assert(addon.settingsControls[key].shown == false)
end

dungeons:SetChecked(true)
dungeons.scripts.OnClick(dungeons)
assert(RollCurtainDB.dungeonNormal == true)
assert(RollCurtainDB.dungeonHeroic == true)
assert(RollCurtainDB.dungeonMythic == true)
assert(RollCurtainDB.dungeonMythicPlus == false)

dungeonNormal:SetChecked(false); dungeonNormal.scripts.OnClick(dungeonNormal)
dungeonHeroic:SetChecked(false); dungeonHeroic.scripts.OnClick(dungeonHeroic)
assert(RollCurtainDB.dungeonsEnabled == true)
dungeonMythic:SetChecked(false); dungeonMythic.scripts.OnClick(dungeonMythic)
assert(RollCurtainDB.dungeonsEnabled == false, "Dungeons should disable when final selected child is cleared")
assert(dungeons:GetChecked() == false)

-- Raid behavior remains unchanged.
local raids = addon.settingsControls.raidsEnabled
raids:SetChecked(true); raids.scripts.OnClick(raids)
assert(RollCurtainDB.raidsEnabled == true and RollCurtainDB.raidStory == true)
local story = addon.settingsControls.raidStory
story:SetChecked(false); story.scripts.OnClick(story)
assert(RollCurtainDB.raidsEnabled == false, "Raids should disable when final selected child is cleared")

-- Classification, including explicit dungeon difficulties.
activePreyQuest = 12345; activeDelve = true; instanceType = "raid"
assert(addon:GetCurrentContentType() == "prey")
activePreyQuest = nil
assert(addon:GetCurrentContentType() == "delves")
activeDelve = false; instanceType = "party"
difficultyID = 1; assert(addon:GetCurrentContentType() == "dungeonNormal")
difficultyID = 2; assert(addon:GetCurrentContentType() == "dungeonHeroic")
difficultyID = 23; assert(addon:GetCurrentContentType() == "dungeonMythic")
difficultyID = 8; assert(addon:GetCurrentContentType() == "dungeonMythicPlus")
difficultyID = 24; assert(addon:GetCurrentContentType() == "dungeons", "Unknown dungeon difficulty should fail open")
instanceType = "raid"
difficultyID = 220; assert(addon:GetCurrentContentType() == "raidStory")
difficultyID = 17; assert(addon:GetCurrentContentType() == "raidLFR")
difficultyID = 14; assert(addon:GetCurrentContentType() == "raidNormal")
difficultyID = 15; assert(addon:GetCurrentContentType() == "raidHeroic")
difficultyID = 16; assert(addon:GetCurrentContentType() == "raidMythic")
difficultyID = nil; assert(addon:GetCurrentContentType() == "raids")

-- Restore behavior still works.
RollCurtainDB.delves = true
activeDelve = true
FireBonusRoll()
assert(closeCount == 1 and not bonusRollShown and addon.hiddenBonusRoll)
assert(chatMessages[#chatMessages]:find("Show Bonus Roll Prompt", 1, true))
currentTime = currentTime + 15
SlashCmdList.ROLLCURTAIN("show")
assert(restoreCount == 1 and bonusRollShown)
assert(BonusRollFrame.remaining == 45 and timerValue == 45)

-- Dungeon suppression defaults and Mythic+ opt-in.
currentTime = 1000; activeDelve = false; instanceType = "party"
RollCurtainDB.dungeonsEnabled = true
RollCurtainDB.dungeonNormal = true
RollCurtainDB.dungeonHeroic = true
RollCurtainDB.dungeonMythic = true
RollCurtainDB.dungeonMythicPlus = false
difficultyID = 1; FireBonusRoll(); assert(closeCount == 2, "Normal dungeon should suppress by default")
difficultyID = 8; FireBonusRoll(); assert(closeCount == 2, "Mythic+ should fail open by default")
RollCurtainDB.dungeonMythicPlus = true; FireBonusRoll(); assert(closeCount == 3, "Enabled Mythic+ should suppress")
difficultyID = 24; FireBonusRoll(); assert(closeCount == 3, "Unknown dungeon difficulty should fail open")

-- Bonus-roll confirmation: show spec and post-spend token count, then accept exactly once.
RollCurtainDB.dungeonMythicPlus = false
difficultyID = 8
RollCurtainDB.confirmBonusRoll = true
popupShown = nil
FireBonusRoll(1)
local beforeAccept = acceptCount
rollButton.scripts.OnClick(rollButton)
assert(popupShown, "Confirmation popup was not shown")
assert(acceptCount == beforeAccept, "Roll should not be accepted before confirmation")
assert(popupShown.text:find("Mistweaver", 1, true), "Loot spec missing from confirmation")
assert(popupShown.text:find("Bonus rolls remaining", 1, true), "Remaining-token label missing")
assert(popupShown.text:find("2", 1, true), "Post-spend token count should be shown")
StaticPopupDialogs[popupShown.key].OnAccept(nil, popupShown.data)
assert(acceptCount == beforeAccept + 1, "Confirm should invoke Blizzard's original roll click once")

-- Disabling the safety option restores one-click behavior.
RollCurtainDB.confirmBonusRoll = false
popupShown = nil
local beforeDirect = acceptCount
rollButton.scripts.OnClick(rollButton)
assert(acceptCount == beforeDirect + 1, "Disabled confirmation should call original click immediately")
assert(popupShown == nil, "Disabled confirmation should not show a popup")

-- Expired rolls cannot be accepted from a stale confirmation.
RollCurtainDB.confirmBonusRoll = true
popupShown = nil
FireBonusRoll(1)
rollButton.scripts.OnClick(rollButton)
local beforeExpiredAccept = acceptCount
currentTime = BonusRollFrame.endTime + 1
StaticPopupDialogs[popupShown.key].OnAccept(nil, popupShown.data)
assert(acceptCount == beforeExpiredAccept, "Expired confirmation should not spend a roll")
assert(chatMessages[#chatMessages]:find("no longer available", 1, true))

-- Migration: preserve old generic dungeon choices exactly.
RollCurtainDB = { dungeons = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.dungeonsEnabled == false)
assert(RollCurtainDB.dungeonNormal == false and RollCurtainDB.dungeonHeroic == false and RollCurtainDB.dungeonMythic == false and RollCurtainDB.dungeonMythicPlus == false)
assert(RollCurtainDB.confirmBonusRoll == true, "Existing users should receive confirmation enabled by default")
assert(RollCurtainDB.dungeons == nil)

RollCurtainDB = { dungeons = true }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.dungeonsEnabled == true)
assert(RollCurtainDB.dungeonNormal == true and RollCurtainDB.dungeonHeroic == true and RollCurtainDB.dungeonMythic == true and RollCurtainDB.dungeonMythicPlus == true, "Legacy enabled dungeons should preserve all-dungeon behavior")

-- Existing raid migrations remain intact.
RollCurtainDB = { raidLFR = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidsEnabled == true)
assert(RollCurtainDB.raidLFR == true and RollCurtainDB.raidStory == false and RollCurtainDB.raidMythic == false)

RollCurtainDB = { raids = true, raidMythic = false }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB.raidsEnabled == true)
assert(RollCurtainDB.raidStory == true and RollCurtainDB.raidLFR == true and RollCurtainDB.raidNormal == true and RollCurtainDB.raidHeroic == true)
assert(RollCurtainDB.raidMythic == false)
assert(RollCurtainDB.raids == nil)

assert(SLASH_ROLLCURTAIN1 == "/rollcurtain")
assert(SLASH_ROLLCURTAIN2 == "/rcurtain")
assert(SLASH_ROLLCURTAIN3 == "/rc")
assert(SLASH_ROLLCURTAIN4 == "/rollc")

print("Roll Curtain tests passed")
