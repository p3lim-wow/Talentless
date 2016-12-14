-- http://www.wowinterface.com/forums/showthread.php?t=54889

function EquipmentManager_EquipSet(name)
	if(EquipmentSetContainsLockedItems(name) or UnitCastingInfo('player')) then
		UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1, 0.1, 0.1, 1)
		return
	end

	-- BUG: legion legendaries will halt the set equipping if the user is swapping
	-- different slotted legendaries beyond the 1/2 equipped limit
	local locations = GetEquipmentSetLocations(name)
	for inventoryID, location in next, locations do
		local itemLink = GetInventoryItemLink('player', inventoryID)
		if(itemLink and select(3, GetItemInfo(itemLink)) == 5) then
			-- legendary item found, manually replace it with the item from the new set
			local action = EquipmentManager_EquipItemByLocation(location, inventoryID)
			if(action) then
				EquipmentManager_RunAction(action)
				locations[inventoryID] = nil
			end
		end
	end

	-- Equip remaining items through _RunAction to avoid blocking from UseEquipmentSet
	for inventoryID, location in next, locations do
		local action = EquipmentManager_EquipItemByLocation(location, inventoryID)
		if(action) then
			EquipmentManager_RunAction(action)
		end
	end
end
