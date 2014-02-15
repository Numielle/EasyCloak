local f = CreateFrame("frame")
f:RegisterEvent("ZONE_CHANGED_INDOORS")

local CLOAK_NAME = "Onyxia Scale Cloak"

local function findCloak() 
	for bag = 0,4 do		
		for slot = 1,GetContainerNumSlots(bag) do			
			local itemLink = GetContainerItemLink(bag, slot)			
			
			if itemLink and string.find(itemLink, CLOAK_NAME) then
				return bag, slot
			end				
		end
	end
end

local function onEvent()
	if event == "ZONE_CHANGED_INDOORS" then		
		local subzone = GetSubZoneText()
				
		if subzone and string.find(subzone, "Nefarian.*Lair") then
			-- check if cloak already equipped and return
			local current = GetInventoryItemLink("player", GetInventorySlotInfo("BackSlot"))
			if current and string.find(current, CLOAK_NAME) then return end
		
			bag, slot = findCloak()
			
			if not (bag and slot) then
				DEFAULT_CHAT_FRAME:AddMessage("Please acquire an "..CLOAK_NAME.."! Couldn't find one in your bags!", 1, 0, 0)
			elseif UnitAffectingCombat("player") then
				DEFAULT_CHAT_FRAME:AddMessage("Please equip "..CLOAK_NAME.." when you get out of combat!", 1, 0, 0)
			else
				-- put previously selected item back
				if CursorHasItem() then ClearCursor() end 
				
				-- pickup and equip ony scale cloak
				PickupContainerItem(bag,slot)
				AutoEquipCursorItem()							
			end
		end		
	end	
 end
 
f:SetScript("OnEvent", onEvent)

