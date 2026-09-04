local addonName, addon = ...

-- Update this key and the notes only for meaningful releases. Beta suffixes do
-- not change the key, so testers see the panel once for the 0.0.8 feature line.
local WHATS_NEW_VERSION = "0.0.8"

local function EnsureWhatsNewDatabase()
	if type(RollCurtainDB) ~= "table" then return false end
	RollCurtainDB.whatsNewSeen = type(RollCurtainDB.whatsNewSeen) == "table" and RollCurtainDB.whatsNewSeen or {}
	return true
end

function addon:MarkWhatsNewSeenForCurrentCharacter()
	if not EnsureWhatsNewDatabase() then return end
	RollCurtainDB.whatsNewSeen[self:GetCharacterKey()] = WHATS_NEW_VERSION
end

function addon:HasSeenCurrentWhatsNew()
	if not EnsureWhatsNewDatabase() then return true end
	return RollCurtainDB.whatsNewSeen[self:GetCharacterKey()] == WHATS_NEW_VERSION
end

local function CreateWhatsNewFrame()
	if addon.whatsNewFrame or not UIParent then return addon.whatsNewFrame end
	local frame = CreateFrame("Frame", "RollCurtainWhatsNewFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(540, 360)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.TitleText then frame.TitleText:SetText("Roll Curtain — What's New in 0.0.8") end

	local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 28, -60)
	intro:SetWidth(485)
	intro:SetJustifyH("LEFT")
	intro:SetText("This update focuses on making hidden bonus rolls easier to understand, recover, and configure.")

	local notes = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	notes:SetPoint("TOPLEFT", 38, -112)
	notes:SetWidth(465)
	notes:SetJustifyH("LEFT")
	notes:SetJustifyV("TOP")
	notes:SetText("• Hidden rolls now show a live expiration countdown and server-time deadline.\n\n• Profiles can be exported and imported with a shareable profile string.\n\n• An optional sound can play when Roll Curtain suppresses a bonus roll.\n\n• New characters get a one-time setup experience with recommended presets.\n\n• Suppressed rolls are more resilient to Blizzard rebuilding the prompt during zoning.")

	local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settingsButton:SetSize(130, 28)
	settingsButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -108, 24)
	settingsButton:SetText("Open Settings")
	settingsButton:SetScript("OnClick", function()
		frame:Hide()
		addon:OpenSettings()
	end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closeButton:SetSize(80, 28)
	closeButton:SetPoint("LEFT", settingsButton, "RIGHT", 12, 0)
	closeButton:SetText(CLOSE or "Close")
	closeButton:SetScript("OnClick", function() frame:Hide() end)

	frame:Hide()
	addon.whatsNewFrame = frame
	return frame
end

function addon:ShowWhatsNewIfNeeded()
	if type(self.IsFirstRunCompleteForCurrentCharacter) == "function" and not self:IsFirstRunCompleteForCurrentCharacter() then
		return false
	end
	if self:HasSeenCurrentWhatsNew() then return false end
	self:MarkWhatsNewSeenForCurrentCharacter()
	local frame = CreateWhatsNewFrame()
	if frame then frame:Show(); return true end
	return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0.8, function() addon:ShowWhatsNewIfNeeded() end)
	else
		addon:ShowWhatsNewIfNeeded()
	end
end)
