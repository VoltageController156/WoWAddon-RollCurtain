local addonName, addon = ...

local DEFAULT_ANGLE = 225
local MINIMAP_RADIUS = 80
local REFRESH_INTERVAL = 0.5
local ICON_TEXTURE = "Interface\\AddOns\\RollCurtain\\Media\\MinimapIcon.png"
local RECOVERY_RING_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local RECOVERY_HALO_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

local function GetSavedAngle()
	if type(addon.GetMinimapButtonAngle) == "function" then
		local angle = addon:GetMinimapButtonAngle()
		if type(angle) == "number" then return angle end
	end
	return DEFAULT_ANGLE
end

local function SaveAngle(angle)
	if type(addon.SetMinimapButtonAngle) == "function" then addon:SetMinimapButtonAngle(angle) end
end

local function Atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	if x > 0 then return math.atan(y / x)
	elseif x < 0 and y >= 0 then return math.atan(y / x) + math.pi
	elseif x < 0 and y < 0 then return math.atan(y / x) - math.pi
	elseif x == 0 and y > 0 then return math.pi / 2
	elseif x == 0 and y < 0 then return -math.pi / 2 end
	return 0
end

local function PositionButton(button, angle)
	local radians = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function UpdateButtonFromCursor(button)
	local minimapX, minimapY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cursorX = cursorX / scale
	cursorY = cursorY / scale
	local angle = math.deg(Atan2(cursorY - minimapY, cursorX - minimapX))
	SaveAngle(angle)
	PositionButton(button, angle)
end

local function HasRecoverableRoll()
	if type(addon.IsDebugRecoveryPreviewActive) == "function" and addon:IsDebugRecoveryPreviewActive() == true then
		return true
	end
	return type(addon.CanRestoreHiddenBonusRoll) == "function" and addon:CanRestoreHiddenBonusRoll() == true
end

function addon:SetMinimapRecoveryGlowActive(active)
	local button = self.minimapButton
	if not button then return end
	active = active == true

	local ring = button.recoveryGlow
	local halo = button.recoveryGlowHalo
	if ring then ring:SetShown(active) end
	if halo then
		halo:SetShown(active)
		if active then halo:SetAlpha(0.52) end
	end
	if active then
		button.recoveryPulseElapsed = button.recoveryPulseElapsed or 0
	else
		button.recoveryPulseElapsed = 0
	end
end

local function RefreshGlow(button)
	addon:SetMinimapRecoveryGlowActive(HasRecoverableRoll())
end

local function UpdateGlowPulse(button, elapsed)
	local ring = button.recoveryGlow
	local halo = button.recoveryGlowHalo
	if not ring or not halo or not ring:IsShown() then return end

	button.recoveryPulseElapsed = (button.recoveryPulseElapsed or 0) + elapsed
	local pulse = (math.sin(button.recoveryPulseElapsed * 2.8) + 1) * 0.5
	-- Keep a strong, crisp gold circle at all times and let the larger outer
	-- halo breathe enough to be noticeable without turning into a flashing box.
	ring:SetAlpha(0.92 + (pulse * 0.08))
	halo:SetAlpha(0.34 + (pulse * 0.46))
end

local function ShowTooltip(button)
	if not GameTooltip then return end
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText("Roll Curtain")
	GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
	GameTooltip:AddLine("Right-click: Show hidden bonus roll", 1, 1, 1)
	if HasRecoverableRoll() then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("A hidden bonus roll is available.", 1, 0.82, 0)
	end
	GameTooltip:Show()
end

function addon:UpdateMinimapButtonVisibility()
	local button = self.minimapButton
	if not button then return end
	if self:GetSetting("showMinimapButton") == false then button:Hide() else button:Show() end
end

function addon:RegisterMinimapButton()
	if self.minimapButton or not Minimap then return end
	local button = CreateFrame("Button", "RollCurtainMinimapButton", Minimap)
	button:SetSize(32, 32)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetMovable(true)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetClampedToScreen(true)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON_TEXTURE)
	icon:SetSize(28, 28)
	icon:SetPoint("CENTER")
	icon:SetTexCoord(0, 1, 0, 1)
	button.icon = icon

	-- Use the symmetric minimap highlight for both layers. The old tracking
	-- border artwork contains asymmetric padding, which made the recovery ring
	-- look shifted inside minimap-button collectors. Anchor directly to the icon
	-- texture so both circles stay centered on the visible die artwork.
	local ring = button:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RECOVERY_RING_TEXTURE)
	if type(ring.SetDesaturated) == "function" then ring:SetDesaturated(true) end
	ring:SetBlendMode("ADD")
	ring:SetSize(36, 36)
	ring:SetPoint("CENTER", icon, "CENTER", 0, 0)
	ring:SetVertexColor(1, 0.76, 0.08)
	ring:SetAlpha(0.96)
	ring:Hide()
	button.recoveryGlow = ring

	-- The larger copy provides the shiny gold aura. Keeping the inner ring within
	-- the 32px button makes the recovery state readable even if a collector clips
	-- some of the outer halo.
	local halo = button:CreateTexture(nil, "OVERLAY")
	halo:SetTexture(RECOVERY_HALO_TEXTURE)
	if type(halo.SetDesaturated) == "function" then halo:SetDesaturated(true) end
	halo:SetBlendMode("ADD")
	halo:SetSize(46, 46)
	halo:SetPoint("CENTER", icon, "CENTER", 0, 0)
	halo:SetVertexColor(1, 0.84, 0.16)
	halo:SetAlpha(0.52)
	halo:Hide()
	button.recoveryGlowHalo = halo
	button.recoveryPulseElapsed = 0

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "LeftButton" then addon:OpenSettings()
		elseif mouseButton == "RightButton" and type(addon.ShowHiddenBonusRoll) == "function" then addon:ShowHiddenBonusRoll() end
	end)
	button:SetScript("OnDragStart", function(self) self.dragging = true end)
	button:SetScript("OnDragStop", function(self) self.dragging = false; UpdateButtonFromCursor(self) end)
	button:SetScript("OnEnter", function(self) RefreshGlow(self); ShowTooltip(self) end)
	button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	button.refreshElapsed = 0
	button:SetScript("OnUpdate", function(self, elapsed)
		if self.dragging then UpdateButtonFromCursor(self) end
		UpdateGlowPulse(self, elapsed)
		self.refreshElapsed = self.refreshElapsed + elapsed
		if self.refreshElapsed >= REFRESH_INTERVAL then self.refreshElapsed = 0; RefreshGlow(self) end
	end)

	PositionButton(button, GetSavedAngle())
	self.minimapButton = button
	RefreshGlow(button)
	self:UpdateMinimapButtonVisibility()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() addon:RegisterMinimapButton() end)
