local addonName, addon = ...

-- Addon files execute before ADDON_LOADED. Capture whether SavedVariables were
-- already present so introducing the wizard does not treat existing users as a
-- brand-new installation.
local hadDatabaseBeforeInitialization = type(RollCurtainDB) == "table" and next(RollCurtainDB) ~= nil
local FIRST_RUN_SCHEMA = 1

local RECOMMENDED = {
	delves = true,
	prey = true,
	world = true,
	dungeonsEnabled = true,
	dungeonNormal = true,
	dungeonHeroic = true,
	dungeonMythic = true,
	dungeonMythicPlus = false,
	raidsEnabled = false,
	raidStory = false,
	raidLFR = false,
	raidNormal = false,
	raidHeroic = false,
	raidMythic = false,
	scenarios = false,
	confirmBonusRoll = true,
	showMinimapButton = true,
}

local OUTDOOR_ONLY = {
	delves = true,
	prey = true,
	world = true,
	dungeonsEnabled = false,
	dungeonNormal = false,
	dungeonHeroic = false,
	dungeonMythic = false,
	dungeonMythicPlus = false,
	raidsEnabled = false,
	raidStory = false,
	raidLFR = false,
	raidNormal = false,
	raidHeroic = false,
	raidMythic = false,
	scenarios = false,
	confirmBonusRoll = true,
	showMinimapButton = true,
}

local function EnsureFirstRunDatabase()
	if type(RollCurtainDB) ~= "table" then return false end
	RollCurtainDB.firstRunCompleted = type(RollCurtainDB.firstRunCompleted) == "table" and RollCurtainDB.firstRunCompleted or {}

	if RollCurtainDB.firstRunSchema ~= FIRST_RUN_SCHEMA then
		-- When this feature is first introduced, existing characters should not be
		-- interrupted by a setup wizard. Future characters remain unmarked and get
		-- the wizard the first time they log in.
		if hadDatabaseBeforeInitialization and type(RollCurtainDB.profileKeys) == "table" then
			for characterKey in pairs(RollCurtainDB.profileKeys) do
				RollCurtainDB.firstRunCompleted[characterKey] = true
			end
		end
		RollCurtainDB.firstRunSchema = FIRST_RUN_SCHEMA
	end
	return true
end

function addon:IsFirstRunCompleteForCurrentCharacter()
	if not EnsureFirstRunDatabase() then return true end
	local characterKey = self:GetCharacterKey()
	return RollCurtainDB.firstRunCompleted[characterKey] == true
end

function addon:MarkFirstRunCompleteForCurrentCharacter()
	if not EnsureFirstRunDatabase() then return end
	RollCurtainDB.firstRunCompleted[self:GetCharacterKey()] = true
end

function addon:ApplyFirstRunPreset(presetName)
	local preset
	if presetName == "recommended" then preset = RECOMMENDED
	elseif presetName == "outdoor" then preset = OUTDOOR_ONLY
	elseif presetName == "manual" then return true
	else return false end

	for key, value in pairs(preset) do
		if self.defaults[key] ~= nil then self:SetSetting(key, value) end
	end
	self:RefreshProfileConsumers()
	return true
end

local function CreateWizard()
	if addon.firstRunFrame or not UIParent then return addon.firstRunFrame end
	local frame = CreateFrame("Frame", "RollCurtainFirstRunFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(560, 430)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.TitleText then frame.TitleText:SetText("Roll Curtain — Welcome") end

	local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 26, -58)
	intro:SetWidth(505)
	intro:SetJustifyH("LEFT")
	intro:SetText("Choose how Roll Curtain should behave for this character. You can change everything afterward in Settings.")

	local recommendedHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	recommendedHeader:SetPoint("TOPLEFT", 26, -112)
	recommendedHeader:SetText("Recommended")
	local recommendedText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	recommendedText:SetPoint("TOPLEFT", 38, -140)
	recommendedText:SetWidth(485)
	recommendedText:SetJustifyH("LEFT")
	recommendedText:SetText("Hidden: Delves, Prey hunts, world/outdoor content, and Normal, Heroic, and Mythic dungeons.\nShown: Mythic+, Story/LFR/Normal/Heroic/Mythic raids, and other scenarios.\nBonus-roll confirmation remains enabled.")

	local sharedNote = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sharedNote:SetPoint("TOPLEFT", 26, -225)
	sharedNote:SetWidth(505)
	sharedNote:SetJustifyH("LEFT")
	sharedNote:SetText("Preset choices apply to this character's active profile. If that profile is shared with another character, the same settings apply there too.")

	local function Finish(preset)
		addon:ApplyFirstRunPreset(preset)
		addon:MarkFirstRunCompleteForCurrentCharacter()
		if type(addon.MarkWhatsNewSeenForCurrentCharacter) == "function" then addon:MarkWhatsNewSeenForCurrentCharacter() end
		frame:Hide()
		if C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(0, function() addon:OpenSettings() end)
		else
			addon:OpenSettings()
		end
	end

	local recommendedButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	recommendedButton:SetSize(150, 28)
	recommendedButton:SetPoint("TOPLEFT", 26, -300)
	recommendedButton:SetText("Use Recommended")
	recommendedButton:SetScript("OnClick", function() Finish("recommended") end)

	local outdoorButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	outdoorButton:SetSize(150, 28)
	outdoorButton:SetPoint("LEFT", recommendedButton, "RIGHT", 18, 0)
	outdoorButton:SetText("Outdoor Only")
	outdoorButton:SetScript("OnClick", function() Finish("outdoor") end)

	local manualButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	manualButton:SetSize(150, 28)
	manualButton:SetPoint("LEFT", outdoorButton, "RIGHT", 18, 0)
	manualButton:SetText("Configure Manually")
	manualButton:SetScript("OnClick", function() Finish("manual") end)

	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("TOPLEFT", 26, -354)
	footer:SetWidth(505)
	footer:SetJustifyH("LEFT")
	footer:SetText("This setup appears once per character while Roll Curtain's SavedVariables are present.")

	frame:Hide()
	addon.firstRunFrame = frame
	return frame
end

function addon:ShowFirstRunWizardIfNeeded()
	if self:IsFirstRunCompleteForCurrentCharacter() then return false end
	local frame = CreateWizard()
	if frame then frame:Show(); return true end
	return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	EnsureFirstRunDatabase()
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0.5, function() addon:ShowFirstRunWizardIfNeeded() end)
	else
		addon:ShowFirstRunWizardIfNeeded()
	end
end)
