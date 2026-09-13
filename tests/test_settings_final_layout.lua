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

C_Timer = { After = function(_, callback) callback() end }

local function Region(text)
	local region = { shown = true, text = text }
	function region:SetPoint(...) self.point = { ... } end
	function region:ClearAllPoints() self.point = nil end
	function region:SetWidth(value) self.width = value end
	function region:SetJustifyH(value) self.justifyH = value end
	function region:SetWordWrap(value) self.wordWrap = value end
	function region:Show() self.shown = true end
	function region:Hide() self.shown = false end
	function region:GetText() return self.text end
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

local footer = Region("Version 0.0.10-beta.4  •  DEVELOPMENT / TEST BUILD  •  Author: VoltageController156")
addon.settingsPanel = { height = 0 }
function addon.settingsPanel:SetHeight(value) self.height = value end
function addon.settingsPanel:GetRegions() return footer end
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

-- The lower page is also part of the authoritative flow. These assertions
-- specifically guard the overlap that was visible in beta.3.
assert(y(addon.safetyHeader) == -582)
assert(y(addon.interfaceHeader) == -702)
assert(y(addon.settingsControls.showMinimapButton) == -736)
assert(y(addon.suppressionSoundControl) == -780)
assert(y(addon.suppressionSoundSelectLabel) == -814)
assert(y(addon.suppressionSoundSelectButton) == -838)
assert(y(addon.notificationHeader) == -894)
assert(y(addon.notificationHelp) == -922)
assert(y(addon.notificationControls.chat1) == -976)
assert(y(addon.notificationControls.chat4) == -1014)
assert(y(footer) == -1068, "Version footer must sit below Chat Notifications")
assert(addon.settingsPanel.height >= 1126, "Scrollable content must include the footer")

-- Deselecting/collapsing Lairs must hide its child row and pull every section
-- below it upward during the same authoritative refresh.
addon.settings.lairsEnabled = false
addon:RefreshSettingsUI()
assert(addon.settingsControls.lairWorld.shown == false)
assert(addon.settingsControls.lairWorld.label.shown == false)
assert(y(addon.settingsControls.raidsEnabled) == -372)
assert(y(addon.settingsControls.raidStory) == -416)
assert(y(addon.settingsControls.scenarios) == -464)
assert(y(addon.suppressionSoundControl) == -732)
assert(y(addon.notificationHeader) == -846)
assert(y(addon.notificationControls.chat1) == -928)
assert(y(footer) == -1020)

-- Collapsing Raids also reflows immediately rather than leaving stale child
-- positions/click targets behind, including all lower settings sections.
addon.settings.raidsEnabled = false
addon:RefreshSettingsUI()
assert(addon.settingsControls.raidStory.shown == false)
assert(addon.settingsControls.raidStory.label.shown == false)
assert(y(addon.settingsControls.scenarios) == -416)
assert(y(addon.suppressionSoundControl) == -684)
assert(y(addon.notificationHeader) == -798)
assert(y(addon.notificationControls.chat1) == -880)
assert(y(footer) == -972)

-- If an older layout layer mutates lower controls, the exported final pass must
-- restore the canonical coordinates without relying on another full refresh.
addon.notificationHeader:SetPoint("TOPLEFT", 18, -1)
addon.suppressionSoundControl:SetPoint("TOPLEFT", 24, -1)
addon.ApplyFinalSettingsLayout(addon)
assert(y(addon.suppressionSoundControl) == -684)
assert(y(addon.notificationHeader) == -798)

print("Roll Curtain final settings layout tests passed")
