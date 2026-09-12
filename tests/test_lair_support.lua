local addon = {
	defaults = {},
	contentLabels = {},
}

local settings = {}
local instanceType = "raid"
local difficultyID = 17
local difficultyName = "World"
local instanceID = 2987
local baseContentType = "raidNormal"
local baseSuppress = true

function GetInstanceInfo()
	return "Test Instance", instanceType, difficultyID, difficultyName, 0, false, false, instanceID
end

function addon:GetSetting(key)
	if settings[key] ~= nil then return settings[key] end
	return self.defaults[key]
end

function addon:SetSetting(key, value)
	if self.defaults[key] == nil then return false end
	settings[key] = value == true
	return true
end

function addon:GetCurrentContentType()
	return baseContentType
end

function addon:ShouldHideCurrentPrompt()
	return baseSuppress, self:GetCurrentContentType()
end

function addon:RegisterSettings() end
function addon:RefreshSettingsUI() end

assert(loadfile("RollCurtain/LairSupport.lua"))("RollCurtain", addon)

-- Lair settings are opt-in so existing users do not suddenly suppress a new
-- content category after upgrading.
assert(addon.defaults.lairsEnabled == false)
assert(addon.defaults.lairWorld == false)
assert(addon.defaults.lairNormal == false)
assert(addon.defaults.lairHeroic == false)
assert(addon.defaults.lairMythic == false)
assert(addon.lairInstanceIDs[2987] == true)

-- The Tidebound Grotto is classified independently from normal raids.
difficultyID = 17; difficultyName = "World"; assert(addon:GetCurrentContentType() == "lairWorld")
difficultyID = 14; difficultyName = "Normal"; assert(addon:GetCurrentContentType() == "lairNormal")
difficultyID = 15; difficultyName = "Heroic"; assert(addon:GetCurrentContentType() == "lairHeroic")
difficultyID = 16; difficultyName = "Mythic"; assert(addon:GetCurrentContentType() == "lairMythic")

-- Unexpected difficulty IDs can still be recognized by Blizzard's difficulty
-- name, while completely unknown Lair difficulties fail open.
difficultyID = 999; difficultyName = "World"; assert(addon:GetCurrentContentType() == "lairWorld")
difficultyName = "Something New"; assert(addon:GetCurrentContentType() == "lairs")
local shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(shouldHide == false and contentType == "lairs")

-- The parent switch gates every Lair child setting.
difficultyID = 15; difficultyName = "Heroic"
settings.lairHeroic = true
settings.lairsEnabled = false
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(shouldHide == false and contentType == "lairHeroic")
settings.lairsEnabled = true
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(shouldHide == true and contentType == "lairHeroic")

-- Ordinary raids continue through the existing classification/suppression path.
instanceID = 3004
baseContentType = "raidNormal"
baseSuppress = true
assert(addon:GetCurrentContentType() == "raidNormal")
shouldHide, contentType = addon:ShouldHideCurrentPrompt()
assert(shouldHide == true and contentType == "raidNormal")

print("Roll Curtain Lair support tests passed")
