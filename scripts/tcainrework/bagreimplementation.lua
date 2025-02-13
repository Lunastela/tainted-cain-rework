local mod = TCainRework

local utility = require("scripts.tcainrework.util")
local saveManager = require("scripts.save_manager")

local bagSprites = {}
local bagSpritesFrame = {}
local hasRenderedThisFrame = {}
local bagCollisions = {}

local function canRenderBagSprite(bagSprite) 
    return not bagSprite:GetAnimation():find("Idle")
        and not bagSprite:IsFinished(bagSprite:GetAnimation())
end

mod:AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM, CallbackPriority.IMPORTANT, 
function(_, id, rng, player, flags, slot)
    if (player:GetSprite():GetAnimation():find("Pickup")) then
        player:AnimateCollectible(id, "HideItem")
    elseif (not bagSprites[player.Index]) 
    or (bagSprites[player.Index] and not canRenderBagSprite(bagSprites[player.Index])) then
        player:AnimateCollectible(id, "LiftItem", "PlayerPickup")
        bagSprites[player.Index] = Sprite()
        bagSprites[player.Index]:Load("gfx/008.004_bag of crafting.anm2", true)
        bagSprites[player.Index]:Play("Idle", true)
        bagCollisions[player.Index] = {}
    end
    return true
end, CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if (player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and (player:GetSprite():GetAnimation():find("Pickup"))) then
        local bagSprite = bagSprites[player.Index]
        if bagSprite and bagSprite:GetAnimation():find("Idle") then
            if player:GetShootingJoystick():LengthSquared() > 0 then
                bagSprite:Play("Swing", true)
                bagSpritesFrame[player.Index] = bagSprite:GetFrame()
                bagSprite.Scale = player.SpriteScale
                bagSprite.Rotation = ((player:GetShootingJoystick():GetAngleDegrees() - 90) + 360) % 360
                player:AnimateCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING, "HideItem")
                SFXManager():Play(SoundEffect.SOUND_BIRD_FLAP, 1, 2, false, 1 + (math.random(-50, 50) / 1000))
            end
        end
    end
end)

local function damageCancelRender(player)
    if (player:GetDamageCooldown() > 0 and player:GetDamageCooldown() % 6 < 3) then -- silly fix for player damage flashing
        return true
    end
    return false
end

local function getBagSwipePosition(bagSprite, player)
    return (Isaac.ScreenToWorldDistance(Vector(0, 18)) * player.SpriteScale):Rotated(bagSprite.Rotation)
end

local entityToItemLookupTable = require("scripts.tcainrework.stored.entityid_to_id")
local function checkEntityConditional(entity, entityLookup, player)
    local checkedCondition = entityLookup.Condition and entityLookup.Condition(entity, player)
    if not entityLookup.Condition or (checkedCondition ~= false) then
        return entityLookup, checkedCondition
    end
    return nil, nil
end

local function getEntityFromTable(entity, gridEntity, player)
    local allVariants = (gridEntity and {entity:GetType(), entity:GetVariant()})
        or {tostring(entity.Type), tostring(entity.Variant), tostring(entity.SubType)}
    for i = #allVariants, 1, -1 do
        local totalString = (gridEntity and "grid." or "") .. allVariants[1]
        for j = 1, i - 1 do
            totalString = totalString .. "." .. allVariants[j + 1]
        end
        if entityToItemLookupTable and entityToItemLookupTable[totalString] then
            if entityToItemLookupTable[totalString].Type then
                local entityLookup, entityConditionTable = checkEntityConditional(entity, entityToItemLookupTable[totalString], player)
                return entityLookup, entityConditionTable
            else
                for i, lookupTable in ipairs(entityToItemLookupTable[totalString]) do
                    local entityLookup, entityConditionTable = checkEntityConditional(entity, lookupTable, player)
                    if entityLookup then
                        return entityLookup, entityConditionTable
                    end
                end
            end
        end
    end
    return nil
end 

local bagExclusions = {
    [EntityType.ENTITY_SHOPKEEPER] = true,
    [EntityType.ENTITY_PROJECTILE] = true,
    [EntityType.ENTITY_SLOT] = true
}

local bagInclusions = {
    [EntityType.ENTITY_FIREPLACE] = true,
    [EntityType.ENTITY_POOP] = true,
    [EntityType.ENTITY_MOVABLE_TNT] = true
}

local function generateGenericEffect(entity, gridEntity)
    if not gridEntity then
        entity:Remove()
        if entity:ToPickup() then
            entity:ToPickup():TriggerTheresOptionsPickup()
        end
    end
    -- Stole this idea from IsaacScript as I was too lazy to implement Babel's GenericPickup
    local entitySpawner = ((not gridEntity) and entity) or nil
    local entitySpriteFilename = entity:GetSprite():GetFilename()
    local collectEffect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LADDER, 255, entity.Position, Vector.Zero, entitySpawner)
    local collectEffectSprite = collectEffect:GetSprite()
    collectEffectSprite:Load(entitySpriteFilename, true)
    collectEffectSprite:SetAnimation("Collect", true)
    if collectEffectSprite:GetAnimation() == "Collect" then
        collectEffectSprite:Play("Collect", true)
    else
        local entitySprite = entity:GetSprite()
        collectEffectSprite:Play(entitySprite:GetAnimation())
        collectEffectSprite:PlayOverlay(entitySprite:GetOverlayAnimation())
        collectEffectSprite.PlaybackSpeed = 0
        collectEffectSprite.FlipX = entitySprite.FlipX
        collectEffectSprite.FlipY = entitySprite.FlipY

        local effectData = collectEffect:GetData()
        effectData.BagOfCraftingAnim = true
        effectData.Frame = 0
        effectData.OriginalScale = Vector(collectEffectSprite.Scale.X, collectEffectSprite.Scale.Y)
    end
    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, (gridEntity and 2) or 1, entity.Position, Vector.Zero, entitySpawner)
end

-- Item Salvaging

local function canSalvageItem(collectibleType)
    local itemConfig = utility.getCollectibleConfig(collectibleType)
    return ((collectibleType > 0) and not (itemConfig.Tags & ItemConfig.TAG_QUEST ~= 0))
end

local salvageOutcomes = WeightedOutcomePicker()
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_HEART, 100)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_COIN, 100)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_KEY, 100)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_BOMB, 100)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_PILL, 15)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_LIL_BATTERY, 15)
salvageOutcomes:AddOutcomeWeight(PickupVariant.PICKUP_TAROTCARD, 15)

local salvagingList = {}
local heartSelectionList = {
    [ItemPoolType.POOL_SECRET] = HeartSubType.HEART_BONE,
    [ItemPoolType.POOL_ANGEL] = HeartSubType.HEART_ETERNAL,
    [ItemPoolType.POOL_DEVIL] = HeartSubType.HEART_BLACK,
    [ItemPoolType.POOL_CURSE] = HeartSubType.HEART_ROTTEN,
    [ItemPoolType.POOL_ULTRA_SECRET] = HeartSubType.HEART_BONE,
}
local function spawnSalvagePickup(pickup, salvageVariant)
    local salvageSubtype = 0
    if salvageVariant == PickupVariant.PICKUP_HEART then
        local game = Game()
        local itemPool = game:GetItemPool()
        local poolType = math.max(0, itemPool:GetPoolForRoom(game:GetRoom():GetType(), pickup:GetDropRNG():GetSeed()))
        salvageSubtype = (heartSelectionList[poolType] or 1)
    end
    local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, salvageVariant, salvageSubtype, 
        pickup.Position, pickup.GetRandomPickupVelocity(pickup.Position), pickup)
    return itemPickup
end

local collectibleToRecipe = require("scripts.tcainrework.stored.collectible_to_recipe")
local function salvageCollectible(player, pickup)
    if canSalvageItem(pickup.SubType) then
        local ptrHash = GetPtrHash(pickup)
        SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN, 1, 2, false, 1)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 2, pickup.Position, Vector.Zero, pickup)
        -- Unlock Item Recipe
        if collectibleToRecipe[pickup.SubType] then
            for i, recipeName in ipairs(collectibleToRecipe[pickup.SubType]) do
                TCainRework:UnlockItemRecipe(recipeName)
            end
        end
        -- Boss Rush / Challenge Room
        local roomType = Game():GetRoom():GetType()
        if roomType == RoomType.ROOM_BOSSRUSH or roomType == RoomType.ROOM_CHALLENGE then
            Ambush.StartChallenge()
            -- Add additional boss rush salvage (because it's depths 2, actually I don't need to justify myself to you?)
            if roomType == RoomType.ROOM_BOSSRUSH then
                local timeStep, times = 3, 6
                Isaac.CreateTimer(function(_)
                    for i = 1, 2 do
                        local salvageVariant = salvageOutcomes:PickOutcome(pickup:GetDropRNG())
                        spawnSalvagePickup(pickup, salvageVariant)
                    end
                end, timeStep, times, false)
                Isaac.CreateTimer(function(_)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_SUPERTROLL, 
                        pickup.Position, pickup.GetRandomPickupVelocity(pickup.Position), pickup)
                end, ((times + 1) * timeStep), 1, false)
            end
        end
        -- Spawn Salvage
        local itemQuality = Isaac.GetItemConfig():GetCollectible(pickup.SubType).Quality
        spawnSalvagePickup(pickup, PickupVariant.PICKUP_HEART)
        for i = 1, ((3 + math.random(1, 3)) + itemQuality) do
            local salvageVariant = salvageOutcomes:PickOutcome(pickup:GetDropRNG())
            spawnSalvagePickup(pickup, salvageVariant)
        end
        pickup:Remove()
        -- There's Options
        Isaac.CreateTimer(function(_) 
            pickup:TriggerTheresOptionsPickup()
            salvagingList[ptrHash] = nil
        end, 8, 1, true)
    end
end

local function notShopItemOrBought(player, pickup)
    if pickup:IsShopItem() and getEntityFromTable(pickup, false, player) then
        -- player:ForceCollide(pickup, false)
        return false
    end
    return true
end

mod:AddPriorityCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, CallbackPriority.LATE, 
function(_, entity, collider, low)
    if canSalvageItem(entity.SubType) then
        local pickup = entity:ToPickup()
        if ((collider.Type == EntityType.ENTITY_PLAYER 
        and ((collider:ToPlayer():GetPlayerType() == PlayerType.PLAYER_CAIN_B) 
        and (not collider:ToPlayer():IsHoldingItem())))
        and notShopItemOrBought(collider:ToPlayer(), pickup)) then
            if not salvagingList[GetPtrHash(entity)] then
                Isaac.CreateTimer(function(_) 
                    salvageCollectible(collider:ToPlayer(), pickup)
                end, 2, 1, true)
                salvagingList[GetPtrHash(entity)] = true
            end
            return pickup:IsShopItem()
        end
    end
end, PickupVariant.PICKUP_COLLECTIBLE)

local bagInteractPickups = {
    [PickupVariant.PICKUP_GRAB_BAG] = true
}

local function renderBagOfCrafting(player, offset)
    if (bagSprites[player.Index] and player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)) then
        local bagSprite = bagSprites[player.Index]
        if canRenderBagSprite(bagSprite) then
            local bagPosition = Isaac.WorldToRenderPosition(player.Position) - (Vector(0, 3) * bagSprite.Scale)
            if not damageCancelRender(player) then
                bagSprite:Render(bagPosition + offset)
            end
            if not hasRenderedThisFrame[player.Index] 
            and (not Game():IsPaused())
            and Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
                hasRenderedThisFrame[player.Index] = true
                -- Null Frame Collisions
                local currentFrame = bagSpritesFrame[player.Index]
                if currentFrame < 2 and player:GetShootingJoystick():LengthSquared() > 0 then
                    bagSprite.Rotation = ((player:GetShootingJoystick():GetAngleDegrees() - 90) + 360) % 360
                end
                if currentFrame <= 5 then
                    local swipePosition = getBagSwipePosition(bagSprite, player)
                    local swipeCapsule = Capsule(player.Position + swipePosition * 0.75, 
                        player.Position + swipePosition, 30 * player.SpriteScale:Length())
                    local foundEntities = Isaac.FindInCapsule(swipeCapsule, 
                        EntityPartition.ENEMY | EntityPartition.PICKUP | EntityPartition.BULLET
                    )
                    for i, entity in ipairs(foundEntities) do
                        local entityPointer = GetPtrHash(entity)
                        if not utility.tableContains(bagCollisions[player.Index], entityPointer) then
                            local knockbackDirection = (entity.Position - swipeCapsule:GetPosition()):Normalized()
                            local pickup = entity:ToPickup()
                            if (((pickup and (notShopItemOrBought(player, pickup) and pickup.Wait <= 0 
                                and (not (pickup:GetSprite():GetAnimation() == "Collect"))))
                                or (not pickup)) and not bagExclusions[entity.Type]) and (((entity:ForceCollide(player, false) ~= true) 
                                or (pickup and pickup:IsShopItem()))) then
                                local tcainPickup = (pickup and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE)
                                    and (player:GetPlayerType() == PlayerType.PLAYER_CAIN_B)
                                local itemTable, itemCondition = getEntityFromTable(entity, false, player)
                                if tcainPickup then
                                    itemTable, itemCondition = nil, nil
                                end
                                local ableToAddItem = itemTable and mod:AddItemToInventory(
                                    itemTable.Type, itemTable.Amount, itemCondition
                                )
                                if not ableToAddItem then
                                    local forcedInclude = bagInclusions[entity.Type]
                                    if (not pickup and entity:IsVulnerableEnemy()) 
                                    or forcedInclude then
                                        if entity:TakeDamage(6, 0, EntityRef(player), 5)
                                        and (not forcedInclude) then
                                            SFXManager():Play(SoundEffect.SOUND_MEATY_DEATHS, 1, 10, false, 1.5)
                                        end
                                    elseif pickup then 
                                        -- Attempt to Open Chest
                                        if utility.chestVariants[pickup.Variant]
                                        or bagInteractPickups[pickup.Variant] then
                                            player:ForceCollide(pickup)
                                        end
                                        if pickup.Variant == mod.minecraftItemID then
                                            local pickupData = saveManager.GetRoomFloorSave(entity) 
                                                and saveManager.GetRoomFloorSave(entity).RerollSave
                                            pickupData.pickupEntity = player
                                        elseif pickup.Variant == PickupVariant.PICKUP_COIN
                                        and pickup.SubType == CoinSubType.COIN_STICKYNICKEL then
                                            pickup:GetSprite():Play("Touched")
                                        elseif tcainPickup and not salvagingList[GetPtrHash(entity)] then
                                            salvageCollectible(player, pickup)
                                            salvagingList[GetPtrHash(entity)] = true
                                        end
                                    end
                                    if not (pickup and (pickup.Variant == mod.minecraftItemID 
                                        or pickup.Variant == PickupVariant.PICKUP_GRAB_BAG)) then
                                        local knockbackVelocity = ((math.max(1, player.Velocity:Length() / 3) * knockbackDirection) * math.max(20, 40 / entity.Mass))
                                        entity.Velocity = entity.Velocity + knockbackVelocity
                                    end
                                else -- DESTROY item
                                    generateGenericEffect(entity)
                                    table.insert(bagCollisions[player.Index], entityPointer)
                                end
                            elseif entity.Type == EntityType.ENTITY_PROJECTILE then
                                local projectileEntity = entity:ToProjectile()
                                if projectileEntity then
                                    local knockbackDirection = (projectileEntity.Position - swipeCapsule:GetPosition()):Normalized()
                                    projectileEntity.Velocity = (projectileEntity.Velocity:Length() * knockbackDirection)
                                    projectileEntity:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES)
                                end
                            end
                            if entity.Type ~= EntityType.ENTITY_FIREPLACE
                            and entity.Type ~= EntityType.ENTITY_POOP
                            and not utility.tableContains(bagCollisions[player.Index], entityPointer) then
                                table.insert(bagCollisions[player.Index], entityPointer)
                            end
                        end
                    end
                    -- Detect Grid Collisions
                    if currentFrame > 2 then
                        local room = Game():GetRoom()
                        for i = 0, 8 do
                            for j = 0, 2 do
                                local gridEntity = room:GetGridEntityFromPos(swipeCapsule:GetPosition() + Vector(20 * j, 0):Rotated(i * 45))
                                if gridEntity then
                                    local positionHash = utility.sha1(tostring(gridEntity.Position.X) .. "." .. tostring(gridEntity.Position.Y))
                                    if (not utility.tableContains(bagCollisions[player.Index], positionHash)) then
                                        local itemTable = getEntityFromTable(gridEntity, true, player)
                                        local ableToAddItem = itemTable and mod:AddItemToInventory(itemTable.Type, itemTable.Amount)
                                        if not ableToAddItem then
                                            gridEntity:Hurt(3)
                                        else
                                            local lastPosition = Vector(gridEntity.Position.X, gridEntity.Position.Y)
                                            local gridIndex = gridEntity:GetGridIndex()
                                            generateGenericEffect(gridEntity, true)
                                            room:RemoveGridEntityImmediate(gridIndex, 0, false)
                                            local replacementEntity = Isaac.GridSpawn(GridEntityType.GRID_DECORATION, 0, lastPosition, true)
                                            if replacementEntity then
                                                replacementEntity:GetSprite():SetRenderFlags(1 << 2)
                                            end
                                        end
                                        table.insert(bagCollisions[player.Index], positionHash)
                                    end
                                end
                            end
                        end
                    end
                    -- DebugRenderer.Get(1, true):Capsule(swipeCapsule)
                end
                bagSprite:SetFrame(math.floor(currentFrame))
                bagSprite:Update()
                bagSpritesFrame[player.Index] = bagSpritesFrame[player.Index] + 0.5
            end
        end
    end
end

local frameScaleTable = {
    Vector(1.1, .9),
    Vector(1.7, .8),
    Vector(2.2, .4),
    Vector(5., .15),
    Vector(0, 0)
}
local colorWhite = Color(0, 0, 0, 1, 1, 1, 1)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_RENDER, function(_, effect, offset)
    if effect.SubType == 255 then 
        local effectSprite = effect:GetSprite()
        if effectSprite:GetAnimation() == "Collect"
        and effectSprite:IsFinished("Collect") then
            effect:Remove()
        elseif effectSprite:GetAnimation() ~= "Collect" 
        and effect:GetData().BagOfCraftingAnim then
            local effectData = effect:GetData()
            local scaleIndex = math.max(1, math.min(math.floor(effectData.Frame), (#frameScaleTable - 1)))
            if effectData.Frame - 1 > scaleIndex then
                effect:Remove()
            end
            effectSprite.Scale = effectData.OriginalScale * frameScaleTable[scaleIndex]
            effectData.Frame = effectData.Frame + 0.5
            effectSprite.Color = colorWhite
        end
    end
end, EffectVariant.LADDER)

local function renderBagOver(player)
    local rotation = ((bagSprites[player.Index] and bagSprites[player.Index].Rotation) 
        + ((math.min(bagSpritesFrame[player.Index] or 0, 4) * 180) / 4) % 360)
    if rotation > 90 and rotation < 270 then
        return true
    end
    return false
end

mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, offset)
    hasRenderedThisFrame = {}
    if bagSprites[player.Index]
    and (not renderBagOver(player)) then
        renderBagOfCrafting(player, offset)
    end
end)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, offset)
    if bagSprites[player.Index]
    and (renderBagOver(player)
    or damageCancelRender(player)) then
        renderBagOfCrafting(player, offset)
    end
end)

-- mod:AddCallback(ModCallbacks.MC_PRE_SFX_PLAY, function(_, ID, Volume, FrameDelay, Loop, Pitch, Pan)
--     print(ID, Volume, FrameDelay, Loop, Pitch, Pan)
-- end)