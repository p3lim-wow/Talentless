local Talentless = CreateFrame('Frame', (...), UIParent, 'UIDropDownMenuTemplate')
Talentless:RegisterEvent('ADDON_LOADED')
Talentless:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
Talentless:SetScript('OnEvent', function(self, event, ...)
	self[event](self, event, ...)
end)

local inferiorItemLevels = {
	[141446] = 109,
	[141333] = 100,
}

local inferiorItemIDs = {
	[141446] = 141640, -- Tome
	[141333] = 141641, -- Codex
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
		local Button = self:CreateButton(specIndex, select(4, GetSpecializationInfo(specIndex)))
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

	local Tome = self:CreateItem(141446, 134915)
	Tome:SetPoint('TOPRIGHT', PlayerTalentFrame, -10, -25)

	local Codex = self:CreateItem(141333, 1495827)
	Codex:SetPoint('RIGHT', Tome, 'LEFT', -6, 0)

	self:UnregisterEvent(event)
	self:RegisterEvent('BAG_UPDATE_DELAYED')
	self:RegisterUnitEvent('UNIT_AURA', 'player')
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

function Talentless:BAG_UPDATE_DELAYED(event)
	if(not self:IsShown()) then
		return
	end

	local inferiorItem
	for itemID, Button in next, self.itemButtons do
		local count = GetItemCount(itemID)
		if(count == 0 and UnitLevel('player') <= inferiorItemLevels[itemID]) then
			itemID = inferiorItemIDs[itemID]
			count = GetItemCount(itemID)
		end

		if(count > 0 and itemID ~= Button:GetID()) then
			inferiorItem = true
		end

		Button.Count:SetText(count)
	end

	if(not event) then
		self:UpdateItems(nil, nil, inferiorItem)
	end
end

function Talentless:UNIT_AURA()
	if(not self:IsShown()) then
		return
	end

	for _, Button in next, self.itemButtons do
		local exists, _, _, _, _, _, expiration = UnitAura('player', Button.buffName)
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

function Talentless:UpdateItems(event, _, inferiorUpdate)
	for itemID, Button in next, self.itemButtons do
		if(inferiorUpdate) then
			itemID = inferiorItemIDs[itemID]
		end

		if(not Button:GetID() or itemID ~= Button:GetID()) then
			local name = GetItemInfo(itemID)
			if(not name) then
				return self:RegisterEvent('GET_ITEM_INFO_RECEIVED')
			else
				Button.buffName = name
				Button:SetID(itemID)
				Button:SetAttribute('item', 'item:' .. itemID)
			end
		end
	end

	if(event) then
		self:UnregisterEvent(event)
	end

	self:UNIT_AURA()
end
Talentless.GET_ITEM_INFO_RECEIVED = Talentless.UpdateItems

function Talentless:OnShow()
	-- Update all the things
	Talentless:BAG_UPDATE_DELAYED()
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

function Talentless:CreateButton(index, texture)
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

local function OnItemEnter(self)
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetItemByID(self:GetID())
	GameTooltip:Show()
end

function Talentless:CreateItem(itemID, texture)
	local Button = CreateFrame('Button', '$parentItemButton' .. #self.itemButtons + 1, self, 'SecureActionButtonTemplate, ActionBarButtonSpellActivationAlert')
	Button:SetSize(34, 34)
	Button:SetAttribute('type', 'item')
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

	self.itemButtons[itemID] = Button
	return Button
end

-- Binding UI global names
local TOGGLE = string.gsub(BINDING_NAME_TOGGLEABILITYBOOK, ABILITIES, '')
BINDING_HEADER_TALENTLESS = ...
BINDING_NAME_TALENTLESS_SPECIALIZATION = TOGGLE .. SPECIALIZATION
BINDING_NAME_TALENTLESS_TALENTS = TOGGLE .. TALENTS
BINDING_NAME_TALENTLESS_PVPTALENTS = TOGGLE .. PVP_TALENTS
