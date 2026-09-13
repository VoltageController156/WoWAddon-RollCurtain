local addon = {
	settings = {
		dungeonsEnabled = true,
		lairsEnabled = true,
		raidsEnabled = true,
	},
	settingsControls = {},
	chatDestinationDefinitions = {
		{ key = "chat1" }, { key = "chat2" }, { key = "chat3" }, { key = "chat4" },
	},
	notificationControls = {},
}

function addon:GetSetting(key) return self.settings[key] == true end
function addon:RefreshSettingsUI() end
function addon:RegisterSettings() end

local function Region()
	local region = { shown = true }
	function region:SetPoint(...) self.point = { ... } end
	function region:ClearAllPoints() self.point = nil end
	function region:SetWidth(value) self.width = value end
	function region:SetJustifyH(value) self.justifyH = value end
	function region:SetWordWrap(value) self.wordWrap = value end
	function region:Show() self.shown = true end
	function region:Hide() self.shown = false end
	return region
end

local function Control()
	local control = Region()
	control.label = Region()
	control.scripts = {}
	function control:GetScript(name) return self.scripts[name] end
	function control:SetScript(name, callback) self.scripts[name] = callback end
	return control
end

for _, key in ipairs({
	"delves", "prey", "world",
	"dungeonsEnabled", "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus",
	"lairsEnabled", "lairWorld", "lairNormal", "lairHeroic", "lairMythic",
	"raidsEnabled", "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic",
	"scenarios", "confirmBonusRoll", "showMinimapButton",
}) do
	addon.settingsControls[key] = Control()
end

for _, definition in ipairs(addon.chatDestinationDefinitions) do
	local control = Control()
	addon.notificationControls[definition.key] = control
	addon.settingsControls[definition.key] = control
end

addon.settingsPanel = { height = 0 }
function addon.settingsPanel:SetHeight(value) self.height = value end
addon.safetyHeader = Region()
addon.previewButton = Region()
addon.interfaceHeader = Region()
addon.notificationHeader = Region()
addon.notificationHelp = Region()
addon.suppressionSoundControl = Control()
addon.suppressionSoundSelectLabel = Region()
addon.suppressionSoundSelectButton = Region()
addon.suppressionSoundTestButton = Region()

assert(loadfile("RollCurtain/SettingsFinalLayout.lua"))("RollCurtain", addon)
addon:RefreshSettingsUI()

local function y(control) return control.point and control.point[3] end

-- Expanded Dungeons, Lairs, and Raids stack in order with no overlap.
assert(y(addon.settingsControls.dungeonsEnabled) == -236)
assert(y(addon.settingsControls.dungeonNormal) == -280)
assert(y(addon.settingsControls.lairsEnabled) == -328)
assert(y(addon.settingsControls.lairWorld) == -372)
assert(y(addon.settingsControls.raidsEnabled) == -420)
assert(y(addon.settingsControls.raidStory) == -464)
assert(y(addon.settingsControls.scenarios) == -512)
assert(addon.settingsControls.lairWorld.shown == true)

-- Deselecting/collapsing Lairs must hide its child row and pull everything below
-- it upward during the same authoritative refresh.
addon.settings.lairsEnabled = false
addon:RefreshSettingsUI()
assert(addon.settingsControls.lairWorld.shown == false)
assert(addon.settingsControls.lairWorld.label.shown == false)
assert(y(addon.settingsControls.raidsEnabled) == -372)
assert(y(addon.settingsControls.raidStory) == -416)
assert(y(addon.settingsControls.scenarios) == -464)

-- Collapsing Raids also reflows immediately rather than leaving stale child
-- positions/click targets behind.
addon.settings.raidsEnabled = false
addon:RefreshSettingsUI()
assert(addon.settingsControls.raidStory.shown == false)
assert(addon.settingsControls.raidStory.label.shown == false)
assert(y(addon.settingsControls.scenarios) == -416)

print("Roll Curtain final settings layout tests passed")
