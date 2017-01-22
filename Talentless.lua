local Talentless = CreateFrame('Frame', (...), UIParent, 'Talentless_UIDropDownMenuTemplate')
Talentless:RegisterEvent('ADDON_LOADED')
Talentless:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
Talentless:SetScript('OnEvent', function(self, event, ...)
	self[event](self, ...)
end)

local PTR = select(4, GetBuildInfo()) == 70200

function Talentless:ADDON_LOADED(addon)
	if(addon == 'Blizzard_TalentUI') then
		self:SetParent(PlayerTalentFrameTalents)

		PlayerTalentFrame:HookScript('OnShow', self.OnShow)
		PlayerTalentFrame:HookScript('OnHide', self.OnHide)

		PlayerTalentFrameTalentsTutorialButton:Hide()
		PlayerTalentFrameTalentsTutorialButton.Show = function() end
		PlayerTalentFrameTalents.unspentText:ClearAllPoints()
		PlayerTalentFrameTalents.unspentText:SetPoint('TOP', 0, 24)

		self:CreateItemButtons()
		self:CreateSpecButtons()
		self:CreateDropdown()

		if(UnitLevel('player') < 110 and not (IsTrialAccount() or IsVeteranTrialAccount())) then
			self:RegisterEvent('PLAYER_LEVEL_UP')
		end

		self:UnregisterEvent('ADDON_LOADED')
		self:OnShow()
	elseif(addon == self:GetName()) then
		if(not PTR) then
			TalentlessDB = TalentlessDB or {}
		end
	end
end

function Talentless:PLAYER_LEVEL_UP(level)
	if(level == 101) then
		self.Items[1].items[1] = nil
	elseif(level == 110) then
		self.Items[2].items[1] = nil
		self:UnregisterEvent('PLAYER_LEVEL_UP')
	end

	if(self:IsShown()) then
		self:UpdateItems()
	end
end

function Talentless:UNIT_AURA()
	if(self:IsShown()) then
		for _, Button in next, self.Items do
			local itemName = Button.itemName
			if(itemName) then
				local exists, _, _, _, _, duration, expiration = UnitAura('player', itemName)
				if(exists) then
					if(expiration > 0) then
						Button.Cooldown:SetCooldown(expiration - duration, duration)
					end

					ActionButton_ShowOverlayGlow(Button)
				else
					ActionButton_HideOverlayGlow(Button)
					Button.Cooldown:SetCooldown(0, 0)
				end
			end
		end
	end
end

function Talentless:BAG_UPDATE_DELAYED()
	self:UpdateItems()
end

local lastSpec -- DEPRECATED
function Talentless:PLAYER_SPECIALIZATION_CHANGED()
	if(not PTR) then -- DEPRECATED
		local spec = GetSpecialization()
		if(lastSpec and lastSpec ~= spec) then
			local setName = TalentlessDB[spec]
			if(setName) then
				for index = 1, GetNumEquipmentSets() do
					local name = GetEquipmentSetInfo(index)
					if(name == setName) then
						EquipmentManager_EquipSet(name)
						break
					end
				end
			end
		end

		lastSpec = spec
	end

	if(self.Specs) then
		local spec = GetSpecialization()
		for index, Button in next, self.Specs do
			Button:SetChecked(index == spec)
		end
	end
end

function Talentless:EQUIPMENT_SETS_CHANGED()
	if(PTR) then
		-- wish we had API for spec > setID as well, not just setID > spec
		for _, Button in next, self.Specs do
			Button.Set:Hide()
		end

		for _, setID in next, C_EquipmentSet.GetEquipmentSetIDs() do
			local Button = self.Specs[C_EquipmentSet.GetEquipmentSetAssignedSpec(setID)]
			Button.SetIcon:SetTexture(select(2, C_EquipmentSet.GetEquipmentSetInfo(setID)) or QUESTION_MARK_ICON)
			Button.Set:Show()
		end
	else
		-- DEPRECATED
		for index, Button in next, self.Specs do
			local setExists

			local savedName = TalentlessDB[index]
			if(savedName) then
				for index = 1, GetNumEquipmentSets() do
					local name, icon = GetEquipmentSetInfo(index)
					if(name == savedName) then
						setExists = true
						Button.SetIcon:SetTexture(icon or [[Interface\Icons\INV_MISC_QUESTIONMARK]])
						break
					end
				end
			end

			Button.Set:SetShown(setExists)
		end
	end
end

function Talentless.OnShow()
	Talentless:RegisterUnitEvent('UNIT_AURA', 'player')
	Talentless:RegisterEvent('BAG_UPDATE_DELAYED')
	Talentless:RegisterEvent('EQUIPMENT_SETS_CHANGED')
	Talentless:EQUIPMENT_SETS_CHANGED()
	Talentless:UpdateItems()
end

function Talentless.OnHide()
	Talentless:UnregisterEvent('UNIT_AURA')
	Talentless:UnregisterEvent('BAG_UPDATE_DELAYED')
	Talentless:UnregisterEvent('EQUIPMENT_SETS_CHANGED')
end

function Talentless:CreateSpecButtons()
	self.Specs = {}

	local OnClick = function(self, button)
		local index = self:GetID()
		self:SetChecked(GetSpecialization() == index)

		if(button == 'RightButton') then
			Talentless_CloseDropDownMenus()
			Talentless_ToggleDropDownMenu(1, index, Talentless, self, -self:GetWidth(), -self:GetHeight())
		else
			Talentless:SetSpecialization(index)
		end
	end

	local OnEnter = function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:AddLine(select(2, GetSpecializationInfo(self:GetID())))
		GameTooltip:Show()
	end

	for index = 1, GetNumSpecializations() do
		local Button = CreateFrame('CheckButton', '$parentSpecButton' .. index, Talentless)
		Button:SetSize(34, 34)
		Button:SetScript('OnClick', OnClick)
		Button:SetScript('OnEnter', OnEnter)
		Button:SetScript('OnLeave', GameTooltip_Hide)
		Button:SetChecked(GetSpecialization() == index)
		Button:SetID(index)
		Button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

		if(index == 1) then
			Button:SetPoint('TOPLEFT', PlayerTalentFrame, 60, -25)
		else
			Button:SetPoint('LEFT', self.Specs[index - 1], 'RIGHT', 6, 0)
		end

		local Icon = Button:CreateTexture('$parentIcon', 'BACKGROUND')
		Icon:SetAllPoints()
		Icon:SetTexture(select(4, GetSpecializationInfo(index)))
		Icon:SetTexCoord(4/64, 60/64, 4/64, 60/64)

		local Border = Button:CreateTexture('$parentNormalTexture')
		Border:SetPoint('CENTER')
		Border:SetSize(60, 60)
		Border:SetTexture([[Interface\Buttons\UI-Quickslot2]])

		Button:SetNormalTexture(Border)
		Button:SetPushedTexture([[Interface\Buttons\UI-Quickslot-Depress]])
		Button:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
		Button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])

		local Set = CreateFrame('CheckButton', '$parentSetButton', Button)
		Set:SetPoint('BOTTOM', 0, -10)
		Set:SetSize(18, 18)
		Set:EnableMouse(false)
		Set:Hide()
		Button.Set = Set

		local SetIcon = Set:CreateTexture('$parentIcon')
		SetIcon:SetAllPoints()
		SetIcon:SetTexCoord(4/64, 60/64, 4/64, 60/64)
		Button.SetIcon = SetIcon

		local SetBorder = Set:CreateTexture('$parentNormalTexture')
		SetBorder:SetPoint('CENTER')
		SetBorder:SetSize(31.76, 31.76)
		SetBorder:SetTexture([[Interface\Buttons\UI-Quickslot2]])
		Set:SetNormalTexture(SetBorder)

		table.insert(self.Specs, Button)
	end
end

function Talentless:CreateItemButtons()
	self.Items = {}

	local OnEnter = function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end

	local OnEvent = function(self, event)
		if(event == 'PLAYER_REGEN_ENABLED') then
			self:UnregisterEvent(event)
			self:SetAttribute('item', 'item:' .. self.itemID)
		else
			local itemName = GetItemInfo(self.itemID)
			if(itemName) then
				self.itemName = itemName
				self:UnregisterEvent(event)

				Talentless:UNIT_AURA()
			end
		end
	end

	local items = {
		{
			141641, -- Codex of the Clear Mind
			141333, -- Codex of the Tranquil Mind
		}, {
			141640, -- Tome of the Clear Mind
			143785, -- Tome of the Tranquil Mind (BoP version)
			141446, -- Tome of the Tranquil Mind
		}
	}

	local playerLevel = UnitLevel('player')
	if(playerLevel > 100) then
		table.remove(items[1], 1)

		if(playerLevel > 109) then
			table.remove(items[2], 1)
		end
	end

	for index, items in next, items do
		local Button = CreateFrame('Button', '$parentItemButton' .. index, self, 'SecureActionButtonTemplate, ActionBarButtonSpellActivationAlert')
		Button:SetPoint('TOPRIGHT', PlayerTalentFrame, -10 - (40 * (index - 1)), -25)
		Button:SetSize(34, 34)
		Button:SetAttribute('type', 'item')
		Button:SetScript('OnEnter', OnEnter)
		Button:SetScript('OnEvent', OnEvent)
		Button:SetScript('OnLeave', GameTooltip_Hide)
		Button.items = items

		local Icon = Button:CreateTexture('$parentIcon', 'BACKGROUND')
		Icon:SetAllPoints()
		Icon:SetTexture(index == 1 and 1495827 or 134915)
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
		Count:SetFont([[Fonts\FRIZQT__.ttf]], 12, 'OUTLINE')
		Button.Count = Count

		local Cooldown = CreateFrame('Cooldown', '$parentCooldown', Button, 'CooldownFrameTemplate')
		Cooldown:SetAllPoints()
		Button.Cooldown = Cooldown

		table.insert(self.Items, Button)
	end
end

function Talentless:CreateDropdown()
	local OnClick = function(self, nameOrSetID, spec) -- DEPRECATED
		if(PTR) then
			C_EquipmentSet.AssignSpecToEquipmentSet(nameOrSetID, spec)
		else
			TalentlessDB[spec] = nameOrSetID
		end

		Talentless:EQUIPMENT_SETS_CHANGED()
	end

	self.relativePoint = 'TOPRIGHT'
	self.displayMode = 'MENU'

	self.initialize = function()
		local info = Talentless_UIDropDownMenu_CreateInfo()

		if(PTR) then
			for _, setID in next, C_EquipmentSet.GetEquipmentSetIDs() do
				local name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
				info.text = string.format('|T%s:18|t %s', icon or QUESTION_MARK_ICON, name)
				info.func = OnClick
				info.arg1 = setID
				info.arg2 = Talentless_UIDROPDOWNMENU_MENU_VALUE
				info.checked = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID) == info.arg2
				Talentless_UIDropDownMenu_AddButton(info)
			end
		else -- DEPRECATED
			for index = 1, GetNumEquipmentSets() do
				local name, icon = GetEquipmentSetInfo(index)
				info.text = string.format('|T%s:18|t %s', icon or [[Interface\Icons\INV_MISC_QUESTIONMARK]], name)
				info.func = OnClick
				info.arg1 = name
				info.arg2 = Talentless_UIDROPDOWNMENU_MENU_VALUE
				info.checked = TalentlessDB[info.arg2] == name
				Talentless_UIDropDownMenu_AddButton(info)
			end
		end

		info.text = KEY_NUMLOCK_MAC -- "Clear"
		info.arg1 = nil
		info.checked = false
		Talentless_UIDropDownMenu_AddButton(info)
	end
end

function Talentless:GetAvailableItemInfo(index)
	for _, itemID in next, self.Items[index].items do
		local itemCount = GetItemCount(itemID)
		if(itemCount > 0) then
			return itemID, itemCount
		end
	end

	return self.Items[index].items[1], 0
end

function Talentless:UpdateItems()
	for index, Button in next, self.Items do
		local itemID, itemCount = self:GetAvailableItemInfo(index)
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
		end

		Button.Count:SetText(itemCount)
	end

	self:UNIT_AURA()
end

function Talentless:SetSpecialization(index)
	if(GetNumSpecializations() >= index) then
		if(InCombatLockdown()) then
			UIErrorsFrame:TryDisplayMessage(50, ERR_AFFECTING_COMBAT, 1, 0.1, 0.1)
		elseif(GetSpecialization() ~= index) then
			SetSpecialization(index)
		end
	end
end

-- Binding UI global names
local TOGGLE = string.gsub(BINDING_NAME_TOGGLEABILITYBOOK, ABILITIES, '')
BINDING_HEADER_TALENTLESS = (...)
BINDING_NAME_TALENTLESS_SPECIALIZATION = TOGGLE .. SPECIALIZATION
BINDING_NAME_TALENTLESS_TALENTS = TOGGLE .. TALENTS
BINDING_NAME_TALENTLESS_PVPTALENTS = TOGGLE .. PVP_TALENTS

local specText = string.format('%s %s ', TALENT_SPEC_ACTIVATE, string.lower(SPECIALIZATION))
BINDING_HEADER_TALENTLESS_BLANK = ''
BINDING_NAME_TALENTLESS_SWAP_1 = specText .. 1
BINDING_NAME_TALENTLESS_SWAP_2 = specText .. 2
BINDING_NAME_TALENTLESS_SWAP_3 = specText .. 3
BINDING_NAME_TALENTLESS_SWAP_4 = specText .. 4
