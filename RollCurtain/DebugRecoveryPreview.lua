local addonName, addon = ...

local DEFAULT_PREVIEW_SECONDS = 15

local function Now()
	if type(GetTime) == "function" then return GetTime() end
	if type(time) == "function" then return time() end
	return 0
end

function addon:IsDebugRecoveryPreviewActive()
	local expiresAt = tonumber(self.debugRecoveryPreviewUntil)
	if not expiresAt then return false end
	if expiresAt <= Now() then
		self.debugRecoveryPreviewUntil = nil
		return false
	end
	return true
end

function addon:StartDebugRecoveryPreview(seconds)
	if type(self.IsDevelopmentBuild) == "function" and not self:IsDevelopmentBuild() then
		return false
	end

	local duration = tonumber(seconds) or DEFAULT_PREVIEW_SECONDS
	if duration < 1 then duration = DEFAULT_PREVIEW_SECONDS end
	self.debugRecoveryPreviewUntil = Now() + duration

	if type(self.RefreshMinimapRecoveryGlow) == "function" then
		self:RefreshMinimapRecoveryGlow()
	end
	if type(self.DebugLog) == "function" then
		self:DebugLog(string.format("Recovery glow preview started for %d seconds.", duration))
	end
	if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff9d9d9dRoll Curtain Debug:|r Recovery glow preview active for %d seconds. No bonus roll is created or spent.", duration))
	end
	return true
end

-- Add a safe visual-only preview to the existing development Debug panel. This
-- deliberately does not create a fake BonusRollFrame, hidden-roll state, or a
-- clickable restore link; it only exercises the same minimap glow texture.
local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		local panel = self.debugSettingsPanel
		if panel and not self.debugRecoveryPreviewButton then
			local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
			button:SetSize(190, 26)
			button:SetPoint("TOPLEFT", 220, -246)
			button:SetText("Test Recovery Glow (15 sec)")
			button:SetScript("OnClick", function()
				addon:StartDebugRecoveryPreview(DEFAULT_PREVIEW_SECONDS)
			end)
			self.debugRecoveryPreviewButton = button
		end
		return result
	end
end

-- Include preview state in snapshots so testers can distinguish a visual test
-- from a real hidden bonus roll.
local previousGetDebugSnapshotLines = addon.GetDebugSnapshotLines
if type(previousGetDebugSnapshotLines) == "function" then
	addon.GetDebugSnapshotLines = function(self, ...)
		local lines = previousGetDebugSnapshotLines(self, ...)
		local preview = self:IsDebugRecoveryPreviewActive()
		for index, line in ipairs(lines) do
			if type(line) == "string" and line:match("^MinimapSetting=") then
				lines[index] = line .. " | RecoveryPreview=" .. (preview and "yes" or "no")
				break
			end
		end
		return lines
	end
end

local previousSlashHandler = SlashCmdList and SlashCmdList.ROLLCURTAIN
if type(previousSlashHandler) == "function" then
	SlashCmdList.ROLLCURTAIN = function(input)
		local command = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if command == "debug glow" or command == "debug preview" then
			addon:StartDebugRecoveryPreview(DEFAULT_PREVIEW_SECONDS)
			return
		end
		return previousSlashHandler(input)
	end
end
