local addonName, addon = ...

local SOUND_SHIFT = 40

local function ApplyOptionalElvUISkin(checkbox)
	local elvUI = _G and _G.ElvUI
	if type(elvUI) ~= "table" then return end
	local unpackFn = unpack or (table and table.unpack)
	if not unpackFn then return end
	local ok, engine = pcall(function() return unpackFn(elvUI) end)
	if not ok or type(engine) ~= "table" or type(engine.GetModule) ~= "function" then return end
	local moduleOK, skins = pcall(engine.GetModule, engine, "Skins", true)
	if moduleOK and skins and type(skins.HandleCheckBox) == "function" then pcall(skins.HandleCheckBox, skins, checkbox) end
end

local function EnsureSuppressionSoundControl(addonObject)
	if addonObject.suppressionSoundControl or not addonObject.settingsPanel then return end
	if addonObject.defaults.suppressionSound == nil then addonObject.defaults.suppressionSound = false end

	local checkbox = CreateFrame("CheckButton", nil, addonObject.settingsPanel, "SettingsCheckboxTemplate")
	local label = addonObject.settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
	label:SetText("Play a sound when a bonus roll is suppressed")
	checkbox.label = label
	checkbox:SetScript("OnClick", function(button) addon:SetSetting("suppressionSound", button:GetChecked() == true) end)
	checkbox:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Suppression sound")
		GameTooltip:AddLine("Play a short Blizzard bonus-roll sound when Roll Curtain hides a prompt.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	checkbox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	ApplyOptionalElvUISkin(checkbox)
	addonObject.suppressionSoundControl = checkbox
	addonObject.settingsControls = addonObject.settingsControls or {}
	addonObject.settingsControls.suppressionSound = checkbox
end

local function ShiftFrameDown(frame, amount)
	if not frame or type(frame.GetPoint) ~= "function" or type(frame.SetPoint) ~= "function" then return end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point or type(y) ~= "number" then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint(point, relativeTo, relativePoint, x or 0, y - amount)
end

local function ReflowSoundSetting(addonObject)
	local checkbox = addonObject.suppressionSoundControl
	local minimap = addonObject.settingsControls and addonObject.settingsControls.showMinimapButton
	if not checkbox or not minimap then return end
	checkbox:ClearAllPoints()
	checkbox:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -10)
	checkbox:SetChecked(addonObject:GetSetting("suppressionSound") == true)

	-- SettingsExtensions lays Chat Notifications immediately after the minimap
	-- option. Shift that block once per refresh to make room for the sound toggle.
	ShiftFrameDown(addonObject.notificationHeader, SOUND_SHIFT)
	ShiftFrameDown(addonObject.notificationHelp, SOUND_SHIFT)
	for _, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		local control = addonObject.notificationControls and addonObject.notificationControls[definition.key]
		ShiftFrameDown(control, SOUND_SHIFT)
	end
	if addonObject.settingsPanel and type(addonObject.settingsPanel.GetHeight) == "function" and type(addonObject.settingsPanel.SetHeight) == "function" then
		addonObject.settingsPanel:SetHeight(addonObject.settingsPanel:GetHeight() + SOUND_SHIFT)
	end
end

local function FindTextRegion(panel, wanted)
	if not panel or type(panel.GetRegions) ~= "function" then return nil end
	for _, region in ipairs({ panel:GetRegions() }) do
		local text = region and type(region.GetText) == "function" and region:GetText() or nil
		if text == wanted then return region end
	end
	return nil
end

local function SetTopLeft(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function ReflowProfileTransfer(addonObject)
	local ui = addonObject.profileTransferUI
	local panel = addonObject.profilesContent
	if not ui or not panel then return end
	SetTopLeft(ui.header, 24, -486)
	SetTopLeft(ui.hint, 24, -512)
	SetTopLeft(ui.exportButton, 24, -548)
	ui.importButton:ClearAllPoints()
	ui.importButton:SetPoint("LEFT", ui.exportButton, "RIGHT", 12, 0)

	SetTopLeft(ui.assignmentsHeader, 24, -606)
	SetTopLeft(ui.assignmentHint, 24, -632)
	SetTopLeft(addonObject.profilesUI and addonObject.profilesUI.assignments, 36, -678)

	local assignments = addonObject.profilesUI and addonObject.profilesUI.assignments
	local assignmentHeight = assignments and type(assignments.GetStringHeight) == "function" and assignments:GetStringHeight() or 160
	if type(panel.SetHeight) == "function" then panel:SetHeight(math.max(820, 700 + assignmentHeight)) end
end

local function EnsureProfileTransferControls(addonObject)
	if addonObject.profileTransferUI or not addonObject.profilesContent then return end
	local panel = addonObject.profilesContent
	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetText("Import / Export")
	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetWidth(550)
	hint:SetJustifyH("LEFT")
	hint:SetText("Export the current profile as a shareable string, or import a string into the current profile.")

	local exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	exportButton:SetSize(132, 24)
	exportButton:SetText("Export Current")
	exportButton:SetScript("OnClick", function() if type(addon.ShowProfileExportDialog) == "function" then addon:ShowProfileExportDialog() end end)
	local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	importButton:SetSize(148, 24)
	importButton:SetText("Import Into Current")
	importButton:SetScript("OnClick", function() if type(addon.ShowProfileImportDialog) == "function" then addon:ShowProfileImportDialog() end end)

	addonObject.profileTransferUI = {
		header = header,
		hint = hint,
		exportButton = exportButton,
		importButton = importButton,
		assignmentsHeader = FindTextRegion(panel, "Profile Assignments"),
		assignmentHint = FindTextRegion(panel, "Characters are remembered after they use Roll Curtain on that character. Shared profiles apply the same settings to every assigned character."),
	}
	if type(panel.HookScript) == "function" then panel:HookScript("OnShow", function() ReflowProfileTransfer(addon) end) end
	ReflowProfileTransfer(addonObject)
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		EnsureSuppressionSoundControl(self)
		EnsureProfileTransferControls(self)
		ReflowSoundSetting(self)
		ReflowProfileTransfer(self)
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		EnsureSuppressionSoundControl(self)
		EnsureProfileTransferControls(self)
		self:RefreshSettingsUI()
		return result
	end
end
