local addonName, addon = ...

if addon.defaults and addon.defaults.suppressionSound == nil then
	addon.defaults.suppressionSound = false
end

local DEFAULT_SOUND_KEY = "builtin:bonus-roll"

local BUILTIN_SOUNDS = {
	{ key = "builtin:bonus-roll", label = "Blizzard: Bonus Roll", soundKit = "UI_BONUS_LOOT_ROLL_END" },
	{ key = "builtin:raid-warning", label = "Blizzard: Raid Warning", soundKit = "RAID_WARNING" },
	{ key = "builtin:ready-check", label = "Blizzard: Ready Check", soundKit = "READY_CHECK" },
	{ key = "builtin:whisper", label = "Blizzard: Whisper", soundKit = "TELL_MESSAGE" },
	{ key = "builtin:boss-warning", label = "Blizzard: Boss Warning", soundKit = "RAID_BOSS_EMOTE_WARNING" },
}

local function GetSharedMedia()
	if not LibStub then return nil end
	local ok, library = pcall(LibStub, "LibSharedMedia-3.0", true)
	if ok then return library end
	return nil
end

local function ResolveBuiltin(entry)
	local soundID = SOUNDKIT and SOUNDKIT[entry.soundKit]
	if type(soundID) ~= "number" then return nil end
	return {
		key = entry.key,
		label = entry.label,
		kind = "kit",
		value = soundID,
		source = "Blizzard",
	}
end

local function ResolveSharedMedia(key)
	local name = type(key) == "string" and key:match("^lsm:(.+)$") or nil
	if not name then return nil end
	local media = GetSharedMedia()
	if not media or type(media.Fetch) ~= "function" then return nil end
	local ok, path = pcall(media.Fetch, media, "sound", name, true)
	if not ok or type(path) ~= "string" or path == "" then return nil end
	return {
		key = key,
		label = name,
		kind = "file",
		value = path,
		source = "SharedMedia",
	}
end

function addon:GetSuppressionSoundChoices()
	local choices = {}
	for _, entry in ipairs(BUILTIN_SOUNDS) do
		local resolved = ResolveBuiltin(entry)
		if resolved then choices[#choices + 1] = resolved end
	end

	local media = GetSharedMedia()
	if media and type(media.HashTable) == "function" then
		local ok, sounds = pcall(media.HashTable, media, "sound")
		if ok and type(sounds) == "table" then
			local names = {}
			for name, path in pairs(sounds) do
				if name ~= "None" and type(path) == "string" and path ~= "" then names[#names + 1] = name end
			end
			table.sort(names, function(a, b) return a:lower() < b:lower() end)
			for _, name in ipairs(names) do
				choices[#choices + 1] = {
					key = "lsm:" .. name,
					label = name,
					kind = "file",
					value = sounds[name],
					source = "SharedMedia",
				}
			end
		end
	end
	return choices
end

function addon:ResolveSuppressionSound(key)
	key = key or DEFAULT_SOUND_KEY
	for _, entry in ipairs(BUILTIN_SOUNDS) do
		if entry.key == key then return ResolveBuiltin(entry) end
	end
	return ResolveSharedMedia(key)
end

function addon:GetSelectedSuppressionSoundKey()
	local key = type(RollCurtainDB) == "table" and RollCurtainDB.suppressionSoundSelection or nil
	if type(key) ~= "string" or not self:ResolveSuppressionSound(key) then return DEFAULT_SOUND_KEY end
	return key
end

function addon:GetSelectedSuppressionSoundLabel()
	local sound = self:ResolveSuppressionSound(self:GetSelectedSuppressionSoundKey())
	return sound and sound.label or "Blizzard: Bonus Roll"
end

function addon:SetSelectedSuppressionSound(key)
	local sound = self:ResolveSuppressionSound(key)
	if not sound or type(RollCurtainDB) ~= "table" then return false end
	RollCurtainDB.suppressionSoundSelection = key
	return true
end

local function PlayResolvedSound(sound)
	if not sound then return false end
	if sound.kind == "kit" and type(PlaySound) == "function" then
		PlaySound(sound.value, "SFX")
		return true
	elseif sound.kind == "file" and type(PlaySoundFile) == "function" then
		PlaySoundFile(sound.value, "SFX")
		return true
	end
	return false
end

function addon:PreviewSuppressionSound()
	local sound = self:ResolveSuppressionSound(self:GetSelectedSuppressionSoundKey())
	return PlayResolvedSound(sound)
end

function addon:PlaySuppressionSound()
	if self:GetSetting("suppressionSound") ~= true then return false end
	return self:PreviewSuppressionSound()
end
