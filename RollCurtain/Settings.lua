local _, addon = ...

local SETTING_PREFIX = "ROLL_CURTAIN_HIDE_"

local SETTING_DEFINITIONS = {
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
	{
		key = "raids",
		label = "Raids",
		tooltip = "Hide bonus-roll prompts inside raid instances. Disabled by default.",
	},
	{
		key = "scenarios",
		label = "Other scenarios",
		tooltip = "Hide bonus-roll prompts in scenarios that are not detected as Delves. Disabled by default.",
	},
}

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
	for _, definition in ipairs(SETTING_DEFINITIONS) do
		local variable = SETTING_PREFIX .. definition.key:upper()
		self.settingVariables[definition.key] = variable

		local setting = Settings.RegisterAddOnSetting(
			category,
			variable,
			definition.key,
			RollCurtainDB,
			Settings.VarType.Boolean,
			definition.label,
			self.defaults[definition.key]
		)

		Settings.CreateCheckbox(category, setting, definition.tooltip)
	end

	Settings.RegisterAddOnCategory(category)
	self.settingsCategory = category
end
