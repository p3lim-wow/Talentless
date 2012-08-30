local Talentless = CreateFrame('Frame', 'Talentless', UIParent, 'UIDropDownMenuTemplate')
Talentless:SetScript('OnEvent', function(self, event, ...) self[event](self, event, ...) end)
Talentless:RegisterEvent('ADDON_LOADED')

local function OnClick(self, button)
	if(button == 'RightButton') then
		CloseDropDownMenus()
		ToggleDropDownMenu(1, nil, Talentless, self, 0, 0)
	end
end

local function SelectClick(self, name)
	TalentlessDB[PlayerTalentFrame.talentGroup] = name
end

local function Initialize()
	local info = UIDropDownMenu_CreateInfo()
	for index = 1, GetNumEquipmentSets() do
		local name, icon = GetEquipmentSetInfo(index)
		info.text = string.format('|T%s:18|t %s', icon, name)
		info.func = SelectClick
		info.arg1 = name
		info.checked = TalentlessDB[PlayerTalentFrame.talentGroup] == name
		UIDropDownMenu_AddButton(info)
	end
end

function Talentless:ADDON_LOADED(event, name)
	if(name == 'Blizzard_TalentUI') then
		TalentlessDB = TalentlessDB or {}

		self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
		self:UnregisterEvent(event)

		PlayerSpecTab1:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		PlayerSpecTab2:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		hooksecurefunc('PlayerSpecTab_OnClick', OnClick)

		self.relativePoint = 'TOPRIGHT'
		self.displayMode = 'MENU'
		self.initialize = Initialize
	end
end

function Talentless:ACTIVE_TALENT_GROUP_CHANGED()
	self:RegisterEvent('UNIT_SPELLCAST_STOP')
end

function Talentless:UNIT_SPELLCAST_STOP(event)
	self:UnregisterEvent(event)

	local group = GetActiveSpecGroup()

	for index = 1, GetNumEquipmentSets() do
		local name = GetEquipmentSetInfo(index)
		if(TalentlessDB[group] == name) then
			return EquipmentManager_EquipSet(name)
		end
	end
end
