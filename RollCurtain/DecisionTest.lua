local addonName, addon = ...

-- Safe decision test for beta/development builds. This never creates, restores,
-- closes, or otherwise touches BonusRollFrame; it only evaluates the same
-- content classification and suppression decision used for a real prompt.

local function GetContentSummary(addonObject)
	local contentType = type(addonObject.GetCurrentContentType) == "function" and addonObject:GetCurrentContentType() or "unknown"
	local label = addonObject.contentLabels and addonObject.contentLabels[contentType] or contentType
	local instanceType, difficultyID, difficultyName = "unknown", "unknown", "unknown"
	if type(GetInstanceInfo) == "function" then
		local _, detectedInstanceType, detectedDifficultyID, detectedDifficultyName = GetInstanceInfo()
		instanceType = detectedInstanceType or "unknown"
		difficultyID = detectedDifficultyID ~= nil and tostring(detectedDifficultyID) or "unknown"
		difficultyName = detectedDifficultyName or "unknown"
	end
	return contentType, label, instanceType, difficultyID, difficultyName
end

local function GetRuleSummary(addonObject, contentType)
	if type(addonObject.GetSetting) ~= "function" then return "Rule state unavailable" end

	if contentType == "dungeonNormal" or contentType == "dungeonHeroic" or contentType == "dungeonMythic" or contentType == "dungeonMythicPlus" then
		return string.format("Dungeons=%s | %s=%s",
			addonObject:GetSetting("dungeonsEnabled") == true and "on" or "off",
			contentType,
			addonObject:GetSetting(contentType) == true and "on" or "off")
	elseif contentType == "raidStory" or contentType == "raidLFR" or contentType == "raidNormal" or contentType == "raidHeroic" or contentType == "raidMythic" then
		return string.format("Raids=%s | %s=%s",
			addonObject:GetSetting("raidsEnabled") == true and "on" or "off",
			contentType,
			addonObject:GetSetting(contentType) == true and "on" or "off")
	elseif contentType == "lairWorld" or contentType == "lairNormal" or contentType == "lairHeroic" or contentType == "lairMythic" then
		return string.format("Lair Bosses=%s | %s=%s",
			addonObject:GetSetting("lairsEnabled") == true and "on" or "off",
			contentType,
			addonObject:GetSetting(contentType) == true and "on" or "off")
	end

	local value = addonObject:GetSetting(contentType)
	if value ~= nil then
		return string.format("%s=%s", tostring(contentType), value == true and "on" or "off")
	end
	return "No configurable suppression rule matched"
end

function addon:GetCurrentDecisionTest()
	local contentType, label, instanceType, difficultyID, difficultyName = GetContentSummary(self)
	local shouldHide, decidedContentType = false, contentType
	if type(self.ShouldHideCurrentPrompt) == "function" then
		shouldHide, decidedContentType = self:ShouldHideCurrentPrompt()
	end
	decidedContentType = decidedContentType or contentType
	if decidedContentType ~= contentType then
		contentType = decidedContentType
		label = self.contentLabels and self.contentLabels[contentType] or contentType
	end

	return {
		contentType = contentType,
		label = label,
		instanceType = instanceType,
		difficultyID = difficultyID,
		difficultyName = difficultyName,
		shouldHide = shouldHide == true,
		rule = GetRuleSummary(self, contentType),
	}
end

function addon:FormatCurrentDecisionTest(result)
	result = result or self:GetCurrentDecisionTest()
	return string.format(
		"Current content: %s (%s)\nInstance: %s | Difficulty: %s (%s)\nRule: %s\nDecision: %s bonus roll prompt",
		tostring(result.label),
		tostring(result.contentType),
		tostring(result.instanceType),
		tostring(result.difficultyName),
		tostring(result.difficultyID),
		tostring(result.rule),
		result.shouldHide and "SUPPRESS" or "SHOW"
	)
end

function addon:RunCurrentDecisionTest(printResult)
	local result = self:GetCurrentDecisionTest()
	local text = self:FormatCurrentDecisionTest(result)

	if self.debugDecisionResult and type(self.debugDecisionResult.SetText) == "function" then
		self.debugDecisionResult:SetText(text)
	end

	if printResult ~= false and DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
		local prefix = "|cff9d9d9dRoll Curtain Decision Test:|r "
		for line in text:gmatch("[^\n]+") do
			DEFAULT_CHAT_FRAME:AddMessage(prefix .. line)
		end
	end

	return result
end

local function EnsureDecisionTestControls(addonObject)
	if addonObject.debugDecisionButton or not addonObject.debugSettingsPanel then return end
	if type(addonObject.IsDevelopmentBuild) == "function" and not addonObject:IsDevelopmentBuild() then return end

	local panel = addonObject.debugSettingsPanel
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(190, 26)
	button:SetPoint("TOPLEFT", 24, -340)
	button:SetText("Test Current Decision")
	button:SetScript("OnClick", function() addon:RunCurrentDecisionTest(true) end)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 226, -344)
	hint:SetWidth(360)
	hint:SetJustifyH("LEFT")
	hint:SetText("Safely evaluates the current content and settings. It does not create or spend a bonus roll.")

	local result = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	result:SetPoint("TOPLEFT", 24, -386)
	result:SetWidth(560)
	result:SetJustifyH("LEFT")
	result:SetJustifyV("TOP")
	result:SetText("Current decision test has not been run yet.")

	addonObject.debugDecisionButton = button
	addonObject.debugDecisionHint = hint
	addonObject.debugDecisionResult = result
end

local previousRegisterSettings = addon.RegisterSettings
if type(previousRegisterSettings) == "function" then
	addon.RegisterSettings = function(self, ...)
		local result = previousRegisterSettings(self, ...)
		EnsureDecisionTestControls(self)
		return result
	end
end

local previousSlashHandler = SlashCmdList and SlashCmdList.ROLLCURTAIN
if type(previousSlashHandler) == "function" then
	SlashCmdList.ROLLCURTAIN = function(input)
		local raw = tostring(input or "")
		local command = raw:lower():gsub("^%s+", ""):gsub("%s+$", "")
		if command == "debug decision" then
			if type(addon.IsDevelopmentBuild) ~= "function" or addon:IsDevelopmentBuild() then
				addon:RunCurrentDecisionTest(true)
			elseif DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
				DEFAULT_CHAT_FRAME:AddMessage("|cff9d9d9dRoll Curtain Decision Test:|r Available in beta/development builds.")
			end
			return
		end
		return previousSlashHandler(input)
	end
end
