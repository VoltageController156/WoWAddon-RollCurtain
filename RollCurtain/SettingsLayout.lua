local addonName, addon = ...

-- Keep the custom Settings canvas inside Blizzard's visible AddOns pane even
-- when both Dungeons and Raids are expanded. This file intentionally contains
-- layout-only behavior so profile/settings logic remains isolated in Settings.lua.

local START_Y = -154
local ROW_SPACING = 34
local CHILD_ROW_SPACING = 38
local SECTION_SPACING = 12
local CHILD_X_DUNGEON = { 62, 188, 314, 438 }
local CHILD_X_RAID = { 62, 178, 288, 404, 520 }

local DUNGEON_KEYS = {
    "dungeonNormal",
    "dungeonHeroic",
    "dungeonMythic",
    "dungeonMythicPlus",
}

local RAID_KEYS = {
    "raidStory",
    "raidLFR",
    "raidNormal",
    "raidHeroic",
    "raidMythic",
}

local function SetPoint(frame, x, y)
    if not frame then return end
    if frame.ClearAllPoints then frame:ClearAllPoints() end
    frame:SetPoint("TOPLEFT", x, y)
end

local function SetTextPoint(fontString, x, y)
    if not fontString then return end
    if fontString.ClearAllPoints then fontString:ClearAllPoints() end
    fontString:SetPoint("TOPLEFT", x, y)
end

local function ApplyMainLayout()
    local panel = addon.settingsPanel
    local controls = addon.settingsControls
    if not panel or not controls then return end

    panel:SetSize(650, 570)

    local y = START_Y
    for _, key in ipairs({ "delves", "prey", "world" }) do
        SetPoint(controls[key], 24, y)
        y = y - ROW_SPACING
    end

    SetPoint(controls.dungeonsEnabled, 24, y)
    y = y - ROW_SPACING
    if addon:GetSetting("dungeonsEnabled") == true then
        for index, key in ipairs(DUNGEON_KEYS) do
            SetPoint(controls[key], CHILD_X_DUNGEON[index], y)
        end
        y = y - CHILD_ROW_SPACING
    end

    SetPoint(controls.raidsEnabled, 24, y)
    y = y - ROW_SPACING
    if addon:GetSetting("raidsEnabled") == true then
        for index, key in ipairs(RAID_KEYS) do
            SetPoint(controls[key], CHILD_X_RAID[index], y)
        end
        y = y - CHILD_ROW_SPACING
    end

    SetPoint(controls.scenarios, 24, y)
    y = y - ROW_SPACING - SECTION_SPACING

    SetTextPoint(addon.safetyHeader, 18, y)
    SetPoint(controls.confirmBonusRoll, 24, y - 28)
    SetPoint(addon.previewButton, 352, y - 30)
    y = y - 66

    SetTextPoint(addon.interfaceHeader, 18, y)
    SetPoint(controls.showMinimapButton, 24, y - 28)
end

local function FindTextRegions(panel)
    local found = {}
    if not panel or not panel.GetRegions then return found end

    for _, region in ipairs({ panel:GetRegions() }) do
        if region and region.GetText then
            local text = region:GetText()
            if text and text ~= "" then found[text] = region end
        end
    end
    return found
end

local function SetWrappedText(region, x, y, width)
    if not region then return end
    SetTextPoint(region, x, y)
    if region.SetWidth then region:SetWidth(width) end
end

local function ApplyHelpLayout()
    local panel = addon.helpSettingsPanel
    if not panel then return end

    panel:SetSize(650, 560)
    local text = FindTextRegions(panel)

    local commands = {
        { "/rc", "Open Roll Curtain settings." },
        { "/rc status", "Show the active profile, detected activity, Curtain state, and confirmation state." },
        { "/rc show", "Restore the most recently hidden bonus-roll prompt if it is still active." },
        { "/rc reset", "Reset only the current profile to Roll Curtain defaults." },
    }

    local y = -96
    for _, entry in ipairs(commands) do
        SetWrappedText(text[entry[1]], 24, y, 116)
        SetWrappedText(text[entry[2]], 154, y, 462)
        y = y - 44
    end

    SetWrappedText(text["Aliases: /rollcurtain, /rcurtain, /rollc, /rc"], 24, y - 12, 592)
    SetWrappedText(text["Minimap button"], 24, y - 62, 592)
    SetWrappedText(
        text["Left-click opens settings. Right-click restores a hidden bonus-roll prompt. Drag to reposition it around the minimap."],
        24,
        y - 90,
        592
    )
    SetWrappedText(text["Profiles"], 24, y - 140, 592)
    SetWrappedText(
        text["Each character is assigned to a named profile. Characters can share a profile, and changes to a shared profile apply to every character assigned to it."],
        24,
        y - 168,
        592
    )
end

local originalRefreshSettingsUI = addon.RefreshSettingsUI
if type(originalRefreshSettingsUI) == "function" then
    addon.RefreshSettingsUI = function(self, ...)
        originalRefreshSettingsUI(self, ...)
        ApplyMainLayout()
    end
end

local originalRegisterSettings = addon.RegisterSettings
if type(originalRegisterSettings) == "function" then
    addon.RegisterSettings = function(self, ...)
        local result = originalRegisterSettings(self, ...)

        ApplyMainLayout()
        ApplyHelpLayout()

        if self.helpSettingsPanel and self.helpSettingsPanel.SetScript then
            self.helpSettingsPanel:SetScript("OnShow", ApplyHelpLayout)
        end

        -- Settings.lua owns the behavior of these controls. Wrap only the
        -- layout-affecting click handlers so its state changes happen first,
        -- then compact positioning is reapplied.
        if self.settingsControls then
            for _, key in ipairs({
                "dungeonsEnabled",
                "dungeonNormal",
                "dungeonHeroic",
                "dungeonMythic",
                "dungeonMythicPlus",
                "raidsEnabled",
                "raidStory",
                "raidLFR",
                "raidNormal",
                "raidHeroic",
                "raidMythic",
            }) do
                local control = self.settingsControls[key]
                if control and control.GetScript and control.SetScript then
                    local originalOnClick = control:GetScript("OnClick")
                    if originalOnClick then
                        control:SetScript("OnClick", function(...)
                            originalOnClick(...)
                            ApplyMainLayout()
                        end)
                    end
                end
            end
        end

        return result
    end
end
