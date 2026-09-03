local addon = {
	defaults = { confirmBonusRoll = true, chatNotifyGeneral = true, chatNotifyLoot = false },
	contentLabels = { dungeonMythic = "Mythic dungeons" },
	chatDestinationDefinitions = {
		{ key = "chatNotifyGeneral", label = "General" },
		{ key = "chatNotifyLoot", label = "Loot" },
	},
}

local messages = {}
local debugCategoryRegistered = false
local oldSlashInput
local currentChannel = "development"
local currentTime = 1000

RollCurtainDB = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = { ROLLCURTAIN = function(input) oldSlashInput = input end }

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		if field == "Version" then return "0.0.7" end
		if field == "X-Release-Channel" then return currentChannel end
	end,
}

function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
function time() return currentTime end
function GetInstanceInfo() return "Test Dungeon", "party", 23 end

local function NewFontString()
	local fs = { text = "" }
	function fs:SetPoint(...) self.point = { ... } end
	function fs:SetWidth(width) self.width = width end
	function fs:SetJustifyH(value) self.justifyH = value end
	function fs:SetText(text) self.text = text end
	return fs
end

function CreateFrame(frameType)
	local frame = { scripts = {}, checked = false, shown = true }
	function frame:RegisterEvent() end
	function frame:SetScript(name, callback) self.scripts[name] = callback end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:SetPoint(...) self.point = { ... } end
	function frame:SetText(text) self.text = text end
	function frame:SetChecked(value) self.checked = value == true end
	function frame:GetChecked() return self.checked end
	function frame:CreateFontString() return NewFontString() end
	function frame:IsShown() return self.shown end
	return frame
end

Settings = {
	RegisterCanvasLayoutSubcategory = function()
		debugCategoryRegistered = true
		return { GetID = function() return 3 end }
	end,
}

addon.settingsCategory = { GetID = function() return 1 end }
addon.settings = { confirmBonusRoll = true, chatNotifyGeneral = true, chatNotifyLoot = false }
addon.currentProfileName = "Default"
addon.currentProfile = addon.settings
addon.currentCharacterKey = "Tester - TestRealm"
addon.hiddenBonusRoll = {
	contentType = "dungeonMythic",
	frame = { spellID = 12345, endTime = currentTime + 45 },
}
addon.minimapButton = {
	shown = true,
	IsShown = function(self) return self.shown end,
	recoveryGlow = { IsShown = function() return true end },
}

function addon:GetCharacterKey() return self.currentCharacterKey end
function addon:GetCurrentProfileName() return self.currentProfileName end
function addon:GetCurrentContentType() return "dungeonMythic" end
function addon:ShouldHideCurrentPrompt() return true, "dungeonMythic" end
function addon:CanRestoreHiddenBonusRoll() return true end
function addon:GetSetting(key) return self.settings[key] end
function addon:SetSetting(key, value) self.settings[key] = value == true; return true end
function addon:SelectProfile() return true end
function addon:CreateProfile() return true end
function addon:CopyProfile() return true end
function addon:RenameCurrentProfile() return true end
function addon:DeleteCurrentProfile() return true end
function addon:HideCurrentPromptIfConfigured() end
function addon:ShowHiddenBonusRoll() return true end
function addon:RegisterSettings() return true end

assert(loadfile("RollCurtain/Debug.lua"))("RollCurtain", addon)

-- Development/beta source builds expose the debug page and remember its toggle.
assert(addon:RegisterSettings() == true)
assert(debugCategoryRegistered == true, "Development builds should expose the Debug settings page")
assert(addon:GetReleaseChannel() == "development")
assert(addon:IsDevelopmentBuild() == true)
assert(addon:IsDebugEnabled() == false)
addon:SetDebugEnabled(true)
assert(addon:IsDebugEnabled() == true)
assert(RollCurtainDB.debugEnabled == true, "Development debug preference should persist across reloads")

local lines = addon:GetDebugSnapshotLines()
local snapshot = table.concat(lines, "\n")
assert(snapshot:find("Channel=development", 1, true))
assert(snapshot:find("Character=Tester - TestRealm", 1, true))
assert(snapshot:find("Profile=Default", 1, true))
assert(snapshot:find("DifficultyID=23", 1, true))
assert(snapshot:find("HiddenRoll=yes", 1, true))
assert(snapshot:find("Recoverable=yes", 1, true))
assert(snapshot:find("SpellID=12345", 1, true))
assert(snapshot:find("Remaining=45", 1, true))
assert(snapshot:find("ChatDestinations=General", 1, true))
assert(snapshot:find("RecoveryGlow=yes", 1, true))

local beforeDump = #messages
SlashCmdList.ROLLCURTAIN("debug dump")
assert(#messages > beforeDump, "Debug dump should print a diagnostic snapshot")
SlashCmdList.ROLLCURTAIN("status")
assert(oldSlashInput == "status", "Non-debug slash commands should continue to use the original handler")

-- Stable builds keep the support command but never persist or expose debug UI.
currentChannel = "release"
RollCurtainDB.debugEnabled = true
addon.debugSettingsCategory = nil
addon.debugSettingsPanel = nil
addon.debugCheckbox = nil
debugCategoryRegistered = false
addon:RegisterSettings()
assert(debugCategoryRegistered == false, "Stable builds should not expose the Debug settings page")
assert(addon:IsDevelopmentBuild() == false)
assert(addon:IsDebugEnabled() == false, "Stable builds should start with debug disabled")
assert(RollCurtainDB.debugEnabled == nil, "Stable builds should clear beta debug persistence")
SlashCmdList.ROLLCURTAIN("debug on")
assert(addon:IsDebugEnabled() == true, "Stable support sessions may enable debug manually")
assert(RollCurtainDB.debugEnabled == nil, "Stable debug must remain session-only")

print("Roll Curtain debug diagnostics tests passed")
