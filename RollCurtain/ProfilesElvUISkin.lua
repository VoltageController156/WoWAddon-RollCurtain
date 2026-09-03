local addonName, addon = ...

-- Optional ElvUI styling for the Profiles page. Roll Curtain keeps using
-- Blizzard's Settings container, but when ElvUI is present the interactive
-- controls are handed to ElvUI's own Skins module so they match the rest of
-- the user's ElvUI interface. Without ElvUI this file is a no-op.

local skinEventFrame

local function GetElvUISkins()
	local elvUI = _G and _G.ElvUI
	if type(elvUI) ~= "table" then return nil, nil end

	local unpackFn = unpack or (table and table.unpack)
	if type(unpackFn) ~= "function" then return nil, nil end

	local ok, engine = pcall(function()
		return unpackFn(elvUI)
	end)
	if not ok or type(engine) ~= "table" or type(engine.GetModule) ~= "function" then
		return nil, nil
	end

	local moduleOK, skins = pcall(engine.GetModule, engine, "Skins", true)
	if not moduleOK or type(skins) ~= "table" then return engine, nil end
	return engine, skins
end

local function FindChildByText(panel, wanted)
	if not panel or type(panel.GetChildren) ~= "function" then return nil end
	for _, child in ipairs({ panel:GetChildren() }) do
		local text
		if child and type(child.GetText) == "function" then text = child:GetText()
		elseif child then text = child.text end
		if text == wanted then return child end
	end
	return nil
end

local function TrySkin(skins, method, frame, ...)
	if not skins or not frame or frame.rollCurtainElvUISkinned then return false end
	local handler = skins[method]
	if type(handler) ~= "function" then return false end
	local ok = pcall(handler, skins, frame, ...)
	if ok then
		frame.rollCurtainElvUISkinned = true
		return true
	end
	return false
end

local function AddDropdownArrow(button)
	if not button or button.rollCurtainElvUIArrow or type(button.CreateFontString) ~= "function" then return end
	local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
	arrow:SetText("▼")
	button.rollCurtainElvUIArrow = arrow
end

local function ApplyElvUIFonts(engine, addonObject)
	if not engine or not addonObject or not addonObject.elvUIProfileLayout then return end
	local media = engine.media
	local font = media and media.normFont
	if not font then return end

	local fontSize = 12
	if engine.db and engine.db.general and tonumber(engine.db.general.fontSize) then
		fontSize = tonumber(engine.db.general.fontSize)
	end

	for _, region in pairs(addonObject.elvUIProfileLayout) do
		if region and type(region.SetFont) == "function" then
			pcall(region.SetFont, region, font, fontSize, "OUTLINE")
		end
	end

	local assignments = addonObject.profilesUI and addonObject.profilesUI.assignments
	if assignments and type(assignments.SetFont) == "function" then
		pcall(assignments.SetFont, assignments, font, fontSize, "OUTLINE")
	end
end

function addon:ApplyProfilesElvUISkin()
	local ui = self.profilesUI
	local panel = self.profilesContent
	if not ui or not panel then return false end

	local engine, skins = GetElvUISkins()
	if not skins then return false end

	local createButton = FindChildByText(panel, "Create")
	local layout = self.elvUIProfileLayout

	for _, button in ipairs({
		layout and layout.resetButton,
		createButton,
		ui.currentProfileButton,
		ui.copySourceButton,
		ui.copyButton,
		ui.renameButton,
		ui.deleteButton,
	}) do
		TrySkin(skins, "HandleButton", button)
	end

	TrySkin(skins, "HandleEditBox", ui.createEdit)
	TrySkin(skins, "HandleEditBox", ui.renameEdit)

	if self.profilesScrollFrame and self.profilesScrollFrame.ScrollBar then
		TrySkin(skins, "HandleScrollBar", self.profilesScrollFrame.ScrollBar)
	end

	-- These two controls function as dropdown selectors. ElvUI skins the
	-- buttons themselves; the small gold arrow gives them the same visual cue
	-- as ElvUI's profile dropdowns without changing Roll Curtain's menu logic.
	AddDropdownArrow(ui.currentProfileButton)
	AddDropdownArrow(ui.copySourceButton)

	ApplyElvUIFonts(engine, self)
	self.profilesElvUISkinActive = true
	return true
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		self:ApplyProfilesElvUISkin()
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		self:ApplyProfilesElvUISkin()
		return result
	end
end

-- ElvUI may initialize after Roll Curtain depending on the player's addon
-- load order. Retry when ElvUI finishes loading and again at player login.
if type(CreateFrame) == "function" then
	skinEventFrame = CreateFrame("Frame")
	if skinEventFrame and type(skinEventFrame.RegisterEvent) == "function" then
		skinEventFrame:RegisterEvent("ADDON_LOADED")
		skinEventFrame:RegisterEvent("PLAYER_LOGIN")
		skinEventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
			if event == "PLAYER_LOGIN" or loadedAddon == "ElvUI" then
				addon:ApplyProfilesElvUISkin()
			end
		end)
	end
end
