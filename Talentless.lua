
local Talentless = CreateFrame('Frame', 'Talentless', UIParent, 'UIDropDownMenuTemplate')
Talentless:SetScript('OnEvent', function(self, event, ...) self[event](self, event, ...) end)
Talentless:RegisterEvent('PLAYER_LOGIN')
Talentless:RegisterEvent('ADDON_LOADED')

local function TabClick(self, button, down)
	if(button == 'RightButton') then
		Talentless.group = self:GetID()
		ToggleDropDownMenu(1, nil, Talentless, self, 0, 0)
	end

	PlayerSpecTab_OnClick(self, button, down)
end

local function MenuClick(self, name)
	TalentlessDB[Talentless.group] = name
end

local function Initialize()
	local info = UIDropDownMenu_CreateInfo()
	for index = 1, GetNumEquipmentSets() do
		local name, icon = GetEquipmentSetInfo(index)
		info.text = string.format('|T%s:26|t %s', icon, name)
		info.func = MenuClick
		info.arg1 = name
		info.checked = TalentlessDB[Talentless.group] == name
		UIDropDownMenu_AddButton(info)
	end
end

function Talentless:ADDON_LOADED(event, addon)
	if(addon ~= 'Blizzard_TalentUI') then return end
	self:UnregisterEvent(event)

	PlayerSpecTab1:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	PlayerSpecTab1:SetScript('OnClick', TabClick)
	PlayerSpecTab2:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	PlayerSpecTab2:SetScript('OnClick', TabClick)

	self.displayMode = 'MENU'
	self.initialize = Initialize
end

function Talentless:PLAYER_LOGIN(event)
	TalentlessDB = TalentlessDB or {}

	self.currentGroup = GetActiveTalentGroup()
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
	self:UnregisterEvent(event)		
end

function Talentless:ACTIVE_TALENT_GROUP_CHANGED()
	if(self.currentGroup ~= GetActiveTalentGroup()) then
		self:RegisterEvent('UNIT_SPELLCAST_STOP')
	end
end

function Talentless:UNIT_SPELLCAST_STOP(event)
	local talentGroup = GetActiveTalentGroup()
	self:UnregisterEvent(event)
	self.currentGroup = talentGroup

	for index = 1, GetNumEquipmentSets(index) do
		local name = GetEquipmentSetInfo(index)
		if(TalentlessDB[talentGroup] == name) then
			return EquipmentManager_EquipSet(name)
		end
	end
end
