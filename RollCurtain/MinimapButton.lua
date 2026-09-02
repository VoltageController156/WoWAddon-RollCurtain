local addonName, addon = ...

local DEFAULT_ANGLE = 225
local MINIMAP_RADIUS = 80
local REFRESH_INTERVAL = 0.5
local ICON_TEXTURE = "Interface\\AddOns\\RollCurtain\\Media\\MinimapIcon"

local function GetSavedAngle()
	if type(RollCurtainDB) == "table" and type(RollCurtainDB.minimapButtonAngle) == "number" then
		return RollCurtainDB.minimapButtonAngle
	end

	return DEFAULT_ANGLE
end

local function SaveAngle(angle)
	if type(RollCurtainDB) ~= "table" then
		RollCurtainDB = {}
	end

	RollCurtainDB.minimapButtonAngle = angle
end

local function Atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end

	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 and y < 0 then
		return math.atan(y / x) - math.pi
	elseif x == 0 and y > 0 then
		return math.pi / 2
	elseif x == 0 and y < 0 then
		return -math.pi / 2
	end

	return 0
end

local function PositionButton(button, angle)
	local radians = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint(
		"CENTER",
		Minimap,
		"CENTER",
		math.cos(radians) * MINIMAP_RADIUS,
		math.sin(radians) * MINIMAP_RADIUS
	)
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
	return type(addon.CanRestoreHiddenBonusRoll) == "function"
		and addon:CanRestoreHiddenBonusRoll() == true
end

local function RefreshGlow(button)
	button.recoveryGlow:SetShown(HasRecoverableRoll())
end

local function ShowTooltip(button)
	if not GameTooltip then
		return
	end

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

function addon:RegisterMinimapButton()
	if self.minimapButton or not Minimap then
		return
	end

	local button = CreateFrame("Button", "RollCurtainMinimapButton", Minimap)
	button:SetSize(32, 32)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetMovable(true)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetClampedToScreen(true)

	-- The minimap artwork is pre-cropped and carries its own circular frame.
	-- Keeping the button free of Blizzard's oversized tracking border makes it
	-- render cleanly both on the minimap and inside minimap-button collectors.
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON_TEXTURE)
	icon:SetSize(28, 28)
	icon:SetPoint("CENTER")
	icon:SetTexCoord(0, 1, 0, 1)
	button.icon = icon

	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetSize(38, 38)
	glow:SetPoint("CENTER")
	glow:SetVertexColor(1, 0.82, 0)
	glow:Hide()
	button.recoveryGlow = glow

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			addon:OpenSettings()
		elseif mouseButton == "RightButton" and type(addon.ShowHiddenBonusRoll) == "function" then
			addon:ShowHiddenBonusRoll()
		end
	end)

	button:SetScript("OnDragStart", function(self)
		self.dragging = true
	end)

	button:SetScript("OnDragStop", function(self)
		self.dragging = false
		UpdateButtonFromCursor(self)
	end)

	button:SetScript("OnEnter", function(self)
		RefreshGlow(self)
		ShowTooltip(self)
	end)

	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	button.refreshElapsed = 0
	button:SetScript("OnUpdate", function(self, elapsed)
		if self.dragging then
			UpdateButtonFromCursor(self)
		end

		self.refreshElapsed = self.refreshElapsed + elapsed
		if self.refreshElapsed >= REFRESH_INTERVAL then
			self.refreshElapsed = 0
			RefreshGlow(self)
		end
	end)

	PositionButton(button, GetSavedAngle())
	RefreshGlow(button)
	self.minimapButton = button
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	addon:RegisterMinimapButton()
end)
