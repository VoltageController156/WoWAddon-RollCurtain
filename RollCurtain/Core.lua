local addonName, addon = ...

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

local function InitializeDatabase()
	if type(RollCurtainDB) ~= "table" then
		RollCurtainDB = {}
	end

	-- 0.0.4 and earlier used one generic dungeon toggle. Migrate it into the
	-- new per-difficulty defaults: false becomes all dungeon difficulties off;
	-- true enables Normal, Heroic, and Mythic while leaving Mythic+ opt-in.
	local legacyDungeonValue
	if type(RollCurtainDB.dungeons) == "boolean" then
		legacyDungeonValue = RollCurtainDB.dungeons
	end
	local existingDungeonChildSeen = false
	local existingDungeonChildEnabled = false
	for key in pairs(DUNGEON_SETTING_KEYS) do
		if type(RollCurtainDB[key]) == "boolean" then
			existingDungeonChildSeen = true
			if RollCurtainDB[key] == true then
				existingDungeonChildEnabled = true
			end
		end
	end

	-- 0.0.1 had one generic raid toggle. Carry it into the master raid switch and
	-- per-difficulty settings when upgrading directly from that release.
	local legacyRaidValue
	if type(RollCurtainDB.raids) == "boolean" then
		legacyRaidValue = RollCurtainDB.raids
	end

	-- 0.0.2 introduced per-difficulty raid settings without a master switch. If
	-- any of those settings were enabled, keep raid suppression enabled when the
	-- master switch is introduced.
	local existingRaidChildEnabled = false
	for key in pairs(RAID_SETTING_KEYS) do
		if RollCurtainDB[key] == true then
			existingRaidChildEnabled = true
			break
		end
	end

	for key, defaultValue in pairs(addon.defaults) do
		if type(RollCurtainDB[key]) ~= "boolean" then
			if key == "dungeonsEnabled" then
				if legacyDungeonValue ~= nil then
					RollCurtainDB[key] = legacyDungeonValue
				elseif existingDungeonChildSeen then
					RollCurtainDB[key] = existingDungeonChildEnabled
				else
					RollCurtainDB[key] = defaultValue
				end
			elseif DUNGEON_SETTING_KEYS[key] and legacyDungeonValue ~= nil then
				RollCurtainDB[key] = legacyDungeonValue == true and key ~= "dungeonMythicPlus"
			elseif key == "raidsEnabled" then
				if legacyRaidValue ~= nil then
					RollCurtainDB[key] = legacyRaidValue
				elseif existingRaidChildEnabled then
					RollCurtainDB[key] = true
				else
					RollCurtainDB[key] = defaultValue
				end
			elseif RAID_SETTING_KEYS[key] and legacyRaidValue ~= nil then
				RollCurtainDB[key] = legacyRaidValue
			else
				RollCurtainDB[key] = defaultValue
			end
		end
	end

	if not RollCurtainDB.dungeonsEnabled then
		for key in pairs(DUNGEON_SETTING_KEYS) do
			RollCurtainDB[key] = false
		end
	end

	if not RollCurtainDB.raidsEnabled then
		for key in pairs(RAID_SETTING_KEYS) do
			RollCurtainDB[key] = false
		end
	end

	RollCurtainDB.dungeons = nil
	RollCurtainDB.raids = nil
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

	return C_PartyInfo
		and C_PartyInfo.IsDelveInProgress
		and C_PartyInfo.IsDelveInProgress()
end

function addon:GetCurrentContentType()
	if HasActivePreyHunt() then
		return "prey"
	end

	if HasActiveDelve() then
		return "delves"
	end

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
		return RollCurtainDB.dungeonsEnabled == true and RollCurtainDB[contentType] == true, contentType
	elseif RAID_SETTING_KEYS[contentType] then
		return RollCurtainDB.raidsEnabled == true and RollCurtainDB[contentType] == true, contentType
	end

	return RollCurtainDB[contentType] == true, contentType
end

function addon:CanRestoreHiddenBonusRoll()
	local hidden = self.hiddenBonusRoll
	local frame = hidden and hidden.frame
	if not frame or frame ~= BonusRollFrame or frame.state ~= "prompt" then
		return false
	end

	if frame:IsShown() then
		return false
	end

	if frame.endTime and type(time) == "function" and frame.endTime <= time() then
		return false
	end

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
		if timer and type(timer.SetValue) == "function" then
			timer:SetValue(remaining)
		end
	end

	GroupLootContainer_AddFrame(GroupLootContainer, frame)
	self.hiddenBonusRoll = nil
	Print("Bonus-roll prompt restored.")
	return true
end

function addon:HideCurrentPromptIfConfigured()
	if not BonusRollFrame or not BonusRollFrame:IsShown() or BonusRollFrame.state ~= "prompt" then
		return
	end

	local shouldHide, contentType = self:ShouldHideCurrentPrompt()
	if shouldHide and BonusRollFrame_CloseBonusRoll then
		self.hiddenBonusRoll = {
			frame = BonusRollFrame,
			contentType = contentType,
		}

		BonusRollFrame_CloseBonusRoll()
		Print("Bonus roll hidden " .. SHOW_ROLL_LINK)
	end
end

local function GetLootSpecName()
	if type(GetLootSpecialization) == "function" then
		local lootSpecID = GetLootSpecialization()
		if lootSpecID and lootSpecID > 0 and type(GetSpecializationInfoByID) == "function" then
			local _, name = GetSpecializationInfoByID(lootSpecID)
			if name and name ~= "" then
				return name
			end
		end
	end

	if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
		local specIndex = GetSpecialization()
		if specIndex then
			local _, name = GetSpecializationInfo(specIndex)
			if name and name ~= "" then
				return name
			end
		end
	end

	return "Current specialization"
end

local function GetBonusRollCurrencyRemaining()
	local frame = BonusRollFrame
	local currencyID = frame and frame.CurrentCountFrame and frame.CurrentCountFrame.currencyID
	if not currencyID or not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
		return nil
	end

	local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not currencyInfo or type(currencyInfo.quantity) ~= "number" then
		return nil
	end

	local cost = tonumber(addon.currentBonusRollCurrencyCost) or 1
	return math.max(0, currencyInfo.quantity - cost)
end

local function IsBonusRollPromptActive(spellID)
	local frame = BonusRollFrame
	if not frame or frame.state ~= "prompt" or not frame:IsShown() then
		return false
	end

	if spellID and frame.spellID ~= spellID then
		return false
	end

	if frame.endTime and type(time) == "function" and frame.endTime <= time() then
		return false
	end

	return true
end

local function EnsureConfirmPopup()
	if not StaticPopupDialogs or StaticPopupDialogs[CONFIRM_POPUP_KEY] then
		return
	end

	StaticPopupDialogs[CONFIRM_POPUP_KEY] = {
		text = "%s",
		button1 = "Confirm",
		button2 = CANCEL or "Cancel",
		OnAccept = function(_, data)
			if not data or not IsBonusRollPromptActive(data.spellID) then
				Print("That bonus roll is no longer available.")
				return
			end

			if type(data.originalOnClick) == "function" then
				data.originalOnClick(data.button)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

function addon:ShowBonusRollConfirmation(button, originalOnClick)
	if not IsBonusRollPromptActive() then
		Print("That bonus roll is no longer available.")
		return false
	end

	EnsureConfirmPopup()
	if not StaticPopup_Show then
		return false
	end

	local remaining = GetBonusRollCurrencyRemaining()
	local remainingText = remaining ~= nil and tostring(remaining) or "Unknown"
	local message = string.format(
		"Are you sure you want to use a bonus roll?\n\nLoot spec: |cffffd100%s|r\nBonus rolls remaining: |cffffd100%s|r",
		GetLootSpecName(),
		remainingText
	)

	StaticPopup_Show(CONFIRM_POPUP_KEY, message, nil, {
		button = button,
		originalOnClick = originalOnClick,
		spellID = BonusRollFrame.spellID,
	})
	return true
end

local function InstallBonusRollConfirmHook()
	if addon.confirmBonusRollHookInstalled then
		return
	end

	local button = BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.RollButton
	if not button or type(button.GetScript) ~= "function" or type(button.SetScript) ~= "function" then
		return
	end

	local originalOnClick = button:GetScript("OnClick")
	if type(originalOnClick) ~= "function" then
		return
	end

	button:SetScript("OnClick", function(self, ...)
		if not RollCurtainDB or RollCurtainDB.confirmBonusRoll ~= true then
			return originalOnClick(self, ...)
		end

		addon:ShowBonusRollConfirmation(self, originalOnClick)
	end)

	addon.confirmBonusRollHookInstalled = true
end

local function InstallBonusRollHook()
	if addon.bonusRollHookInstalled or type(BonusRollFrame_StartBonusRoll) ~= "function" then
		return
	end

	hooksecurefunc("BonusRollFrame_StartBonusRoll", function(_, _, _, _, currencyCost)
		addon.currentBonusRollCurrencyCost = tonumber(currencyCost) or 1
		InstallBonusRollConfirmHook()
		addon:HideCurrentPromptIfConfigured()
	end)

	addon.bonusRollHookInstalled = true
end

local function InstallChatLinkHook()
	if addon.chatLinkHookInstalled or type(SetItemRef) ~= "function" then
		return
	end

	hooksecurefunc("SetItemRef", function(link)
		if link == SHOW_ROLL_LINK_TARGET then
			addon:ShowHiddenBonusRoll()
		end
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
	for key, defaultValue in pairs(self.defaults) do
		local variable = self.settingVariables and self.settingVariables[key]
		if variable and Settings and Settings.GetSetting and Settings.GetSetting(variable) then
			Settings.SetValue(variable, defaultValue)
		else
			RollCurtainDB[key] = defaultValue
		end
	end

	if self.RefreshSettingsUI then
		self:RefreshSettingsUI()
	end

	Print("Settings restored to their defaults.")
end

local function HandleSlashCommand(input)
	local command = strtrim(input or ""):lower()
	if command == "" or command == "options" or command == "config" then
		addon:OpenSettings()
	elseif command == "status" then
		local shouldHide, contentType = addon:ShouldHideCurrentPrompt()
		local label = addon.contentLabels[contentType] or addon.contentLabels.unknown
		Print(string.format("Current content: %s. Bonus-roll prompt: %s.", label, shouldHide and "hidden" or "shown"))
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
