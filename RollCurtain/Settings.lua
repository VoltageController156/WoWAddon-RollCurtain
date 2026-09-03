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

local START_Y = -100
local ROW_SPACING = 44
local CHILD_ROW_SPACING = 52
local SECTION_SPACING = 26
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
		if tooltip and tooltip ~= "" then
			GameTooltip:AddLine(tooltip, 1, 1, 1, true)
		end
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
			if visible then
				checkbox:Show(); checkbox.label:Show()
			else
				checkbox:Hide(); checkbox.label:Hide()
			end
		end
	end
end

local function SetDefinitionGroup(addonObject, definitions, value)
	for _, definition in ipairs(definitions) do
		RollCurtainDB[definition.key] = value
		local checkbox = addonObject.settingsControls[definition.key]
		if checkbox then checkbox:SetChecked(value) end
	end
end

local function HasSelectedDifficulty(definitions)
	for _, definition in ipairs(definitions) do
		if RollCurtainDB[definition.key] == true then return true end
	end
	return false
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
	local dungeonsExpanded = RollCurtainDB.dungeonsEnabled == true
	SetDefinitionGroupVisible(addonObject, DUNGEON_SETTING_DEFINITIONS, dungeonsExpanded)
	if dungeonsExpanded then
		for index, definition in ipairs(DUNGEON_SETTING_DEFINITIONS) do
			SetCheckboxPosition(addonObject.settingsControls[definition.key], CHILD_X_DUNGEON[index], y)
		end
		y = y - CHILD_ROW_SPACING
	end

	SetCheckboxPosition(addonObject.settingsControls.raidsEnabled, 24, y)
	y = y - ROW_SPACING
	local raidsExpanded = RollCurtainDB.raidsEnabled == true
	SetDefinitionGroupVisible(addonObject, RAID_SETTING_DEFINITIONS, raidsExpanded)
	if raidsExpanded then
		for index, definition in ipairs(RAID_SETTING_DEFINITIONS) do
			SetCheckboxPosition(addonObject.settingsControls[definition.key], CHILD_X_RAID[index], y)
		end
		y = y - CHILD_ROW_SPACING
	end

	SetCheckboxPosition(addonObject.settingsControls.scenarios, 24, y)
	y = y - ROW_SPACING - SECTION_SPACING

	if addonObject.safetyHeader then
		addonObject.safetyHeader:SetPoint("TOPLEFT", 18, y)
	end
	SetCheckboxPosition(addonObject.settingsControls.confirmBonusRoll, 24, y - 34)
end

function addon:RefreshSettingsUI()
	if not self.settingsControls then return end
	for key, checkbox in pairs(self.settingsControls) do
		if RollCurtainDB[key] ~= nil then
			checkbox:SetChecked(RollCurtainDB[key] == true)
		end
	end
	LayoutSettings(self)
end

function addon:RegisterSettings()
	if self.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then return end

	local panel = CreateFrame("Frame")
	panel:SetSize(650, 660)

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

	for _, definition in ipairs(PRIMARY_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button)
			RollCurtainDB[key] = button:GetChecked() == true
		end)
		self.settingsControls[key] = checkbox
	end

	local dungeonCheckbox = CreateCheckbox(panel, DUNGEON_PARENT_DEFINITION)
	self.settingsControls.dungeonsEnabled = dungeonCheckbox
	for _, definition in ipairs(DUNGEON_SETTING_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button)
			RollCurtainDB[key] = button:GetChecked() == true
			if not HasSelectedDifficulty(DUNGEON_SETTING_DEFINITIONS) then
				RollCurtainDB.dungeonsEnabled = false
				dungeonCheckbox:SetChecked(false)
			end
			LayoutSettings(self)
		end)
		self.settingsControls[key] = checkbox
	end

	dungeonCheckbox:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		RollCurtainDB.dungeonsEnabled = enabled
		SetDefinitionGroup(self, DUNGEON_SETTING_DEFINITIONS, false)
		if enabled then
			for _, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic" }) do
				RollCurtainDB[key] = true
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
			RollCurtainDB[key] = button:GetChecked() == true
			if not HasSelectedDifficulty(RAID_SETTING_DEFINITIONS) then
				RollCurtainDB.raidsEnabled = false
				raidCheckbox:SetChecked(false)
			end
			LayoutSettings(self)
		end)
		self.settingsControls[key] = checkbox
	end

	raidCheckbox:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		RollCurtainDB.raidsEnabled = enabled
		SetDefinitionGroup(self, RAID_SETTING_DEFINITIONS, false)
		if enabled then
			RollCurtainDB.raidStory = true
			self.settingsControls.raidStory:SetChecked(true)
		end
		LayoutSettings(self)
	end)

	local scenarioCheckbox = CreateCheckbox(panel, SCENARIO_DEFINITION)
	self.settingsControls.scenarios = scenarioCheckbox
	scenarioCheckbox:SetScript("OnClick", function(button)
		RollCurtainDB.scenarios = button:GetChecked() == true
	end)

	local safetyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	safetyHeader:SetText("Safety")
	self.safetyHeader = safetyHeader

	local confirmCheckbox = CreateCheckbox(panel, CONFIRM_DEFINITION)
	self.settingsControls.confirmBonusRoll = confirmCheckbox
	confirmCheckbox:SetScript("OnClick", function(button)
		RollCurtainDB.confirmBonusRoll = button:GetChecked() == true
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
end
