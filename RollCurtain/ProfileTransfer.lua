local addonName, addon = ...

local EXPORT_PREFIX = "RC1"
local EXPORT_POPUP_KEY = "ROLLCURTAIN_PROFILE_EXPORT"
local IMPORT_POPUP_KEY = "ROLLCURTAIN_PROFILE_IMPORT"
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_LOOKUP = {}
for index = 1, #BASE64_ALPHABET do
	BASE64_LOOKUP[BASE64_ALPHABET:sub(index, index)] = index - 1
end

local function Print(message)
	if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff7dd3fcRoll Curtain:|r " .. message)
	end
end

local function Base64Encode(input)
	local output = {}
	for index = 1, #input, 3 do
		local b1 = input:byte(index) or 0
		local b2 = input:byte(index + 1) or 0
		local b3 = input:byte(index + 2) or 0
		local count = math.min(3, #input - index + 1)
		local value = (b1 * 65536) + (b2 * 256) + b3
		local c1 = math.floor(value / 262144) % 64
		local c2 = math.floor(value / 4096) % 64
		local c3 = math.floor(value / 64) % 64
		local c4 = value % 64
		output[#output + 1] = BASE64_ALPHABET:sub(c1 + 1, c1 + 1)
		output[#output + 1] = BASE64_ALPHABET:sub(c2 + 1, c2 + 1)
		output[#output + 1] = count >= 2 and BASE64_ALPHABET:sub(c3 + 1, c3 + 1) or "="
		output[#output + 1] = count >= 3 and BASE64_ALPHABET:sub(c4 + 1, c4 + 1) or "="
	end
	return table.concat(output)
end

local function Base64Decode(input)
	input = (input or ""):gsub("%s+", "")
	if #input == 0 or #input % 4 ~= 0 then return nil end
	local output = {}
	for index = 1, #input, 4 do
		local a, b, c, d = input:sub(index, index), input:sub(index + 1, index + 1), input:sub(index + 2, index + 2), input:sub(index + 3, index + 3)
		local v1, v2 = BASE64_LOOKUP[a], BASE64_LOOKUP[b]
		local v3 = c == "=" and 0 or BASE64_LOOKUP[c]
		local v4 = d == "=" and 0 or BASE64_LOOKUP[d]
		if v1 == nil or v2 == nil or v3 == nil or v4 == nil then return nil end
		local value = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
		output[#output + 1] = string.char(math.floor(value / 65536) % 256)
		if c ~= "=" then output[#output + 1] = string.char(math.floor(value / 256) % 256) end
		if d ~= "=" then output[#output + 1] = string.char(value % 256) end
	end
	return table.concat(output)
end

local function Checksum(input)
	local sum = 0
	for index = 1, #input do
		sum = (sum + (input:byte(index) * index)) % 65535
	end
	return string.format("%04X", sum)
end

local function SortedSettingKeys()
	local keys = {}
	for key in pairs(addon.defaults or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	return keys
end

function addon:ExportCurrentProfileString()
	local profile = self:GetCurrentProfile()
	if type(profile) ~= "table" then return nil end
	local entries = {}
	for _, key in ipairs(SortedSettingKeys()) do
		local value = profile[key]
		if type(value) ~= "boolean" then value = self.defaults[key] == true end
		entries[#entries + 1] = key .. "=" .. (value and "1" or "0")
	end
	local payload = "1|" .. table.concat(entries, ",")
	return string.format("%s:%s:%s", EXPORT_PREFIX, Checksum(payload), Base64Encode(payload))
end

function addon:ImportProfileString(exportString)
	exportString = tostring(exportString or ""):gsub("%s+", "")
	local prefix, checksum, encoded = exportString:match("^([^:]+):([^:]+):(.+)$")
	if prefix ~= EXPORT_PREFIX or not checksum or not encoded then
		Print("That does not look like a Roll Curtain profile string.")
		return false
	end
	local payload = Base64Decode(encoded)
	if not payload or Checksum(payload) ~= checksum:upper() then
		Print("The profile string is invalid or incomplete.")
		return false
	end
	local version, settingsText = payload:match("^(%d+)|(.+)$")
	if version ~= "1" or not settingsText then
		Print("That profile string uses an unsupported format.")
		return false
	end

	local imported = {}
	for entry in settingsText:gmatch("[^,]+") do
		local key, value = entry:match("^([^=]+)=([01])$")
		if key and addon.defaults[key] ~= nil then imported[key] = value == "1" end
	end
	if next(imported) == nil then
		Print("The profile string did not contain any recognized settings.")
		return false
	end

	local profile = self:GetCurrentProfile()
	if type(profile) ~= "table" then return false end
	for key, value in pairs(imported) do profile[key] = value end
	self:RefreshProfileConsumers()
	Print("Imported settings into profile " .. self:GetCurrentProfileName() .. ".")
	return true
end

local function EnsureTransferPopups()
	if not StaticPopupDialogs then return end
	if not StaticPopupDialogs[EXPORT_POPUP_KEY] then
		StaticPopupDialogs[EXPORT_POPUP_KEY] = {
			text = "Copy this Roll Curtain profile string. You can paste it into Roll Curtain on another character or installation.",
			button1 = CLOSE or "Close",
			hasEditBox = true,
			maxLetters = 4096,
			OnShow = function(self, data)
				if self.EditBox then
					self.EditBox:SetText(data and data.exportString or "")
					self.EditBox:HighlightText()
					self.EditBox:SetFocus()
				end
			end,
			EditBoxOnEscapePressed = function(editBox) local parent = editBox:GetParent(); if parent then parent:Hide() end end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	if not StaticPopupDialogs[IMPORT_POPUP_KEY] then
		StaticPopupDialogs[IMPORT_POPUP_KEY] = {
			text = "Paste a Roll Curtain profile string. Importing replaces matching settings in the current profile: |cffffd100%s|r.",
			button1 = "Import",
			button2 = CANCEL or "Cancel",
			hasEditBox = true,
			maxLetters = 4096,
			OnShow = function(self)
				if self.EditBox then self.EditBox:SetText(""); self.EditBox:SetFocus() end
			end,
			OnAccept = function(self)
				if self.EditBox then addon:ImportProfileString(self.EditBox:GetText()) end
			end,
			EditBoxOnEnterPressed = function(editBox) local parent = editBox:GetParent(); if parent and parent.button1 then parent.button1:Click() end end,
			EditBoxOnEscapePressed = function(editBox) local parent = editBox:GetParent(); if parent then parent:Hide() end end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
end

function addon:ShowProfileExportDialog()
	EnsureTransferPopups()
	local exportString = self:ExportCurrentProfileString()
	if exportString and StaticPopup_Show then
		StaticPopup_Show(EXPORT_POPUP_KEY, nil, nil, { exportString = exportString })
	end
end

function addon:ShowProfileImportDialog()
	EnsureTransferPopups()
	if StaticPopup_Show then StaticPopup_Show(IMPORT_POPUP_KEY, self:GetCurrentProfileName()) end
end
