local addon = {}
local refreshCount = 0
local recoverable = false
local shouldHide = true
local contentType = "dungeonMythic"
local bonusRollShown = true
local closeCount = 0
local alreadySuppressed = false

addon.defaults = {
	delves = true,
	world = true,
	showMinimapButton = true,
}
addon.contentLabels = { unknown = "Unknown Content" }

RollCurtainDB = {
	profiles = {
		Default = {
			delves = false,
			world = true,
			showMinimapButton = true,
		},
	},
	profileKeys = {
		["Tester - TestRealm"] = "Default",
	},
}

addon.currentCharacterKey = "Tester - TestRealm"
addon.currentProfileName = "Default"
addon.currentProfile = RollCurtainDB.profiles.Default

function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
function addon:GetCharacterKey() return "Tester - TestRealm" end
function addon:GetCurrentProfileName() return self.currentProfileName end
function addon:GetCurrentProfile() return self.currentProfile end
function addon:GetSetting(key)
	local value = self.currentProfile and self.currentProfile[key]
	if value ~= nil then return value end
	return self.defaults[key]
end
function addon:SetSetting(key, value)
	self.currentProfile[key] = value == true
	return true
end
function addon:GetProfileNames()
	local names = {}
	for name in pairs(RollCurtainDB.profiles) do table.insert(names, name) end
	table.sort(names, function(a, b)
		if a == "Default" then return true end
		if b == "Default" then return false end
		return a:lower() < b:lower()
	end)
	return names
end
function addon:RefreshProfileConsumers() refreshCount = refreshCount + 1 end
function addon:ShouldHideCurrentPrompt() return shouldHide, contentType end
function addon:CanRestoreHiddenBonusRoll() return recoverable end
function addon:IsCurrentBonusRollAlreadySuppressed() return alreadySuppressed end
function addon:ShowHiddenBonusRoll()
	recoverable = false
	self.hiddenBonusRoll = nil
	return true
end
function addon:RegisterSettings() end
function addon:RefreshSettingsUI() end

local primaryMessages, lootMessages, groupMessages, whisperMessages = {}, {}, {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(primaryMessages, message) end }
ChatFrame1 = DEFAULT_CHAT_FRAME
ChatFrame2 = { AddMessage = function(_, message) table.insert(lootMessages, message) end }
ChatFrame3 = { AddMessage = function(_, message) table.insert(groupMessages, message) end }
ChatFrame4 = { AddMessage = function(_, message) table.insert(whisperMessages, message) end }
NUM_CHAT_WINDOWS = 4
function GetChatWindowMessages(index)
	if index == 1 then return "SYSTEM", "SAY", "CHANNEL" end
	if index == 2 then return "LOOT" end
	if index == 3 then return "PARTY", "RAID", "INSTANCE_CHAT" end
	if index == 4 then return "WHISPER", "BN_WHISPER" end
end

BonusRollFrame = {
	state = "prompt",
	IsShown = function() return bonusRollShown end,
}
function BonusRollFrame_CloseBonusRoll()
	closeCount = closeCount + 1
	bonusRollShown = false
end

assert(loadfile("RollCurtain/Notifications.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/SettingsExtensions.lua"))("RollCurtain", addon)

-- Chat destination defaults are profile-backed and General is the only default.
assert(addon.defaults.chatNotifyGeneral == true)
for _, definition in ipairs(addon.chatDestinationDefinitions) do
	if definition.key ~= "chatNotifyGeneral" then
		assert(addon.defaults[definition.key] == false, definition.key .. " should default off")
	end
end

-- New profiles clone the current profile instead of resetting to defaults.
addon.currentProfile.chatNotifyGeneral = false
addon.currentProfile.chatNotifyLoot = true
assert(addon:CreateProfile("My Main") == true)
assert(addon:GetCurrentProfileName() == "My Main")
assert(RollCurtainDB.profileKeys["Tester - TestRealm"] == "My Main")
assert(addon:GetSetting("delves") == false, "New profile should inherit current Delves setting")
assert(addon:GetSetting("chatNotifyGeneral") == false, "New profile should inherit notification settings")
assert(addon:GetSetting("chatNotifyLoot") == true)
assert(refreshCount > 0)
assert(addon:CreateProfile("my main") == false, "Profile names should remain case-insensitively unique")

-- Character assignments can be inspected per profile and as a summary.
RollCurtainDB.profileKeys["Alt - TestRealm"] = "My Main"
local characters = addon:GetCharactersUsingProfile("My Main")
assert(#characters == 2)
assert(characters[1] == "Alt - TestRealm" and characters[2] == "Tester - TestRealm")
local assignmentText = addon:GetProfileAssignmentsText()
assert(assignmentText:find("My Main", 1, true))
assert(assignmentText:find("Alt - TestRealm", 1, true))
assert(assignmentText:find("Tester - TestRealm", 1, true))

-- Suppression notification wording uses the requested content label and link.
local formatted = addon:BuildSuppressionNotification("dungeonMythic")
assert(formatted:find("Roll Curtain:", 1, true))
assert(formatted:find("Bonus roll suppressed - Mythic Dungeon -", 1, true))
assert(formatted:find("[Restore Bonus Roll]", 1, true))

-- Multiple local destinations are supported and duplicate chat frames are deduped.
for _, definition in ipairs(addon.chatDestinationDefinitions) do addon:SetSetting(definition.key, false) end
addon:SetSetting("chatNotifyLoot", true)
addon:SetSetting("chatNotifyRaid", true)
addon:SetSetting("chatNotifyParty", true)
local beforeRoutingGeneral = #primaryMessages
addon:NotifyBonusRollSuppressed("dungeonMythic")
assert(#primaryMessages == beforeRoutingGeneral, "Unselected General should not receive the routed notification")
assert(#lootMessages == 1, "Loot destination should receive one notification")
assert(#groupMessages == 1, "Raid + Party on the same chat frame should be deduped")
assert(#whisperMessages == 0)

-- Hidden-roll suppression routes the new notification and keeps restore state.
for _, definition in ipairs(addon.chatDestinationDefinitions) do addon:SetSetting(definition.key, false) end
addon:SetSetting("chatNotifyGeneral", true)
bonusRollShown = true
recoverable = true
local beforeGeneral = #primaryMessages
addon:HideCurrentPromptIfConfigured()
assert(closeCount == 1 and addon.hiddenBonusRoll and not bonusRollShown)
assert(#primaryMessages == beforeGeneral + 1)
assert(primaryMessages[#primaryMessages]:find("Bonus roll suppressed - Mythic Dungeon -", 1, true))
assert(primaryMessages[#primaryMessages]:find("[Restore Bonus Roll]", 1, true))

-- Reconstructing that same active roll during a zone transition should close it
-- again without sending another notification or changing its original content.
local originalHiddenRoll = addon.hiddenBonusRoll
bonusRollShown = true
contentType = "world"
alreadySuppressed = true
local beforeRepeatedSuppression = #primaryMessages
addon:HideCurrentPromptIfConfigured()
assert(closeCount == 2 and not bonusRollShown, "Reconstructed suppressed roll should be closed again")
assert(#primaryMessages == beforeRepeatedSuppression, "Reconstructed suppressed roll must not resend chat notification")
assert(addon.hiddenBonusRoll == originalHiddenRoll, "Existing hidden-roll record should be preserved")
assert(addon.hiddenBonusRoll.contentType == "dungeonMythic", "Zone context must not reclassify the original hidden roll")
alreadySuppressed = false
contentType = "dungeonMythic"

-- The minimap glow follows recoverability and clears immediately on restore.
local glow = { shown = false }
function glow:SetShown(value) self.shown = value == true end
addon.minimapButton = { recoveryGlow = glow }
recoverable = true
addon:RefreshMinimapRecoveryGlow()
assert(glow.shown == true)
recoverable = false
addon:RefreshMinimapRecoveryGlow()
assert(glow.shown == false)
recoverable = true
glow.shown = true
addon:ShowHiddenBonusRoll()
assert(glow.shown == false, "Restoring a roll should stop the glow immediately")

print("Roll Curtain profile/notification tests passed")
