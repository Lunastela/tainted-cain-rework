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

local simpleItemDisplacement = {
    0, 1, 3, -2, 1
}

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_RENDER, function(_, entity, offset)
    local entityHash = GetPtrHash(entity)
    if not collectedItems[entityHash] then
        local reflection = Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
        local pickupData = saveManager.GetRoomFloorSave(entity)
            and saveManager.GetRoomFloorSave(entity).RerollSave
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
                        mod:AddItemToInventory(pickupData.Type, pickupData.Count, pickupData.ComponentData)
                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Pop"), 2, 2, false, math.random(16, 24) / 10, 0)
                        collectedItems[entityHash] = true
                        entity:Remove()
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
    local pickupData = saveManager.GetRoomFloorSave(entity) 
        and saveManager.GetRoomFloorSave(entity).RerollSave
    if (collider.Type == EntityType.ENTITY_PLAYER) then
        pickupData.pickupEntity = collider
        return true
    end
    if (collider.Type == EntityType.ENTITY_PICKUP and collider.Variant == minecraftItemID) then
        -- local colliderData = saveManager.GetRoomFloorSave(collider) 
        --     and saveManager.GetRoomFloorSave(collider).RerollSave
        -- if mod.inventoryHelper.canStack
        -- collider:Remove()
        return true
    end
end, minecraftItemID)

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
                    local pickupData = saveManager.GetRoomFloorSave(itemPickup) 
                        and saveManager.GetRoomFloorSave(itemPickup).RerollSave
                    local dropOutcomes = chestDropRates[chest.Variant] or defaultDrop
                    pickupData.Type = numberToItems[dropOutcomes:PickOutcome(chest:GetDropRNG())]
                    pickupData.Count = 1
                end
            end
        end
    end
end
for i in pairs(utility.chestVariants) do
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, mod.testChestOpening, i)
end

local rockToType = {
    [GridEntityType.GRID_ROCK] = "minecraft:cobblestone",
    [GridEntityType.GRID_ROCKT] = "minecraft:cobblestone",
    [GridEntityType.GRID_ROCK_SS] = "minecraft:cobblestone"
}
mod:AddCallback(ModCallbacks.MC_POST_GRID_ROCK_DESTROY, function(_, rock, type)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and mod.inventoryHelper.getUnlockedInventory()
    and rockToType[type] then
        local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, minecraftItemID, 0, rock.Position, Vector.Zero, nil)
        local pickupData = saveManager.GetRoomFloorSave(itemPickup)
            and saveManager.GetRoomFloorSave(itemPickup).RerollSave
        pickupData.Type = rockToType[type]
        pickupData.Count = 1
    end
end)