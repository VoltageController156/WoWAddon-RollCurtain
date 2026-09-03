local addonName, addon = ...

local PROFILE_SCHEMA_VERSION = 1
local DEFAULT_PROFILE_NAME = "Default"
local MAX_PROFILE_NAME_LENGTH = 32

local DUNGEON_DIFFICULTY_CONTENT_TYPES = {
	[1] = "dungeonNormal",
	[2] = "dungeonHeroic",
	[23] = "dungeonMythic",
	[8] = "dungeonMythicPlus",
}

local DUNGEON_SETTING_KEYS = {
	dungeonNormal = true,
	dungeonHeroic = true,
	dungeonMythic = true,
	dungeonMythicPlus = true,
}

local RAID_DIFFICULTY_CONTENT_TYPES = {
	-- Legacy raid difficulties.
	[3] = "raidNormal",
	[4] = "raidNormal",
	[5] = "raidHeroic",
	[6] = "raidHeroic",
	[7] = "raidLFR",
	[9] = "raidNormal",

	-- Modern raid difficulties.
	[14] = "raidNormal",
	[15] = "raidHeroic",
	[16] = "raidMythic",
	[17] = "raidLFR",
	[151] = "raidLFR", -- Timewalking Raid Finder
	[220] = "raidStory",
}

local RAID_SETTING_KEYS = {
	raidStory = true,
	raidLFR = true,
	raidNormal = true,
	raidHeroic = true,
	raidMythic = true,
}

addon.defaults = {
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

addon.contentLabels = {
	delves = "Delves",
	prey = "Prey hunts",
	world = "World bosses / outdoor content",
	dungeonNormal = "Normal dungeons",
	dungeonHeroic = "Heroic dungeons",
	dungeonMythic = "Mythic dungeons",
	dungeonMythicPlus = "Mythic+ dungeons",
	dungeons = "Other dungeon difficulty",
	raidStory = "Story Mode raids",
	raidLFR = "Raid Finder (LFR)",
	raidNormal = "Normal raids",
	raidHeroic = "Heroic raids",
	raidMythic = "Mythic raids",
	raids = "Other raid difficulty",
	scenarios = "Other scenarios",
	unknown = "Unknown content",
}

local PREFIX = "|cff7dd3fcRoll Curtain:|r "
local SHOW_ROLL_LINK_TARGET = "rollcurtain:show"
local SHOW_ROLL_LINK = "|H" .. SHOW_ROLL_LINK_TARGET .. "|h|cff7dd3fc[Show Bonus Roll Prompt]|r|h"
local CONFIRM_POPUP_KEY = "ROLLCURTAIN_CONFIRM_BONUS_ROLL"
local eventFrame = CreateFrame("Frame")

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

local function Trim(value)
	if type(strtrim) == "function" then
		return strtrim(value or "")
	end
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CopyDefaults()
	local profile = {}
	for key, value in pairs(addon.defaults) do
		profile[key] = value
	end
	return profile
end

local function CopyProfileSettings(source)
	local profile = CopyDefaults()
	if type(source) == "table" then
		for key in pairs(addon.defaults) do
			if type(source[key]) == "boolean" then
				profile[key] = source[key]
			end
		end
	end
	return profile
end

local function NormalizeProfile(profile)
	if type(profile) ~= "table" then
		profile = {}
	end

	for key, defaultValue in pairs(addon.defaults) do
		if type(profile[key]) ~= "boolean" then
			profile[key] = defaultValue
		end
	end

	if not profile.dungeonsEnabled then
		for key in pairs(DUNGEON_SETTING_KEYS) do
			profile[key] = false
		end
	end

	if not profile.raidsEnabled then
		for key in pairs(RAID_SETTING_KEYS) do
			profile[key] = false
		end
	end

	return profile
end

local function BuildProfileFromLegacy(legacy)
	legacy = type(legacy) == "table" and legacy or {}
	local profile = CopyProfileSettings(legacy)

	-- 0.0.4 and earlier used one generic Dungeon toggle. Migrate an enabled
	-- toggle to Normal/Heroic/Mythic while keeping Mythic+ opt-in for 0.0.5.
	if type(legacy.dungeons) == "boolean" and type(legacy.dungeonsEnabled) ~= "boolean" then
		profile.dungeonsEnabled = legacy.dungeons
		profile.dungeonNormal = legacy.dungeons
		profile.dungeonHeroic = legacy.dungeons
		profile.dungeonMythic = legacy.dungeons
		profile.dungeonMythicPlus = false
	end

	-- 0.0.2 introduced raid child settings without a master switch. Preserve
	-- those choices and infer the master switch when any child is selected.
	if type(legacy.raidsEnabled) ~= "boolean" then
		if type(legacy.raids) == "boolean" then
			profile.raidsEnabled = legacy.raids
			for key in pairs(RAID_SETTING_KEYS) do
				if type(legacy[key]) ~= "boolean" then
					profile[key] = legacy.raids
				end
			end
		else
			local anyRaidChild = false
			for key in pairs(RAID_SETTING_KEYS) do
				if legacy[key] == true then
					anyRaidChild = true
					break
				end
			end
			profile.raidsEnabled = anyRaidChild
		end
	end

	return NormalizeProfile(profile)
end

function addon:GetCharacterKey()
	local name, realm
	if type(UnitFullName) == "function" then
		name, realm = UnitFullName("player")
	end
	if not name and type(UnitName) == "function" then
		name = UnitName("player")
	end
	if not realm or realm == "" then
		if type(GetNormalizedRealmName) == "function" then
			realm = GetNormalizedRealmName()
		elseif type(GetRealmName) == "function" then
			realm = GetRealmName()
		end
	end

	name = name or "Unknown"
	realm = realm or "Unknown"
	return string.format("%s - %s", name, realm)
end

local function FindProfileName(name)
	if type(RollCurtainDB) ~= "table" or type(RollCurtainDB.profiles) ~= "table" then
		return nil
	end

	local wanted = Trim(name):lower()
	for existingName in pairs(RollCurtainDB.profiles) do
		if existingName:lower() == wanted then
			return existingName
		end
	end
	return nil
end

local function SetCurrentProfilePointers(profileName)
	local characterKey = addon:GetCharacterKey()
	local resolved = FindProfileName(profileName) or DEFAULT_PROFILE_NAME
	RollCurtainDB.profileKeys[characterKey] = resolved
	addon.currentCharacterKey = characterKey
	addon.currentProfileName = resolved
	addon.currentProfile = RollCurtainDB.profiles[resolved]
end

local function InitializeDatabase()
	local oldDB = type(RollCurtainDB) == "table" and RollCurtainDB or {}
	local characterKey = addon:GetCharacterKey()

	if type(oldDB.profiles) ~= "table" then
		local migratedProfile = BuildProfileFromLegacy(oldDB)
		local oldAngle = type(oldDB.minimapButtonAngle) == "number" and oldDB.minimapButtonAngle or nil
		RollCurtainDB = {
			schemaVersion = PROFILE_SCHEMA_VERSION,
			profiles = {
				[DEFAULT_PROFILE_NAME] = migratedProfile,
			},
			profileKeys = {
				[characterKey] = DEFAULT_PROFILE_NAME,
			},
			minimapAngles = {},
		}
		if oldAngle then
			RollCurtainDB.minimapAngles[characterKey] = oldAngle
		end
	else
		RollCurtainDB = oldDB
		RollCurtainDB.schemaVersion = PROFILE_SCHEMA_VERSION
		RollCurtainDB.profileKeys = type(RollCurtainDB.profileKeys) == "table" and RollCurtainDB.profileKeys or {}
		RollCurtainDB.minimapAngles = type(RollCurtainDB.minimapAngles) == "table" and RollCurtainDB.minimapAngles or {}

		if type(RollCurtainDB.profiles[DEFAULT_PROFILE_NAME]) ~= "table" then
			RollCurtainDB.profiles[DEFAULT_PROFILE_NAME] = CopyDefaults()
		end
		for name, profile in pairs(RollCurtainDB.profiles) do
			RollCurtainDB.profiles[name] = NormalizeProfile(profile)
		end

		-- Early 0.0.5 test builds stored the minimap angle at the root.
		if type(RollCurtainDB.minimapButtonAngle) == "number" and type(RollCurtainDB.minimapAngles[characterKey]) ~= "number" then
			RollCurtainDB.minimapAngles[characterKey] = RollCurtainDB.minimapButtonAngle
		end
		RollCurtainDB.minimapButtonAngle = nil

		local assigned = RollCurtainDB.profileKeys[characterKey]
		if not FindProfileName(assigned) then
			RollCurtainDB.profileKeys[characterKey] = DEFAULT_PROFILE_NAME
		end
	end

	SetCurrentProfilePointers(RollCurtainDB.profileKeys[characterKey])
end

function addon:GetCurrentProfileName()
	return self.currentProfileName or DEFAULT_PROFILE_NAME
end

function addon:GetCurrentProfile()
	return self.currentProfile or (RollCurtainDB and RollCurtainDB.profiles and RollCurtainDB.profiles[DEFAULT_PROFILE_NAME])
end

function addon:GetSetting(key)
	local profile = self:GetCurrentProfile()
	if profile and profile[key] ~= nil then
		return profile[key]
	end
	return self.defaults[key]
end

function addon:SetSetting(key, value)
	if self.defaults[key] == nil then
		return false
	end
	local profile = self:GetCurrentProfile()
	if not profile then
		return false
	end
	profile[key] = value == true
	return true
end

function addon:GetProfileNames()
	local names = {}
	if RollCurtainDB and type(RollCurtainDB.profiles) == "table" then
		for name in pairs(RollCurtainDB.profiles) do
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		if a == b then return false end
		if a == DEFAULT_PROFILE_NAME then return true end
		if b == DEFAULT_PROFILE_NAME then return false end
		return a:lower() < b:lower()
	end)
	return names
end

function addon:RefreshProfileConsumers()
	if self.RefreshSettingsUI then
		self:RefreshSettingsUI()
	end
	if self.UpdateMinimapButtonVisibility then
		self:UpdateMinimapButtonVisibility()
	end
end

function addon:SelectProfile(name)
	local resolved = FindProfileName(name)
	if not resolved then
		Print("Profile not found: " .. tostring(name))
		return false
	end
	SetCurrentProfilePointers(resolved)
	self:RefreshProfileConsumers()
	Print("Profile selected: " .. resolved)
	return true
end

local function ValidateNewProfileName(name)
	name = Trim(name):gsub("[%c]", "")
	if name == "" then
		return nil, "Profile name cannot be empty."
	end
	if #name > MAX_PROFILE_NAME_LENGTH then
		return nil, string.format("Profile names are limited to %d characters.", MAX_PROFILE_NAME_LENGTH)
	end
	if FindProfileName(name) then
		return nil, "A profile with that name already exists."
	end
	return name
end

function addon:CreateProfile(name)
	local validName, errorMessage = ValidateNewProfileName(name)
	if not validName then
		Print(errorMessage)
		return false
	end

	RollCurtainDB.profiles[validName] = CopyDefaults()
	SetCurrentProfilePointers(validName)
	self:RefreshProfileConsumers()
	Print("Profile created: " .. validName)
	return true
end

function addon:CopyProfile(sourceName)
	local source = FindProfileName(sourceName)
	if not source then
		Print("Profile not found: " .. tostring(sourceName))
		return false
	end

	local targetName = self:GetCurrentProfileName()
	RollCurtainDB.profiles[targetName] = CopyProfileSettings(RollCurtainDB.profiles[source])
	self.currentProfile = RollCurtainDB.profiles[targetName]
	self:RefreshProfileConsumers()
	Print(string.format("Copied profile %s into %s.", source, targetName))
	return true
end

function addon:RenameCurrentProfile(newName)
	local oldName = self:GetCurrentProfileName()
	if oldName == DEFAULT_PROFILE_NAME then
		Print("The Default profile cannot be renamed.")
		return false
	end

	local validName, errorMessage = ValidateNewProfileName(newName)
	if not validName then
		Print(errorMessage)
		return false
	end

	RollCurtainDB.profiles[validName] = RollCurtainDB.profiles[oldName]
	RollCurtainDB.profiles[oldName] = nil
	for characterKey, profileName in pairs(RollCurtainDB.profileKeys) do
		if profileName == oldName then
			RollCurtainDB.profileKeys[characterKey] = validName
		end
	end
	SetCurrentProfilePointers(validName)
	self:RefreshProfileConsumers()
	Print(string.format("Profile renamed: %s -> %s", oldName, validName))
	return true
end

function addon:DeleteCurrentProfile()
	local name = self:GetCurrentProfileName()
	if name == DEFAULT_PROFILE_NAME then
		Print("The Default profile cannot be deleted.")
		return false
	end

	RollCurtainDB.profiles[name] = nil
	for characterKey, profileName in pairs(RollCurtainDB.profileKeys) do
		if profileName == name then
			RollCurtainDB.profileKeys[characterKey] = DEFAULT_PROFILE_NAME
		end
	end
	SetCurrentProfilePointers(DEFAULT_PROFILE_NAME)
	self:RefreshProfileConsumers()
	Print("Profile deleted: " .. name)
	return true
end

function addon:GetMinimapButtonAngle()
	local characterKey = self.currentCharacterKey or self:GetCharacterKey()
	local angles = RollCurtainDB and RollCurtainDB.minimapAngles
	return angles and angles[characterKey] or nil
end

function addon:SetMinimapButtonAngle(angle)
	if type(angle) ~= "number" or type(RollCurtainDB) ~= "table" then
		return
	end
	RollCurtainDB.minimapAngles = type(RollCurtainDB.minimapAngles) == "table" and RollCurtainDB.minimapAngles or {}
	RollCurtainDB.minimapAngles[self.currentCharacterKey or self:GetCharacterKey()] = angle
end

local function HasActivePreyHunt()
	if not C_QuestLog or not C_QuestLog.GetActivePreyQuest then
		return false
	end
	local questID = C_QuestLog.GetActivePreyQuest()
	return questID ~= nil and questID > 0
end

local function HasActiveDelve()
	if C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve() then
		return true
	end
	return C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()
end

function addon:GetCurrentContentType()
	if HasActivePreyHunt() then return "prey" end
	if HasActiveDelve() then return "delves" end

	local _, instanceType, difficultyID = GetInstanceInfo()
	if instanceType == "party" then
		return DUNGEON_DIFFICULTY_CONTENT_TYPES[difficultyID] or "dungeons"
	elseif instanceType == "raid" then
		return RAID_DIFFICULTY_CONTENT_TYPES[difficultyID] or "raids"
	elseif instanceType == "scenario" then
		return "scenarios"
	elseif instanceType == "none" then
		return "world"
	end
	return "unknown"
end

function addon:ShouldHideCurrentPrompt()
	local contentType = self:GetCurrentContentType()
	if DUNGEON_SETTING_KEYS[contentType] then
		return self:GetSetting("dungeonsEnabled") == true and self:GetSetting(contentType) == true, contentType
	elseif RAID_SETTING_KEYS[contentType] then
		return self:GetSetting("raidsEnabled") == true and self:GetSetting(contentType) == true, contentType
	end
	return self:GetSetting(contentType) == true, contentType
end

function addon:CanRestoreHiddenBonusRoll()
	local hidden = self.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not frame or frame ~= BonusRollFrame or frame.state ~= "prompt" then return false end
	if frame:IsShown() then return false end
	if frame.endTime and type(time) == "function" and frame.endTime <= time() then return false end
	return true
end

function addon:ShowHiddenBonusRoll()
	if not self:CanRestoreHiddenBonusRoll() then
		self.hiddenBonusRoll = nil
		Print("That bonus roll is no longer available.")
		return false
	end
	if not GroupLootContainer or type(GroupLootContainer_AddFrame) ~= "function" then
		Print("The Blizzard loot container is not available yet; the bonus roll could not be restored.")
		return false
	end

	local frame = self.hiddenBonusRoll.frame
	if frame.endTime and type(time) == "function" then
		local remaining = math.max(0, frame.endTime - time())
		frame.remaining = remaining
		local timer = frame.PromptFrame and frame.PromptFrame.Timer
		if timer and type(timer.SetValue) == "function" then timer:SetValue(remaining) end
	end

	GroupLootContainer_AddFrame(GroupLootContainer, frame)
	self.hiddenBonusRoll = nil
	Print("Bonus-roll prompt restored.")
	return true
end

function addon:HideCurrentPromptIfConfigured()
	if not BonusRollFrame or not BonusRollFrame:IsShown() or BonusRollFrame.state ~= "prompt" then return end
	local shouldHide, contentType = self:ShouldHideCurrentPrompt()
	if shouldHide and BonusRollFrame_CloseBonusRoll then
		self.hiddenBonusRoll = { frame = BonusRollFrame, contentType = contentType }
		BonusRollFrame_CloseBonusRoll()
		Print("Bonus roll hidden " .. SHOW_ROLL_LINK)
	end
end

local function GetLootSpecName()
	if type(GetLootSpecialization) == "function" then
		local lootSpecID = GetLootSpecialization()
		if lootSpecID and lootSpecID > 0 and type(GetSpecializationInfoByID) == "function" then
			local _, name = GetSpecializationInfoByID(lootSpecID)
			if name and name ~= "" then return name end
		end
	end
	if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
		local specIndex = GetSpecialization()
		if specIndex then
			local _, name = GetSpecializationInfo(specIndex)
			if name and name ~= "" then return name end
		end
	end
	return "Current specialization"
end

local function GetBonusRollCurrencyRemaining()
	local frame = BonusRollFrame
	local currencyID = frame and frame.CurrentCountFrame and frame.CurrentCountFrame.currencyID
	if not currencyID or not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then return nil end
	local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not currencyInfo or type(currencyInfo.quantity) ~= "number" then return nil end
	local cost = tonumber(addon.currentBonusRollCurrencyCost) or 1
	return math.max(0, currencyInfo.quantity - cost)
end

local function IsBonusRollPromptActive(spellID)
	local frame = BonusRollFrame
	if not frame or frame.state ~= "prompt" or not frame:IsShown() then return false end
	if spellID and frame.spellID ~= spellID then return false end
	if frame.endTime and type(time) == "function" and frame.endTime <= time() then return false end
	return true
end

local function EnsureConfirmPopup()
	if not StaticPopupDialogs or StaticPopupDialogs[CONFIRM_POPUP_KEY] then return end
	StaticPopupDialogs[CONFIRM_POPUP_KEY] = {
		text = "%s",
		button1 = "Confirm",
		button2 = CANCEL or "Cancel",
		OnAccept = function(_, data)
			if data and data.preview then return end
			if not data or not IsBonusRollPromptActive(data.spellID) then
				Print("That bonus roll is no longer available.")
				return
			end
			if type(data.originalOnClick) == "function" then data.originalOnClick(data.button) end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function BuildConfirmationMessage(remaining, preview)
	local message = string.format(
		"Are you sure you want to use a bonus roll?\n\nLoot spec: |cffffd100%s|r\nBonus rolls remaining: |cffffd100%s|r",
		GetLootSpecName(),
		remaining ~= nil and tostring(remaining) or "Unknown"
	)
	if preview then
		message = message .. "\n\n|cff9d9d9dPreview only — no bonus-roll token will be spent.|r"
	end
	return message
end

function addon:ShowBonusRollConfirmation(button, originalOnClick)
	if not IsBonusRollPromptActive() then
		Print("That bonus roll is no longer available.")
		return false
	end
	EnsureConfirmPopup()
	if not StaticPopup_Show then return false end
	StaticPopup_Show(CONFIRM_POPUP_KEY, BuildConfirmationMessage(GetBonusRollCurrencyRemaining(), false), nil, {
		button = button,
		originalOnClick = originalOnClick,
		spellID = BonusRollFrame.spellID,
	})
	return true
end

function addon:ShowBonusRollConfirmationPreview()
	EnsureConfirmPopup()
	if not StaticPopup_Show then return false end
	local remaining = GetBonusRollCurrencyRemaining()
	if remaining == nil then remaining = 2 end
	StaticPopup_Show(CONFIRM_POPUP_KEY, BuildConfirmationMessage(remaining, true), nil, { preview = true })
	return true
end

local function InstallBonusRollConfirmHook()
	if addon.confirmBonusRollHookInstalled then return end
	local button = BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.RollButton
	if not button or type(button.GetScript) ~= "function" or type(button.SetScript) ~= "function" then return end
	local originalOnClick = button:GetScript("OnClick")
	if type(originalOnClick) ~= "function" then return end

	button:SetScript("OnClick", function(self, ...)
		if addon:GetSetting("confirmBonusRoll") ~= true then
			return originalOnClick(self, ...)
		end
		addon:ShowBonusRollConfirmation(self, originalOnClick)
	end)
	addon.confirmBonusRollHookInstalled = true
end

local function InstallBonusRollHook()
	if addon.bonusRollHookInstalled or type(BonusRollFrame_StartBonusRoll) ~= "function" then return end
	hooksecurefunc("BonusRollFrame_StartBonusRoll", function(_, _, _, _, currencyCost)
		addon.currentBonusRollCurrencyCost = tonumber(currencyCost) or 1
		InstallBonusRollConfirmHook()
		addon:HideCurrentPromptIfConfigured()
	end)
	addon.bonusRollHookInstalled = true
end

local function InstallChatLinkHook()
	if addon.chatLinkHookInstalled or type(SetItemRef) ~= "function" then return end
	hooksecurefunc("SetItemRef", function(link)
		if link == SHOW_ROLL_LINK_TARGET then addon:ShowHiddenBonusRoll() end
	end)
	addon.chatLinkHookInstalled = true
end

function addon:OpenSettings()
	if self.settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.settingsCategory:GetID())
	else
		Print("The settings panel is not available yet. Try again after the UI finishes loading.")
	end
end

function addon:ResetDefaults()
	local profile = self:GetCurrentProfile()
	if not profile then return end
	for key, defaultValue in pairs(self.defaults) do profile[key] = defaultValue end
	self:RefreshProfileConsumers()
	Print(string.format("Profile %s restored to defaults.", self:GetCurrentProfileName()))
end

local function HandleSlashCommand(input)
	local command = Trim(input):lower()
	if command == "" or command == "options" or command == "config" then
		addon:OpenSettings()
	elseif command == "status" then
		local shouldHide, contentType = addon:ShouldHideCurrentPrompt()
		local label = addon.contentLabels[contentType] or addon.contentLabels.unknown
		Print(string.format("Profile: %s. Current content: %s. Bonus-roll prompt: %s. Confirmation: %s.",
			addon:GetCurrentProfileName(), label, shouldHide and "hidden" or "shown", addon:GetSetting("confirmBonusRoll") and "enabled" or "disabled"))
	elseif command == "show" then
		addon:ShowHiddenBonusRoll()
	elseif command == "reset" then
		addon:ResetDefaults()
	else
		Print("Commands: /rollcurtain, /rcurtain, /rollc, /rc; subcommands: status, show, reset")
	end
end

SLASH_ROLLCURTAIN1 = "/rollcurtain"
SLASH_ROLLCURTAIN2 = "/rcurtain"
SLASH_ROLLCURTAIN3 = "/rc"
SLASH_ROLLCURTAIN4 = "/rollc"
SlashCmdList.ROLLCURTAIN = HandleSlashCommand

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
	if event == "ADDON_LOADED" then
		if loadedAddonName == addonName then
			InitializeDatabase()
			addon:RegisterSettings()
			InstallBonusRollHook()
			InstallChatLinkHook()
			InstallBonusRollConfirmHook()
		elseif loadedAddonName == "Blizzard_UIPanels_Game" then
			InstallBonusRollHook()
			InstallBonusRollConfirmHook()
		end
	elseif event == "PLAYER_LOGIN" then
		InstallBonusRollHook()
		InstallChatLinkHook()
		InstallBonusRollConfirmHook()
	end
end)
