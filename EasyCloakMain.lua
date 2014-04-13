local f = CreateFrame("frame")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local ONY_CLOAK_NAME = "Onyxia Scale Cloak"
local NOT_FOUND_MSG = ONY_CLOAK_NAME.." not found in your inventory!"
local equipCloakOnCombatEnd = false

-- construct from Programming in Lua, taken from
-- http://stackoverflow.com/questions/656199/search-for-an-item-in-a-lua-list
local function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

local ecBosses = Set {"Firemaw", "Ebonroc", "Flamegor", "Nefarian", 	
	"Elder Mottled Boar"} 

local function ecPrint(msg, r, g, b)
	r = r or 1
	g = g or 1
	b = b or 0
	if msg then		
		DEFAULT_CHAT_FRAME:AddMessage("[EasyCloak] " .. tostring(msg), r, g, b)
	end
end

local function findCloak(cloakName) 
	for bag = 0,4 do		
		for slot = 1,GetContainerNumSlots(bag) do			
			local itemLink = GetContainerItemLink(bag, slot)			
			
			if itemLink and string.find(itemLink, cloakName) then
				return bag, slot
			end				
		end
	end
end

local function equipOnyCloak() 
	-- check if cloak already equipped and return
	local currentCloak = GetInventoryItemLink("player", GetInventorySlotInfo("BackSlot"))
	if currentCloak and string.find(currentCloak, ONY_CLOAK_NAME) then return end

	-- if player is in combat, equip cloak when combat is over
	if UnitAffectingCombat("player") then
		ecPrint("Equpping after combat!")
		equipCloakOnCombatEnd = true -- flag for event handler
		return
	end
	
	bag, slot = findCloak(ONY_CLOAK_NAME)
	
	if not (bag and slot) then
		ecPrint(NOT_FOUND_MSG, 1, 0, 0)		
	else
		-- put previously selected item back
		if CursorHasItem() then ClearCursor() end 
		
		-- pickup and equip ony scale cloak
		PickupContainerItem(bag,slot)
		AutoEquipCursorItem()							
	end
end

local function onEvent()
	if event == "ZONE_CHANGED_INDOORS" then		
		local subzone = GetSubZoneText()
				
		if subzone and string.find(subzone, "Nefarian.*Lair") then
			equipOnyCloak()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if UnitName("target") and ecBosses[UnitName("target")] then
			equipOnyCloak()
		end
	elseif event == "PLAYER_REGEN_ENABLED" and equipCloakOnCombatEnd then
		equipCloakOnCombatEnd = false
		
		equipOnyCloak()
	end	
 end
 
f:SetScript("OnEvent", onEvent)

