local addonName, addon = ...

local PRIMARY_SETTING_DEFINITIONS = {
	{
		key = "delves",
		label = "Delves",
		tooltip = "Hide the bonus-roll prompt when a Delve is active.",
	},
	{
		key = "prey",
		label = "Prey hunts",
		tooltip = "Hide the bonus-roll prompt while you have an active Prey hunt.",
	},
	{
		key = "world",
		label = "World bosses and outdoor content",
		tooltip = "Hide bonus-roll prompts outside instances, including world bosses and other outdoor encounters.",
	},
	{
		key = "dungeons",
		label = "Dungeons",
		tooltip = "Hide bonus-roll prompts inside five-player dungeon instances.",
	},
}

local RAID_PARENT_DEFINITION = {
	key = "raidsEnabled",
	label = "Raids",
	tooltip = "Enable raid-specific bonus-roll suppression. Story Mode is selected automatically when Raids is enabled.",
}

local RAID_SETTING_DEFINITIONS = {
	{
		key = "raidStory",
		label = "Story",
		tooltip = "Hide bonus-roll prompts in Story Mode raid instances.",
	},
	{
		key = "raidLFR",
		label = "LFR",
		tooltip = "Hide bonus-roll prompts in Raid Finder raid instances.",
	},
	{
		key = "raidNormal",
		label = "Normal",
		tooltip = "Hide bonus-roll prompts in Normal raid instances.",
	},
	{
		key = "raidHeroic",
		label = "Heroic",
		tooltip = "Hide bonus-roll prompts in Heroic raid instances.",
	},
	{
		key = "raidMythic",
		label = "Mythic",
		tooltip = "Hide bonus-roll prompts in Mythic raid instances.",
	},
}

local SCENARIO_DEFINITION = {
	key = "scenarios",
	label = "Other scenarios",
	tooltip = "Hide bonus-roll prompts in scenarios that are not detected as Delves.",
}

local function GetMetadata(field, fallback)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, field) or fallback
	end

	return fallback
end

local function AddTooltip(frame, title, tooltip)
	frame:SetScript("OnEnter", function(self)
		if not GameTooltip then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if tooltip and tooltip ~= "" then
			GameTooltip:AddLine(tooltip, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)

	frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

-- Settings.CreateCheckbox uses Blizzard's SettingsCheckboxTemplate. Use that
-- same template in the custom Canvas so stock WoW retains the modern Settings
-- appearance instead of falling back to the older UICheckButton artwork.
--
-- ElvUI normally skins checkboxes created inside Blizzard's vertical Settings
-- list automatically, but Canvas children are not part of that list. If ElvUI
-- is present, opt into its checkbox skin explicitly. This is intentionally
-- optional: stock Blizzard UI and other UI replacements (including Tukui)
-- continue to use the native template without requiring a hard dependency.
local function ApplyOptionalElvUISkin(checkbox)
	local elvUI = _G and _G.ElvUI
	if type(elvUI) ~= "table" then
		return
	end

	local unpackFn = unpack or (table and table.unpack)
	if not unpackFn then
		return
	end

	local ok, engine = pcall(function()
		return unpackFn(elvUI)
	end)
	if not ok or type(engine) ~= "table" or type(engine.GetModule) ~= "function" then
		return
	end

	local moduleOK, skins = pcall(engine.GetModule, engine, "Skins", true)
	if not moduleOK or not skins or type(skins.HandleCheckBox) ~= "function" then
		return
	end

	-- Keep ElvUI completely optional and fail open if its skin API changes.
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

local function SetRaidChildrenVisible(addonObject, visible)
	for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		local checkbox = addonObject.settingsControls[definition.key]
		if checkbox then
			if visible then
				checkbox:Show()
				checkbox.label:Show()
			else
				checkbox:Hide()
				checkbox.label:Hide()
			end
		end
	end

	local scenario = addonObject.settingsControls.scenarios
	if scenario then
		SetCheckboxPosition(scenario, 24, visible and -418 or -326)
	end
end

local function SetRaidChildren(addonObject, value)
	for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		RollCurtainDB[definition.key] = value
		local checkbox = addonObject.settingsControls[definition.key]
		if checkbox then
			checkbox:SetChecked(value)
		end
	end
end

local function HasSelectedRaidDifficulty()
	for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		if RollCurtainDB[definition.key] == true then
			return true
		end
	end

	return false
end

function addon:RefreshSettingsUI()
	if not self.settingsControls then
		return
	end

	for key, checkbox in pairs(self.settingsControls) do
		if RollCurtainDB[key] ~= nil then
			checkbox:SetChecked(RollCurtainDB[key] == true)
		end
	end

	SetRaidChildrenVisible(self, RollCurtainDB.raidsEnabled == true)
end

function addon:RegisterSettings()
	if self.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then
		return
	end

	local panel = CreateFrame("Frame")
	panel:SetSize(650, 540)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Roll Curtain")

	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header:SetPoint("TOPLEFT", 16, -58)
	header:SetText("Hide the bonus-roll prompt in these activities")

	local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	defaultsButton:SetSize(96, 24)
	defaultsButton:SetPoint("TOPRIGHT", -18, -12)
	defaultsButton:SetText("Defaults")
	defaultsButton:SetScript("OnClick", function()
		self:ResetDefaults()
		self:RefreshSettingsUI()
	end)

	self.settingsControls = {}
	self.settingVariables = nil

	local primaryY = -100
	local primaryRowSpacing = 44
	for index, definition in ipairs(PRIMARY_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		SetCheckboxPosition(checkbox, 24, primaryY - ((index - 1) * primaryRowSpacing))
		checkbox:SetScript("OnClick", function(button)
			RollCurtainDB[key] = button:GetChecked() == true
		end)
		self.settingsControls[key] = checkbox
	end

	local raidCheckbox = CreateCheckbox(panel, RAID_PARENT_DEFINITION)
	SetCheckboxPosition(raidCheckbox, 24, -292)
	self.settingsControls.raidsEnabled = raidCheckbox

	local raidChildX = { 62, 178, 288, 404, 520 }
	for index, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		SetCheckboxPosition(checkbox, raidChildX[index], -352)
		checkbox:SetScript("OnClick", function(button)
			RollCurtainDB[key] = button:GetChecked() == true

			if not HasSelectedRaidDifficulty() then
				RollCurtainDB.raidsEnabled = false
				raidCheckbox:SetChecked(false)
				SetRaidChildrenVisible(self, false)
			end
		end)
		self.settingsControls[key] = checkbox
	end

	raidCheckbox:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		RollCurtainDB.raidsEnabled = enabled

		if enabled then
			SetRaidChildren(self, false)
			RollCurtainDB.raidStory = true
			self.settingsControls.raidStory:SetChecked(true)
		else
			SetRaidChildren(self, false)
		end

		SetRaidChildrenVisible(self, enabled)
	end)

	local scenarioCheckbox = CreateCheckbox(panel, SCENARIO_DEFINITION)
	self.settingsControls.scenarios = scenarioCheckbox
	scenarioCheckbox:SetScript("OnClick", function(button)
		RollCurtainDB.scenarios = button:GetChecked() == true
	end)

	local version = GetMetadata("Version", "Unknown")
	local author = GetMetadata("Author", "VoltageController156")
	local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", 18, 18)
	footer:SetText(string.format("Version %s  •  Author: %s", version, author))

	panel:SetScript("OnShow", function()
		self:RefreshSettingsUI()
	end)

	self.settingsPanel = panel
	self:RefreshSettingsUI()

	local category = Settings.RegisterCanvasLayoutCategory(panel, "Roll Curtain")
	Settings.RegisterAddOnCategory(category)
	self.settingsCategory = category
end
