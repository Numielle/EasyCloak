local f = CreateFrame("frame")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")

f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")

local ONY_CLOAK_NAME = "Onyxia Scale Cloak"
local ONY_NOT_FOUND_MSG = ONY_CLOAK_NAME.." not found in your inventory!"
local PREV_NOT_FOUND_MSG = "Previous cloak not found in your inventory!"
local equipOnyOnCombatEnd = false
local equipPrevOnCombatEnd = false
local equipPrevOnRess = false

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

local function nameFromItemlink(itemlink)
	if itemlink then
		pattern = "[[].*[]]"

		x,y =  string.find(itemlink,pattern)
		name =  strsub(itemlink, x + 1, y - 1)
		
		return name
	else 
		return nil
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

local function saveEquip(bag, slot)
	-- put previously selected item back
	if CursorHasItem() then ClearCursor() end 
	
	-- pickup and equip ony scale cloak
	PickupContainerItem(bag,slot)
	AutoEquipCursorItem()
end

local function equipOnyCloak() 
	-- check if cloak already equipped and return
	local currentCloak = GetInventoryItemLink("player", 
			GetInventorySlotInfo("BackSlot"))
	if currentCloak and string.find(currentCloak, ONY_CLOAK_NAME) then return end

	-- if player is in combat, equip cloak when combat is over
	if UnitAffectingCombat("player") then
		--ecPrint("Equpping after combat!")
		equipOnyOnCombatEnd = true -- flag for event handler
		return
	end	
	
	local bag, slot = findCloak(ONY_CLOAK_NAME)
	
	if not (bag and slot) then
		ecPrint(ONY_NOT_FOUND_MSG, 1, 0, 0)
		return
	end
	
	-- store itemlink of currently equipped cloak in settings
	EasyCloakDB.previous = nameFromItemlink(currentCloak)
	
	saveEquip(bag, slot)						
end

local function equipPreviousCloak()
	-- abort if ony cloak is not equipped
	local currentCloak = GetInventoryItemLink("player", 
			GetInventorySlotInfo("BackSlot"))
			
	if currentCloak and not string.find(currentCloak, ONY_CLOAK_NAME) then 		
		-- for some reason no onyxia cloak eqipped, do nothing
		return
	elseif not EasyCloakDB.previous then
		-- for some reason previous name not persisted
		ecPrint("An error occurred, please equip your regular cloak!")
		return
	end
	
		-- if player is in combat, equip cloak when combat is over
	if UnitAffectingCombat("player") then
		ecPrint("Equipping " .. EasyCloakDB.previous .. " after combat!")
		equipPrevOnCombatEnd = true -- flag for event handler
		return
	elseif UnitHealth("player") == 0 then
		ecPrint("Equipping " .. EasyCloakDB.previous .. " after ress!")
		equipPrevOnRess = true
		return
	end
		
	local bag, slot = findCloak(EasyCloakDB.previous)
	
	if not (bag and slot) then
		-- for some reason the previous cloak is not in the bags anymore
		ecPrint(PREV_NOT_FOUND_MSG)
		return
	end
		
	saveEquip(bag, slot)
end

local function onEvent()
	if event == "ZONE_CHANGED_INDOORS" then		
		local subzone = GetSubZoneText()
				
		if subzone and string.find(subzone, "Nefarian.*Lair") then
			equipOnyCloak()
		end
		
	elseif event == "PLAYER_TARGET_CHANGED" then
		if UnitName("target") and ecBosses[UnitName("target")] 
				and UnitHealth("target") > 0 then
			equipOnyCloak()
		end
		
	elseif event == "PLAYER_REGEN_ENABLED" then
		if equipOnyOnCombatEnd then
			equipOnyOnCombatEnd = false
			equipOnyCloak()
		elseif equipPrevOnCombatEnd then
			ecPrint("unequipping ony cloak")
			equipPrevOnCombatEnd = false
			equipPreviousCloak()
		end
	
	elseif (event == "PLAYER_UNGHOST" or "PLAYER_ALIVE") and equipPrevOnRess then
		if UnitHealth("player") > 1 then
			ecPrint("unequip cloak")
			equipPrevOnRess = false
			equipPreviousCloak()
		end
	elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then 		
		local _,_,victim = string.find(arg1, "(.+)% dies.")
		if victim and ecBosses[victim] then
			equipPreviousCloak()
		end	
	elseif event == "ADDON_LOADED" and arg1 == "EasyCloak" then
		if not EasyCloakDB then
			-- initialize DB (first time addon is loaded)
			EasyCloakDB = {}
			EasyCloakDB.drakes = true
		end
		
		-- process settings from DB and perform setup actions
	end	
 end
 
f:SetScript("OnEvent", onEvent)

SLASH_EASYCLOAK1 = '/easycloak'
SLASH_EASYCLOAK2 = '/ec'
function SlashCmdList.EASYCLOAK(msg, editbox)	
	if msg == "reset" then
		if EasyCloakDB.previous then
			ecPrint("resetting previous cloak")
			EasyCloakDB.previous = nil
		end
	elseif msg == "print" then
		if EasyCloakDB.previous then
			ecPrint("former cloak: " .. EasyCloakDB.previous)
		end
	else
		-- default behavior
 	end
end

