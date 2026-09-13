local addonName, addon = ...

-- Final authoritative layout pass for the main Settings page. Earlier modules
-- add controls in layers; this pass places every main-page control from current
-- state so collapsing/deselecting one section cannot leave stale coordinates.

local START_Y = -104
local ROW_SPACING = 44
local CHILD_ROW_SPACING = 48
local SECTION_SPACING = 26
local DUNGEON_X = { 62, 188, 314, 438 }
local LAIR_X = { 62, 188, 314, 438 }
local RAID_X = { 62, 178, 288, 404, 520 }
local NOTIFICATION_X = { 24, 220, 416 }
local NOTIFICATION_ROW_SPACING = 38

local DUNGEON_KEYS = { "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus" }
local LAIR_KEYS = { "lairWorld", "lairNormal", "lairHeroic", "lairMythic" }
local RAID_KEYS = { "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic" }

local function SetPoint(frame, x, y)
	if not frame then return end
	if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
	frame:SetPoint("TOPLEFT", x, y)
end

local function SetFontPoint(region, x, y, width)
	if not region then return end
	if type(region.ClearAllPoints) == "function" then region:ClearAllPoints() end
	region:SetPoint("TOPLEFT", x, y)
	if width and type(region.SetWidth) == "function" then region:SetWidth(width) end
	if type(region.SetJustifyH) == "function" then region:SetJustifyH("LEFT") end
	if type(region.SetWordWrap) == "function" then region:SetWordWrap(true) end
end

local function SetControlVisible(control, visible)
	if not control then return end
	if visible then
		if type(control.Show) == "function" then control:Show() end
		if control.label and type(control.label.Show) == "function" then control.label:Show() end
	else
		if type(control.Hide) == "function" then control:Hide() end
		if control.label and type(control.label.Hide) == "function" then control.label:Hide() end
	end
end

local function LayoutChildRow(controls, keys, xPositions, y, visible)
	for index, key in ipairs(keys) do
		local control = controls[key]
		SetControlVisible(control, visible)
		if visible then SetPoint(control, xPositions[index], y) end
	end
end

local function ApplyFinalSettingsLayout(addonObject)
	local controls = addonObject.settingsControls
	local panel = addonObject.settingsPanel
	if not controls or not panel then return end

	local y = START_Y
	for _, key in ipairs({ "delves", "prey", "world" }) do
		SetPoint(controls[key], 24, y)
		y = y - ROW_SPACING
	end

	SetPoint(controls.dungeonsEnabled, 24, y)
	y = y - ROW_SPACING
	local dungeonsExpanded = addonObject:GetSetting("dungeonsEnabled") == true
	LayoutChildRow(controls, DUNGEON_KEYS, DUNGEON_X, y, dungeonsExpanded)
	if dungeonsExpanded then y = y - CHILD_ROW_SPACING end

	if controls.lairsEnabled then
		SetPoint(controls.lairsEnabled, 24, y)
		y = y - ROW_SPACING
		local lairsExpanded = addonObject:GetSetting("lairsEnabled") == true
		LayoutChildRow(controls, LAIR_KEYS, LAIR_X, y, lairsExpanded)
		if lairsExpanded then y = y - CHILD_ROW_SPACING end
	end

	SetPoint(controls.raidsEnabled, 24, y)
	y = y - ROW_SPACING
	local raidsExpanded = addonObject:GetSetting("raidsEnabled") == true
	LayoutChildRow(controls, RAID_KEYS, RAID_X, y, raidsExpanded)
	if raidsExpanded then y = y - CHILD_ROW_SPACING end

	SetPoint(controls.scenarios, 24, y)
	y = y - ROW_SPACING - SECTION_SPACING

	SetFontPoint(addonObject.safetyHeader, 18, y, 560)
	SetPoint(controls.confirmBonusRoll, 24, y - 34)
	SetPoint(addonObject.previewButton, 24, y - 72)
	y = y - 120

	SetFontPoint(addonObject.interfaceHeader, 18, y, 560)
	SetPoint(controls.showMinimapButton, 24, y - 34)

	-- The sound controls are added by UXSettings/UXPolish. Place them explicitly
	-- instead of incrementally shifting whatever coordinates a previous pass left.
	local soundCheckbox = addonObject.suppressionSoundControl
	if soundCheckbox then
		if type(soundCheckbox.ClearAllPoints) == "function" then soundCheckbox:ClearAllPoints() end
		soundCheckbox:SetPoint("TOPLEFT", controls.showMinimapButton, "BOTTOMLEFT", 0, -10)
	end
	local soundLabel = addonObject.suppressionSoundSelectLabel
	if soundLabel and soundCheckbox then
		if type(soundLabel.ClearAllPoints) == "function" then soundLabel:ClearAllPoints() end
		soundLabel:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 2, -8)
	end
	local soundSelect = addonObject.suppressionSoundSelectButton
	if soundSelect and soundLabel then
		if type(soundSelect.ClearAllPoints) == "function" then soundSelect:ClearAllPoints() end
		soundSelect:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -2, -5)
	end
	local soundTest = addonObject.suppressionSoundTestButton
	if soundTest and soundSelect then
		if type(soundTest.ClearAllPoints) == "function" then soundTest:ClearAllPoints() end
		soundTest:SetPoint("LEFT", soundSelect, "RIGHT", 10, 0)
	end

	-- Match the space historically reserved by UXSettings + UXPolish, but derive
	-- it from this layout pass so repeated refreshes/collapses cannot accumulate.
	local notificationHeaderY = y - 196
	SetFontPoint(addonObject.notificationHeader, 18, notificationHeaderY, 560)
	SetFontPoint(addonObject.notificationHelp, 24, notificationHeaderY - 28, 550)
	local notificationY = notificationHeaderY - 82
	for index, definition in ipairs(addonObject.chatDestinationDefinitions or {}) do
		local column = ((index - 1) % 3) + 1
		local row = math.floor((index - 1) / 3)
		local control = addonObject.notificationControls and addonObject.notificationControls[definition.key]
		SetPoint(control, NOTIFICATION_X[column], notificationY - row * NOTIFICATION_ROW_SPACING)
	end

	local rows = math.ceil(#(addonObject.chatDestinationDefinitions or {}) / 3)
	local contentHeight = math.max(760, math.abs(notificationY - rows * NOTIFICATION_ROW_SPACING - 110))
	if type(panel.SetHeight) == "function" then panel:SetHeight(contentHeight) end
end

addon.ApplyFinalSettingsLayout = ApplyFinalSettingsLayout

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		ApplyFinalSettingsLayout(self)
		return result
	end
end

local function HookExpansionControls(addonObject)
	for _, key in ipairs({
		"dungeonsEnabled", "dungeonNormal", "dungeonHeroic", "dungeonMythic", "dungeonMythicPlus",
		"lairsEnabled", "lairWorld", "lairNormal", "lairHeroic", "lairMythic",
		"raidsEnabled", "raidStory", "raidLFR", "raidNormal", "raidHeroic", "raidMythic",
	}) do
		local control = addonObject.settingsControls and addonObject.settingsControls[key]
		if control and not control.rollCurtainFinalLayoutHook and type(control.GetScript) == "function" and type(control.SetScript) == "function" then
			local previous = control:GetScript("OnClick")
			if previous then
				control:SetScript("OnClick", function(...)
					previous(...)
					addonObject:RefreshSettingsUI()
				end)
			end
			control.rollCurtainFinalLayoutHook = true
		end
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		HookExpansionControls(self)
		self:RefreshSettingsUI()
		return result
	end
end
