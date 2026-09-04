local addonName, addon = ...

local SOUND_SELECTOR_SHIFT = 64

local function ShiftFrameDown(frame, amount)
	if not frame or type(frame.GetPoint) ~= "function" or type(frame.SetPoint) ~= "function" then return end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point or type(y) ~= "number" then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint(point, relativeTo, relativePoint, x or 0, y - amount)
end

local function OpenSoundMenu(button)
	if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
	MenuUtil.CreateContextMenu(button, function(_, rootDescription)
		local current = addon:GetSelectedSuppressionSoundKey()
		local choices = addon:GetSuppressionSoundChoices()
		local currentSource
		for _, choice in ipairs(choices) do
			if choice.source ~= currentSource then
				currentSource = choice.source
				if currentSource == "Blizzard" then
					rootDescription:CreateTitle("Blizzard sounds")
				else
					rootDescription:CreateTitle("SharedMedia sounds")
				end
			end
			local label = choice.label
			if choice.key == current then label = label .. "  (Current)" end
			rootDescription:CreateButton(label, function()
				if addon:SetSelectedSuppressionSound(choice.key) then
					if addon.suppressionSoundSelectButton then
						addon.suppressionSoundSelectButton:SetText(addon:GetSelectedSuppressionSoundLabel())
					end
					addon:PreviewSuppressionSound()
				end
			end)
		end
	end)
end

local function EnsureSoundSelector(addonObject)
	if addonObject.suppressionSoundSelectButton or not addonObject.settingsPanel or not addonObject.suppressionSoundControl then return end
	local panel = addonObject.settingsPanel

	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetText("Suppression sound")

	local selectButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	selectButton:SetSize(260, 24)
	selectButton:SetText(addonObject:GetSelectedSuppressionSoundLabel())
	selectButton:SetScript("OnClick", OpenSoundMenu)
	selectButton:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Suppression sound")
		GameTooltip:AddLine("Choose a built-in Blizzard sound. If another addon provides LibSharedMedia-3.0, its registered sounds are listed here too.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	selectButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testButton:SetSize(92, 24)
	testButton:SetText("Test Sound")
	testButton:SetScript("OnClick", function() addon:PreviewSuppressionSound() end)

	addonObject.suppressionSoundSelectLabel = label
	addonObject.suppressionSoundSelectButton = selectButton
	addonObject.suppressionSoundTestButton = testButton
end

local function ReflowSoundSelector(addonObject)
	local checkbox = addonObject.suppressionSoundControl
	local label = addonObject.suppressionSoundSelectLabel
	local selectButton = addonObject.suppressionSoundSelectButton
	local testButton = addonObject.suppressionSoundTestButton
	if not checkbox or not label or not selectButton or not testButton then return end

	label:ClearAllPoints()
	label:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 2, -8)
	selectButton:ClearAllPoints()
	selectButton:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -5)
	testButton:ClearAllPoints()
	testButton:SetPoint("LEFT", selectButton, "RIGHT", 10, 0)
	selectButton:SetText(addonObject:GetSelectedSuppressionSoundLabel())

	-- UXSettings already reserves one row for the enable checkbox. Reserve one
	-- additional row for the selector/test controls after its layout has run.
	ShiftFrameDown(addonObject.notificationHeader, SOUND_SELECTOR_SHIFT)
	ShiftFrameDown(addonObject.notificationHelp, SOUND_SELECTOR_SHIFT)
	for _, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		local control = addonObject.notificationControls and addonObject.notificationControls[definition.key]
		ShiftFrameDown(control, SOUND_SELECTOR_SHIFT)
	end
	if addonObject.settingsPanel and type(addonObject.settingsPanel.GetHeight) == "function" and type(addonObject.settingsPanel.SetHeight) == "function" then
		addonObject.settingsPanel:SetHeight(addonObject.settingsPanel:GetHeight() + SOUND_SELECTOR_SHIFT)
	end
end

local function SetTopLeft(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function RepairProfilesLayout(addonObject)
	local panel = addonObject.profilesContent
	local transfer = addonObject.profileTransferUI
	local layout = addonObject.elvUIProfileLayout
	local profiles = addonObject.profilesUI
	if not panel or not transfer or not layout or not profiles then return end

	-- ProfilesElvUILayout is the final visual layout for this page. Keep the
	-- import/export block below Delete and move profile assignments beneath it so
	-- the two independently-added sections never share the same coordinates.
	SetTopLeft(transfer.header, 24, -566)
	SetTopLeft(transfer.hint, 24, -594)
	SetTopLeft(transfer.exportButton, 24, -626)
	transfer.importButton:ClearAllPoints()
	transfer.importButton:SetPoint("LEFT", transfer.exportButton, "RIGHT", 12, 0)

	SetTopLeft(layout.assignmentsHeader, 24, -682)
	SetTopLeft(layout.assignmentsHelp, 24, -710)
	SetTopLeft(profiles.assignments, 36, -754)
	if type(profiles.assignments.SetWidth) == "function" then profiles.assignments:SetWidth(520) end

	local assignmentHeight = type(profiles.assignments.GetStringHeight) == "function" and profiles.assignments:GetStringHeight() or 120
	if type(panel.SetHeight) == "function" then panel:SetHeight(math.max(900, 790 + assignmentHeight)) end
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		EnsureSoundSelector(self)
		ReflowSoundSelector(self)
		RepairProfilesLayout(self)
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		EnsureSoundSelector(self)
		ReflowSoundSelector(self)
		RepairProfilesLayout(self)
		return result
	end
end
