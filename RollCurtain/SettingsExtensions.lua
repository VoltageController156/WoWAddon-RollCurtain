local addonName, addon = ...

local DEFAULT_PROFILE_NAME = "Default"
local MAX_PROFILE_NAME_LENGTH = 32
local PROFILE_DELETE_POPUP_KEY = "ROLLCURTAIN_PROFILE_DELETE_V2"
local MAIN_START_Y = -104
local ROW_SPACING = 44
local CHILD_ROW_SPACING = 48
local SECTION_SPACING = 26
local DUNGEON_KEYS = { "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }
local RAID_KEYS = { "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }
local DUNGEON_X = { 62, 188, 314, 438 }
local RAID_X = { 62, 178, 288, 404, 520 }
local NOTIFICATION_X = { 24, 220, 416 }
local NOTIFICATION_ROW_SPACING = 38

local function Print(message)
	if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff7dd3fcRoll Curtain:|r " .. message)
	end
end

local function Trim(value)
	if type(strtrim) == "function" then return strtrim(value or "") end
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ProfileNameExists(name)
	local wanted = Trim(name):lower()
	for _, existingName in ipairs(addon:GetProfileNames()) do
		if existingName:lower() == wanted then return true end
	end
	return false
end

-- New profiles intentionally inherit the current profile. This mirrors the
-- common WoW profile workflow where a player starts from a working setup and
-- then changes only what is different for the new profile.
function addon:CreateProfile(name)
	name = Trim(name):gsub("[%c]", "")
	if name == "" then
		Print("Profile name cannot be empty.")
		return false
	end
	if #name > MAX_PROFILE_NAME_LENGTH then
		Print(string.format("Profile names are limited to %d characters.", MAX_PROFILE_NAME_LENGTH))
		return false
	end
	if ProfileNameExists(name) then
		Print("A profile with that name already exists.")
		return false
	end
	if type(RollCurtainDB) ~= "table" or type(RollCurtainDB.profiles) ~= "table" then return false end

	local sourceName = self:GetCurrentProfileName()
	local source = self:GetCurrentProfile()
	local profile = {}
	for key, defaultValue in pairs(self.defaults) do
		local value = source and source[key]
		profile[key] = type(value) == "boolean" and value or defaultValue
	end

	RollCurtainDB.profiles[name] = profile
	local characterKey = self:GetCharacterKey()
	RollCurtainDB.profileKeys[characterKey] = name
	self.currentCharacterKey = characterKey
	self.currentProfileName = name
	self.currentProfile = profile
	self:RefreshProfileConsumers()
	Print(string.format("Profile created: %s (copied from %s).", name, sourceName))
	return true
end

function addon:GetCharactersUsingProfile(profileName)
	local characters = {}
	if RollCurtainDB and type(RollCurtainDB.profileKeys) == "table" then
		for characterKey, assignedProfile in pairs(RollCurtainDB.profileKeys) do
			if assignedProfile == profileName then table.insert(characters, characterKey) end
		end
	end
	table.sort(characters, function(a, b) return a:lower() < b:lower() end)
	return characters
end

function addon:GetProfileAssignmentsText()
	local lines = {}
	for _, profileName in ipairs(self:GetProfileNames()) do
		table.insert(lines, "|cffffd100" .. profileName .. "|r")
		local characters = self:GetCharactersUsingProfile(profileName)
		if #characters == 0 then
			table.insert(lines, "  No characters assigned")
		else
			for _, characterKey in ipairs(characters) do
				table.insert(lines, "  • " .. characterKey)
			end
		end
		table.insert(lines, "")
	end
	return table.concat(lines, "\n")
end

local function SetPoint(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function SetFontPoint(region, x, y, width)
	if not region then return end
	if type(region.ClearAllPoints) == "function" then region:ClearAllPoints() end
	region:SetPoint("TOPLEFT", x, y)
	if width and type(region.SetWidth) == "function" then region:SetWidth(width) end
	if type(region.SetJustifyH) == "function" then region:SetJustifyH("LEFT") end
	if type(region.SetWordWrap) == "function" then region:SetWordWrap(true) end
end

local function FindTextRegion(panel, wanted)
	if not panel or type(panel.GetRegions) ~= "function" then return nil end
	for _, region in ipairs({ panel:GetRegions() }) do
		local text
		if region and type(region.GetText) == "function" then text = region:GetText()
		elseif region then text = region.text end
		if text == wanted then return region end
	end
	return nil
end

local function HideLegacyProfileUI(addonObject)
	for _, frame in ipairs({
		addonObject.profileSelector,
		addonObject.copyProfileButton,
		addonObject.renameProfileButton,
		addonObject.deleteProfileButton,
	}) do
		if frame and type(frame.Hide) == "function" then frame:Hide() end
	end

	local panel = addonObject.settingsPanel
	if panel and type(panel.GetChildren) == "function" then
		for _, child in ipairs({ panel:GetChildren() }) do
			local text
			if child and type(child.GetText) == "function" then text = child:GetText()
			elseif child then text = child.text end
			if text == "New" or text == "Copy" or text == "Rename" or text == "Delete" then
				if type(child.Hide) == "function" then child:Hide() end
			end
		end
	end

	local profileHeader = FindTextRegion(panel, "Profile for this character")
	if profileHeader and type(profileHeader.Hide) == "function" then profileHeader:Hide() end
end

local function CreateNotificationCheckbox(parent, definition)
	local checkbox = CreateFrame("CheckButton", nil, parent, "SettingsCheckboxTemplate")
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
	label:SetText(definition.label)
	checkbox.label = label
	checkbox:SetScript("OnClick", function(button)
		addon:SetSetting(definition.key, button:GetChecked() == true)
	end)
	checkbox:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(definition.label)
		GameTooltip:AddLine("Display the Roll Curtain suppression notification in local chat windows that receive this chat category. Nothing is sent to other players.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	checkbox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return checkbox
end

local function EnsureNotificationControls(addonObject)
	if addonObject.notificationControls or not addonObject.settingsPanel then return end
	addonObject.notificationControls = {}
	addonObject.settingsControls = addonObject.settingsControls or {}

	local header = addonObject.settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header:SetText("Chat Notifications")
	addonObject.notificationHeader = header

	local help = addonObject.settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetText("Choose any number of local chat destinations. Roll Curtain only displays the notification on your client; it never sends these messages to other players.")
	addonObject.notificationHelp = help

	for _, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		local checkbox = CreateNotificationCheckbox(addonObject.settingsPanel, definition)
		addonObject.notificationControls[definition.key] = checkbox
		addonObject.settingsControls[definition.key] = checkbox
	end
end

local function ReflowMainSettings(addonObject)
	local controls = addonObject.settingsControls
	local panel = addonObject.settingsPanel
	if not controls or not panel then return end

	HideLegacyProfileUI(addonObject)
	local activityHeader = FindTextRegion(panel, "Hide the bonus-roll prompt in these activities")
	SetFontPoint(activityHeader, 16, -62, 560)

	local y = MAIN_START_Y
	for _, key in ipairs({ "delves", "prey", "world" }) do
		SetPoint(controls[key], 24, y)
		y = y - ROW_SPACING
	end

	SetPoint(controls.dungeonsEnabled, 24, y)
	y = y - ROW_SPACING
	if addonObject:GetSetting("dungeonsEnabled") == true then
		for index, key in ipairs(DUNGEON_KEYS) do SetPoint(controls[key], DUNGEON_X[index], y) end
		y = y - CHILD_ROW_SPACING
	end

	SetPoint(controls.raidsEnabled, 24, y)
	y = y - ROW_SPACING
	if addonObject:GetSetting("raidsEnabled") == true then
		for index, key in ipairs(RAID_KEYS) do SetPoint(controls[key], RAID_X[index], y) end
		y = y - CHILD_ROW_SPACING
	end

	SetPoint(controls.scenarios, 24, y)
	y = y - ROW_SPACING - SECTION_SPACING

	SetFontPoint(addonObject.safetyHeader, 18, y, 560)
	SetPoint(controls.confirmBonusRoll, 24, y - 34)
	SetPoint(addonObject.previewButton, 24, y - 72)
	y = y - 120

	SetFontPoint(addonObject.interfaceHeader, 18, y, 560)
	SetPoint(controls.showMinimapButton, 24, y - 34)
	y = y - 92

	SetFontPoint(addonObject.notificationHeader, 18, y, 560)
	SetFontPoint(addonObject.notificationHelp, 24, y - 28, 550)
	local notificationY = y - 82
	for index, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		local column = ((index - 1) % 3) + 1
		local row = math.floor((index - 1) / 3)
		SetPoint(controls[definition.key], NOTIFICATION_X[column], notificationY - row * NOTIFICATION_ROW_SPACING)
	end

	local rows = math.ceil(#(addonObject.chatDestinationDefinitions or {}) / 3)
	local contentHeight = math.max(760, math.abs(notificationY - rows * NOTIFICATION_ROW_SPACING - 110))
	if type(panel.SetHeight) == "function" then panel:SetHeight(contentHeight) end
end

local function OpenProfileMenu(button, onSelect, excludeName)
	if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
	MenuUtil.CreateContextMenu(button, function(_, rootDescription)
		rootDescription:CreateTitle("Profiles")
		for _, profileName in ipairs(addon:GetProfileNames()) do
			if profileName ~= excludeName then
				rootDescription:CreateButton(profileName, function() onSelect(profileName) end)
			end
		end
	end)
end

local function CreateLabel(panel, text, x, y)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function CreateSectionHeader(panel, text, y)
	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", 24, y)
	header:SetText(text)
	return header
end

local function CreateEditBox(panel, x, y, width)
	local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	editBox:SetSize(width, 24)
	editBox:SetPoint("TOPLEFT", x, y)
	if type(editBox.SetAutoFocus) == "function" then editBox:SetAutoFocus(false) end
	return editBox
end

local function RefreshProfilesPanel(addonObject)
	local ui = addonObject.profilesUI
	if not ui then return end
	local current = addonObject:GetCurrentProfileName()
	ui.currentProfileButton:SetText(current)
	ui.currentCharacter:SetText("Current character: " .. addonObject:GetCharacterKey())

	if not (type(ui.renameEdit.HasFocus) == "function" and ui.renameEdit:HasFocus()) then
		ui.renameEdit:SetText(current)
	end
	local protected = current == DEFAULT_PROFILE_NAME
	if type(ui.renameButton.SetEnabled) == "function" then ui.renameButton:SetEnabled(not protected) end
	if type(ui.deleteButton.SetEnabled) == "function" then ui.deleteButton:SetEnabled(not protected) end

	local copySource = addonObject.profileCopySourceName
	local validCopySource = false
	for _, profileName in ipairs(addonObject:GetProfileNames()) do
		if profileName == copySource and profileName ~= current then validCopySource = true break end
	end
	if not validCopySource then
		copySource = nil
		for _, profileName in ipairs(addonObject:GetProfileNames()) do
			if profileName ~= current then copySource = profileName break end
		end
		addonObject.profileCopySourceName = copySource
	end
	ui.copySourceButton:SetText(copySource or "No other profiles")
	if type(ui.copyButton.SetEnabled) == "function" then ui.copyButton:SetEnabled(copySource ~= nil) end

	local characters = addonObject:GetCharactersUsingProfile(current)
	if #characters == 0 then
		ui.currentUsers:SetText("Characters using this profile: none")
	else
		ui.currentUsers:SetText("Characters using this profile: " .. table.concat(characters, ", "))
	end

	ui.assignments:SetText(addonObject:GetProfileAssignmentsText())
	local assignmentHeight = type(ui.assignments.GetStringHeight) == "function" and ui.assignments:GetStringHeight() or 160
	if addonObject.profilesContent and type(addonObject.profilesContent.SetHeight) == "function" then
		addonObject.profilesContent:SetHeight(math.max(720, 540 + assignmentHeight))
	end
end

local function EnsureProfileDeletePopup()
	if not StaticPopupDialogs or StaticPopupDialogs[PROFILE_DELETE_POPUP_KEY] then return end
	StaticPopupDialogs[PROFILE_DELETE_POPUP_KEY] = {
		text = "Delete profile |cffffd100%s|r? Characters using it will be moved to Default.",
		button1 = "Delete",
		button2 = CANCEL or "Cancel",
		OnAccept = function() addon:DeleteCurrentProfile() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function CreateProfilesPanel(addonObject)
	if addonObject.profilesSettingsCategory or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
	EnsureProfileDeletePopup()

	local wrapper = CreateFrame("Frame")
	wrapper:SetSize(650, 560)
	local scrollFrame = CreateFrame("ScrollFrame", nil, wrapper, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 0, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)
	local panel = CreateFrame("Frame", nil, scrollFrame)
	panel:SetSize(608, 720)
	if type(scrollFrame.SetScrollChild) == "function" then scrollFrame:SetScrollChild(panel) end

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Roll Curtain — Profiles")
	local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 16, -52)
	intro:SetWidth(560)
	intro:SetJustifyH("LEFT")
	intro:SetText("Profiles store Roll Curtain settings and can be shared across characters. New profiles start as a copy of your currently active profile.")

	CreateSectionHeader(panel, "Current Profile", -104)
	local currentProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	currentProfileButton:SetSize(220, 26)
	currentProfileButton:SetPoint("TOPLEFT", 24, -132)
	currentProfileButton:SetScript("OnClick", function(button)
		OpenProfileMenu(button, function(profileName) addon:SelectProfile(profileName) end)
	end)
	local currentCharacter = CreateLabel(panel, "", 264, -136)
	local currentUsers = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	currentUsers:SetPoint("TOPLEFT", 24, -166)
	currentUsers:SetWidth(550)
	currentUsers:SetJustifyH("LEFT")

	CreateSectionHeader(panel, "Create New Profile", -214)
	local createHint = CreateLabel(panel, "Starts as a copy of the current profile.", 24, -240)
	local createEdit = CreateEditBox(panel, 24, -268, 260)
	local createButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	createButton:SetSize(92, 24)
	createButton:SetPoint("LEFT", createEdit, "RIGHT", 12, 0)
	createButton:SetText("Create")
	createButton:SetScript("OnClick", function()
		if addon:CreateProfile(createEdit:GetText()) then createEdit:SetText("") end
	end)

	CreateSectionHeader(panel, "Copy Settings From", -320)
	local copySourceButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	copySourceButton:SetSize(220, 24)
	copySourceButton:SetPoint("TOPLEFT", 24, -348)
	copySourceButton:SetScript("OnClick", function(button)
		OpenProfileMenu(button, function(profileName)
			addon.profileCopySourceName = profileName
			RefreshProfilesPanel(addon)
		end, addon:GetCurrentProfileName())
	end)
	local copyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	copyButton:SetSize(132, 24)
	copyButton:SetPoint("LEFT", copySourceButton, "RIGHT", 12, 0)
	copyButton:SetText("Copy Into Current")
	copyButton:SetScript("OnClick", function()
		if addon.profileCopySourceName then addon:CopyProfile(addon.profileCopySourceName) end
	end)

	CreateSectionHeader(panel, "Manage Current Profile", -400)
	local renameEdit = CreateEditBox(panel, 24, -428, 220)
	local renameButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	renameButton:SetSize(90, 24)
	renameButton:SetPoint("LEFT", renameEdit, "RIGHT", 12, 0)
	renameButton:SetText("Rename")
	renameButton:SetScript("OnClick", function() addon:RenameCurrentProfile(renameEdit:GetText()) end)
	local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	deleteButton:SetSize(128, 24)
	deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 12, 0)
	deleteButton:SetText("Delete Profile")
	deleteButton:SetScript("OnClick", function()
		if addon:GetCurrentProfileName() ~= DEFAULT_PROFILE_NAME and StaticPopup_Show then
			StaticPopup_Show(PROFILE_DELETE_POPUP_KEY, addon:GetCurrentProfileName())
		end
	end)

	CreateSectionHeader(panel, "Profile Assignments", -486)
	local assignmentHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	assignmentHint:SetPoint("TOPLEFT", 24, -512)
	assignmentHint:SetWidth(550)
	assignmentHint:SetJustifyH("LEFT")
	assignmentHint:SetText("Characters are remembered after they use Roll Curtain on that character. Shared profiles apply the same settings to every assigned character.")
	local assignments = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	assignments:SetPoint("TOPLEFT", 36, -558)
	assignments:SetWidth(530)
	assignments:SetJustifyH("LEFT")
	assignments:SetJustifyV("TOP")

	addonObject.profilesUI = {
		currentProfileButton = currentProfileButton,
		currentCharacter = currentCharacter,
		currentUsers = currentUsers,
		createEdit = createEdit,
		copySourceButton = copySourceButton,
		copyButton = copyButton,
		renameEdit = renameEdit,
		renameButton = renameButton,
		deleteButton = deleteButton,
		assignments = assignments,
	}
	addonObject.profilesContent = panel
	addonObject.profilesScrollFrame = scrollFrame
	panel:SetScript("OnShow", function() RefreshProfilesPanel(addon) end)

	addonObject.profilesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(addonObject.settingsCategory, wrapper, "Profiles")
	RefreshProfilesPanel(addonObject)
end

local function HookReflowControls(addonObject)
	for _, key in ipairs({
		"dungeonsEnabled", "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus",
		"raidsEnabled", "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic",
	}) do
		local control = addonObject.settingsControls and addonObject.settingsControls[key]
		if control and not control.rollCurtainExtendedLayoutHook and type(control.GetScript) == "function" and type(control.SetScript) == "function" then
			local previous = control:GetScript("OnClick")
			if previous then
				control:SetScript("OnClick", function(...)
					previous(...)
					ReflowMainSettings(addon)
				end)
			end
			control.rollCurtainExtendedLayoutHook = true
		end
	end
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		previousRefreshSettingsUI(self, ...)
		if self.notificationControls then
			for _, definition in ipairs(self.chatDestinationDefinitions or {}) do
				local checkbox = self.notificationControls[definition.key]
				if checkbox then checkbox:SetChecked(self:GetSetting(definition.key) == true) end
			end
		end
		RefreshProfilesPanel(self)
		ReflowMainSettings(self)
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		EnsureNotificationControls(self)
		CreateProfilesPanel(self)
		HookReflowControls(self)
		HideLegacyProfileUI(self)
		self:RefreshSettingsUI()
		return result
	end
end
