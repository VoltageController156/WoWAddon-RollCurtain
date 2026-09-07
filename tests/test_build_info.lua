local addon = {}
local metadata = {
	Version = "0.0.9",
	Author = "VoltageController156",
	["X-Release-Channel"] = "development",
}

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return metadata[field]
	end,
}

local footer = {
	text = "Version 0.0.9  •  Author: VoltageController156",
	GetText = function(self) return self.text end,
	SetText = function(self, value) self.text = value end,
}

local unrelated = {
	text = "Other text",
	GetText = function(self) return self.text end,
	SetText = function(self, value) self.text = value end,
}

addon.RegisterSettings = function(self)
	self.settingsPanel = {
		GetRegions = function()
			return unrelated, footer
		end,
	}
	return "registered"
end

assert(loadfile("RollCurtain/BuildInfo.lua"))("RollCurtain", addon)

assert(addon:GetReleaseChannel() == "development")
assert(addon:GetBuildIndicatorText():find("DEVELOPMENT / TEST BUILD", 1, true))
assert(addon:RegisterSettings() == "registered")
assert(footer.text:find("Version 0.0.9", 1, true))
assert(footer.text:find("DEVELOPMENT / TEST BUILD", 1, true))
assert(footer.text:find("Author: VoltageController156", 1, true))
assert(addon.settingsFooter == footer, "Expected settings footer to be cached")

metadata.Version = "0.0.9-beta.3"
metadata["X-Release-Channel"] = "beta"
assert(addon:GetReleaseChannel() == "beta")
assert(addon:GetBuildIndicatorText():find("BETA / TEST BUILD", 1, true))
assert(addon:RefreshBuildIndicator() == true)
assert(footer.text:find("Version 0.0.9-beta.3", 1, true))
assert(footer.text:find("BETA / TEST BUILD", 1, true))

metadata.Version = "0.0.9"
metadata["X-Release-Channel"] = "release"
assert(addon:GetReleaseChannel() == "release")
assert(addon:GetBuildIndicatorText() == nil)
assert(addon:RefreshBuildIndicator() == true)
assert(footer.text == "Version 0.0.9  •  Author: VoltageController156", "Stable footer should not show a test-build warning")

metadata["X-Release-Channel"] = "unexpected"
assert(addon:GetReleaseChannel() == "development", "Unknown channels should fail safe as development")

print("Roll Curtain build-info tests passed")
