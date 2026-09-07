local addonName, addon = ...

local function GetMetadata(field, fallback)
	if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
		return C_AddOns.GetAddOnMetadata(addonName, field) or fallback
	end
	return fallback
end

function addon:GetReleaseChannel()
	local channel = tostring(GetMetadata("X-Release-Channel", "development")):lower()
	if channel == "beta" or channel == "development" or channel == "release" then
		return channel
	end
	return "development"
end

function addon:GetBuildIndicatorText()
	local channel = self:GetReleaseChannel()
	if channel == "beta" then
		return "|cffff8c00BETA / TEST BUILD|r"
	elseif channel == "development" then
		return "|cffffd100DEVELOPMENT / TEST BUILD|r"
	end
	return nil
end

function addon:BuildSettingsFooterText()
	local version = GetMetadata("Version", "Unknown")
	local author = GetMetadata("Author", "VoltageController156")
	local indicator = self:GetBuildIndicatorText()
	if indicator then
		return string.format("Version %s  •  %s  •  Author: %s", version, indicator, author)
	end
	return string.format("Version %s  •  Author: %s", version, author)
end

function addon:RefreshBuildIndicator()
	local panel = self.settingsPanel
	if not panel then return false end

	local footer = self.settingsFooter
	if not footer and type(panel.GetRegions) == "function" then
		for _, region in ipairs({ panel:GetRegions() }) do
			if region and type(region.GetText) == "function" and type(region.SetText) == "function" then
				local text = region:GetText()
				if type(text) == "string" and text:match("^Version%s") and text:find("Author:", 1, true) then
					footer = region
					self.settingsFooter = region
					break
				end
			end
		end
	end

	if not footer or type(footer.SetText) ~= "function" then return false end
	footer:SetText(self:BuildSettingsFooterText())
	return true
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		self:RefreshBuildIndicator()
		return result
	end
end

-- Also support unusual load orders where the settings panel already exists.
if addon.settingsPanel then
	addon:RefreshBuildIndicator()
end
