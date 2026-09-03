local addonName, addon = ...

local function BoolText(value)
	return value and "yes" or "no"
end

local function GetFrameParentName(frame)
	if not frame or type(frame.GetParent) ~= "function" then return "n/a" end
	local parent = frame:GetParent()
	if not parent then return "none" end
	if type(parent.GetName) == "function" then
		local name = parent:GetName()
		if name and name ~= "" then return name end
	end
	return "<unnamed>"
end

local function IsAddOnLoaded(name)
	if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
		return C_AddOns.IsAddOnLoaded(name) == true
	end
	if type(IsAddOnLoaded) == "function" then
		return IsAddOnLoaded(name) == true
	end
	return false
end

local function DetectCollector()
	if IsAddOnLoaded("MinimapButtonBag") then return "MinimapButtonBag" end
	return "none"
end

local previousGetDebugSnapshotLines = addon.GetDebugSnapshotLines
if type(previousGetDebugSnapshotLines) == "function" then
	addon.GetDebugSnapshotLines = function(self, ...)
		local lines = previousGetDebugSnapshotLines(self, ...)
		local button = self.minimapButton
		local settingEnabled = type(self.GetSetting) == "function" and self:GetSetting("showMinimapButton") == true
		local shown = button and type(button.IsShown) == "function" and button:IsShown() == true
		local visible = button and type(button.IsVisible) == "function" and button:IsVisible() == true
		local glow = button and button.recoveryGlow
		local glowShown = glow and type(glow.IsShown) == "function" and glow:IsShown() == true
		local parentName = GetFrameParentName(button)
		local collector = DetectCollector()
		local replacement = string.format(
			"MinimapSetting=%s | NativeButtonShown=%s | NativeButtonVisible=%s | Parent=%s | Collector=%s | RecoveryGlow=%s",
			BoolText(settingEnabled), BoolText(shown), BoolText(visible), parentName, collector, BoolText(glowShown)
		)

		local replaced = false
		for index, line in ipairs(lines) do
			if type(line) == "string" and line:match("^MinimapShown=") then
				lines[index] = replacement
				replaced = true
				break
			end
		end
		if not replaced then table.insert(lines, replacement) end
		return lines
	end
end
