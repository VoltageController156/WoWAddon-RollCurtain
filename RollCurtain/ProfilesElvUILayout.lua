local addonName, addon = ...

-- Visual-only refinement for the Profiles settings page. The underlying
-- profile behavior stays in SettingsExtensions.lua; this file presents those
-- controls in the compact, explanatory layout popularized by ElvUI's profile
-- page while retaining Roll Curtain's native Blizzard Settings appearance.

local function SetPoint(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function FindRegionByText(panel, wanted)
	if not panel or type(panel.GetRegions) ~= "function" then return nil end
	for _, region in ipairs({ panel:GetRegions() }) do
		local text
		if region and type(region.GetText) == "function" then text = region:GetText()
		elseif region then text = region.text end
		if text == wanted then return region end
	end
	return nil
end

local function FindChildByText(panel, wanted)
	if not panel or type(panel.GetChildren) ~= "function" then return nil end
	for _, child in ipairs({ panel:GetChildren() }) do
		local text
		if child and type(child.GetText) == "function" then text = child:GetText()
		elseif child then text = child.text end
		if text == wanted then return child end
	end
	return nil
end

local function CreateLabel(panel, text, x, y, template)
	local label = panel:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function CreateHelpText(panel, text, x, y, width)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", x, y)
	label:SetWidth(width)
	label:SetJustifyH("LEFT")
	if type(label.SetWordWrap) == "function" then label:SetWordWrap(true) end
	label:SetText(text)
	return label
end

local function UpdateElvUIProfileText(addonObject)
	local layout = addonObject.elvUIProfileLayout
	if not layout then return end
	local current = addonObject:GetCurrentProfileName()
	layout.currentProfile:SetText("Current Profile: |cffffd100" .. current .. "|r")
	layout.currentCharacter:SetText("Current Character: |cffffd100" .. addonObject:GetCharacterKey() .. "|r")
end

local function ApplyElvUIProfileLayout(addonObject)
	local panel = addonObject.profilesContent
	local ui = addonObject.profilesUI
	if not panel or not ui then return end

	-- Existing headings are replaced with a denser ElvUI-inspired hierarchy.
	for _, text in ipairs({
		"Current Profile",
		"Create New Profile",
		"Starts as a copy of the current profile.",
		"Copy Settings From",
		"Manage Current Profile",
		"Profile Assignments",
	}) do
		local region = FindRegionByText(panel, text)
		if region and type(region.Hide) == "function" then region:Hide() end
	end

	local title = FindRegionByText(panel, "Roll Curtain — Profiles")
	if title then SetPoint(title, 16, -16) end
	local oldIntro = FindRegionByText(panel, "Profiles store Roll Curtain settings and can be shared across characters. New profiles start as a copy of your currently active profile.")
	if oldIntro and type(oldIntro.Hide) == "function" then oldIntro:Hide() end

	if not addonObject.elvUIProfileLayout then
		local intro = CreateHelpText(panel,
			"You can change the active profile to maintain different Roll Curtain settings for each character, or share one profile across several characters.",
			24, -54, 552)
		local resetHelp = CreateHelpText(panel,
			"Reset the current profile back to Roll Curtain defaults if you want to start over.",
			24, -86, 552)

		local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		resetButton:SetSize(150, 24)
		resetButton:SetPoint("TOPLEFT", 24, -116)
		resetButton:SetText("Reset Profile")
		resetButton:SetScript("OnClick", function() addon:ResetDefaults() end)

		local currentProfile = CreateLabel(panel, "", 188, -121, "GameFontHighlight")
		local currentCharacter = CreateLabel(panel, "", 370, -121, "GameFontHighlightSmall")

		local chooseHelp = CreateHelpText(panel,
			"Create a new profile by entering a name, or choose one of your existing profiles. New profiles begin as a copy of the profile you are currently using.",
			24, -162, 552)
		local newLabel = CreateLabel(panel, "New", 24, -204)
		local existingLabel = CreateLabel(panel, "Existing Profiles", 306, -204)

		local copyHelp = CreateHelpText(panel,
			"Copy the settings from an existing profile into the currently active profile.",
			24, -286, 552)
		local copyLabel = CreateLabel(panel, "Copy From", 24, -318)

		local renameHelp = CreateHelpText(panel,
			"Rename the currently active profile. The Default profile cannot be renamed.",
			24, -374, 552)
		local renameLabel = CreateLabel(panel, "Rename Current Profile", 24, -406)

		local deleteHelp = CreateHelpText(panel,
			"Delete the active profile when it is no longer needed. Characters assigned to it will be moved to Default.",
			24, -462, 552)
		local deleteLabel = CreateLabel(panel, "Delete Current Profile", 24, -494)

		local assignmentsHeader = CreateLabel(panel, "Characters Using Profiles", 24, -554)
		local assignmentsHelp = CreateHelpText(panel,
			"Roll Curtain remembers a character after that character has loaded the addon. Characters listed under the same profile share the same settings.",
			24, -582, 552)

		addonObject.elvUIProfileLayout = {
			intro = intro,
			resetHelp = resetHelp,
			resetButton = resetButton,
			currentProfile = currentProfile,
			currentCharacter = currentCharacter,
			chooseHelp = chooseHelp,
			newLabel = newLabel,
			existingLabel = existingLabel,
			copyHelp = copyHelp,
			copyLabel = copyLabel,
			renameHelp = renameHelp,
			renameLabel = renameLabel,
			deleteHelp = deleteHelp,
			deleteLabel = deleteLabel,
			assignmentsHeader = assignmentsHeader,
			assignmentsHelp = assignmentsHelp,
		}
	end

	local createButton = FindChildByText(panel, "Create")

	-- New + Existing Profiles side-by-side, matching the ElvUI profile page.
	SetPoint(ui.createEdit, 24, -228)
	if type(ui.createEdit.SetSize) == "function" then ui.createEdit:SetSize(210, 24) end
	if createButton then
		SetPoint(createButton, 242, -228)
		if type(createButton.SetSize) == "function" then createButton:SetSize(54, 24) end
	end
	SetPoint(ui.currentProfileButton, 306, -228)
	if type(ui.currentProfileButton.SetSize) == "function" then ui.currentProfileButton:SetSize(218, 24) end

	-- The old top-of-page character/user strings are redundant with the new
	-- status line and the assignment list below.
	if ui.currentCharacter and type(ui.currentCharacter.Hide) == "function" then ui.currentCharacter:Hide() end
	if ui.currentUsers and type(ui.currentUsers.Hide) == "function" then ui.currentUsers:Hide() end

	SetPoint(ui.copySourceButton, 24, -340)
	if type(ui.copySourceButton.SetSize) == "function" then ui.copySourceButton:SetSize(218, 24) end
	SetPoint(ui.copyButton, 254, -340)
	if type(ui.copyButton.SetSize) == "function" then ui.copyButton:SetSize(142, 24) end

	SetPoint(ui.renameEdit, 24, -428)
	if type(ui.renameEdit.SetSize) == "function" then ui.renameEdit:SetSize(218, 24) end
	SetPoint(ui.renameButton, 254, -428)
	if type(ui.renameButton.SetSize) == "function" then ui.renameButton:SetSize(90, 24) end

	SetPoint(ui.deleteButton, 24, -516)
	if type(ui.deleteButton.SetSize) == "function" then ui.deleteButton:SetSize(150, 24) end
	ui.deleteButton:SetText("Delete Profile")

	SetPoint(ui.assignments, 36, -624)
	if type(ui.assignments.SetWidth) == "function" then ui.assignments:SetWidth(520) end

	-- Hide the original assignment helper because the replacement above uses
	-- the same concise explanatory style as the ElvUI reference.
	local oldAssignmentHelp = FindRegionByText(panel, "Characters are remembered after they use Roll Curtain on that character. Shared profiles apply the same settings to every assigned character.")
	if oldAssignmentHelp and type(oldAssignmentHelp.Hide) == "function" then oldAssignmentHelp:Hide() end

	if type(panel.SetHeight) == "function" then panel:SetHeight(820) end
	UpdateElvUIProfileText(addonObject)
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		ApplyElvUIProfileLayout(self)
		UpdateElvUIProfileText(self)
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		ApplyElvUIProfileLayout(self)
		return result
	end
end
