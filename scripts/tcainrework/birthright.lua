local mod = TCainRework

local libraryShiftIdx = 0
local ENCHANTED_LIBRARY_SUBTYPE = 171
local function getLibraryConfig(seed, requiredDoors)
    local roomConfig = RoomConfigHolder.GetRandomRoom(
        seed, true, StbType.SPECIAL_ROOMS, RoomType.ROOM_LIBRARY, RoomShape.ROOMSHAPE_1x1,
        nil, nil, 20, 20, (requiredDoors or 0), ENCHANTED_LIBRARY_SUBTYPE
    )
    return roomConfig
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_)
    libraryShiftIdx = 0
end)

-- Generate Library every floor
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
    if PlayerManager.AnyPlayerTypeHasBirthright(PlayerType.PLAYER_CAIN_B) then
        -- print('attempting to generate library')
        local gameInstance = Game()
        local level = gameInstance:GetLevel()
        local roomList = level:GetRooms()
        -- create RNG
        local customRNG = RNG()
        customRNG:SetSeed(gameInstance:GetSeeds():GetStartSeed(), (35 + libraryShiftIdx) % 80)
        libraryShiftIdx = libraryShiftIdx + 1
        local seed = customRNG:RandomInt(1, 285365076)
        for i = 1, roomList.Size do
            local myRoom = roomList:Get(i - 1)
            local roomType = myRoom and myRoom.Data and myRoom.Data.Type
            if roomType == RoomType.ROOM_LIBRARY then
                -- replace existing library with custom one
                myRoom.Data = getLibraryConfig(seed, myRoom.AllowedDoors)
                myRoom:InitSeeds(RNG(seed, 35))
                return
            end
        end
        local roomConfig = getLibraryConfig(seed)
        local roomOptions = level:FindValidRoomPlacementLocations(roomConfig, Dimension.CURRENT, false, false)
        for _, gridIndex in pairs(roomOptions) do
            local neighbors = level:GetNeighboringRooms(gridIndex, roomConfig.Shape, Dimension.CURRENT)
            for doorSlot, neighborDesc in pairs(neighbors) do
                roomConfig = getLibraryConfig(seed, doorSlot)
                if level:TryPlaceRoom(roomConfig, gridIndex, Dimension.CURRENT, seed, false, false) then
                    -- print('success')
                    return
                end
            end
        end
        -- print("found a really fucked up cursed floor, reseed floor")
        Isaac.ExecuteCommand("reseed")
    end
end)

-- Enchanting Table

local ENCHANTING_TABLE_NAME = "Enchanting Table"
local ENCHANTING_TABLE_VARIANT = Isaac.GetEntityVariantByName(ENCHANTING_TABLE_NAME)

local storedTouchedMachines = {}
mod:AddCallback(ModCallbacks.MC_POST_SLOT_COLLISION, function(_, enchantingTable, entity, low)
    if entity:ToPlayer() and (entity:ToPlayer():GetPlayerType() == PlayerType.PLAYER_CAIN_B) then
        storedTouchedMachines[GetPtrHash(enchantingTable)] = enchantingTable:GetTouch()
    end
end, ENCHANTING_TABLE_VARIANT)

local enchantingTableReplacement = {
    [SlotVariant.SLOT_MACHINE] = true,
    [SlotVariant.BLOOD_DONATION_MACHINE] = true,
    [SlotVariant.FORTUNE_TELLING_MACHINE] = true
}

mod:AddPriorityCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, CallbackPriority.LATE, 
function(_, entityType, entityVariant, entitySubType, _, _, _, entitySeed)
    if entityType == EntityType.ENTITY_SLOT and enchantingTableReplacement[entityVariant] 
    and PlayerManager.AnyPlayerTypeHasBirthright(PlayerType.PLAYER_CAIN_B) then
        local roomDescriptor = Game():GetLevel():GetCurrentRoomDesc()
        if roomDescriptor.Data and (roomDescriptor.Data.Type == RoomType.ROOM_LIBRARY
        and roomDescriptor.Data.Subtype == ENCHANTED_LIBRARY_SUBTYPE) then
            return {    
                EntityType.ENTITY_SLOT,
                ENCHANTING_TABLE_VARIANT,
                0, entitySeed
            }
        end
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_SLOT_UPDATE, function(_, enchantingTable)
    if storedTouchedMachines[GetPtrHash(enchantingTable)]
    and (storedTouchedMachines[GetPtrHash(enchantingTable)] > 2)
    and enchantingTable:GetTouch() <= 0 then
        mod.setInventoryState(InventoryStates.ENCHANTING)
        storedTouchedMachines[GetPtrHash(enchantingTable)] = nil
    end
end, ENCHANTING_TABLE_VARIANT)

-- Invincibility
mod:AddPriorityCallback(ModCallbacks.MC_PRE_SLOT_CREATE_EXPLOSION_DROPS, CallbackPriority.EARLY, function(_, enchantingTable)
    enchantingTable:SetState(1)
    return false
end, ENCHANTING_TABLE_VARIANT)