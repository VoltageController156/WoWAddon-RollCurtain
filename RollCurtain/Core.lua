local addonName, addon = ...

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
	dungeons = false,
	raidsEnabled = false,
	raidStory = false,
	raidLFR = false,
	raidNormal = false,
	raidHeroic = false,
	raidMythic = false,
	scenarios = false,
}

addon.contentLabels = {
	delves = "Delves",
	prey = "Prey hunts",
	world = "World bosses / outdoor content",
	dungeons = "Dungeons",
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
local eventFrame = CreateFrame("Frame")

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

local function InitializeDatabase()
	if type(RollCurtainDB) ~= "table" then
		RollCurtainDB = {}
	end

	-- 0.0.1 had one generic raid toggle. Carry it into the master raid switch and
	-- per-difficulty settings when upgrading directly from that release.
	local legacyRaidValue = type(RollCurtainDB.raids) == "boolean" and RollCurtainDB.raids or nil

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
			if key == "raidsEnabled" then
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

	-- The master switch owns its children. Keep the saved database internally
	-- consistent if it is disabled.
	if not RollCurtainDB.raidsEnabled then
		for key in pairs(RAID_SETTING_KEYS) do
			RollCurtainDB[key] = false
		end
	end

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
	-- Check activity-specific APIs first because Prey hunts take place outdoors
	-- and Delves are implemented as scenarios.
	if HasActivePreyHunt() then
		return "prey"
	end

	if HasActiveDelve() then
		return "delves"
	end

	local _, instanceType, difficultyID = GetInstanceInfo()
	if instanceType == "party" then
		return "dungeons"
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
	if RAID_SETTING_KEYS[contentType] then
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

	-- BonusRollFrame's OnUpdate does not advance while the frame is hidden, so
	-- synchronize the visual countdown with Blizzard's absolute end time before
	-- putting the original frame back into the loot container.
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

local function InstallBonusRollHook()
	if addon.bonusRollHookInstalled or type(BonusRollFrame_StartBonusRoll) ~= "function" then
		return
	end

	hooksecurefunc("BonusRollFrame_StartBonusRoll", function()
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
		elseif loadedAddonName == "Blizzard_UIPanels_Game" then
			InstallBonusRollHook()
		end
	elseif event == "PLAYER_LOGIN" then
		InstallBonusRollHook()
		InstallChatLinkHook()
	end
end)
