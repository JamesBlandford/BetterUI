BUI.Inventory.CraftList = BUI.Inventory.List:Subclass()

local function GetFilterComparator(filterType)
    return function(itemData)
        if filterType then
			-- we can pass a table of filters into the function, and this case has to be handled separately
			if type(filterType) == "table" then
				local filterHit = false
				
				for key, filter in pairs(filterType) do
					if ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filter) then
						filterHit = true
					end
				end
				
				return filterHit
			else
				return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType)	
			end
        else
			-- for "All"
            return true
        end

        return ZO_InventoryUtils_DoesNewItemMatchSupplies(itemData)
    end
end


function BUI.Inventory.CraftList:AddSlotDataToTable(slotsTable, slotIndex)
    local itemFilterFunction = GetFilterComparator(self.filterType)
    local categorizationFunction = self.categorizationFunction or GetBestItemCategoryDescription

    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(self.inventoryType, slotIndex)
    if slotData then
        if itemFilterFunction(slotData) then
            -- itemData is shared in several places and can write their own value of bestItemCategoryName.
            -- We'll use bestGamepadItemCategoryName instead so there are no conflicts.
            slotData.bestGamepadItemCategoryName = categorizationFunction(slotData)
			slotData.bestItemCategoryName = categorizationFunction(slotData)
			
			if self.inventoryType ~= BAG_VIRTUAL then -- virtual items don't have any champion points associated with them
				slotData.requiredChampionPoints = GetItemLinkRequiredChampionPoints(slotData)
			end
			
            table.insert(slotsTable, slotData)
        end
    end
end

function BUI.Inventory.CraftList:RefreshList(filterType) 
	self.list:Clear()

	self.filterType = filterType

	filteredDataTable = self:GenerateSlotTable()
	
	table.sort(filteredDataTable, ZO_GamepadInventory_DefaultItemSortComparator)

    local lastBestItemCategoryName
    for i, itemData in ipairs(filteredDataTable) do
        local nextItemData = filteredDataTable[i + 1]

        local data = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        data:InitializeInventoryVisualData(itemData)

		data.bestItemCategoryName = itemData.bestItemCategoryName
		data.bestGamepadItemCategoryName = itemData.bestItemCategoryName

        if itemData.bestItemCategoryName ~= lastBestItemCategoryName then
            data:SetHeader(itemData.bestItemCategoryName)
        end

        self.list:AddEntry("BUI_GamepadItemSubEntryTemplate", data)
		
        lastBestItemCategoryName = itemData.bestItemCategoryName
    end
	
    self.list:Commit()
end