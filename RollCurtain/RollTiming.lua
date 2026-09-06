local addonName, addon = ...

local function GetHiddenEndTime(addonObject)
	local hidden = addonObject.hiddenBonusRoll
	if not hidden then return nil end
	if type(hidden.rollEndTime) == "number" then return hidden.rollEndTime end
	local frame = hidden.frame
	if frame and type(frame.endTime) == "number" then return frame.endTime end
	return nil
end

local function GetNow()
	if type(time) == "function" then return time() end
	if type(GetServerTime) == "function" then return GetServerTime() end
	return nil
end

function addon:GetHiddenRollEndTime()
	return GetHiddenEndTime(self)
end

function addon:GetHiddenRollRemainingSeconds()
	local endTime = GetHiddenEndTime(self)
	local now = GetNow()
	if type(endTime) ~= "number" or type(now) ~= "number" then return nil end
	return math.max(0, math.ceil(endTime - now))
end

function addon:FormatRollRemaining(seconds)
	seconds = tonumber(seconds)
	if not seconds then return nil end
	seconds = math.max(0, math.ceil(seconds))

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainder = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, remainder)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, remainder)
	end
	return string.format("%ds", remainder)
end

local function GetServerClock()
	if C_DateAndTime and type(C_DateAndTime.GetCurrentCalendarTime) == "function" then
		local info = C_DateAndTime.GetCurrentCalendarTime()
		if type(info) == "table" and type(info.hour) == "number" and type(info.minute) == "number" then
			return info.hour, info.minute
		end
	end
	if type(GetGameTime) == "function" then
		local hour, minute = GetGameTime()
		if type(hour) == "number" and type(minute) == "number" then return hour, minute end
	end
	return nil, nil
end

function addon:GetHiddenRollExpirationServerTime()
	local remaining = self:GetHiddenRollRemainingSeconds()
	if remaining == nil then return nil end

	local hour, minute = GetServerClock()
	if hour == nil or minute == nil then return nil end
	local second = 0
	if type(GetServerTime) == "function" then
		second = GetServerTime() % 60
	end

	local total = (hour * 3600) + (minute * 60) + second + remaining
	local expireHour = math.floor(total / 3600) % 24
	local expireMinute = math.floor((total % 3600) / 60)
	local suffix = expireHour >= 12 and "PM" or "AM"
	local displayHour = expireHour % 12
	if displayHour == 0 then displayHour = 12 end
	return string.format("%d:%02d %s", displayHour, expireMinute, suffix)
end

function addon:GetHiddenRollExpirationSummary()
	local remaining = self:GetHiddenRollRemainingSeconds()
	if remaining == nil then return nil, nil end
	return self:FormatRollRemaining(remaining), self:GetHiddenRollExpirationServerTime()
end
