local addon = {}

local now = 1000
local serverUnix = 1000
local serverLocal = (14 * 3600) + (16 * 60)
local calendarHour = 14
local calendarMinute = 16

function time() return now end
function GetServerTime() return serverUnix end
C_DateAndTime = {
	GetServerTimeLocal = function()
		return serverLocal
	end,
	GetCurrentCalendarTime = function()
		return { hour = calendarHour, minute = calendarMinute }
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

-- The countdown uses Blizzard's local-clock deadline, while the wall-clock label
-- must use realm/server time. Deliberately make the calendar API stale by two
-- minutes; GetServerTimeLocal should remain authoritative for the displayed
-- deadline. A 3-minute roll at 12:24 realm time must expire at 12:27.
now = 2000
serverUnix = 20 -- 20 seconds into the current server minute.
serverLocal = (12 * 3600) + (24 * 60)
calendarHour = 12
calendarMinute = 22
addon.hiddenBonusRoll.rollEndTime = 2180
assert(addon:GetHiddenRollRemainingSeconds() == 180)
assert(addon:GetHiddenRollExpirationServerTime() == "12:27 PM")
remaining, serverTime = addon:GetHiddenRollExpirationSummary()
assert(remaining == "3m 00s")
assert(serverTime == "12:27 PM")

-- Fall back to the calendar/game clock path when GetServerTimeLocal is not
-- available, including rollover across midnight.
C_DateAndTime.GetServerTimeLocal = nil
now = 3000
serverUnix = 50
calendarHour = 23
calendarMinute = 59
addon.hiddenBonusRoll.rollEndTime = 3075
assert(addon:GetHiddenRollRemainingSeconds() == 75)
assert(addon:GetHiddenRollExpirationServerTime() == "12:01 AM")

-- Fall back to the Blizzard frame deadline when the transition guard has not
-- captured rollEndTime yet.
C_DateAndTime.GetServerTimeLocal = function() return serverLocal end
now = 1000
serverUnix = 1000
serverLocal = (14 * 3600) + (16 * 60)
addon.hiddenBonusRoll.rollEndTime = nil
addon.hiddenBonusRoll.frame.endTime = 1060
assert(addon:GetHiddenRollRemainingSeconds() == 60)
assert(addon:FormatRollRemaining(addon:GetHiddenRollRemainingSeconds()) == "1m 00s")

print("Roll Curtain roll-timing tests passed")
