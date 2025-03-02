local mod = TCainRework

local utility = require("scripts.tcainrework.util")
local saveManager = require("scripts.save_manager")

local elapsedTimeTable = {}
local collectedItems = {}
mod.minecraftItemID = 25565
local minecraftItemID = mod.minecraftItemID

local constantScale = Vector.One * 1.15
local numberToItems = require("scripts.tcainrework.stored.num_to_id")
local itemDescriptions = require("scripts.tcainrework.stored.id_to_iteminfo")
local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")

local simpleItemDisplacement = {
    0, 1, 3, -2, 1
}

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_RENDER, function(_, entity, offset)
    local entityHash = GetPtrHash(entity)
    if not collectedItems[entityHash] then
        local reflection = Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
        local pickupData = saveManager.GetRerollPickupSave(entity)
        if not pickupData.Type or not pickupData.Count then
            pickupData.Type = numberToItems[math.random(1, #numberToItems)]
            pickupData.Count = 1
        end

        local renderType = mod.inventoryHelper.getItemRenderType(pickupData.Type)
        if not reflection then
            elapsedTimeTable[entityHash] = (elapsedTimeTable[entityHash] or 0) + 0.0375
        end
        -- Animation Rendering
        local entitySprite = entity:GetSprite()
        local animationLayer = entitySprite:GetCurrentAnimationData():GetLayer(0)
        if animationLayer then
            local animFrame = animationLayer:GetFrame(entitySprite:GetFrame())
            if animFrame then
                local itemPosition = Vector(12, (((reflection and -1 or 1) * 28) + math.sin(math.pi * (elapsedTimeTable[entityHash] or 0) / 2) * 2))
                itemPosition = itemPosition - (animFrame:GetPos() * (reflection and -1 or 1))
                local itemScale = constantScale * animFrame:GetScale()

                if renderType == InventoryItemRenderType.Default then
                    itemScale = itemScale * 1.5
                    itemPosition.Y = itemPosition.Y - (reflection and -1 or 1) * 5
                end

                if pickupData.pickupEntity
                and not (entity.Wait > 0) then
                    if not pickupData.overridePosition then
                        pickupData.overridePosition = Vector.Zero
                        entity:SetShadowSize(0)
                    end
                    local targetPosition = entity.Position - pickupData.pickupEntity.Position
                    pickupData.lerpTimer = math.min((pickupData.lerpTimer or 0) + 0.025, 1)
                    pickupData.overridePosition:Lerp(entity.Position - pickupData.pickupEntity.Position, pickupData.lerpTimer or 0)
                    if (pickupData.overridePosition - targetPosition):Length() <= 5 then
                        if mod:AddItemToInventory(pickupData.Type, pickupData.Count, pickupData.ComponentData) then
                            collectedItems[entityHash] = true
                            elapsedTimeTable[entityHash] = nil
                            entity:Remove()
                            return false
                        else
                            pickupData.pickupEntity = nil
                        end
                    end
                end

                local renderPosition = Isaac.WorldToScreen(entity.Position - ((itemPosition * itemScale) + (pickupData.overridePosition or Vector.Zero)))
                if reflection then
                    renderPosition = Isaac.WorldToRenderPosition(entity.Position - ((itemPosition * itemScale) + (pickupData.overridePosition or Vector.Zero))) + offset 
                end
                if entitySprite:GetAnimation() ~= "Appear"
                or (entitySprite:GetFrame() > 4) then
                    local totalStackAmount = (((pickupData.Count or 1) > 1) and (math.ceil((pickupData.Count or 1) / 16) + 1)) or 1
                    local eightSpin = .785
                    local elapsedTime = ((eightSpin * ((elapsedTimeTable[entityHash] or 0) * 0.75)) + (eightSpin * 3)) % (eightSpin * 8)
                    local flip = not (elapsedTime > (eightSpin * 5) or elapsedTime < eightSpin)
                    for i = 1, totalStackAmount do
                        local vectorDisplacement = ((flip and i) or ((totalStackAmount - i) + 1)) 
                        mod.inventoryHelper.renderItem(
                            {Type = pickupData.Type, Count = pickupData.Count, ComponentData = pickupData.ComponentData}, 
                            renderPosition + ((Vector(-vectorDisplacement + math.floor(totalStackAmount / 2), vectorDisplacement) 
                                + Vector(1, -1)):Rotated((elapsedTime / (eightSpin * 8)) * 360) 
                                + Vector(0, simpleItemDisplacement[vectorDisplacement])) * Vector(1.25, 1 / 4), 
                            itemScale, elapsedTime
                        )
                    end
                end
            end
        end
    end
    return false
end, minecraftItemID)

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, entity, collider, low)
    local pickupData = saveManager.GetRerollPickupSave(entity)
    if (collider.Type == EntityType.ENTITY_PLAYER) then
        if (entity.Wait <= 0) and (mod.inventoryHelper.searchForFreeSlot(
            {mod.inventoryHelper.getInventory(InventoryTypes.HOTBAR), mod.inventoryHelper.getInventory(InventoryTypes.INVENTORY)}, pickupData)
        ) then
            pickupData.pickupEntity = collider
        end
        return true
    end

    if (collider.Type == EntityType.ENTITY_PICKUP and collider.Variant == minecraftItemID) then
        if Isaac.GetTime() % 4000 >= 3000 then
            local colliderData = saveManager.GetRerollPickupSave(collider)
            if ((pickupData and pickupData.Count) and (colliderData and colliderData.Count)) 
            and ((pickupData.Count >= colliderData.Count) and (mod.inventoryHelper.itemCanStackWith(pickupData, colliderData))) then
                local removableAmount = math.min(colliderData.Count, mod.inventoryHelper.getMaxStackFor(pickupData.Type) - pickupData.Count)
                if removableAmount > 0 then
                    pickupData.Count = pickupData.Count + removableAmount
                    colliderData.Count = colliderData.Count - removableAmount
                    if colliderData.Count <= 0 then
                        collectedItems[GetPtrHash(collider)] = true
                        collider:Remove()
                    end
                end
            end
        end
        return true
    end
end, minecraftItemID)

-- keepInventory
mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
    -- only if the player has the bag of crafting
    local player = entity:ToPlayer()
    if (player and player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and ((TCainRework.getModSettings().keepInventory or 1) == 1)) then
        local inventoryHelper = mod.inventoryHelper
        -- in the future, check individual player inventories
        local inventoryList = saveManager.GetRunSave().Inventories
        for i, inventory in pairs(inventoryList) do
            if inventoryHelper.isValidInventory(inventory) then
                for j, inventoryItem in pairs(inventory) do
                    local itemPickup = Isaac.Spawn(
                        EntityType.ENTITY_PICKUP, minecraftItemID, 0, player.Position, 
                        EntityPickup.GetRandomPickupVelocity(player.Position), player
                    )
                    local pickupData = saveManager.GetRerollPickupSave(itemPickup)
                    -- shallow copy
                    for k, v in pairs(inventory[j]) do
                        pickupData[k] = v
                    end
                    inventory[j] = nil
                end
            end
        end
    end
end, EntityType.ENTITY_PLAYER)


local function numericID(string)
    return itemDescriptions[string].NumericID
end

local defaultDrop = WeightedOutcomePicker()
defaultDrop:AddOutcomeWeight(numericID("minecraft:oak_planks"), 75)
defaultDrop:AddOutcomeWeight(numericID("minecraft:stick"), 25)

local redChestDrop = WeightedOutcomePicker()
redChestDrop:AddOutcomeWeight(numericID("minecraft:paper"), 3)
redChestDrop:AddOutcomeWeight(numericID("minecraft:leather"), 1)

local chestDropRates = {
    [PickupVariant.PICKUP_REDCHEST] = redChestDrop,
}

function mod:testChestOpening(chest)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and mod.inventoryHelper.getUnlockedInventory() then
        local chestSprite = chest:GetSprite()
        if chestSprite:GetAnimation() == "Open" and chestSprite:GetFrame() <= 1 then
            local lootList = chest:GetLootList()
            if lootList and (#lootList:GetEntries() > 0) then
                for i = 1, math.random(2, 3 + ((chest.Variant == PickupVariant.PICKUP_CHEST and 0) or 3)) do
                    local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, minecraftItemID, 0, chest.Position, chest.GetRandomPickupVelocity(chest.Position), chest)
                    local pickupData = saveManager.GetRerollPickupSave(itemPickup)
                    local dropOutcomes = chestDropRates[chest.Variant] or defaultDrop
                    pickupData.Type = numberToItems[dropOutcomes:PickOutcome(chest:GetDropRNG()) - collectibleStorage.itemOffset]
                    pickupData.Count = 1
                end
            end
        end
    end
end
for i in pairs(utility.chestVariants) do
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, mod.testChestOpening, i)
end

-- Cobblestone
local rockToType = {
    [GridEntityType.GRID_ROCK] = "minecraft:cobblestone",
    [GridEntityType.GRID_ROCKT] = "minecraft:cobblestone",
    [GridEntityType.GRID_ROCK_SS] = "minecraft:cobblestone",
}
local rockTypeOverride = {
    [BackdropType.CELLAR] = FiendFolio and "minecraft:oak_planks",
    [BackdropType.BURNT_BASEMENT] = FiendFolio and "minecraft:oak_planks",
    [BackdropType.DOWNPOUR] = FiendFolio and "minecraft:oak_planks"
}
mod:AddCallback(ModCallbacks.MC_POST_GRID_ROCK_DESTROY, function(_, rock, type)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and mod.inventoryHelper.getUnlockedInventory() and (rockToType[type]) then
        local conditionTable = rockTypeOverride[Game():GetRoom():GetBackdropType()]
        if not conditionTable and StageAPI and StageAPI.CurrentStage then
            conditionTable = rockTypeOverride[(StageAPI.CurrentStage.Name):match("([^%s]+)")]
        end
        local itemType = conditionTable or rockToType[type]
        if itemType then
            local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, minecraftItemID, 0, rock.Position, Vector.Zero, nil)
            local pickupData = saveManager.GetRerollPickupSave(itemPickup)
            pickupData.Type = itemType
            pickupData.Count = 1
        end
    end
end)

-- Mushrooms
local mushroomBackdrops = {
    [BackdropType.SECRET] = true,
    [BackdropType.FLOODED_CAVES] = true,
    [BackdropType.CATACOMBS] = true,
    [BackdropType.CAVES] = true,
    [BackdropType.ASHPIT] = true,
    [BackdropType.MINES] = true
}
mod:AddCallback(ModCallbacks.MC_POST_GRID_ROCK_DESTROY, function(_, rock, type)
    if (PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and mod.inventoryHelper.getUnlockedInventory() and (type == GridEntityType.GRID_ROCK_ALT))
    and (mushroomBackdrops[Game():GetRoom():GetBackdropType()]) then
        local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, minecraftItemID, 0, rock.Position, Vector.Zero, nil)
        local pickupData = saveManager.GetRerollPickupSave(itemPickup)
        pickupData.Type = (((math.random(10) <= 5) and "minecraft:red_mushroom") or "minecraft:brown_mushroom")
        pickupData.Count = 1
    end
end)