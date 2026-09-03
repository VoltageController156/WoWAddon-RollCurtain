local addon = {}
local loginHandler
local currentCharacterKey = "Tester - TestRealm"

RollCurtainDB = {
	profiles = {
		Default = {},
		Raid = {},
	},
	profileKeys = {
		["Tester - TestRealm"] = "Default",
		["Tester - Unknown"] = "Raid",
		["Alt - TestRealm"] = "Raid",
		["Alt - Unknown"] = "Default",
		["Orphan - Unknown"] = "Raid",
	},
	minimapAngles = {
		["Tester - Unknown"] = 225,
		["Alt - TestRealm"] = 90,
		["Alt - Unknown"] = 45,
	},
}

function addon:GetCharacterKey() return currentCharacterKey end
function addon:GetCurrentProfileName() return self.currentProfileName or "Default" end
function addon:GetProfileNames() return { "Default", "Raid" } end
function addon:GetCharactersUsingProfile(profileName)
	local result = {}
	for characterKey, assignedProfile in pairs(RollCurtainDB.profileKeys) do
		if assignedProfile == profileName then table.insert(result, characterKey) end
	end
	table.sort(result)
	return result
end
function addon:RefreshSettingsUI() end
function addon:RegisterSettings() end

local assignmentHeader = { text = nil, SetText = function(self, text) self.text = text end }
local assignmentHelp = { text = nil, SetText = function(self, text) self.text = text end }
local assignmentText = { text = nil, SetText = function(self, text) self.text = text end }
addon.elvUIProfileLayout = { assignmentsHeader = assignmentHeader, assignmentsHelp = assignmentHelp }
addon.profilesUI = { assignments = assignmentText }

function CreateFrame()
	local frame = {}
	function frame:RegisterEvent() end
	function frame:SetScript(scriptName, callback)
		if scriptName == "OnEvent" then loginHandler = callback end
	end
	return frame
end

assert(loadfile("RollCurtain/CharacterIdentity.lua"))("RollCurtain", addon)
assert(loginHandler, "Character identity module did not register PLAYER_LOGIN")

-- Unknown startup identities stay out of the visible assignment list.
local defaultCharacters = addon:GetCharactersUsingProfile("Default")
assert(#defaultCharacters == 1 and defaultCharacters[1] == "Tester - TestRealm")
local raidCharacters = addon:GetCharactersUsingProfile("Raid")
assert(#raidCharacters == 1 and raidCharacters[1] == "Alt - TestRealm")

local assignmentSummary = addon:GetProfileAssignmentsText()
assert(assignmentSummary:find("Default", 1, true))
assert(assignmentSummary:find("Tester - TestRealm", 1, true))
assert(assignmentSummary:find("Raid", 1, true))
assert(assignmentSummary:find("Alt - TestRealm", 1, true))
assert(not assignmentSummary:find("Unknown", 1, true))
assert(not assignmentSummary:find("•", 1, true), "Assignment list should use the cleaner no-bullet layout")

-- Existing duplicate Unknown keys are removed when a realm-qualified key exists.
loginHandler(nil, "PLAYER_LOGIN")
assert(RollCurtainDB.profileKeys["Tester - Unknown"] == nil)
assert(RollCurtainDB.profileKeys["Alt - Unknown"] == nil)
assert(RollCurtainDB.profileKeys["Orphan - Unknown"] == "Raid", "Do not discard an orphaned assignment before that character can be reconciled")
assert(RollCurtainDB.minimapAngles["Tester - Unknown"] == nil)
assert(RollCurtainDB.minimapAngles["Tester - TestRealm"] == 225)
assert(RollCurtainDB.minimapAngles["Alt - Unknown"] == nil)
assert(RollCurtainDB.minimapAngles["Alt - TestRealm"] == 90, "Existing resolved minimap position should win")

-- If only an Unknown key exists for the current character, migrate its profile and position.
RollCurtainDB.profileKeys["Tester - TestRealm"] = nil
RollCurtainDB.profileKeys["Tester - Unknown"] = "Raid"
RollCurtainDB.minimapAngles["Tester - TestRealm"] = nil
RollCurtainDB.minimapAngles["Tester - Unknown"] = 137
addon.currentProfileName = "Default"
addon.currentProfile = RollCurtainDB.profiles.Default
assert(addon:ReconcileCharacterIdentity() == true)
assert(RollCurtainDB.profileKeys["Tester - TestRealm"] == "Raid")
assert(RollCurtainDB.profileKeys["Tester - Unknown"] == nil)
assert(RollCurtainDB.minimapAngles["Tester - TestRealm"] == 137)
assert(RollCurtainDB.minimapAngles["Tester - Unknown"] == nil)
assert(addon.currentProfileName == "Raid")
assert(addon.currentProfile == RollCurtainDB.profiles.Raid)

-- Profile panel wording is explicit about what the section represents.
addon:RefreshSettingsUI()
assert(assignmentHeader.text == "Profile Assignments")
assert(assignmentHelp.text:find("which saved characters", 1, true))
assert(not assignmentText.text:find("Unknown", 1, true))

print("Roll Curtain character identity tests passed")
