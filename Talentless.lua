local Talentless = CreateFrame('Frame', (...), UIParent, 'UIDropDownMenuTemplate')
Talentless:RegisterEvent('ADDON_LOADED')
Talentless:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
Talentless:SetScript('OnEvent', function(self, event, ...)
	self[event](self, event, ...)
end)

local talentItems = {
	{141640, 141446}, -- Tomes
	{141641, 141333}, -- Codexes
}

function Talentless:ADDON_LOADED(event, addon)
	if(addon ~= 'Blizzard_TalentUI') then
		return
	end

	TalentlessDB = TalentlessDB or {}

	self:SetParent(PlayerTalentFrameTalents)

	self.itemButtons = {}
	self.specButtons = {}

	self.relativePoint = 'TOPRIGHT'
	self.displayMode = 'MENU'
	self.initialize = self.InitializeMenu

	PlayerTalentFrame:HookScript('OnShow', self.OnShow)
	PlayerTalentFrameTalentsTutorialButton:Hide()
	PlayerTalentFrameTalentsTutorialButton.Show = function() end
	PlayerTalentFrameTalents.unspentText:ClearAllPoints()
	PlayerTalentFrameTalents.unspentText:SetPoint('TOP', 0, 24)

	local spec = GetSpecialization()
	for specIndex = 1, GetNumSpecializations() do
		local Button = self:CreateSpecButton(specIndex, select(4, GetSpecializationInfo(specIndex)))
		Button:SetChecked(specIndex == spec)

		if(specIndex == 1) then
			Button:SetPoint('TOPLEFT', PlayerTalentFrame, 60, -25)
		else
			Button:SetPoint('LEFT', self.specButtons[specIndex - 1], 'RIGHT', 6, 0)
		end

		local EquipmentIcon = Button.EquipmentIcon
		if(TalentlessDB[specIndex]) then
			EquipmentIcon:GetParent():Show()

			for equipmentIndex = 1, GetNumEquipmentSets() do
				local setName, icon = GetEquipmentSetInfo(equipmentIndex)
				if(setName == TalentlessDB[specIndex]) then
					EquipmentIcon:SetTexture(icon)
					break
				end
			end
		else
			EquipmentIcon:GetParent():Hide()
		end
	end

	local Tome = self:CreateItemButton(1, 134915)
	Tome:SetPoint('TOPRIGHT', PlayerTalentFrame, -10, -25)

	local Codex = self:CreateItemButton(2, 1495827)
	Codex:SetPoint('RIGHT', Tome, 'LEFT', -6, 0)

	local playerLevel = UnitLevel('player')
	Tome.highLevel = playerLevel > 109
	Codex.highLevel = playerLevel > 100

	if(playerLevel < 110 and not (IsTrialAccount() or IsVeteranTrialAccount())) then
		self:RegisterEvent('PLAYER_LEVEL_UP')
	end

	self:UnregisterEvent(event)
	self:RegisterUnitEvent('UNIT_AURA', 'player')
	self:RegisterEvent('BAG_UPDATE_DELAYED')

	self:UpdateItems()
end

function Talentless:PLAYER_SPECIALIZATION_CHANGED()
	local spec = GetSpecialization()
	local setName = TalentlessDB[spec]
	if(setName) then
		for index = 1, GetNumEquipmentSets() do
			local name = GetEquipmentSetInfo(index)
			if(name == setName) then
				C_Timer.After(1, function()
					EquipmentManager_EquipSet(name)
				end)

				break
			end
		end
	end

	if(self.specButtons) then
		for index, Button in next, self.specButtons do
			Button:SetChecked(index == spec)
		end
	end
end

function Talentless:PLAYER_LEVEL_UP(event, newLevel)
	local change
	if(level == 101) then
		Codex.highLevel = true
		change = true
	elseif(level == 110) then
		Tome.highLevel = true
		change = true

		self:UnregisterEvent(event)
	end

	if(change) then
		-- update buttons
		if(InCombatLockdown()) then
			self:RegisterEvent('PLAYER_REGEN_ENABLED')
		else
			self:PLAYER_REGEN_ENABLED()
		end
	end
end

function Talentless:GetTalentItemID(slotID)
	local itemID
	if(self.itemButtons[slotID].highLevel) then
		itemID = talentItems[slotID][2]
	else
		for _, talentItemID in next, talentItems[slotID] do
			if(GetItemCount(itemID) > 0) then
				itemID = talentItemID
				break
			end
		end

		if(not itemID) then
			itemID = talentItems[slotID][1]
		end
	end

	return itemID
end

function Talentless:UpdateItems(event)
	for slotID, Button in next, self.itemButtons do
		local itemID = self:GetTalentItemID(slotID)
		if(Button.itemID ~= itemID) then
			Button.itemID = itemID

			local itemName = GetItemInfo(itemID)
			if(not itemName) then
				Button.itemName = nil
				Button:RegisterEvent('GET_ITEM_INFO_RECEIVED')
			else
				Button.itemName = itemName
			end

			if(InCombatLockdown()) then
				Button:RegisterEvent('PLAYER_REGEN_ENABLED')
			else
				Button:SetAttribute('item', 'item:' .. itemID)
			end

			Button.Count:SetText(GetItemCount(itemID))
		end
	end

	if(event) then
		self:UNIT_AURA()
	end
end

function Talentless:BAG_UPDATE_DELAYED(event)
	if(self:IsShown()) then
		self:UpdateItems(event)
	end
end

function Talentless:UNIT_AURA()
	if(not self:IsShown()) then
		return
	end

	for _, Button in next, self.itemButtons do
		local itemName = Button.itemName
		if(itemName) then
			local exists, _, _, _, _, _, expiration = UnitAura('player', itemName)
			if(exists) then
				if(expiration > 0) then
					local time = GetTime()
					Button.Cooldown:SetCooldown(time, expiration - time)
				end

				ActionButton_ShowOverlayGlow(Button)
			else
				ActionButton_HideOverlayGlow(Button)
				Button.Cooldown:SetCooldown(0, 0)
			end
		end
	end
end

function Talentless:OnShow()
	-- Update all the things
	Talentless:UpdateItems()
end

local lastClickedSpec
local function OnMenuClick(self, name)
	TalentlessDB[lastClickedSpec] = name

	local EquipmentIcon = Talentless.specButtons[lastClickedSpec].EquipmentIcon
	if(name) then
		EquipmentIcon:GetParent():Show()

		for index = 1, GetNumEquipmentSets() do
			local setName, icon = GetEquipmentSetInfo(index)
			if(setName == name) then
				EquipmentIcon:SetTexture(icon)
				break
			end
		end
	else
		EquipmentIcon:GetParent():Hide()
	end
end

local UNKNOWN_ICON = [[Interface\Icons\INV_MISC_QUESTIONMARK]]
function Talentless:InitializeMenu()
	local info = UIDropDownMenu_CreateInfo()
	for index = 1, GetNumEquipmentSets() do
		local name, icon = GetEquipmentSetInfo(index)
		info.text = string.format('|T%s:18|t %s', icon or UNKNOWN_ICON, name)
		info.func = OnMenuClick
		info.arg1 = name
		info.checked = TalentlessDB[lastClickedSpec] == name
		UIDropDownMenu_AddButton(info)
	end

	info.text = KEY_NUMLOCK_MAC
	info.arg1 = nil
	info.checked = false
	UIDropDownMenu_AddButton(info)
end

local function OnSpecClick(self, button)
	local specIndex = self:GetID()
	local differentSpec = GetSpecialization() ~= specIndex
	self:SetChecked(not differentSpec)

	if(button == 'RightButton') then
		lastClickedSpec = specIndex
		CloseDropDownMenus()
		ToggleDropDownMenu(1, nil, Talentless, self, -self:GetWidth(), -self:GetHeight())
	elseif(not InCombatLockdown() and differentSpec) then
		SetSpecialization(specIndex)
	end
end

local function OnSpecEnter(self)
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:AddLine(select(2, GetSpecializationInfo(self:GetID())))
	GameTooltip:Show()
end

function Talentless:CreateSpecButton(index, texture)
	local Button = CreateFrame('CheckButton', '$parentSpecButton' .. index, self)
	Button:SetSize(34, 34)
	Button:SetScript('OnClick', OnSpecClick)
	Button:SetScript('OnEnter', OnSpecEnter)
	Button:SetScript('OnLeave', GameTooltip_Hide)
	Button:SetID(index)
	Button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

	local Icon = Button:CreateTexture('$parentIcon', 'BACKGROUND')
	Icon:SetAllPoints()
	Icon:SetTexture(texture)
	Icon:SetTexCoord(4/64, 60/64, 4/64, 60/64)

	local Border = Button:CreateTexture('$parentNormalTexture')
	Border:SetPoint('CENTER')
	Border:SetSize(60, 60)
	Border:SetTexture([[Interface\Buttons\UI-Quickslot2]])

	Button:SetNormalTexture(Border)
	Button:SetPushedTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	Button:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	Button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])

	local Equipment = CreateFrame('CheckButton', '$parentEquipmentButton', Button)
	Equipment:SetPoint('BOTTOM', 0, -10)
	Equipment:SetSize(18, 18)
	Equipment:EnableMouse(false)
	Equipment:Hide()

	local EquipmentIcon = Equipment:CreateTexture('$parentIcon')
	EquipmentIcon:SetAllPoints()
	EquipmentIcon:SetTexCoord(4/64, 60/64, 4/64, 60/64)
	Button.EquipmentIcon = EquipmentIcon

	local EquipmentBorder = Equipment:CreateTexture('$parentNormalTexture')
	EquipmentBorder:SetPoint('CENTER')
	EquipmentBorder:SetSize(31.76, 31.76)
	EquipmentBorder:SetTexture([[Interface\Buttons\UI-Quickslot2]])

	Equipment:SetNormalTexture(EquipmentBorder)

	self.specButtons[index] = Button
	return Button
end

local function OnItemEvent(self, event)
	if(event == 'PLAYER_REGEN_ENABLED') then
		self:SetAttribute('item', 'item:' .. self.itemID)
		self:UnregisterEvent(event)
	else
		local itemName = GetItemInfo(self.itemID)
		if(itemName) then
			self.itemName = itemName
			self:UnregisterEvent(event)
			Talentless:UNIT_AURA()
		end
	end
end

local function OnItemEnter(self)
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetItemByID(self.itemID)
	GameTooltip:Show()
end

function Talentless:CreateItemButton(slotID, texture)
	local Button = CreateFrame('Button', '$parentItemButton' .. #self.itemButtons + 1, self, 'SecureActionButtonTemplate, ActionBarButtonSpellActivationAlert')
	Button:SetSize(34, 34)
	Button:SetAttribute('type', 'item')
	Button:SetScript('OnEvent', OnItemEvent)
	Button:SetScript('OnEnter', OnItemEnter)
	Button:SetScript('OnLeave', GameTooltip_Hide)

	local Icon = Button:CreateTexture('$parentIcon', 'BACKGROUND')
	Icon:SetAllPoints()
	Icon:SetTexture(texture)
	Icon:SetTexCoord(4/64, 60/64, 4/64, 60/64)

	local Normal = Button:CreateTexture('$parentNormalTexture')
	Normal:SetPoint('CENTER')
	Normal:SetSize(60, 60)
	Normal:SetTexture([[Interface\Buttons\UI-Quickslot2]])

	Button:SetNormalTexture(Normal)
	Button:SetPushedTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	Button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])

	local Count = Button:CreateFontString('$parentCount', 'OVERLAY')
	Count:SetPoint('BOTTOMLEFT', 1, 1)
	Count:SetFont('Fonts\\FRIZQT__.ttf', 12, 'OUTLINE')
	Button.Count = Count

	local Cooldown = CreateFrame('Cooldown', '$parentCooldown', Button, 'CooldownFrameTemplate')
	Cooldown:SetAllPoints()
	Button.Cooldown = Cooldown

	self.itemButtons[slotID] = Button
	return Button
end

-- Binding UI global names
local TOGGLE = string.gsub(BINDING_NAME_TOGGLEABILITYBOOK, ABILITIES, '')
BINDING_HEADER_TALENTLESS = ...
BINDING_NAME_TALENTLESS_SPECIALIZATION = TOGGLE .. SPECIALIZATION
BINDING_NAME_TALENTLESS_TALENTS = TOGGLE .. TALENTS
BINDING_NAME_TALENTLESS_PVPTALENTS = TOGGLE .. PVP_TALENTS
