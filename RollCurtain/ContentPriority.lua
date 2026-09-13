local addonName, addon = ...

-- Content-specific settings should follow the activity the bonus roll actually
-- belongs to. Persistent outdoor state (especially an active Prey hunt) must
-- not override a real dungeon/raid instance that the player is currently in.

local DUNGEON_DIFFICULTY_CONTENT_TYPES = {
	[1] = "dungeonNormal",
	[2] = "dungeonHeroic",
	[23] = "dungeonMythic",
	[8] = "dungeonMythicPlus",
}

local RAID_DIFFICULTY_CONTENT_TYPES = {
	[3] = "raidNormal",
	[4] = "raidNormal",
	[5] = "raidHeroic",
	[6] = "raidHeroic",
	[7] = "raidLFR",
	[9] = "raidNormal",
	[14] = "raidNormal",
	[15] = "raidHeroic",
	[16] = "raidMythic",
	[17] = "raidLFR",
	[151] = "raidLFR",
	[220] = "raidStory",
}

local LAIR_DIFFICULTY_CONTENT_TYPES = {
	[17] = "lairWorld",
	[14] = "lairNormal",
	[15] = "lairHeroic",
	[16] = "lairMythic",
}

local DUNGEON_SETTING_KEYS = {
	dungeonNormal = true,
	dungeonHeroic = true,
	dungeonMythic = true,
	dungeonMythicPlus = true,
}

local RAID_SETTING_KEYS = {
	raidStory = true,
	raidLFR = true,
	raidNormal = true,
	raidHeroic = true,
	raidMythic = true,
}

local LAIR_SETTING_KEYS = {
	lairWorld = true,
	lairNormal = true,
	lairHeroic = true,
	lairMythic = true,
}

local function HasActivePreyHunt()
	if not C_QuestLog or type(C_QuestLog.GetActivePreyQuest) ~= "function" then return false end
	local questID = C_QuestLog.GetActivePreyQuest()
	return questID ~= nil and questID > 0
end

local function HasActiveDelve()
	if C_DelvesUI and type(C_DelvesUI.HasActiveDelve) == "function" and C_DelvesUI.HasActiveDelve() then
		return true
	end
	return C_PartyInfo and type(C_PartyInfo.IsDelveInProgress) == "function" and C_PartyInfo.IsDelveInProgress() == true
end

local function ClassifyLairDifficulty(difficultyID, difficultyName)
	local mapped = LAIR_DIFFICULTY_CONTENT_TYPES[difficultyID]
	if mapped then return mapped end
	local name = type(difficultyName) == "string" and difficultyName:lower() or ""
	if name:find("world", 1, true) or name:find("raid finder", 1, true) or name == "lfr" then return "lairWorld" end
	if name:find("normal", 1, true) then return "lairNormal" end
	if name:find("heroic", 1, true) then return "lairHeroic" end
	if name:find("mythic", 1, true) then return "lairMythic" end
	return "lairs"
end

-- Final classifier for the current feature line. Instance type wins over
-- unrelated outdoor quest state. Delves remain a special case because Blizzard
-- can expose a Delve through party/scenario-style instance plumbing.
function addon:GetCurrentContentType()
	local _, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()

	if instanceType == "raid" then
		if self.lairInstanceIDs and self.lairInstanceIDs[instanceID] then
			return ClassifyLairDifficulty(difficultyID, difficultyName)
		end
		return RAID_DIFFICULTY_CONTENT_TYPES[difficultyID] or "raids"
	elseif instanceType == "party" then
		if HasActiveDelve() then return "delves" end
		return DUNGEON_DIFFICULTY_CONTENT_TYPES[difficultyID] or "dungeons"
	elseif instanceType == "scenario" then
		if HasActiveDelve() then return "delves" end
		return "scenarios"
	elseif instanceType == "none" or instanceType == nil then
		if HasActivePreyHunt() then return "prey" end
		if HasActiveDelve() then return "delves" end
		return "world"
	end

	if HasActiveDelve() then return "delves" end
	if HasActivePreyHunt() then return "prey" end
	return "unknown"
end

function addon:ShouldHideContentType(contentType)
	if DUNGEON_SETTING_KEYS[contentType] then
		return self:GetSetting("dungeonsEnabled") == true and self:GetSetting(contentType) == true
	elseif RAID_SETTING_KEYS[contentType] then
		return self:GetSetting("raidsEnabled") == true and self:GetSetting(contentType) == true
	elseif LAIR_SETTING_KEYS[contentType] then
		return self:GetSetting("lairsEnabled") == true and self:GetSetting(contentType) == true
	elseif contentType == "dungeons" or contentType == "raids" or contentType == "lairs" or contentType == "unknown" then
		return false
	end
	return self:GetSetting(contentType) == true
end

function addon:ShouldHideCurrentPrompt()
	local contentType = self:GetCurrentContentType()
	return self:ShouldHideContentType(contentType), contentType
end

-- If a saved/reconstructed hidden roll belongs to content the user no longer
-- suppresses, do not let the transition guard silently keep it hidden.
local previousResumePriorSuppressedRoll = addon.ResumePriorSuppressedRoll
if type(previousResumePriorSuppressedRoll) == "function" then
	addon.ResumePriorSuppressedRoll = function(self, frame)
		local resumed = previousResumePriorSuppressedRoll(self, frame)
		local hidden = self.hiddenBonusRoll
		if resumed and hidden and not self:ShouldHideContentType(hidden.contentType) then
			self.hiddenBonusRoll = nil
			if type(self.ClearSuppressedRollReplayMarker) == "function" then self:ClearSuppressedRollReplayMarker() end
			return false
		end
		return resumed
	end
end

local previousIsCurrentBonusRollAlreadySuppressed = addon.IsCurrentBonusRollAlreadySuppressed
if type(previousIsCurrentBonusRollAlreadySuppressed) == "function" then
	addon.IsCurrentBonusRollAlreadySuppressed = function(self, frame)
		local hidden = self.hiddenBonusRoll
		if hidden and not self:ShouldHideContentType(hidden.contentType) then
			self.hiddenBonusRoll = nil
			if type(self.ClearSuppressedRollReplayMarker) == "function" then self:ClearSuppressedRollReplayMarker() end
			return false
		end
		return previousIsCurrentBonusRollAlreadySuppressed(self, frame)
	end
end
