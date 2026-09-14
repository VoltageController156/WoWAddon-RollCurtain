local addonName, addon = ...

-- Lairs are presented as their own content type to players, but Blizzard exposes
-- The Tidebound Grotto as a raid instance. Keep the known Lair instance IDs here
-- so future Lairs can be added without treating every one-boss raid as a Lair.
local LAIR_INSTANCE_IDS = {
	[2987] = true, -- The Tidebound Grotto (Nymrissa Wavecaller)
}

local LAIR_DIFFICULTY_CONTENT_TYPES = {
	[17] = "lairWorld", -- World difficulty currently uses the Raid Finder difficulty slot internally.
	[14] = "lairNormal",
	[15] = "lairHeroic",
	[16] = "lairMythic",
}

local LAIR_SETTING_KEYS = {
	lairWorld = true,
	lairNormal = true,
	lairHeroic = true,
	lairMythic = true,
}

local LAIR_DEFINITIONS = {
	{ key = "lairWorld", label = "World", tooltip = "Hide bonus-roll prompts in World-difficulty Lairs." },
	{ key = "lairNormal", label = "Normal", tooltip = "Hide bonus-roll prompts in Normal Lairs." },
	{ key = "lairHeroic", label = "Heroic", tooltip = "Hide bonus-roll prompts in Heroic Lairs." },
	{ key = "lairMythic", label = "Mythic", tooltip = "Hide bonus-roll prompts in Mythic Lairs." },
}

local LAIR_PARENT_DEFINITION = {
	key = "lairsEnabled",
	label = "Lair Bosses",
	tooltip = "Enable Lair boss-specific bonus-roll suppression. World difficulty is selected automatically when Lair Bosses is enabled.",
}

addon.defaults.lairsEnabled = false
addon.defaults.lairWorld = false
addon.defaults.lairNormal = false
addon.defaults.lairHeroic = false
addon.defaults.lairMythic = false

addon.contentLabels.lairWorld = "World Lair boss"
addon.contentLabels.lairNormal = "Normal Lair boss"
addon.contentLabels.lairHeroic = "Heroic Lair boss"
addon.contentLabels.lairMythic = "Mythic Lair boss"
addon.contentLabels.lairs = "Other Lair difficulty"
addon.lairInstanceIDs = LAIR_INSTANCE_IDS

local function ClassifyLairDifficulty(difficultyID, difficultyName)
	local mapped = LAIR_DIFFICULTY_CONTENT_TYPES[difficultyID]
	if mapped then return mapped end

	-- Difficulty names are only a fallback for unexpected Blizzard IDs. The ID
	-- mapping above remains the locale-independent primary path.
	local name = type(difficultyName) == "string" and difficultyName:lower() or ""
	if name:find("world", 1, true) or name:find("raid finder", 1, true) or name == "lfr" then return "lairWorld" end
	if name:find("normal", 1, true) then return "lairNormal" end
	if name:find("heroic", 1, true) then return "lairHeroic" end
	if name:find("mythic", 1, true) then return "lairMythic" end
	return "lairs"
end

local previousGetCurrentContentType = addon.GetCurrentContentType
if type(previousGetCurrentContentType) == "function" then
	addon.GetCurrentContentType = function(self)
		if type(GetInstanceInfo) == "function" then
			local _, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
			if instanceType == "raid" and LAIR_INSTANCE_IDS[instanceID] then
				return ClassifyLairDifficulty(difficultyID, difficultyName)
			end
		end
		return previousGetCurrentContentType(self)
	end
end

local previousShouldHideCurrentPrompt = addon.ShouldHideCurrentPrompt
if type(previousShouldHideCurrentPrompt) == "function" then
	addon.ShouldHideCurrentPrompt = function(self)
		local contentType = self:GetCurrentContentType()
		if LAIR_SETTING_KEYS[contentType] then
			return self:GetSetting("lairsEnabled") == true and self:GetSetting(contentType) == true, contentType
		elseif contentType == "lairs" then
			-- Unknown Lair difficulties fail open, matching unknown Dungeon/Raid behavior.
			return false, contentType
		end
		return previousShouldHideCurrentPrompt(self)
	end
end

local function AddTooltip(frame, title, tooltip)
	frame:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if tooltip and tooltip ~= "" then GameTooltip:AddLine(tooltip, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

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

local function SetPoint(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function SetChildrenVisible(addonObject, visible)
	for _, definition in ipairs(LAIR_DEFINITIONS) do
		local control = addonObject.settingsControls and addonObject.settingsControls[definition.key]
		if control then
			if visible then
				control:Show()
				if control.label then control.label:Show() end
			else
				control:Hide()
				if control.label then control.label:Hide() end
			end
		end
	end
end

local function HasSelectedLairDifficulty(addonObject)
	for _, definition in ipairs(LAIR_DEFINITIONS) do
		if addonObject:GetSetting(definition.key) == true then return true end
	end
	return false
end

local function ApplyLairLayout(addonObject)
	local controls = addonObject.settingsControls
	local panel = addonObject.settingsPanel
	if not panel or not controls or not controls.lairsEnabled then return end

	local y = -176
	local rowSpacing = 44
	local childRowSpacing = 48
	local sectionSpacing = 26
	local childXDungeon = { 62, 188, 314, 438 }
	local childXLair = { 62, 188, 314, 438 }
	local childXRaid = { 62, 178, 288, 404, 520 }

	for _, key in ipairs({ "delves", "prey", "world" }) do
		SetPoint(controls[key], 24, y)
		y = y - rowSpacing
	end

	SetPoint(controls.dungeonsEnabled, 24, y)
	y = y - rowSpacing
	if addonObject:GetSetting("dungeonsEnabled") == true then
		for index, key in ipairs({ "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }) do
			SetPoint(controls[key], childXDungeon[index], y)
		end
		y = y - childRowSpacing
	end

	SetPoint(controls.lairsEnabled, 24, y)
	y = y - rowSpacing
	local lairsExpanded = addonObject:GetSetting("lairsEnabled") == true
	SetChildrenVisible(addonObject, lairsExpanded)
	if lairsExpanded then
		for index, definition in ipairs(LAIR_DEFINITIONS) do
			SetPoint(controls[definition.key], childXLair[index], y)
		end
		y = y - childRowSpacing
	end

	SetPoint(controls.raidsEnabled, 24, y)
	y = y - rowSpacing
	if addonObject:GetSetting("raidsEnabled") == true then
		for index, key in ipairs({ "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }) do
			SetPoint(controls[key], childXRaid[index], y)
		end
		y = y - childRowSpacing
	end

	SetPoint(controls.scenarios, 24, y)
	y = y - rowSpacing - sectionSpacing

	SetPoint(addonObject.safetyHeader, 18, y)
	SetPoint(controls.confirmBonusRoll, 24, y - 34)
	SetPoint(addonObject.previewButton, 24, y - 72)
	y = y - 120

	SetPoint(addonObject.interfaceHeader, 18, y)
	SetPoint(controls.showMinimapButton, 24, y - 34)

	if type(panel.SetHeight) == "function" then
		panel:SetHeight(math.max(560, math.abs(y - 116)))
	end
end

local function HookExistingExpansionControls(addonObject)
	if addonObject.lairLayoutHooksInstalled then return end
	addonObject.lairLayoutHooksInstalled = true
	for _, key in ipairs({
		"dungeonsEnabled", "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus",
		"raidsEnabled", "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic",
	}) do
		local control = addonObject.settingsControls and addonObject.settingsControls[key]
		if control and type(control.GetScript) == "function" and type(control.SetScript) == "function" then
			local previous = control:GetScript("OnClick")
			if previous then
				control:SetScript("OnClick", function(...)
					previous(...)
					ApplyLairLayout(addonObject)
				end)
			end
		end
	end
end

local function EnsureLairControls(addonObject)
	if not addonObject.settingsPanel or not addonObject.settingsControls or addonObject.settingsControls.lairsEnabled then return end
	local panel = addonObject.settingsPanel

	local parent = CreateCheckbox(panel, LAIR_PARENT_DEFINITION)
	addonObject.settingsControls.lairsEnabled = parent

	for _, definition in ipairs(LAIR_DEFINITIONS) do
		local key = definition.key
		local checkbox = CreateCheckbox(panel, definition)
		checkbox:SetScript("OnClick", function(button)
			addonObject:SetSetting(key, button:GetChecked() == true)
			if not HasSelectedLairDifficulty(addonObject) then
				addonObject:SetSetting("lairsEnabled", false)
				parent:SetChecked(false)
			end
			ApplyLairLayout(addonObject)
		end)
		addonObject.settingsControls[key] = checkbox
	end

	parent:SetScript("OnClick", function(button)
		local enabled = button:GetChecked() == true
		addonObject:SetSetting("lairsEnabled", enabled)
		for _, definition in ipairs(LAIR_DEFINITIONS) do
			addonObject:SetSetting(definition.key, false)
			addonObject.settingsControls[definition.key]:SetChecked(false)
		end
		if enabled then
			addonObject:SetSetting("lairWorld", true)
			addonObject.settingsControls.lairWorld:SetChecked(true)
		end
		ApplyLairLayout(addonObject)
	end)

	HookExistingExpansionControls(addonObject)
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		if self.settingsControls and self.settingsControls.lairsEnabled then
			for _, key in ipairs({ "lairsEnabled", "lairWorld", "lairNormal", "lairHeroic", "lairMythic" }) do
				local control = self.settingsControls[key]
				if control then control:SetChecked(self:GetSetting(key) == true) end
			end
			ApplyLairLayout(self)
		end
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		EnsureLairControls(self)
		self:RefreshSettingsUI()
		return result
	end
end

local previousApplyFirstRunPreset = addon.ApplyFirstRunPreset
if type(previousApplyFirstRunPreset) == "function" then
	addon.ApplyFirstRunPreset = function(self, presetName, ...)
		local result = previousApplyFirstRunPreset(self, presetName, ...)
		if result and (presetName == "recommended" or presetName == "outdoor") then
			self:SetSetting("lairsEnabled", false)
			for key in pairs(LAIR_SETTING_KEYS) do self:SetSetting(key, false) end
			self:RefreshProfileConsumers()
		end
		return result
	end
end
