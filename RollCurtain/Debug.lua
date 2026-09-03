local addonName, addon = ...

local DEBUG_PREFIX = "|cff9d9d9dRoll Curtain Debug:|r "
local RELEASE_CHANNEL_FALLBACK = "development"

local function Trim(value)
	if type(strtrim) == "function" then return strtrim(value or "") end
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetMetadata(field, fallback)
	if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
		return C_AddOns.GetAddOnMetadata(addonName, field) or fallback
	end
	return fallback
end

function addon:GetReleaseChannel()
	return GetMetadata("X-Release-Channel", RELEASE_CHANNEL_FALLBACK)
end

function addon:IsDevelopmentBuild()
	return self:GetReleaseChannel() ~= "release"
end

local function DebugPrint(message)
	if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
		DEFAULT_CHAT_FRAME:AddMessage(DEBUG_PREFIX .. tostring(message))
	end
end

function addon:IsDebugEnabled()
	return self.debugEnabled == true
end

function addon:SetDebugEnabled(enabled)
	self.debugEnabled = enabled == true
	-- Beta/development builds remember the toggle across /reload. Stable builds
	-- deliberately do not persist it so a tester cannot accidentally carry chat
	-- logging into a production release.
	if self:IsDevelopmentBuild() and type(RollCurtainDB) == "table" then
		RollCurtainDB.debugEnabled = self.debugEnabled
	end
	DebugPrint("Debug logging " .. (self.debugEnabled and "enabled." or "disabled."))
	if self.debugCheckbox and type(self.debugCheckbox.SetChecked) == "function" then
		self.debugCheckbox:SetChecked(self.debugEnabled)
	end
	return self.debugEnabled
end

function addon:DebugLog(message)
	if self:IsDebugEnabled() then DebugPrint(message) end
end

local function GetContentSummary(addonObject)
	local contentType = type(addonObject.GetCurrentContentType) == "function" and addonObject:GetCurrentContentType() or "unknown"
	local label = addonObject.contentLabels and addonObject.contentLabels[contentType] or contentType
	local instanceType, difficultyID = "unknown", "unknown"
	if type(GetInstanceInfo) == "function" then
		local _, detectedInstanceType, detectedDifficultyID = GetInstanceInfo()
		instanceType = detectedInstanceType or "unknown"
		difficultyID = detectedDifficultyID ~= nil and tostring(detectedDifficultyID) or "unknown"
	end
	return contentType, label, instanceType, difficultyID
end

local function GetNotificationDestinations(addonObject)
	local enabled = {}
	for _, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		if type(addonObject.GetSetting) == "function" and addonObject:GetSetting(definition.key) == true then
			table.insert(enabled, definition.label)
		end
	end
	return #enabled > 0 and table.concat(enabled, ", ") or "None"
end

function addon:GetDebugSnapshotLines()
	local version = GetMetadata("Version", "unknown")
	local channel = self:GetReleaseChannel()
	local character = type(self.GetCharacterKey) == "function" and self:GetCharacterKey() or "unknown"
	local profile = type(self.GetCurrentProfileName) == "function" and self:GetCurrentProfileName() or "unknown"
	local contentType, contentLabel, instanceType, difficultyID = GetContentSummary(self)
	local shouldHide = false
	if type(self.ShouldHideCurrentPrompt) == "function" then shouldHide = self:ShouldHideCurrentPrompt() == true end
	local confirmation = type(self.GetSetting) == "function" and self:GetSetting("confirmBonusRoll") == true
	local hidden = self.hiddenBonusRoll
	local recoverable = type(self.CanRestoreHiddenBonusRoll) == "function" and self:CanRestoreHiddenBonusRoll() == true
	local frame = hidden and hidden.frame
	local remaining = "n/a"
	if frame and type(frame.endTime) == "number" and type(time) == "function" then remaining = tostring(math.max(0, frame.endTime - time())) end
	local minimapShown = self.minimapButton and type(self.minimapButton.IsShown) == "function" and self.minimapButton:IsShown() or false
	local glow = self.minimapButton and self.minimapButton.recoveryGlow
	local glowShown = glow and type(glow.IsShown) == "function" and glow:IsShown() or false

	return {
		string.format("Version=%s | Channel=%s | Debug=%s", version, channel, self:IsDebugEnabled() and "on" or "off"),
		string.format("Character=%s | Profile=%s", character, profile),
		string.format("Content=%s (%s) | Instance=%s | DifficultyID=%s | Suppress=%s", contentLabel, contentType, instanceType, difficultyID, shouldHide and "yes" or "no"),
		string.format("Confirmation=%s | HiddenRoll=%s | Recoverable=%s | SpellID=%s | Remaining=%s", confirmation and "on" or "off", hidden and "yes" or "no", recoverable and "yes" or "no", frame and tostring(frame.spellID or "unknown") or "n/a", remaining),
		string.format("ChatDestinations=%s", GetNotificationDestinations(self)),
		string.format("MinimapShown=%s | RecoveryGlow=%s", minimapShown and "yes" or "no", glowShown and "yes" or "no"),
	}
end

function addon:PrintDebugSnapshot()
	DebugPrint("----- snapshot -----")
	for _, line in ipairs(self:GetDebugSnapshotLines()) do DebugPrint(line) end
	DebugPrint("----- end snapshot -----")
end

local function CreateDebugPanel(addonObject)
	if not addonObject:IsDevelopmentBuild() or addonObject.debugSettingsCategory then return end
	if not addonObject.settingsCategory or not Settings or type(Settings.RegisterCanvasLayoutSubcategory) ~= "function" then return end

	local panel = CreateFrame("Frame")
	panel:SetSize(650, 560)
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Roll Curtain — Debug")

	local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 24, -58)
	intro:SetWidth(560)
	intro:SetJustifyH("LEFT")
	intro:SetText("Diagnostics for beta and development testing. Debug output is local to your client and is never sent to other players.")

	local build = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	build:SetPoint("TOPLEFT", 24, -104)
	build:SetText(string.format("Build: %s   Channel: %s", GetMetadata("Version", "unknown"), addonObject:GetReleaseChannel()))

	local checkbox = CreateFrame("CheckButton", nil, panel, "SettingsCheckboxTemplate")
	checkbox:SetPoint("TOPLEFT", 24, -146)
	checkbox:SetChecked(addonObject:IsDebugEnabled())
	local checkboxLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
	checkboxLabel:SetText("Enable debug logging")
	checkbox:SetScript("OnClick", function(button) addon:SetDebugEnabled(button:GetChecked() == true) end)
	addonObject.debugCheckbox = checkbox

	local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 24, -188)
	help:SetWidth(560)
	help:SetJustifyH("LEFT")
	help:SetText("When enabled, Roll Curtain logs important suppression, restore, profile, and settings events to your local chat. Use the snapshot button when reporting a beta issue.")

	local snapshotButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	snapshotButton:SetSize(180, 26)
	snapshotButton:SetPoint("TOPLEFT", 24, -246)
	snapshotButton:SetText("Print Debug Snapshot")
	snapshotButton:SetScript("OnClick", function() addon:PrintDebugSnapshot() end)

	local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	commands:SetPoint("TOPLEFT", 24, -294)
	commands:SetWidth(560)
	commands:SetJustifyH("LEFT")
	commands:SetText("Commands: /rc debug on, /rc debug off, /rc debug status, /rc debug dump")

	addonObject.debugSettingsPanel = panel
	addonObject.debugSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(addonObject.settingsCategory, panel, "Debug")
end

local function InitializeDebugState(addonObject)
	if addonObject:IsDevelopmentBuild() then
		addonObject.debugEnabled = type(RollCurtainDB) == "table" and RollCurtainDB.debugEnabled == true
	else
		addonObject.debugEnabled = false
		if type(RollCurtainDB) == "table" then RollCurtainDB.debugEnabled = nil end
	end
end

-- Wrap selected methods after every functional module has loaded. Debug logging
-- is intentionally observational; it never changes the result of the wrapped call.
local previousSetSetting = addon.SetSetting
if type(previousSetSetting) == "function" then
	addon.SetSetting = function(self, key, value)
		local before = type(self.GetSetting) == "function" and self:GetSetting(key) or nil
		local result = previousSetSetting(self, key, value)
		local after = type(self.GetSetting) == "function" and self:GetSetting(key) or nil
		if result and before ~= after then self:DebugLog(string.format("Setting %s: %s -> %s", tostring(key), tostring(before), tostring(after))) end
		return result
	end
end

local previousHideCurrentPromptIfConfigured = addon.HideCurrentPromptIfConfigured
if type(previousHideCurrentPromptIfConfigured) == "function" then
	addon.HideCurrentPromptIfConfigured = function(self, ...)
		local before = self.hiddenBonusRoll
		local result = previousHideCurrentPromptIfConfigured(self, ...)
		if self.hiddenBonusRoll and self.hiddenBonusRoll ~= before then
			self:DebugLog("Suppressed bonus roll in " .. tostring(self.hiddenBonusRoll.contentType or "unknown"))
		end
		return result
	end
end

local previousShowHiddenBonusRoll = addon.ShowHiddenBonusRoll
if type(previousShowHiddenBonusRoll) == "function" then
	addon.ShowHiddenBonusRoll = function(self, ...)
		local result = previousShowHiddenBonusRoll(self, ...)
		self:DebugLog("Restore hidden bonus roll result=" .. tostring(result))
		return result
	end
end

for _, methodName in ipairs({ "SelectProfile", "CreateProfile", "CopyProfile", "RenameCurrentProfile", "DeleteCurrentProfile" }) do
	local previous = addon[methodName]
	if type(previous) == "function" then
		addon[methodName] = function(self, ...)
			local result = previous(self, ...)
			self:DebugLog(methodName .. " result=" .. tostring(result) .. " profile=" .. tostring(self:GetCurrentProfileName()))
			return result
		end
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		InitializeDebugState(self)
		local result = previousRegisterSettings(self, ...)
		CreateDebugPanel(self)
		return result
	end
end

local previousSlashHandler = SlashCmdList and SlashCmdList.ROLLCURTAIN
if type(previousSlashHandler) == "function" then
	SlashCmdList.ROLLCURTAIN = function(input)
		local command = Trim(input):lower()
		local argument = command:match("^debug%s*(.*)$")
		if argument ~= nil then
			if argument == "on" then
				addon:SetDebugEnabled(true)
			elseif argument == "off" then
				addon:SetDebugEnabled(false)
			elseif argument == "status" then
				DebugPrint(string.format("Debug=%s | Channel=%s | Version=%s", addon:IsDebugEnabled() and "on" or "off", addon:GetReleaseChannel(), GetMetadata("Version", "unknown")))
			elseif argument == "dump" then
				addon:PrintDebugSnapshot()
			else
				DebugPrint("Usage: /rc debug on|off|status|dump")
			end
			return
		end
		return previousSlashHandler(input)
	end
end
