local addonName, addon = ...

-- Safe, beta/development-only decision test. This never creates, restores,
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
