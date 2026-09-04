local addonName, addon = ...

-- Notification destinations are profile-backed booleans. Destinations only
-- control which local chat windows receive Roll Curtain's notification; they
-- never send chat messages to other players.
addon.chatDestinationDefinitions = {
	{ key = "chatNotifyGeneral", label = "General", default = true, primary = true },
	{ key = "chatNotifyLoot", label = "Loot", messageGroup = "LOOT" },
	{ key = "chatNotifySystem", label = "System", messageGroup = "SYSTEM" },
	{ key = "chatNotifySay", label = "Say", messageGroup = "SAY" },
	{ key = "chatNotifyYell", label = "Yell", messageGroup = "YELL" },
	{ key = "chatNotifyParty", label = "Party", messageGroup = "PARTY" },
	{ key = "chatNotifyRaid", label = "Raid", messageGroup = "RAID" },
	{ key = "chatNotifyInstance", label = "Instance", messageGroup = "INSTANCE_CHAT" },
	{ key = "chatNotifyGuild", label = "Guild", messageGroup = "GUILD" },
	{ key = "chatNotifyOfficer", label = "Officer", messageGroup = "OFFICER" },
	{ key = "chatNotifyWhisper", label = "Whisper", messageGroup = "WHISPER" },
	{ key = "chatNotifyBNWhisper", label = "Battle.net Whisper", messageGroup = "BN_WHISPER" },
	{ key = "chatNotifyEmote", label = "Emote", messageGroup = "EMOTE" },
	{ key = "chatNotifyChannels", label = "Channel Messages", messageGroup = "CHANNEL" },
}

for _, definition in ipairs(addon.chatDestinationDefinitions) do
	if addon.defaults[definition.key] == nil then
		addon.defaults[definition.key] = definition.default == true
	end
end

local PREFIX = "|cff7dd3fcRoll Curtain:|r "
local RESTORE_LINK_TARGET = "rollcurtain:show"
local RESTORE_LINK = "|H" .. RESTORE_LINK_TARGET .. "|h|cff7dd3fc[Restore Bonus Roll]|r|h"

local notificationContentLabels = {
	delves = "Delve",
	prey = "Prey Hunt",
	world = "World / Outdoor",
	dungeonNormal = "Normal Dungeon",
	dungeonHeroic = "Heroic Dungeon",
	dungeonMythic = "Mythic Dungeon",
	dungeonMythicPlus = "Mythic+ Dungeon",
	dungeons = "Dungeon",
	raidStory = "Story Mode Raid",
	raidLFR = "Raid Finder",
	raidNormal = "Normal Raid",
	raidHeroic = "Heroic Raid",
	raidMythic = "Mythic Raid",
	raids = "Raid",
	scenarios = "Scenario",
	unknown = "Unknown Content",
}

local function FrameListensToMessageGroup(index, messageGroup)
	if type(GetChatWindowMessages) ~= "function" or not messageGroup then return false end
	local groups = { GetChatWindowMessages(index) }
	for _, group in ipairs(groups) do
		if group == messageGroup then return true end
	end
	return false
end

local function AddUniqueFrame(frames, seen, frame)
	if not frame or type(frame.AddMessage) ~= "function" or seen[frame] then return end
	seen[frame] = true
	table.insert(frames, frame)
end

function addon:GetNotificationChatFrames()
	local frames = {}
	local seen = {}

	for _, definition in ipairs(self.chatDestinationDefinitions or {}) do
		if self:GetSetting(definition.key) == true then
			if definition.primary then
				AddUniqueFrame(frames, seen, DEFAULT_CHAT_FRAME)
			elseif definition.messageGroup and type(GetChatWindowMessages) == "function" then
				local count = tonumber(NUM_CHAT_WINDOWS) or 10
				for index = 1, count do
					if FrameListensToMessageGroup(index, definition.messageGroup) then
						local frame = _G and _G["ChatFrame" .. index]
						AddUniqueFrame(frames, seen, frame)
					end
				end
			end
		end
	end

	return frames
end

function addon:BuildSuppressionNotification(contentType)
	local label = notificationContentLabels[contentType]
		or (self.contentLabels and self.contentLabels[contentType])
		or notificationContentLabels.unknown
	return PREFIX .. "Bonus roll suppressed - " .. label .. " - " .. RESTORE_LINK
end

function addon:NotifyBonusRollSuppressed(contentType)
	local message = self:BuildSuppressionNotification(contentType)
	for _, frame in ipairs(self:GetNotificationChatFrames()) do
		frame:AddMessage(message)
	end
	return message
end

function addon:RefreshMinimapRecoveryGlow()
	local recoverable = type(self.CanRestoreHiddenBonusRoll) == "function"
		and self:CanRestoreHiddenBonusRoll() == true
	local preview = type(self.IsDebugRecoveryPreviewActive) == "function"
		and self:IsDebugRecoveryPreviewActive() == true
	local active = recoverable or preview

	if type(self.SetMinimapRecoveryGlowActive) == "function" then
		self:SetMinimapRecoveryGlowActive(active)
		return
	end

	-- Compatibility fallback for older/minimal minimap implementations.
	local button = self.minimapButton
	local glow = button and button.recoveryGlow
	if not glow then return end
	if type(glow.SetShown) == "function" then
		glow:SetShown(active)
	elseif active and type(glow.Show) == "function" then
		glow:Show()
	elseif not active and type(glow.Hide) == "function" then
		glow:Hide()
	end
end

-- Replace the small suppression routine so the hidden-roll state remains the
-- same while notification output becomes configurable and the restore link is
-- shorter. Core's StartBonusRoll hook calls this method dynamically.
function addon:HideCurrentPromptIfConfigured()
	if not BonusRollFrame or not BonusRollFrame:IsShown() or BonusRollFrame.state ~= "prompt" then return end

	-- Blizzard may call StartBonusRoll again for the same still-active prompt when
	-- zoning. The transition guard already knows how to identify that reconstructed
	-- copy. Close it again, but preserve the original hidden record and do not send
	-- another chat notification or reclassify it based on the new zone.
	if type(self.IsCurrentBonusRollAlreadySuppressed) == "function"
		and self:IsCurrentBonusRollAlreadySuppressed(BonusRollFrame) then
		if type(BonusRollFrame_CloseBonusRoll) == "function" then
			BonusRollFrame_CloseBonusRoll()
		end
		self:RefreshMinimapRecoveryGlow()
		return
	end

	local shouldHide, contentType = self:ShouldHideCurrentPrompt()
	if shouldHide and type(BonusRollFrame_CloseBonusRoll) == "function" then
		self.hiddenBonusRoll = { frame = BonusRollFrame, contentType = contentType }
		BonusRollFrame_CloseBonusRoll()
		self:NotifyBonusRollSuppressed(contentType)
		self:RefreshMinimapRecoveryGlow()
	end
end

-- TransitionGuard already wraps ShowHiddenBonusRoll before this file loads.
-- Wrap that final implementation so the glow disappears immediately after an
-- explicit restore (the minimap OnUpdate remains the expiry safety net).
local previousShowHiddenBonusRoll = addon.ShowHiddenBonusRoll
if type(previousShowHiddenBonusRoll) == "function" then
	addon.ShowHiddenBonusRoll = function(self, ...)
		local result = previousShowHiddenBonusRoll(self, ...)
		self:RefreshMinimapRecoveryGlow()
		return result
	end
end
