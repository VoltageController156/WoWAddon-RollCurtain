local addonName, addon = ...

local SETTING_PREFIX = "ROLL_CURTAIN_HIDE_"

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
		tooltip = "Hide bonus-roll prompts inside five-player dungeon instances. Disabled by default.",
	},
}

local RAID_PARENT_DEFINITION = {
	key = "raidsEnabled",
	label = "Raids",
	tooltip = "Enable raid-specific bonus-roll suppression. Story Mode is selected by default when Raids is enabled.",
}

local RAID_SETTING_DEFINITIONS = {
	{
		key = "raidStory",
		label = "Story Mode",
		tooltip = "Hide bonus-roll prompts in Story Mode raid instances.",
	},
	{
		key = "raidLFR",
		label = "Raid Finder (LFR)",
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
	tooltip = "Hide bonus-roll prompts in scenarios that are not detected as Delves. Disabled by default.",
}

local function GetMetadata(field, fallback)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, field) or fallback
	end

	return fallback
end

local function RegisterCheckbox(addonObject, category, definition)
	local variable = SETTING_PREFIX .. definition.key:upper()
	addonObject.settingVariables[definition.key] = variable

	local setting = Settings.RegisterAddOnSetting(
		category,
		variable,
		definition.key,
		RollCurtainDB,
		Settings.VarType.Boolean,
		definition.label,
		addonObject.defaults[definition.key]
	)

	local initializer = Settings.CreateCheckbox(category, setting, definition.tooltip)
	return setting, initializer
end

local function SetSettingValue(addonObject, key, value)
	local variable = addonObject.settingVariables and addonObject.settingVariables[key]
	if variable and Settings.SetValue then
		Settings.SetValue(variable, value)
	else
		RollCurtainDB[key] = value
	end
end

function addon:RegisterSettings()
	if self.settingsCategory or not Settings then
		return
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("Roll Curtain")

	if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
			"Hide the bonus-roll prompt in these activities"
		))
	end

	self.settingVariables = {}

	for _, definition in ipairs(PRIMARY_SETTING_DEFINITIONS) do
		RegisterCheckbox(self, category, definition)
	end

	local raidSetting, raidInitializer = RegisterCheckbox(self, category, RAID_PARENT_DEFINITION)

	for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
		local _, childInitializer = RegisterCheckbox(self, category, definition)

		if childInitializer and childInitializer.SetParentInitializer then
			childInitializer:SetParentInitializer(raidInitializer, function()
				return raidSetting:GetValue() == true
			end)
		end

		if childInitializer and childInitializer.AddShownPredicate then
			childInitializer:AddShownPredicate(function()
				return raidSetting:GetValue() == true
			end)
		end
	end

	RegisterCheckbox(self, category, SCENARIO_DEFINITION)

	local function OnRaidsEnabledChanged(_, _, enabled)
		if enabled then
			-- Story Mode is the safe/default raid suppression choice when the user
			-- explicitly enables the raid group. Other difficulties remain opt-in.
			SetSettingValue(self, "raidStory", true)
		else
			for _, definition in ipairs(RAID_SETTING_DEFINITIONS) do
				SetSettingValue(self, definition.key, false)
			end
		end
	end

	local raidVariable = self.settingVariables.raidsEnabled
	if Settings.SetOnValueChangedCallback then
		Settings.SetOnValueChangedCallback(raidVariable, OnRaidsEnabledChanged)
	elseif raidSetting and raidSetting.SetValueChangedCallback then
		raidSetting:SetValueChangedCallback(function(setting, value)
			OnRaidsEnabledChanged(nil, setting, value)
		end)
	end

	if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
		local version = GetMetadata("Version", "Unknown")
		local author = GetMetadata("Author", "VoltageController156")
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
			string.format("Roll Curtain v%s  •  by %s", version, author)
		))
	end

	Settings.RegisterAddOnCategory(category)
	self.settingsCategory = category
end
