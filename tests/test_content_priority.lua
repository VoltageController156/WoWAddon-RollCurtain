local addon = {
	settings = {
		prey = true,
		delves = true,
		world = true,
		dungeonsEnabled = true,
		dungeonNormal = true,
		dungeonHeroic = false,
		dungeonMythic = true,
		dungeonMythicPlus = false,
		raidsEnabled = true,
		raidStory = false,
		raidLFR = false,
		raidNormal = false,
		raidHeroic = false,
		raidMythic = false,
		lairsEnabled = true,
		lairWorld = true,
		lairNormal = false,
		lairHeroic = false,
		lairMythic = false,
		scenarios = false,
	},
	lairInstanceIDs = { [2987] = true },
}

function addon:GetSetting(key) return self.settings[key] end

local instanceType = "none"
local difficultyID
local difficultyName
local instanceID
local activePreyQuest
local activeDelve = false

function GetInstanceInfo()
	return "Test", instanceType, difficultyID, difficultyName, 0, false, false, instanceID
end

function GetDifficultyInfo(id)
	if id == 1 then return "Normal", "party" end
	if id == 2 then return "Heroic", "party" end
	if id == 8 then return "Mythic Keystone", "party" end
	if id == 23 then return "Mythic", "party" end
	if id == 14 then return "Normal", "raid" end
	if id == 15 then return "Heroic", "raid" end
	if id == 16 then return "Mythic", "raid" end
	if id == 17 then return "Raid Finder", "raid" end
	if id == 220 then return "Story", "raid" end
	if id == 11 then return "Scenario", nil end
	return nil, nil
end

BonusRollFrame = { state = "prompt", difficultyID = nil }

C_QuestLog = { GetActivePreyQuest = function() return activePreyQuest end }
C_DelvesUI = { HasActiveDelve = function() return activeDelve end }
C_PartyInfo = { IsDelveInProgress = function() return activeDelve end }

local clearedReplay = false
function addon:ClearSuppressedRollReplayMarker() clearedReplay = true end
function addon:ResumePriorSuppressedRoll()
	self.hiddenBonusRoll = { contentType = "raidHeroic" }
	return true
end
function addon:IsCurrentBonusRollAlreadySuppressed() return true end

assert(loadfile("RollCurtain/ContentPriority.lua"))("RollCurtain", addon)

-- A persistent Prey quest must never turn a real Heroic raid into Prey content.
activePreyQuest = 12345
instanceType = "raid"
difficultyID = 15
difficultyName = "Heroic"
instanceID = 3004
assert(addon:GetCurrentContentType() == "raidHeroic")
local shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "raidHeroic")
assert(shouldHide == false, "Unchecked Heroic Raid must fail open even while a Prey hunt is active")

-- The same priority rule applies to real dungeons.
instanceType = "party"
difficultyID = 2
difficultyName = "Heroic"
assert(addon:GetCurrentContentType() == "dungeonHeroic")
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "dungeonHeroic" and shouldHide == false)

-- Delves still override party/scenario plumbing while they are actually active.
activeDelve = true
assert(addon:GetCurrentContentType() == "delves")
activeDelve = false

-- Outdoors, Prey remains the intended higher-priority classification.
instanceType = "none"
difficultyID = nil
difficultyName = nil
instanceID = nil
BonusRollFrame.difficultyID = nil
assert(addon:GetCurrentContentType() == "prey")
assert(addon:ShouldHideCurrentPrompt() == true)

-- Known Lairs retain their own classification and difficulty gating.
instanceType = "raid"
difficultyID = 15
difficultyName = "Heroic"
instanceID = 2987
assert(addon:GetCurrentContentType() == "lairHeroic")
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "lairHeroic" and shouldHide == false)

-- "Other scenarios" must not behave like a global catch-all. WoW can expose
-- surrounding/phased content as a scenario while the bonus-roll frame itself
-- carries a real raid or dungeon difficulty. The prompt-local difficulty wins.
addon.settings.scenarios = true
instanceType = "scenario"
difficultyID = 11
difficultyName = "Scenario"
instanceID = 4000

BonusRollFrame.difficultyID = 15
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "raidHeroic", "Raid prompt metadata must outrank broad scenario context")
assert(shouldHide == false, "Other scenarios must not suppress an unchecked Heroic raid")

BonusRollFrame.difficultyID = 2
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "dungeonHeroic", "Dungeon prompt metadata must outrank broad scenario context")
assert(shouldHide == false, "Other scenarios must not suppress an unchecked Heroic dungeon")

-- A genuine/ambiguous scenario prompt with no party/raid difficulty hint still
-- follows the Other scenarios setting.
BonusRollFrame.difficultyID = 11
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "scenarios")
assert(shouldHide == true, "Other scenarios should still suppress genuine scenario content")

-- If raid suppression is explicitly enabled for the prompt's raid difficulty,
-- the raid setting—not Other scenarios—controls the result.
addon.settings.raidHeroic = true
BonusRollFrame.difficultyID = 15
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(contentType == "raidHeroic" and shouldHide == true)
addon.settings.raidHeroic = false

-- A replay marker for content that is no longer suppressed must not force the
-- reconstructed prompt back into hidden state.
clearedReplay = false
addon.hiddenBonusRoll = nil
assert(addon:ResumePriorSuppressedRoll({}) == false)
assert(addon.hiddenBonusRoll == nil)
assert(clearedReplay == true)

addon.hiddenBonusRoll = { contentType = "raidHeroic" }
clearedReplay = false
assert(addon:IsCurrentBonusRollAlreadySuppressed({}) == false)
assert(addon.hiddenBonusRoll == nil)
assert(clearedReplay == true)

print("Roll Curtain content priority tests passed")
