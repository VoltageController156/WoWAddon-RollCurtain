local addonName, addon = ...

local PRIMARY_SETTING_DEFINITIONS = {
	{ key = "delves", label = "Delves", tooltip = "Hide the bonus-roll prompt when a Delve is active." },
	{ key = "prey", label = "Prey hunts", tooltip = "Hide the bonus-roll prompt while you have an active Prey hunt." },
	{ key = "world", label = "World bosses and outdoor content", tooltip = "Hide bonus-roll prompts outside instances, including world bosses and other outdoor encounters." },
}

local DUNGEON_PARENT_DEFINITION = {
	key = "dungeonsEnabled",
	label = "Dungeons",
	tooltip = "Enable dungeon-specific bonus-roll suppression. Normal, Heroic, and Mythic are selected automatically when Dungeons is enabled.",
}

local DUNGEON_SETTING_DEFINITIONS = {
	{ key = "dungeonNormal", label = "Normal", tooltip = "Hide bonus-roll prompts in Normal dungeons." },
	{ key = "dungeonHeroic", label = "Heroic", tooltip = "Hide bonus-roll prompts in Heroic dungeons." },
	{ key = "dungeonMythic", label = "Mythic", tooltip = "Hide bonus-roll prompts in Mythic dungeons." },
	{ key = "dungeonMythicPlus", label = "Mythic+", tooltip = "Hide bonus-roll prompts in Mythic+ dungeons." },
}

local RAID_PARENT_DEFINITION = {
	key = "raidsEnabled",
	label = "Raids",
	tooltip = "Enable raid-specific bonus-roll suppression. Story Mode is selected automatically when Raids is enabled.",
}

local RAID_SETTING_DEFINITIONS = {
	{ key = "raidStory", label = "Story", tooltip = "Hide bonus-roll prompts in Story Mode raid instances." },
	{ key = "raidLFR", label = "LFR", tooltip = "Hide bonus-roll prompts in Raid Finder raid instances." },
	{ key = "raidNormal", label = "Normal", tooltip = "Hide bonus-roll prompts in Normal raid instances." },
	{ key = "raidHeroic", label = "Heroic", tooltip = "Hide bonus-roll prompts in Heroic raid instances." },
	{ key = "raidMythic", label = "Mythic", tooltip = "Hide bonus-roll prompts in Mythic raid instances." },
}

local SCENARIO_DEFINITION = {
	key = "scenarios",
	label = "Other scenarios",
	tooltip = "Hide bonus-roll prompts in scenarios that are not detected as Delves.",
}

local CONFIRM_DEFINITION = {
	key = "confirmBonusRoll",
	label = "Confirm before using a bonus roll",
	tooltip = "Show a confirmation with your loot specialization and remaining bonus-roll tokens before spending one.",
}

local MINIMAP_DEFINITION = {
	key = "showMinimapButton",
	label = "Show minimap button",
	tooltip = "Show Roll Curtain's draggable minimap button. Its saved position is preserved while hidden.",
}

local PROFILE_NAME_POPUP_KEY = "ROLLCURTAIN_PROFILE_NAME"
local PROFILE_DELETE_POPUP_KEY = "ROLLCURTAIN_PROFILE_DELETE"
local START_Y = -176
local ROW_SPACING = 44
local CHILD_ROW_SPACING = 52
local SECTION_SPACING = 24
local CHILD_X_DUNGEON = { 62, 188, 314, 438 }
local CHILD_X_RAID = { 62, 178, 288, 404, 520 }

local function GetMetadata(field, fallback)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, field) or fallback
	end
	return fallback
end

local function AddTooltip(frame, title, tooltip)
	frame:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if tooltip and tooltip ~= "" then GameTooltip:AddLine(tooltip, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
end

local function ApplyOptionalElvUISkin(checkbox)
	local elvUI = _G and _G.ElvUI
	if type(elvUI) ~= "table" then return end
	local unpackFn = unpack or (table and table.unpack)
	if not unpackFn then return end
	local ok, engine = pcall(function() return unpackFn(elvUI) end)
	if not ok or type(engine) ~= "table" or type(engine.GetModule) ~= "function" then return end
	local moduleOK, skins = pcall(engine.GetModule, engine, "Skins", true)
	if not moduleOK or not skins or type(skins.HandleCheckBox) ~= "function" then return end
	pcall(skins.HandleCheckBox, skins, checkbox)
end

local function CreateCheckbox(parent, definition)
	local checkbox = CreateFrame("CheckButton", nil, parent, "SettingsCheckboxTemplate")
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
	label:SetText(definition.label)
	checkbox.label = label
	checkbox.definition = definition
	AddTooltip(checkbox, definition.label, definition.tooltip)
	ApplyOptionalElvUISkin(checkbox)
	return checkbox
end

local function SetCheckboxPosition(checkbox, x, y)
	checkbox:ClearAllPoints()
	checkbox:SetPoint("TOPLEFT", x, y)
end

local function SetDefinitionGroupVisible(addonObject, definitions, visible)
	for _, definition in ipairs(definitions) do
		local checkbox = addonObject.settingsControls[definition.key]
		if checkbox then
			if visible then checkbox:Show(); checkbox.label:Show() else checkbox:Hide(); checkbox.label:Hide() end
		end
	end
end

local function SetDefinitionGroup(addonObject, definitions, value)
	for _, definition in ipairs(definitions) do
		addonObject:SetSetting(definition.key, value)
		local checkbox = addonObject.settingsControls[definition.key]
		if checkbox then checkbox:SetChecked(value) end
	end
end

local function HasSelectedDifficulty(addonObject, definitions)
	for _, definition in ipairs(definitions) do
		if addonObject:GetSetting(definition.key) == true then return true end
	end
	return false
end

local function SetFontStringPoint(fontString, ...)
	if fontString.ClearAllPoints then fontString:ClearAllPoints() end
	fontString:SetPoint(...)
end

local function RefreshProfileControls(addonObject)
	if addonObject.profileSelector then
		addonObject.profileSelector:SetText(addonObject:GetCurrentProfileName())
	end
	local isDefault = addonObject:GetCurrentProfileName() == "Default"
	if addonObject.renameProfileButton and addonObject.renameProfileButton.SetEnabled then addonObject.renameProfileButton:SetEnabled(not isDefault) end
	if addonObject.deleteProfileButton and addonObject.deleteProfileButton.SetEnabled then addonObject.deleteProfileButton:SetEnabled(not isDefault) end
	if addonObject.copyProfileButton and addonObject.copyProfileButton.SetEnabled then addonObject.copyProfileButton:SetEnabled(#addonObject:GetProfileNames() > 1) end
end

local function LayoutSettings(addonObject)
	if not addonObject.settingsControls then return end
	local y = START_Y

	for _, definition in ipairs(PRIMARY_SETTING_DEFINITIONS) do
		SetCheckboxPosition(addonObject.settingsControls[definition.key], 24, y)
		y = y - ROW_SPACING
	end

	SetCheckboxPosition(addonObject.settingsControls.dungeonsEnabled, 24, y)
	y = y - ROW_SPACING
	local dungeonsExpanded = addonObject:GetSetting("dungeonsEnabled") == true
	SetDefinitionGroupVisible(addonObject, DUNGEON_SETTING_DEFINITIONS, dungeonsExpanded)
	if dungeonsExpanded then
		for index, definition in ipairs(DUNGEON_SETTING_DEFINITIONS) do
			SetCheckboxPosition(addonObject.settingsControls[definition.key], CHILD_X_DUNGEON[index], y)
		end
		y = y - CHILD_ROW_SPACING
	end

	SetCheckboxPosition(addonObject.settingsControls.raidsEnabled, 24, y)
	y = y - ROW_SPACING
	local raidsExpanded = addonObject:GetSetting("raidsEnabled") == true
	SetDefinitionGroupVisible(addonObject, RAID_SETTING_DEFINITIONS, raidsExpanded)
	if raidsExpanded then
		for index, definition in ipairs(RAID_SETTING_DEFINITIONS) do
			SetCheckboxPosition(addonObject.settingsControls[definition.key], CHILD_X_RAID[index], y)
		end
		y = y - CHILD_ROW_SPACING
	end

	SetCheckboxPosition(addonObject.settingsControls.scenarios, 24, y)
	y = y - ROW_SPACING - SECTION_SPACING

	if addonObject.safetyHeader then SetFontStringPoint(addonObject.safetyHeader, "TOPLEFT", 18, y) end
	SetCheckboxPosition(addonObject.settingsControls.confirmBonusRoll, 24, y - 34)
	if addonObject.previewButton then
		addonObject.previewButton:ClearAllPoints()
		addonObject.previewButton:SetPoint("TOPLEFT", 24, y - 68)
	end
	y = y - 112

	if addonObject.interfaceHeader then SetFontStringPoint(addonObject.interfaceHeader, "TOPLEFT", 18, y) end
	SetCheckboxPosition(addonObject.settingsControls.showMinimapButton, 24, y - 34)
end

local function EnsureProfilePopups()
	if not StaticPopupDialogs then return end
	if not StaticPopupDialogs[PROFILE_NAME_POPUP_KEY] then
		StaticPopupDialogs[PROFILE_NAME_POPUP_KEY] = {
			text = "%s",
			button1 = "Save",
			button2 = CANCEL or "Cancel",
			hasEditBox = true,
			maxLetters = 32,
			OnShow = function(self, data)
				if self.EditBox then
					self.EditBox:SetText(data and data.initialText or "")
					self.EditBox:HighlightText()
					self.EditBox:SetFocus()
				end
			end,
			OnAccept = function(self, data)
				if data and type(data.onAccept) == "function" and self.EditBox then
					data.onAccept(self.EditBox:GetText())
				end
			end,
			EditBoxOnEnterPressed = function(editBox)
				local parent = editBox:GetParent()
				if parent and parent.button1 then parent.button1:Click() end
			end,
			EditBoxOnEscapePressed = function(editBox)
				local parent = editBox:GetParent()
				if parent then parent:Hide() end
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end

	if not StaticPopupDialogs[PROFILE_DELETE_POPUP_KEY] then
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
end

local function ShowNamePrompt(title, initialText, onAccept)
	EnsureProfilePopups()
	if StaticPopup_Show then
		StaticPopup_Show(PROFILE_NAME_POPUP_KEY, title, nil, { initialText = initialText or "", onAccept = onAccept })
	end
end

local function OpenProfileSelectionMenu(button)
	if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
	MenuUtil.CreateContextMenu(button, function(_, rootDescription)
		rootDescription:CreateTitle("Profiles")
		local current = addon:GetCurrentProfileName()
		for _, name in ipairs(addon:GetProfileNames()) do
			local label = name == current and (name .. "  (Current)") or name
			rootDescription:CreateButton(label, function() addon:SelectProfile(name) end)
		end
	end)
end

local function OpenCopyProfileMenu(button)
	if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
	MenuUtil.CreateContextMenu(button, function(_, rootDescription)
		rootDescription:CreateTitle("Copy settings from")
		local current = addon:GetCurrentProfileName()
		for _, name in ipairs(addon:GetProfileNames()) do
			if name ~= current then rootDescription:CreateButton(name, function() addon:CopyProfile(name) end) end
		end
	end)
end

local function AddHelpLine(panel, y, command, description)
	local commandText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	commandText:SetPoint("TOPLEFT", 24, y)
	commandText:SetText(command)
	local descriptionText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	descriptionText:SetPoint("TOPLEFT", 190, y)
	descriptionText:SetText(description)
	return y - 34
end

local function CreateHelpPanel()
	local panel = CreateFrame("Frame")
	panel:SetSize(650, 560)
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Roll Curtain — Commands & Help")

	local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 16, -56)
	intro:SetText("All slash aliases use the same commands.")

	local y = -96
	y = AddHelpLine(panel, y, "/rc", "Open Roll Curtain settings.")
	y = AddHelpLine(panel, y, "/rc status", "Show the active profile, detected activity, Curtain state, and confirmation state.")
	y = AddHelpLine(panel, y, "/rc show", "Restore the most recently hidden bonus-roll prompt if it is still active.")
	y = AddHelpLine(panel, y, "/rc reset", "Reset only the current profile to Roll Curtain defaults.")

	local aliases = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	aliases:SetPoint("TOPLEFT", 24, y - 12)
	aliases:SetText("Aliases: /rollcurtain, /rcurtain, /rollc, /rc")

	local minimapHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	minimapHeader:SetPoint("TOPLEFT", 24, y - 62)
	minimapHeader:SetText("Minimap button")
	local minimapHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	minimapHelp:SetPoint("TOPLEFT", 24, y - 90)
	minimapHelp:SetText("Left-click opens settings. Right-click restores a hidden bonus-roll prompt. Drag to reposition it around the minimap.")

	local profilesHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	profilesHeader:SetPoint("TOPLEFT", 24, y - 140)
	profilesHeader:SetText("Profiles")
	local profilesHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	profilesHelp:SetPoint("TOPLEFT", 24, y - 168)
	profilesHelp:SetText("Each character is assigned to a named profile. Characters can share a profile, and changes to a shared profile apply to every character assigned to it.")
	return panel
end

function addon:RefreshSettingsUI()
	if not self.settingsControls then return end
	for key, checkbox in pairs(self.settingsControls) do
		if self.defaults[key] ~= nil then checkbox:SetChecked(self:GetSetting(key) == true) end
	end
	RefreshProfileControls(self)
	LayoutSettings(self)
end

function addon:RegisterSettings()
	if self.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
	EnsureProfilePopups()

	local panel = CreateFrame("Frame")
	panel:SetSize(650, 790)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Roll Curtain")

	local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	defaultsButton:SetSize(96, 24)
	defaultsButton:SetPoint("TOPRIGHT", -18, -12)
	defaultsButton:SetText("Defaults")
	defaultsButton:SetScript("OnClick", function() self:ResetDefaults() end)

	local profileHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	profileHeader:SetPoint("TOPLEFT", 16, -56)
	profileHeader:SetText("Profile for this character")

	local profileSelector = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	profileSelector:SetSize(190, 24)
	profileSelector:SetPoint("TOPLEFT", 24, -82)
	profileSelector:SetScript("OnClick", function(button) OpenProfileSelectionMenu(button) end)
	self.profileSelector = profileSelector

	local newButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	newButton:SetSize(64, 24); newButton:SetPoint("LEFT", profileSelector, "RIGHT", 10, 0); newButton:SetText("New")
	newButton:SetScript("OnClick", function()
		ShowNamePrompt("Create profile", "", function(name) addon:CreateProfile(name) end)
	end)

	local copyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	copyButton:SetSize(64, 24); copyButton:SetPoint("LEFT", newButton, "RIGHT", 8, 0); copyButton:SetText("Copy")
	copyButton:SetScript("OnClick", function(button) OpenCopyProfileMenu(button) end)
	self.copyProfileButton = copyButton

	local renameButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	renameButton:SetSize(70, 24); renameButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0); renameButton:SetText("Rename")
	renameButton:SetScript("OnClick", function()
		ShowNamePrompt("Rename profile", addon:GetCurrentProfileName(), function(name) addon:RenameCurrentProfile(name) end)
	end)
	self.renameProfileButton = renameButton

	local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	deleteButton:SetSize(64, 24); deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 8, 0); deleteButton:SetText("Delete")
	deleteButton:SetScript("OnClick", function()
		if addon:GetCurrentProfileName() ~= "Default" and StaticPopup_Show then
			StaticPopup_Show(PROFILE_DELETE_POPUP_KEY, addon:GetCurrentProfileName())
		end
	end)
	self.deleteProfileButton = deleteButton

	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header:SetPoint("TOPLEFT", 16, -136)
	header:SetText("Hide the bonus-roll prompt in these activities")

	self.settingsControls = {}
	for _, definition in ipairs(PRIMARY_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button) self:SetSetting(key, button:GetChecked() == true) end)
		self.settingsControls[key] = checkbox
	end

	local dungeonCheckbox = CreateCheckbox(panel, DUNGEON_PARENT_DEFINITION)
	self.settingsControls.dungeonsEnabled = dungeonCheckbox
	for _, definition in ipairs(DUNGEON_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button)
			self:SetSetting(key, button:GetChecked() == true)
			if not HasSelectedDifficulty(self, DUNGEON_SETTING_DEFINITIONS) then
				self:SetSetting("dungeonsEnabled", false)
				dungeonCheckbox:SetChecked(false)
			end
			LayoutSettings(self)
		end)
		self.settingsControls[key] = checkbox
	end
	dungeonCheckbox:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		self:SetSetting("dungeonsEnabled", enabled)
		SetDefinitionGroup(self, DUNGEON_SETTING_DEFINITIONS, false)
		if enabled then
			for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic" }) do
				self:SetSetting(key, true)
				self.settingsControls[key]:SetChecked(true)
			end
		end
		LayoutSettings(self)
	end)

	local raidCheckbox = CreateCheckbox(panel, RAID_PARENT_DEFINITION)
	self.settingsControls.raidsEnabled = raidCheckbox
	for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button)
			self:SetSetting(key, button:GetChecked() == true)
			if not HasSelectedDifficulty(self, RAID_SETTING_DEFINITIONS) then
				self:SetSetting("raidsEnabled", false)
				raidCheckbox:SetChecked(false)
			end
			LayoutSettings(self)
		end)
		self.settingsControls[key] = checkbox
	end
	raidCheckbox:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		self:SetSetting("raidsEnabled", enabled)
		SetDefinitionGroup(self, RAID_SETTING_DEFINITIONS, false)
		if enabled then
			self:SetSetting("raidStory", true)
			self.settingsControls.raidStory:SetChecked(true)
		end
		LayoutSettings(self)
	end)

	local scenarioCheckbox = CreateCheckbox(panel, SCENARIO_DEFINITION)
	self.settingsControls.scenarios = scenarioCheckbox
	scenarioCheckbox:SetScript("OnClick", function(button) self:SetSetting("scenarios", button:GetChecked() == true) end)

	local safetyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	safetyHeader:SetText("Safety")
	self.safetyHeader = safetyHeader

	local confirmCheckbox = CreateCheckbox(panel, CONFIRM_DEFINITION)
	self.settingsControls.confirmBonusRoll = confirmCheckbox
	confirmCheckbox:SetScript("OnClick", function(button) self:SetSetting("confirmBonusRoll", button:GetChecked() == true) end)

	local previewButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	previewButton:SetSize(156, 24)
	previewButton:SetText("Preview Confirmation")
	previewButton:SetScript("OnClick", function() self:ShowBonusRollConfirmationPreview() end)
	self.previewButton = previewButton

	local interfaceHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	interfaceHeader:SetText("Interface")
	self.interfaceHeader = interfaceHeader

	local minimapCheckbox = CreateCheckbox(panel, MINIMAP_DEFINITION)
	self.settingsControls.showMinimapButton = minimapCheckbox
	minimapCheckbox:SetScript("OnClick", function(button)
		self:SetSetting("showMinimapButton", button:GetChecked() == true)
		if self.UpdateMinimapButtonVisibility then self:UpdateMinimapButtonVisibility() end
	end)

	local version = GetMetadata("Version", "Unknown")
	local author = GetMetadata("Author", "VoltageController156")
	local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", 18, 18)
	footer:SetText(string.format("Version %s  •  Author: %s", version, author))

	panel:SetScript("OnShow", function() self:RefreshSettingsUI() end)
	self.settingsPanel = panel
	self:RefreshSettingsUI()

	local category = Settings.RegisterCanvasLayoutCategory(panel, "Roll Curtain")
	Settings.RegisterAddOnCategory(category)
	self.settingsCategory = category

	if Settings.RegisterCanvasLayoutSubcategory then
		local helpPanel = CreateHelpPanel()
		self.helpSettingsPanel = helpPanel
		self.helpSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(category, helpPanel, "Commands & Help")
	end
end
