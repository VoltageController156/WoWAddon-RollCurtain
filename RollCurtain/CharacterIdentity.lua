local addonName, addon = ...

-- Character/profile assignment cleanup. WoW can briefly report a character
-- name before its realm is available during addon startup. Older builds could
-- therefore leave entries such as "Character - Unknown" in profileKeys. Keep
-- those transient identities out of the Profiles UI and reconcile them once a
-- real realm-qualified character key is available.

local function SplitCharacterKey(characterKey)
	if type(characterKey) ~= "string" then return nil, nil end
	return characterKey:match("^(.-) %- (.+)$")
end

local function IsResolvedCharacterKey(characterKey)
	local name, realm = SplitCharacterKey(characterKey)
	return name ~= nil and name ~= "" and name ~= "Unknown"
		and realm ~= nil and realm ~= "" and realm ~= "Unknown"
end

local function IsUnknownCharacterKey(characterKey)
	local name, realm = SplitCharacterKey(characterKey)
	return name ~= nil and name ~= "" and realm == "Unknown"
end

local function ProfileExists(profileName)
	return type(profileName) == "string"
		and type(RollCurtainDB) == "table"
		and type(RollCurtainDB.profiles) == "table"
		and type(RollCurtainDB.profiles[profileName]) == "table"
end

local function FindResolvedProfileKeyForName(name)
	if type(RollCurtainDB) ~= "table" or type(RollCurtainDB.profileKeys) ~= "table" then return nil end
	for characterKey in pairs(RollCurtainDB.profileKeys) do
		local candidateName = SplitCharacterKey(characterKey)
		if candidateName == name and IsResolvedCharacterKey(characterKey) then
			return characterKey
		end
	end
	return nil
end

local function FindResolvedAngleKeyForName(name)
	if type(RollCurtainDB) ~= "table" or type(RollCurtainDB.minimapAngles) ~= "table" then return nil end
	for characterKey in pairs(RollCurtainDB.minimapAngles) do
		local candidateName = SplitCharacterKey(characterKey)
		if candidateName == name and IsResolvedCharacterKey(characterKey) then
			return characterKey
		end
	end
	return nil
end

local function CleanupDuplicateUnknownKeys()
	if type(RollCurtainDB) ~= "table" then return end
	RollCurtainDB.profileKeys = type(RollCurtainDB.profileKeys) == "table" and RollCurtainDB.profileKeys or {}
	RollCurtainDB.minimapAngles = type(RollCurtainDB.minimapAngles) == "table" and RollCurtainDB.minimapAngles or {}

	local profileKeysToRemove = {}
	for characterKey, profileName in pairs(RollCurtainDB.profileKeys) do
		if IsUnknownCharacterKey(characterKey) then
			local name = SplitCharacterKey(characterKey)
			local resolvedKey = FindResolvedProfileKeyForName(name)
			if resolvedKey then
				if not ProfileExists(RollCurtainDB.profileKeys[resolvedKey]) and ProfileExists(profileName) then
					RollCurtainDB.profileKeys[resolvedKey] = profileName
				end
				table.insert(profileKeysToRemove, characterKey)
			end
		end
	end
	for _, characterKey in ipairs(profileKeysToRemove) do RollCurtainDB.profileKeys[characterKey] = nil end

	local angleKeysToRemove = {}
	for characterKey, angle in pairs(RollCurtainDB.minimapAngles) do
		if IsUnknownCharacterKey(characterKey) then
			local name = SplitCharacterKey(characterKey)
			local resolvedKey = FindResolvedAngleKeyForName(name) or FindResolvedProfileKeyForName(name)
			if resolvedKey then
				if type(RollCurtainDB.minimapAngles[resolvedKey]) ~= "number" and type(angle) == "number" then
					RollCurtainDB.minimapAngles[resolvedKey] = angle
				end
				table.insert(angleKeysToRemove, characterKey)
			end
		end
	end
	for _, characterKey in ipairs(angleKeysToRemove) do RollCurtainDB.minimapAngles[characterKey] = nil end
end

function addon:ReconcileCharacterIdentity()
	if type(RollCurtainDB) ~= "table" then return false end
	RollCurtainDB.profileKeys = type(RollCurtainDB.profileKeys) == "table" and RollCurtainDB.profileKeys or {}
	RollCurtainDB.minimapAngles = type(RollCurtainDB.minimapAngles) == "table" and RollCurtainDB.minimapAngles or {}

	CleanupDuplicateUnknownKeys()

	local resolvedKey = self:GetCharacterKey()
	if not IsResolvedCharacterKey(resolvedKey) then return false end

	local name = SplitCharacterKey(resolvedKey)
	local unknownKey = name .. " - Unknown"
	local oldAssignment = RollCurtainDB.profileKeys[unknownKey]
	local resolvedAssignment = RollCurtainDB.profileKeys[resolvedKey]

	if not ProfileExists(resolvedAssignment) then
		if ProfileExists(oldAssignment) then
			resolvedAssignment = oldAssignment
		elseif ProfileExists(self:GetCurrentProfileName()) then
			resolvedAssignment = self:GetCurrentProfileName()
		else
			resolvedAssignment = "Default"
		end
		RollCurtainDB.profileKeys[resolvedKey] = resolvedAssignment
	end
	RollCurtainDB.profileKeys[unknownKey] = nil

	local oldAngle = RollCurtainDB.minimapAngles[unknownKey]
	if type(RollCurtainDB.minimapAngles[resolvedKey]) ~= "number" and type(oldAngle) == "number" then
		RollCurtainDB.minimapAngles[resolvedKey] = oldAngle
	end
	RollCurtainDB.minimapAngles[unknownKey] = nil

	self.currentCharacterKey = resolvedKey
	self.currentProfileName = resolvedAssignment
	self.currentProfile = RollCurtainDB.profiles[resolvedAssignment]
	CleanupDuplicateUnknownKeys()
	return true
end

-- Hide unresolved startup identities from the assignment list. If a character
-- only has an old Unknown key, that assignment is kept in SavedVariables until
-- that character logs in with a resolved realm, at which point it is migrated.
local previousGetCharactersUsingProfile = addon.GetCharactersUsingProfile
if type(previousGetCharactersUsingProfile) == "function" then
	addon.GetCharactersUsingProfile = function(self, profileName)
		local characters = previousGetCharactersUsingProfile(self, profileName)
		local resolved = {}
		for _, characterKey in ipairs(characters or {}) do
			if IsResolvedCharacterKey(characterKey) then table.insert(resolved, characterKey) end
		end
		table.sort(resolved, function(a, b) return a:lower() < b:lower() end)
		return resolved
	end
end

function addon:GetProfileAssignmentsText()
	local lines = {}
	for _, profileName in ipairs(self:GetProfileNames()) do
		local characters = self:GetCharactersUsingProfile(profileName)
		if #characters > 0 then
			if #lines > 0 then table.insert(lines, "") end
			table.insert(lines, "|cffffd100" .. profileName .. "|r")
			for _, characterKey in ipairs(characters) do table.insert(lines, characterKey) end
		end
	end
	if #lines == 0 then return "No saved character assignments." end
	return table.concat(lines, "\n")
end

local function RefreshProfileAssignmentPresentation(addonObject)
	local layout = addonObject.elvUIProfileLayout
	if layout then
		if layout.assignmentsHeader and type(layout.assignmentsHeader.SetText) == "function" then
			layout.assignmentsHeader:SetText("Profile Assignments")
		end
		if layout.assignmentsHelp and type(layout.assignmentsHelp.SetText) == "function" then
			layout.assignmentsHelp:SetText("Shows which saved characters currently use each profile. Characters sharing a profile share the same Roll Curtain settings.")
		end
	end
	local ui = addonObject.profilesUI
	if ui and ui.assignments and type(ui.assignments.SetText) == "function" then
		ui.assignments:SetText(addonObject:GetProfileAssignmentsText())
	end
end

local previousRefreshSettingsUI = addon.RefreshSettingsUI
if type(previousRefreshSettingsUI) == "function" then
	addon.RefreshSettingsUI = function(self, ...)
		local result = previousRefreshSettingsUI(self, ...)
		RefreshProfileAssignmentPresentation(self)
		return result
	end
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		RefreshProfileAssignmentPresentation(self)
		return result
	end
end

local identityFrame = CreateFrame("Frame")
identityFrame:RegisterEvent("PLAYER_LOGIN")
identityFrame:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" then return end
	if addon:ReconcileCharacterIdentity() and addon.RefreshSettingsUI then addon:RefreshSettingsUI() end
end)
