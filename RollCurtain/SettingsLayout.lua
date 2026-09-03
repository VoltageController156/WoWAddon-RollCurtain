local addonName, addon = ...

-- Scrollable Blizzard Settings layout for Roll Curtain.
-- Settings.lua owns behavior/state; this file only wraps the existing canvas
-- panels in native ScrollFrames and positions their controls cleanly.

local MAIN_PANEL_WIDTH = 608
local VIEWPORT_HEIGHT = 560
local START_Y = -176
local ROW_SPACING = 44
local CHILD_ROW_SPACING = 48
local SECTION_SPACING = 26
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

local function SetWrappedText(region, x, y, width)
    if not region then return end
    SetTextPoint(region, x, y)
    if region.SetWidth then region:SetWidth(width) end
    if region.SetJustifyH then region:SetJustifyH("LEFT") end
    if region.SetJustifyV then region:SetJustifyV("TOP") end
    if region.SetWordWrap then region:SetWordWrap(true) end
end

local function WrapPanelInScrollFrame(contentPanel, name)
    if not contentPanel or not CreateFrame then
        return contentPanel
    end

    local wrapper = CreateFrame("Frame")
    wrapper:SetSize(650, VIEWPORT_HEIGHT)

    local scrollFrame = CreateFrame("ScrollFrame", nil, wrapper, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    if contentPanel.SetParent then contentPanel:SetParent(scrollFrame) end
    if contentPanel.ClearAllPoints then contentPanel:ClearAllPoints() end
    contentPanel:SetPoint("TOPLEFT", 0, 0)
    contentPanel:SetSize(MAIN_PANEL_WIDTH, contentPanel.GetHeight and contentPanel:GetHeight() or VIEWPORT_HEIGHT)

    if scrollFrame.SetScrollChild then
        scrollFrame:SetScrollChild(contentPanel)
    end

    if name == "Roll Curtain" then
        addon.settingsScrollWrapper = wrapper
        addon.settingsScrollFrame = scrollFrame
    elseif name == "Commands & Help" then
        addon.helpSettingsScrollWrapper = wrapper
        addon.helpSettingsScrollFrame = scrollFrame
    end

    return wrapper
end

local function ApplyMainLayout()
    local panel = addon.settingsPanel
    local controls = addon.settingsControls
    if not panel or not controls then return end

    if panel.SetWidth then panel:SetWidth(MAIN_PANEL_WIDTH) end

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
    SetPoint(controls.confirmBonusRoll, 24, y - 34)
    SetPoint(addon.previewButton, 24, y - 72)
    y = y - 120

    SetTextPoint(addon.interfaceHeader, 18, y)
    SetPoint(controls.showMinimapButton, 24, y - 34)

    local contentHeight = math.max(VIEWPORT_HEIGHT, math.abs(y - 116))
    if panel.SetHeight then panel:SetHeight(contentHeight) end
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

local function ApplyHelpLayout()
    local panel = addon.helpSettingsPanel
    if not panel then return end

    if panel.SetWidth then panel:SetWidth(MAIN_PANEL_WIDTH) end
    if panel.SetHeight then panel:SetHeight(720) end

    local text = FindTextRegions(panel)

    SetWrappedText(text["Roll Curtain — Commands & Help"], 16, -16, 560)
    SetWrappedText(text["All slash aliases use the same commands."], 16, -58, 560)

    local commands = {
        { "/rc", "Open Roll Curtain settings." },
        { "/rc status", "Show the active profile, detected activity, Curtain state, and confirmation state." },
        { "/rc show", "Restore the most recently hidden bonus-roll prompt if it is still active." },
        { "/rc reset", "Reset only the current profile to Roll Curtain defaults." },
    }

    local y = -108
    for _, entry in ipairs(commands) do
        SetWrappedText(text[entry[1]], 24, y, 104)
        SetWrappedText(text[entry[2]], 154, y, 410)
        y = y - 52
    end

    SetWrappedText(text["Aliases: /rollcurtain, /rcurtain, /rollc, /rc"], 24, y - 8, 540)

    SetWrappedText(text["Minimap button"], 24, y - 64, 540)
    SetWrappedText(
        text["Left-click opens settings. Right-click restores a hidden bonus-roll prompt. Drag to reposition it around the minimap."],
        36,
        y - 96,
        520
    )

    SetWrappedText(text["Profiles"], 24, y - 170, 540)
    SetWrappedText(
        text["Each character is assigned to a named profile. Characters can share a profile, and changes to a shared profile apply to every character assigned to it."],
        36,
        y - 202,
        520
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
        local originalCategoryRegistrar = Settings and Settings.RegisterCanvasLayoutCategory
        local originalSubcategoryRegistrar = Settings and Settings.RegisterCanvasLayoutSubcategory

        if originalCategoryRegistrar then
            Settings.RegisterCanvasLayoutCategory = function(panel, name)
                return originalCategoryRegistrar(WrapPanelInScrollFrame(panel, name), name)
            end
        end

        if originalSubcategoryRegistrar then
            Settings.RegisterCanvasLayoutSubcategory = function(category, panel, name)
                return originalSubcategoryRegistrar(category, WrapPanelInScrollFrame(panel, name), name)
            end
        end

        local ok, result = pcall(originalRegisterSettings, self, ...)

        if originalCategoryRegistrar then
            Settings.RegisterCanvasLayoutCategory = originalCategoryRegistrar
        end
        if originalSubcategoryRegistrar then
            Settings.RegisterCanvasLayoutSubcategory = originalSubcategoryRegistrar
        end

        if not ok then
            error(result)
        end

        ApplyMainLayout()
        ApplyHelpLayout()

        if self.helpSettingsPanel and self.helpSettingsPanel.SetScript then
            self.helpSettingsPanel:SetScript("OnShow", ApplyHelpLayout)
        end

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
