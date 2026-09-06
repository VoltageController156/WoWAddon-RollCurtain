local addon = { defaults = {} }
local enabled = false

function addon:GetSetting(key)
	if key == "suppressionSound" then return enabled end
	return self.defaults[key]
end

RollCurtainDB = {}
SOUNDKIT = {
	UI_BONUS_LOOT_ROLL_END = 100,
	RAID_WARNING = 101,
	READY_CHECK = 102,
	TELL_MESSAGE = 103,
	RAID_BOSS_EMOTE_WARNING = 104,
}

local playedKit, playedFile
function PlaySound(id, channel)
	playedKit = { id = id, channel = channel }
end
function PlaySoundFile(path, channel)
	playedFile = { path = path, channel = channel }
end

local sharedSounds = {
	["AirHorn (DBM)"] = "Interface\\AddOns\\DBM-Core\\sounds\\AirHorn.ogg",
	["BigWigs: Alert"] = "Interface\\AddOns\\BigWigs\\Sounds\\Alert.ogg",
	None = "Interface\\Quiet.mp3",
}
local LSM = {}
function LSM:HashTable(kind) if kind == "sound" then return sharedSounds end end
function LSM:Fetch(kind, name, noDefault)
	if kind == "sound" then return sharedSounds[name] end
end
function LibStub(name, silent)
	if name == "LibSharedMedia-3.0" then return LSM end
	if silent then return nil end
	error("missing library")
end

assert(loadfile("RollCurtain/SuppressionSound.lua"))("RollCurtain", addon)

assert(addon.defaults.suppressionSound == false)
assert(addon:GetSelectedSuppressionSoundKey() == "builtin:bonus-roll")
assert(addon:GetSelectedSuppressionSoundLabel() == "Blizzard: Bonus Roll")

local choices = addon:GetSuppressionSoundChoices()
local foundDBM, foundBigWigs, foundNone = false, false, false
for _, choice in ipairs(choices) do
	if choice.key == "lsm:AirHorn (DBM)" then foundDBM = true end
	if choice.key == "lsm:BigWigs: Alert" then foundBigWigs = true end
	if choice.key == "lsm:None" then foundNone = true end
end
assert(foundDBM and foundBigWigs)
assert(not foundNone)

assert(addon:PreviewSuppressionSound() == true)
assert(playedKit and playedKit.id == 100 and playedKit.channel == "SFX")

-- Previewing a menu option must not change the selected sound.
playedKit = nil
assert(addon:PreviewSuppressionSoundKey("builtin:ready-check") == true)
assert(playedKit and playedKit.id == 102 and playedKit.channel == "SFX")
assert(addon:GetSelectedSuppressionSoundKey() == "builtin:bonus-roll")
assert(RollCurtainDB.suppressionSoundSelection == nil)

assert(addon:SetSelectedSuppressionSound("lsm:AirHorn (DBM)") == true)
assert(RollCurtainDB.suppressionSoundSelection == "lsm:AirHorn (DBM)")
assert(addon:GetSelectedSuppressionSoundLabel() == "AirHorn (DBM)")
assert(addon:PreviewSuppressionSound() == true)
assert(playedFile and playedFile.path == sharedSounds["AirHorn (DBM)"] and playedFile.channel == "SFX")

-- Per-row preview can audition a different SharedMedia sound without selecting it.
playedFile = nil
assert(addon:PreviewSuppressionSoundKey("lsm:BigWigs: Alert") == true)
assert(playedFile and playedFile.path == sharedSounds["BigWigs: Alert"])
assert(addon:GetSelectedSuppressionSoundKey() == "lsm:AirHorn (DBM)")
assert(RollCurtainDB.suppressionSoundSelection == "lsm:AirHorn (DBM)")

playedFile = nil
enabled = false
assert(addon:PlaySuppressionSound() == false)
assert(playedFile == nil)
enabled = true
assert(addon:PlaySuppressionSound() == true)
assert(playedFile and playedFile.path == sharedSounds["AirHorn (DBM)"])

assert(addon:SetSelectedSuppressionSound("lsm:Missing") == false)
assert(addon:PreviewSuppressionSoundKey("lsm:Missing") == false)

print("Roll Curtain suppression sound tests passed")
