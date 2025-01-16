local mod = TCainRework

local utility = require("scripts.tcainrework.util")
local saveManager = require("scripts.save_manager")

local elapsedTimeTable = {}
local collectedItems = {}
mod.minecraftItemID = 25565
local minecraftItemID = mod.minecraftItemID

local constantScale = Vector.One * 1.15
local numberToItems = require("scripts.tcainrework.stored.num_to_id")
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
            elapsedTimeTable[entityHash] = (elapsedTimeTable[entityHash] or math.random(0, 10)) + 0.025
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
                    mod.inventoryHelper.renderItem(
                        {Type = pickupData.Type, Count = pickupData.Count}, 
                        renderPosition, 
                        itemScale, (elapsedTimeTable[entityHash] or 0)
                    )
                end
            end
        end
    end
    return false
end, minecraftItemID)

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, entity, collider, low)
    if (collider.Type == EntityType.ENTITY_PLAYER) then
        local pickupData = saveManager.GetRoomFloorSave(entity) 
            and saveManager.GetRoomFloorSave(entity).RerollSave
        pickupData.pickupEntity = collider
        return true
    end
    if (collider.Type == EntityType.ENTITY_PICKUP and collider.Variant == minecraftItemID) then
        -- collider:Remove()
        return true
    end
end, minecraftItemID)

function mod:testChestOpening(chest)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and mod.inventoryHelper.getUnlockedInventory() then
        local chestSprite = chest:GetSprite()
        if chestSprite:GetAnimation() == "Open" and chestSprite:GetFrame() <= 1 then
            local lootList = chest:GetLootList()
            if lootList and (#lootList:GetEntries() > 0) then
                for i = 1, math.random(2, 5) do
                    local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, minecraftItemID, 0, chest.Position, chest.GetRandomPickupVelocity(chest.Position), chest)
                    local pickupData = saveManager.GetRoomFloorSave(itemPickup) 
                        and saveManager.GetRoomFloorSave(itemPickup).RerollSave
                    local unlucky = math.random(1, 5) == 1
                    pickupData.Type = unlucky and "minecraft:stick" or "minecraft:oak_planks"
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