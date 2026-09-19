local addon = {
	contentLabels = {
		raidHeroic = "Heroic raids",
		dungeonHeroic = "Heroic dungeons",
		scenarios = "Other scenarios",
	},
	settings = {
		dungeonsEnabled = true,
		dungeonHeroic = false,
		raidsEnabled = true,
		raidHeroic = false,
		scenarios = true,
	},
	lairInstanceIDs = {},
}

local messages = {}
local forwardedSlashInput
local originalBonusRollFrame = { sentinel = "untouched" }
BonusRollFrame = originalBonusRollFrame
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = { ROLLCURTAIN = function(input) forwardedSlashInput = input end }

function GetInstanceInfo()
	return "Test Heroic Raid", "raid", 15, "Heroic", 0, false, false, 3004
end

function GetDifficultyInfo(id)
	if id == 15 then return "Heroic", "raid" end
	if id == 2 then return "Heroic", "party" end
	return "Scenario", nil
end

function addon:GetSetting(key)
	return self.settings[key]
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

-- Load the production resolver before the debug diagnostics so the simulator
-- exercises exactly the same decision helper as a real bonus-roll prompt.
assert(loadfile("RollCurtain/ContentPriority.lua"))("RollCurtain", addon)
assert(loadfile("RollCurtain/DecisionTest.lua"))("RollCurtain", addon)
assert(addon:RegisterSettings() == true)
assert(addon.debugDecisionButton, "Development Debug page should get a decision-test button")
assert(addon.debugDecisionResult, "Decision-test result text should be created")
assert(addon.debugSimulationButtons and #addon.debugSimulationButtons == 3, "Debug page should expose three safe simulation buttons")

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

-- Simulate the exact Other scenarios bug without an available bonus roll.
result = addon:RunSimulatedDecisionTest("raid heroic", false)
assert(result.simulated == true)
assert(result.sourceContentType == "scenarios")
assert(result.contentType == "raidHeroic")
assert(result.shouldHide == false, "Other scenarios ON must not suppress a simulated unchecked Heroic Raid")
assert(addon.debugDecisionResult.text:find("Other scenarios context + Heroic Raid prompt", 1, true))
assert(addon.debugDecisionResult.text:find("Decision: SHOW bonus roll prompt", 1, true))

result = addon:RunSimulatedDecisionTest("dungeon heroic", false)
assert(result.contentType == "dungeonHeroic")
assert(result.shouldHide == false, "Other scenarios ON must not suppress a simulated unchecked Heroic Dungeon")

result = addon:RunSimulatedDecisionTest("scenario", false)
assert(result.contentType == "scenarios")
assert(result.shouldHide == true, "A simulated genuine scenario must still follow Other scenarios")

-- Toggling Heroic Raid on changes both live and simulated decisions, without
-- touching Blizzard's frame.
addon.settings.raidHeroic = true
result = addon:RunCurrentDecisionTest(false)
assert(result.shouldHide == true, "Enabled Heroic Raid must produce a SUPPRESS decision")
result = addon:RunSimulatedDecisionTest("raid heroic", false)
assert(result.shouldHide == true, "Enabled Heroic Raid must suppress the simulated raid prompt")
assert(BonusRollFrame == originalBonusRollFrame and BonusRollFrame.sentinel == "untouched", "Decision tests must not touch BonusRollFrame")

-- Slash commands print both real and simulated decisions; unrelated commands
-- still pass through the existing handler.
local beforeMessages = #messages
SlashCmdList.ROLLCURTAIN("debug decision")
assert(#messages > beforeMessages, "/rc debug decision should print the current decision")
assert(messages[#messages]:find("Decision: SUPPRESS bonus roll prompt", 1, true))

beforeMessages = #messages
SlashCmdList.ROLLCURTAIN("debug simulate raid heroic")
assert(#messages > beforeMessages, "/rc debug simulate raid heroic should print the simulation")
assert(messages[#messages]:find("Decision: SUPPRESS bonus roll prompt", 1, true))

SlashCmdList.ROLLCURTAIN("status")
assert(forwardedSlashInput == "status", "Non-decision slash commands should continue through the existing handler")

print("Roll Curtain decision test diagnostics passed")
