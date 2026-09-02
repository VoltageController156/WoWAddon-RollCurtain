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
		key = "raidStory",
		label = "Raids: Story Mode",
		tooltip = "Hide bonus-roll prompts in Story Mode raid instances. Disabled by default.",
	},
	{
		key = "raidLFR",
		label = "Raids: Raid Finder (LFR)",
		tooltip = "Hide bonus-roll prompts in Raid Finder raid instances. Disabled by default.",
	},
	{
		key = "raidNormal",
		label = "Raids: Normal",
		tooltip = "Hide bonus-roll prompts in Normal raid instances. Disabled by default.",
	},
	{
		key = "raidHeroic",
		label = "Raids: Heroic",
		tooltip = "Hide bonus-roll prompts in Heroic raid instances. Disabled by default.",
	},
	{
		key = "raidMythic",
		label = "Raids: Mythic",
		tooltip = "Hide bonus-roll prompts in Mythic raid instances. Disabled by default.",
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
