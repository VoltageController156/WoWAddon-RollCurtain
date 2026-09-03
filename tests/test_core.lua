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
local subcategoryRegistered = false

SlashCmdList = {}
StaticPopupDialogs = {}
CANCEL = "Cancel"
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(chatMessages, message) end }
UIParent = {}
Minimap = nil

function UnitFullName() return "Tester", "TestRealm" end
function GetRealmName() return "TestRealm" end

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
	function fontString:ClearAllPoints() self.point = nil end
	function fontString:SetText(text) self.text = text end
	function fontString:Show() self.shown = true end
	function fontString:Hide() self.shown = false end
	table.insert(createdFontStrings, fontString)
	return fontString
end

function CreateFrame(frameType, _, _, template)
	local frame = { frameType = frameType, template = template, scripts = {}, shown = true, checked = false, enabled = true }
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
	function frame:SetEnabled(value) self.enabled = value == true end
	function frame:IsEnabled() return self.enabled end
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
rollButton.scripts.OnClick = function() acceptCount = acceptCount + 1 end
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
	RegisterCanvasLayoutSubcategory = function()
		subcategoryRegistered = true
		return { GetID = function() return 2 end }
	end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
}

assert(loadfile("RollCurtain/Core.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/Settings.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/MinimapButton.lua"))("RollCurtain", addon)
assert(eventHandler, "Core did not register an event handler")
eventHandler(nil, "ADDON_LOADED", "RollCurtain")

local function profile()
	return addon:GetCurrentProfile()
end

-- Profile-backed fresh defaults and database shape.
assert(RollCurtainDB.schemaVersion == 1)
assert(type(RollCurtainDB.profiles) == "table")
assert(type(RollCurtainDB.profileKeys) == "table")
assert(type(RollCurtainDB.minimapAngles) == "table")
assert(addon:GetCharacterKey() == "Tester - TestRealm")
assert(addon:GetCurrentProfileName() == "Default")
assert(RollCurtainDB.profileKeys["Tester - TestRealm"] == "Default")
assert(profile().delves == true)
assert(profile().prey == true)
assert(profile().world == true)
assert(profile().dungeonsEnabled == true)
assert(profile().dungeonNormal == true)
assert(profile().dungeonHeroic == true)
assert(profile().dungeonMythic == true)
assert(profile().dungeonMythicPlus == false, "Mythic+ should remain visible by default")
assert(profile().raidsEnabled == false)
assert(profile().confirmBonusRoll == true)
assert(profile().showMinimapButton == true)
assert(#createdCheckboxes == 17, "Expected seventeen custom settings checkboxes")
assert(subcategoryRegistered, "Commands & Help subcategory should be registered")
assert(addon.helpSettingsCategory, "Commands & Help category reference missing")
assert(addon.confirmBonusRollHookInstalled, "Bonus-roll confirmation hook was not installed")

for _, checkbox in ipairs(createdCheckboxes) do
	assert(checkbox.template == "SettingsCheckboxTemplate")
end
assert(addon.settingsControls.showMinimapButton:GetChecked() == true)
assert(addon.profileSelector.text == "Default")
assert(addon.renameProfileButton.enabled == false and addon.deleteProfileButton.enabled == false, "Default profile controls should be protected")

local foundMetadata = false
local foundHelp = false
for _, fontString in ipairs(createdFontStrings) do
	if fontString.text:find("0.0.5", 1, true) and fontString.text:find("VoltageController156", 1, true) then foundMetadata = true end
	if fontString.text:find("/rc status", 1, true) then foundHelp = true end
end
assert(foundMetadata, "Settings should display version 0.0.5 and author")
assert(foundHelp, "Commands & Help should document slash commands")

-- Dungeon parent/child behavior and Mythic+ default.
local dungeons = addon.settingsControls.dungeonsEnabled
local dungeonNormal = addon.settingsControls.dungeonNormal
local dungeonHeroic = addon.settingsControls.dungeonHeroic
local dungeonMythic = addon.settingsControls.dungeonMythic
local dungeonMythicPlus = addon.settingsControls.dungeonMythicPlus

dungeons:SetChecked(false); dungeons.scripts.OnClick(dungeons)
assert(addon:GetSetting("dungeonsEnabled") == false)
for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }) do
	assert(addon:GetSetting(key) == false)
	assert(addon.settingsControls[key].shown == false)
end

dungeons:SetChecked(true); dungeons.scripts.OnClick(dungeons)
assert(addon:GetSetting("dungeonNormal") == true)
assert(addon:GetSetting("dungeonHeroic") == true)
assert(addon:GetSetting("dungeonMythic") == true)
assert(addon:GetSetting("dungeonMythicPlus") == false)

dungeonNormal:SetChecked(false); dungeonNormal.scripts.OnClick(dungeonNormal)
dungeonHeroic:SetChecked(false); dungeonHeroic.scripts.OnClick(dungeonHeroic)
assert(addon:GetSetting("dungeonsEnabled") == true)
dungeonMythic:SetChecked(false); dungeonMythic.scripts.OnClick(dungeonMythic)
assert(addon:GetSetting("dungeonsEnabled") == false, "Dungeons should disable when final selected child is cleared")

-- Raid behavior remains unchanged.
local raids = addon.settingsControls.raidsEnabled
raids:SetChecked(true); raids.scripts.OnClick(raids)
assert(addon:GetSetting("raidsEnabled") == true and addon:GetSetting("raidStory") == true)
local story = addon.settingsControls.raidStory
story:SetChecked(false); story.scripts.OnClick(story)
assert(addon:GetSetting("raidsEnabled") == false)

-- Profile creation, assignment, switching and persistence.
assert(addon:CreateProfile("Main") == true)
assert(addon:GetCurrentProfileName() == "Main")
assert(RollCurtainDB.profileKeys["Tester - TestRealm"] == "Main")
addon:SetSetting("delves", false)
addon:SetSetting("showMinimapButton", false)
assert(addon:SelectProfile("Default") == true)
assert(addon:GetSetting("delves") == true, "Default profile should remain independent")
assert(addon:GetSetting("showMinimapButton") == true)
assert(addon:SelectProfile("Main") == true)
assert(addon:GetSetting("delves") == false, "Profile settings should persist after switching away and back")
assert(addon:GetSetting("showMinimapButton") == false)

-- Profiles can be shared, renamed, copied, and deleted safely.
RollCurtainDB.profileKeys["Alt - TestRealm"] = "Main"
assert(addon:RenameCurrentProfile("Raid Main") == true)
assert(addon:GetCurrentProfileName() == "Raid Main")
assert(RollCurtainDB.profileKeys["Alt - TestRealm"] == "Raid Main", "Rename should update all character assignments")
assert(addon:CopyProfile("Default") == true)
assert(addon:GetSetting("delves") == true, "Copy should replace current profile settings from the source")
addon:SetSetting("delves", false)
addon:ResetDefaults()
assert(addon:GetSetting("delves") == true, "Reset should reset current profile")
assert(addon:GetCurrentProfileName() == "Raid Main", "Reset should not change profile assignment")
assert(addon:DeleteCurrentProfile() == true)
assert(addon:GetCurrentProfileName() == "Default")
assert(RollCurtainDB.profileKeys["Alt - TestRealm"] == "Default", "Delete should move assigned characters to Default")
assert(RollCurtainDB.profiles["Raid Main"] == nil)
assert(addon:RenameCurrentProfile("Nope") == false, "Default profile must not be renamed")
assert(addon:DeleteCurrentProfile() == false, "Default profile must not be deleted")

-- Minimap visibility is profile-backed, while position is character-specific.
local mockMinimapButton = { shown = true }
function mockMinimapButton:Show() self.shown = true end
function mockMinimapButton:Hide() self.shown = false end
addon.minimapButton = mockMinimapButton
addon:SetSetting("showMinimapButton", false)
addon:UpdateMinimapButtonVisibility()
assert(mockMinimapButton.shown == false)
addon:SetMinimapButtonAngle(137)
assert(addon:GetMinimapButtonAngle() == 137)
addon:SetSetting("showMinimapButton", true)
addon:UpdateMinimapButtonVisibility()
assert(mockMinimapButton.shown == true)
assert(addon:GetMinimapButtonAngle() == 137, "Showing/hiding the minimap button should not reset position")

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
difficultyID = 24; assert(addon:GetCurrentContentType() == "dungeons")
instanceType = "raid"
difficultyID = 220; assert(addon:GetCurrentContentType() == "raidStory")
difficultyID = 17; assert(addon:GetCurrentContentType() == "raidLFR")
difficultyID = 14; assert(addon:GetCurrentContentType() == "raidNormal")
difficultyID = 15; assert(addon:GetCurrentContentType() == "raidHeroic")
difficultyID = 16; assert(addon:GetCurrentContentType() == "raidMythic")

-- Restore behavior still works.
addon:ResetDefaults()
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
difficultyID = 1; FireBonusRoll(); assert(closeCount == 2, "Normal dungeon should suppress by default")
difficultyID = 8; FireBonusRoll(); assert(closeCount == 2, "Mythic+ should fail open by default")
addon:SetSetting("dungeonMythicPlus", true); FireBonusRoll(); assert(closeCount == 3, "Enabled Mythic+ should suppress")
difficultyID = 24; FireBonusRoll(); assert(closeCount == 3, "Unknown dungeon difficulty should fail open")

-- Confirmation preview works without spending or requiring an active roll.
popupShown = nil
local beforePreview = acceptCount
assert(addon:ShowBonusRollConfirmationPreview() == true)
assert(popupShown and popupShown.text:find("Preview only", 1, true), "Preview should be clearly labeled")
assert(popupShown.text:find("Mistweaver", 1, true), "Preview should show loot spec")
StaticPopupDialogs[popupShown.key].OnAccept(nil, popupShown.data)
assert(acceptCount == beforePreview, "Preview confirmation must never spend a roll")

-- Real bonus-roll confirmation: spec + post-spend token count and one accept.
addon:SetSetting("dungeonMythicPlus", false)
difficultyID = 8
addon:SetSetting("confirmBonusRoll", true)
popupShown = nil
FireBonusRoll(1)
local beforeAccept = acceptCount
rollButton.scripts.OnClick(rollButton)
assert(popupShown, "Confirmation popup was not shown")
assert(acceptCount == beforeAccept)
assert(popupShown.text:find("Mistweaver", 1, true))
assert(popupShown.text:find("Bonus rolls remaining", 1, true))
assert(popupShown.text:find("2", 1, true))
StaticPopupDialogs[popupShown.key].OnAccept(nil, popupShown.data)
assert(acceptCount == beforeAccept + 1)

addon:SetSetting("confirmBonusRoll", false)
popupShown = nil
local beforeDirect = acceptCount
rollButton.scripts.OnClick(rollButton)
assert(acceptCount == beforeDirect + 1)
assert(popupShown == nil)

-- Legacy flat migration into Default profile, including angle and Mythic+ opt-in.
RollCurtainDB = { dungeons = true, raidLFR = true, minimapButtonAngle = 123 }
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(addon:GetCurrentProfileName() == "Default")
assert(addon:GetSetting("dungeonsEnabled") == true)
assert(addon:GetSetting("dungeonNormal") == true and addon:GetSetting("dungeonHeroic") == true and addon:GetSetting("dungeonMythic") == true)
assert(addon:GetSetting("dungeonMythicPlus") == false, "Legacy generic Dungeons should leave Mythic+ opt-in")
assert(addon:GetSetting("raidsEnabled") == true and addon:GetSetting("raidLFR") == true)
assert(addon:GetSetting("confirmBonusRoll") == true and addon:GetSetting("showMinimapButton") == true)
assert(addon:GetMinimapButtonAngle() == 123, "Legacy minimap angle should migrate per character")
assert(RollCurtainDB.minimapButtonAngle == nil)

-- Existing profile schema survives addon updates without settings being reset.
addon:CreateProfile("Persist Me")
addon:SetSetting("world", false)
addon:SetSetting("dungeonHeroic", false)
local dbBeforeReload = RollCurtainDB
eventHandler(nil, "ADDON_LOADED", "RollCurtain")
assert(RollCurtainDB == dbBeforeReload, "Profile database should be preserved on update/reload")
assert(addon:GetCurrentProfileName() == "Persist Me")
assert(addon:GetSetting("world") == false and addon:GetSetting("dungeonHeroic") == false)

-- Slash aliases and reset semantics remain available.
assert(SLASH_ROLLCURTAIN1 == "/rollcurtain")
assert(SLASH_ROLLCURTAIN2 == "/rcurtain")
assert(SLASH_ROLLCURTAIN3 == "/rc")
assert(SLASH_ROLLCURTAIN4 == "/rollc")
local profileNameBeforeReset = addon:GetCurrentProfileName()
SlashCmdList.ROLLCURTAIN("reset")
assert(addon:GetCurrentProfileName() == profileNameBeforeReset, "/rc reset should only reset the active profile")
assert(addon:GetSetting("world") == true and addon:GetSetting("dungeonHeroic") == true)

print("Roll Curtain tests passed")
