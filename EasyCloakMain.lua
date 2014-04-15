local ONY_CLOAK_ID = 15138
local ONY_NOT_FOUND_MSG = "Onyxia Scale Cloak not found in your inventory!"
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

local ecBosses = Set {"Firemaw", "Ebonroc", "Flamegor", "Nefarian"} 
	
local function ecPrint(msg, r, g, b)
	r = r or 1
	g = g or 1
	b = b or 0
	if msg then		
		DEFAULT_CHAT_FRAME:AddMessage("[EasyCloak] " .. tostring(msg), r, g, b)		
	end
end

local ecTooltip
local function isSoulbound(bag, slot)
	-- don't initialize twice
	ecTooltip = ecTooltip or CreateFrame( "GameTooltip", "ecTooltip", nil, 
		"GameTooltipTemplate" )
	ecTooltip:AddFontStrings(
		ecTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
		ecTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ), 
		ecTooltip:CreateFontString( "$parentTextLeft2", nil, "GameTooltipText" ),
		ecTooltip:CreateFontString( "$parentTextRight2", nil, "GameTooltipText" ) 
	);	
	-- make tooltip "hidden"
	ecTooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );

	ecTooltip:ClearLines()
	ecTooltip:SetBagItem(bag, slot)		
		
	return (ecTooltipTextLeft2:GetText() == ITEM_SOULBOUND)
end	

local function idFromLink(itemlink)
	if itemlink then
		local _,_,id = string.find(itemlink, "|Hitem:([^:]+)%:")
		return tonumber(id)
	end
	
	return nil	
end

local function findCloak(itemId) 
	local bagIdx, slotIdx 
	
	for bag = 0,4 do		
		for slot = 1,GetContainerNumSlots(bag) do			
			local itemLink = GetContainerItemLink(bag, slot)		
			
			if itemLink and idFromLink(itemLink) == tonumber(itemId) then				
				if isSoulbound(bag, slot) then 
					-- this is definitely the right item
					return bag, slot
				else 
					-- keep looking for soulbound cloak, store values
					bagIdx, slotIdx = bag, slot
				end				
			end				
		end
	end
		
	return bagIdx, slotIdx
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
	if currentCloak and idFromLink(currentCloak) == ONY_CLOAK_ID then return end			
	-- if player is in combat, equip cloak when combat is over
	if UnitAffectingCombat("player") then		
		equipOnyOnCombatEnd = true -- flag for event handler
		return
	end	
		
	local bag, slot = findCloak(ONY_CLOAK_ID)
	
	if not (bag and slot) then
		ecPrint(ONY_NOT_FOUND_MSG, 1, 0, 0)
		return
	end
	
	-- store id of currently equipped cloak in settings
	EasyCloakDB.previous = idFromLink(currentCloak)
	
	saveEquip(bag, slot)						
end

local function equipPreviousCloak()
	-- abort if ony cloak is not equipped
	local currentCloak = GetInventoryItemLink("player", 
			GetInventorySlotInfo("BackSlot"))
				
	if currentCloak and not (idFromLink(currentCloak) == ONY_CLOAK_ID) then
		-- for some reason no onyxia cloak eqipped, do nothing
		return
		
	elseif not EasyCloakDB.previous then
		-- for some reason previous name not persisted
		ecPrint("An error occurred, please equip your regular cloak!")
		return
		
	end

	-- if player is in combat, equip cloak when combat is over
	if UnitAffectingCombat("player") then				
		equipPrevOnCombatEnd = true -- flag for event handler
		return
		
	elseif UnitHealth("player") == 0 then		
		equipPrevOnRess = true -- flag for event handler
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
		
	elseif event == "PLAYER_TARGET_CHANGED" and EasyCloakDB.drakes then
		if UnitName("target") and ecBosses[UnitName("target")] 
				and UnitHealth("target") > 0 then
			equipOnyCloak()
		end
		
	elseif event == "PLAYER_REGEN_ENABLED" then
		if equipOnyOnCombatEnd then
			equipOnyOnCombatEnd = false
			equipOnyCloak()
		elseif equipPrevOnCombatEnd then			
			equipPrevOnCombatEnd = false
			equipPreviousCloak()
		end
	
	elseif (event == "PLAYER_UNGHOST" or "PLAYER_ALIVE") and equipPrevOnRess then
		if UnitHealth("player") > 1 then -- don't equip in ghost form (hp = 1)		
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
		
	end	
 end
 
local function printStatus()
	if EasyCloakDB.drakes then
		ecPrint("Equip on drakes turned ON")
	else
		ecPrint("Equip on drakes turned OFF")
	end
end
 
local f = CreateFrame("frame")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:SetScript("OnEvent", onEvent)

SLASH_EASYCLOAK1 = '/easycloak'
SLASH_EASYCLOAK2 = '/ec'
function SlashCmdList.EASYCLOAK(msg, editbox)	
	if msg == "toggle" then
		if EasyCloakDB.drakes then
			EasyCloakDB.drakes = false
		else
			EasyCloakDB.drakes = true
		end
		
		printStatus()
	elseif msg == "" then
		printStatus()
	end		
end