local addon = {
	contentLabels = {
		raidHeroic = "Heroic raids",
	},
	settings = {
		raidsEnabled = true,
		raidHeroic = false,
	},
}

local messages = {}
local forwardedSlashInput
local originalBonusRollFrame = { sentinel = "untouched" }
BonusRollFrame = originalBonusRollFrame
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = { ROLLCURTAIN = function(input) forwardedSlashInput = input end }

function GetInstanceInfo()
	return "Test Heroic Raid", "raid", 15, "Heroic"
end

function addon:GetCurrentContentType()
	return "raidHeroic"
end

function addon:GetSetting(key)
	return self.settings[key]
end

function addon:ShouldHideCurrentPrompt()
	return self.settings.raidsEnabled == true and self.settings.raidHeroic == true, "raidHeroic"
end

function addon:IsDevelopmentBuild()
	return true
end

local function NewFontString()
	local fs = { text = "" }
	function fs:SetPoint(...) self.point = { ... } end
	function fs:SetWidth(value) self.width = value end
	function fs:SetJustifyH(value) self.justifyH = value end
	function fs:SetJustifyV(value) self.justifyV = value end
	function fs:SetText(text) self.text = text end
	return fs
end

function CreateFrame()
	local frame = { scripts = {} }
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:SetPoint(...) self.point = { ... } end
	function frame:SetText(text) self.text = text end
	function frame:SetScript(name, callback) self.scripts[name] = callback end
	return frame
end

addon.debugSettingsPanel = {
	CreateFontString = function() return NewFontString() end,
}

function addon:RegisterSettings()
	return true
end

assert(loadfile("RollCurtain/DecisionTest.lua"))("RollCurtain", addon)
assert(addon:RegisterSettings() == true)
assert(addon.debugDecisionButton, "Development Debug page should get a decision-test button")
assert(addon.debugDecisionResult, "Decision-test result text should be created")

-- Heroic Raid is detected, but Heroic suppression is disabled: fail open / SHOW.
local result = addon:RunCurrentDecisionTest(false)
assert(result.contentType == "raidHeroic")
assert(result.label == "Heroic raids")
assert(result.instanceType == "raid")
assert(result.difficultyID == "15")
assert(result.difficultyName == "Heroic")
assert(result.shouldHide == false, "Unchecked Heroic Raid must produce a SHOW decision")
assert(result.rule:find("Raids=on", 1, true))
assert(result.rule:find("raidHeroic=off", 1, true))
assert(addon.debugDecisionResult.text:find("Decision: SHOW bonus roll prompt", 1, true))

-- Toggling Heroic on should change only the decision, without touching Blizzard's frame.
addon.settings.raidHeroic = true
result = addon:RunCurrentDecisionTest(false)
assert(result.shouldHide == true, "Enabled Heroic Raid must produce a SUPPRESS decision")
assert(addon.debugDecisionResult.text:find("Decision: SUPPRESS bonus roll prompt", 1, true))
assert(BonusRollFrame == originalBonusRollFrame and BonusRollFrame.sentinel == "untouched", "Decision test must not touch BonusRollFrame")

-- Slash command prints the decision; unrelated commands still pass through.
local beforeMessages = #messages
SlashCmdList.ROLLCURTAIN("debug decision")
assert(#messages > beforeMessages, "/rc debug decision should print the current decision")
assert(messages[#messages]:find("Decision: SUPPRESS bonus roll prompt", 1, true))
SlashCmdList.ROLLCURTAIN("status")
assert(forwardedSlashInput == "status", "Non-decision slash commands should continue through the existing handler")

print("Roll Curtain decision test diagnostics passed")
