local addon = {}
local refreshCount = 0
local messages = {}

addon.defaults = {
	delves = true,
	world = true,
	dungeonMythicPlus = false,
	confirmBonusRoll = true,
	suppressionSound = false,
}
addon.currentProfileName = "Default"
addon.currentProfile = {
	delves = false,
	world = true,
	dungeonMythicPlus = true,
	confirmBonusRoll = false,
	suppressionSound = true,
}

DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
function addon:GetCurrentProfile() return self.currentProfile end
function addon:GetCurrentProfileName() return self.currentProfileName end
function addon:RefreshProfileConsumers() refreshCount = refreshCount + 1 end

assert(loadfile("RollCurtain/ProfileTransfer.lua"))("RollCurtain", addon)

local exported = addon:ExportCurrentProfileString()
assert(type(exported) == "string")
assert(exported:match("^RC1:"))
assert(#exported > 50, "Export should be a paste-friendly encoded profile string")

-- Change every value, then verify import restores the exported state.
addon.currentProfile.delves = true
addon.currentProfile.world = false
addon.currentProfile.dungeonMythicPlus = false
addon.currentProfile.confirmBonusRoll = true
addon.currentProfile.suppressionSound = false

assert(addon:ImportProfileString(exported) == true)
assert(addon.currentProfile.delves == false)
assert(addon.currentProfile.world == true)
assert(addon.currentProfile.dungeonMythicPlus == true)
assert(addon.currentProfile.confirmBonusRoll == false)
assert(addon.currentProfile.suppressionSound == true)
assert(refreshCount == 1)

local corrupted = exported:sub(1, -2) .. (exported:sub(-1) == "A" and "B" or "A")
assert(addon:ImportProfileString(corrupted) == false)
assert(#messages >= 2)

print("Roll Curtain profile-transfer tests passed")
