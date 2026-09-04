local addon = {}

local now = 1000
function time() return now end
function GetServerTime() return 1000 end
C_DateAndTime = {
	GetCurrentCalendarTime = function()
		return { hour = 14, minute = 16 }
	end,
}

addon.hiddenBonusRoll = {
	rollEndTime = 1102,
	frame = { endTime = 9999 },
}

assert(loadfile("RollCurtain/RollTiming.lua"))("RollCurtain", addon)

assert(addon:GetHiddenRollRemainingSeconds() == 102)
assert(addon:FormatRollRemaining(102) == "1m 42s")
assert(addon:FormatRollRemaining(42) == "42s")
assert(addon:FormatRollRemaining(3661) == "1h 01m 01s")
assert(addon:GetHiddenRollExpirationServerTime() == "2:18 PM")
local remaining, serverTime = addon:GetHiddenRollExpirationSummary()
assert(remaining == "1m 42s")
assert(serverTime == "2:18 PM")

-- Fall back to the Blizzard frame deadline when the transition guard has not
-- captured rollEndTime yet.
addon.hiddenBonusRoll.rollEndTime = nil
addon.hiddenBonusRoll.frame.endTime = 1060
assert(addon:GetHiddenRollRemainingSeconds() == 60)
assert(addon:FormatRollRemaining(addon:GetHiddenRollRemainingSeconds()) == "1m 00s")

print("Roll Curtain roll-timing tests passed")
