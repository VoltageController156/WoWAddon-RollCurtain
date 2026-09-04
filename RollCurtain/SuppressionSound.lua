local addonName, addon = ...

if addon.defaults and addon.defaults.suppressionSound == nil then
	addon.defaults.suppressionSound = false
end

function addon:PlaySuppressionSound()
	if self:GetSetting("suppressionSound") ~= true then return false end
	if type(PlaySound) ~= "function" then return false end
	local soundID = SOUNDKIT and SOUNDKIT.UI_BONUS_LOOT_ROLL_END
	if not soundID then return false end
	PlaySound(soundID, "SFX")
	return true
end
