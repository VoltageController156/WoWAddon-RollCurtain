local addonName, addon = ...

local SOUND_SELECTOR_SHIFT = 64
local SOUND_MENU_HEIGHT = 200
local SPEAKER_TEXTURE = 130979 -- interface/common/voicechat-speaker

local function ShiftFrameDown(frame, amount)
	if not frame or type(frame.GetPoint) ~= "function" or type(frame.SetPoint) ~= "function" then return end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point or type(y) ~= "number" then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint(point, relativeTo, relativePoint, x or 0, y - amount)
end

local function AttachSoundPreviewButton(description, soundKey)
	if not description or type(description.AddInitializer) ~= "function" then return end
	description:AddInitializer(function(menuButton)
		if not menuButton then return end

		local playButton = menuButton.rollCurtainPlayButton
		if not playButton then
			if type(menuButton.AttachFrame) == "function" then
				playButton = menuButton:AttachFrame("Button")
			else
				playButton = CreateFrame("Button", nil, menuButton)
			end
			if not playButton then return end

			if type(playButton.SetFrameStrata) == "function" and type(menuButton.GetFrameStrata) == "function" then
				playButton:SetFrameStrata(menuButton:GetFrameStrata())
			end
			if type(playButton.SetMouseClickEnabled) == "function" then
				playButton:SetMouseClickEnabled(true)
			end
			if type(playButton.SetMouseMotionEnabled) == "function" then
				playButton:SetMouseMotionEnabled(true)
			end
			playButton:SetSize(16, 16)
			playButton:SetPoint("RIGHT", -5, 0)
			playButton:Show()

			local texture
			if type(playButton.AttachTexture) == "function" then
				texture = playButton:AttachTexture()
			elseif type(playButton.CreateTexture) == "function" then
				texture = playButton:CreateTexture(nil, "ARTWORK")
			end
			if texture then
				texture:SetAllPoints()
				texture:SetTexture(SPEAKER_TEXTURE)
				texture:SetVertexColor(0.8, 0.8, 0.8)
				playButton:SetScript("OnEnter", function()
					texture:SetVertexColor(1, 1, 1)
				end)
				playButton:SetScript("OnLeave", function()
					texture:SetVertexColor(0.8, 0.8, 0.8)
				end)
			end

			menuButton.rollCurtainPlayButton = playButton
		end

		local function Preview()
			if type(addon.PreviewSuppressionSoundKey) == "function" then
				addon:PreviewSuppressionSoundKey(soundKey)
			end
		end

		if MenuTemplates and type(MenuTemplates.SetUtilityButtonClickHandler) == "function" then
			MenuTemplates.SetUtilityButtonClickHandler(playButton, Preview)
		else
			playButton:SetScript("OnClick", Preview)
		end
		playButton:Show()
	end)
end

local function OpenSoundMenu(button)
	if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
	MenuUtil.CreateContextMenu(button, function(_, rootDescription)
		if type(rootDescription.SetScrollMode) == "function" then
			-- Match DBM's sound picker height so long SharedMedia lists stay compact.
			rootDescription:SetScrollMode(SOUND_MENU_HEIGHT)
		end

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

			local soundKey = choice.key
			local radio = rootDescription:CreateRadio(
				choice.label,
				function(data)
					return addon:GetSelectedSuppressionSoundKey() == data.key
				end,
				function(data)
					if addon:SetSelectedSuppressionSound(data.key) and addon.suppressionSoundSelectButton then
						addon.suppressionSoundSelectButton:SetText(addon:GetSelectedSuppressionSoundLabel())
					end
				end,
				choice
			)
			AttachSoundPreviewButton(radio, soundKey)
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
		GameTooltip:AddLine("Choose a built-in Blizzard sound or a sound registered through LibSharedMedia-3.0. Use the speaker icon beside a sound to preview it without selecting it.", 1, 1, 1, true)
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
