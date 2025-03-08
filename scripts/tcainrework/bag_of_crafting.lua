local mod = TCainRework

local utility = require("scripts.tcainrework.util")
local saveManager = require("scripts.save_manager")

local bagSprites = {}
local bagSpritesFrame = {}
local hasRenderedThisFrame = {}
local bagCollisions, removedEntities = {}, {}

local function canRenderBagSprite(bagSprite) 
    return not bagSprite:GetAnimation():find("Idle")
        and not bagSprite:IsFinished(bagSprite:GetAnimation())
end

mod:AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM, CallbackPriority.IMPORTANT, 
function(_, id, rng, player, flags, slot)
    local playerIndex = GetPtrHash(player)
    if (player:GetSprite():GetAnimation():find("Pickup")) then
        player:AnimateCollectible(id, "HideItem")
    elseif (not bagSprites[playerIndex]) 
    or (bagSprites[playerIndex] and not canRenderBagSprite(bagSprites[playerIndex])) then
        player:AnimateCollectible(id, "LiftItem", "PlayerPickup")
        bagSprites[playerIndex] = Sprite()
        bagSprites[playerIndex]:Load("gfx/008.004_bag of crafting.anm2", true)
        bagSprites[playerIndex]:Play("Idle", true)
        bagCollisions[playerIndex] = {}
    end
    return true
end, CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if (player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and (player:GetSprite():GetAnimation():find("Pickup"))) then
        local playerIndex = GetPtrHash(player)
        local bagSprite = bagSprites[playerIndex]
        if bagSprite and bagSprite:GetAnimation():find("Idle") then
            if player:GetShootingJoystick():LengthSquared() > 0 then
                bagSprite:Play("Swing", true)
                bagSpritesFrame[playerIndex] = bagSprite:GetFrame()
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
    if (not entityLookup.Condition or (checkedCondition ~= false)) then
        return entityLookup, checkedCondition, false
    end
    return nil, nil, true
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
                    local entityLookup, entityConditionTable, continueNext = checkEntityConditional(entity, lookupTable, player)
                    if not continueNext then
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
    [ItemPoolType.POOL_GREED_SECRET] = HeartSubType.HEART_BONE,
    [ItemPoolType.POOL_ANGEL] = HeartSubType.HEART_ETERNAL,
    [ItemPoolType.POOL_GREED_ANGEL] = HeartSubType.HEART_ETERNAL,
    [ItemPoolType.POOL_DEVIL] = HeartSubType.HEART_BLACK,
    [ItemPoolType.POOL_GREED_DEVIL] = HeartSubType.HEART_BLACK,
    [ItemPoolType.POOL_CURSE] = HeartSubType.HEART_ROTTEN,
    [ItemPoolType.POOL_GREED_CURSE] = HeartSubType.HEART_ROTTEN,
    [ItemPoolType.POOL_ULTRA_SECRET] = HeartSubType.HEART_BONE,
    [ItemPoolType.POOL_GREED_SECRET] = HeartSubType.HEART_BONE,
}

local function spawnSalvagePickup(pickup, salvageVariant)
    local salvageSubtype = 0
    if salvageVariant == PickupVariant.PICKUP_HEART then
        local game = Game()
        local itemPool = game:GetItemPool()
        local poolType = math.max(0, itemPool:GetPoolForRoom(game:GetRoom():GetType(), pickup:GetDropRNG():GetSeed()))
        local defaultHeartChance = ((pickup:GetDropRNG():RandomInt(1, 8) == 1) and HeartSubType.HEART_SOUL) or HeartSubType.HEART_FULL
        salvageSubtype = (heartSelectionList[poolType] or defaultHeartChance)
    end
    local itemPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, salvageVariant, salvageSubtype, 
        pickup.Position, EntityPickup.GetRandomPickupVelocity(pickup.Position), pickup)
    return itemPickup
end

local collectibleToRecipe = require("scripts.tcainrework.stored.recipe_storage_cache").itemRecipeLookup
local function salvageCollectible(pickup)
    if canSalvageItem(pickup.SubType) then
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
                        pickup.Position, EntityPickup.GetRandomPickupVelocity(pickup.Position), pickup)
                end, ((times + 1) * timeStep), 1, false)
            end
        end
        -- Spawn Salvage
        local itemQuality = Isaac.GetItemConfig():GetCollectible(pickup.SubType).Quality
        spawnSalvagePickup(pickup, PickupVariant.PICKUP_HEART)
        for i = 1, (3 + pickup:GetDropRNG():RandomInt(1, 3) + itemQuality) do
            local salvageVariant = salvageOutcomes:PickOutcome(pickup:GetDropRNG())
            spawnSalvagePickup(pickup, salvageVariant)
        end
        pickup:Remove()
    end
end

local function notShopItemOrBought(player, pickup)
    if pickup:IsShopItem() and getEntityFromTable(pickup, false, player) then
        if ((pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE)
        and ((pickup.Price >= 0) and player:GetNumCoins() >= pickup.Price)) then
            player:AddCoins(-pickup.Price)
            return true
        end
        return false
    end
    return true
end

local skipNext = false
local function initializeSalvage(entity)
    if not salvagingList[GetPtrHash(entity)] then
        skipNext = true
        salvagingList[GetPtrHash(entity)] = true
        salvageCollectible(entity)
        skipNext = false
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    salvagingList, removedEntities = {}, {}
    for playerIndex in pairs(bagCollisions) do
        bagCollisions[playerIndex] = {}
    end
end)

mod:AddPriorityCallback(ModCallbacks.MC_POST_PICKUP_INIT, CallbackPriority.LATE, 
function(_, pickup)
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        if not skipNext then
            local entityList = Isaac.FindInRadius(pickup.Position, 0, EntityPartition.PICKUP)
            for i, entity in ipairs(entityList) do
                if entity.Variant == PickupVariant.PICKUP_COLLECTIBLE
                and (not entity.SpawnerEntity) then
                    initializeSalvage(entity)
                    pickup:Remove()
                end
            end
        end
        -- delete pickups that spawn on deleted gridentities
        local positionHash = utility.sha1(tostring(pickup.Position.X) .. "." .. tostring(pickup.Position.Y))
        for i, playerCollisions in pairs(bagCollisions) do
            for collisionHash in pairs(playerCollisions) do
                if removedEntities[positionHash] and positionHash == collisionHash then
                    print('removing', pickup.Type, pickup.Variant, pickup.SubType, 'of position hash', positionHash)
                    pickup:Remove()
                    playerCollisions[positionHash], removedEntities[positionHash] = nil, nil
                end
            end
        end
    end
end)

local bagInteractPickups = {
    [PickupVariant.PICKUP_GRAB_BAG] = true
}

local function renderBagOfCrafting(player, offset)
    local playerIndex = GetPtrHash(player)
    if (bagSprites[playerIndex] and player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)) then
        local bagSprite = bagSprites[playerIndex]
        if canRenderBagSprite(bagSprite) then
            local bagPosition = Isaac.WorldToRenderPosition(player.Position) - (Vector(0, 3) * bagSprite.Scale)
            if not damageCancelRender(player) then
                bagSprite:Render(bagPosition + offset)
            end
            if not hasRenderedThisFrame[playerIndex] 
            and (not Game():IsPaused())
            and Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
                hasRenderedThisFrame[playerIndex] = true
                -- Null Frame Collisions
                local currentFrame = bagSpritesFrame[playerIndex]
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
                    local isCrawlspace = (Game():GetRoom():GetType() == RoomType.ROOM_DUNGEON)
                    for i, entity in ipairs(foundEntities) do
                        local entityPointer = GetPtrHash(entity)
                        if not bagCollisions[playerIndex][entityPointer] then
                            local knockbackDirection = (entity.Position - swipeCapsule:GetPosition()):Normalized()
                            local pickup = entity:ToPickup()
                            if (((pickup and (notShopItemOrBought(player, pickup) and pickup.Wait <= 0 
                                and (not (pickup:GetSprite():GetAnimation() == "Collect"))))
                                or (not pickup)) and not bagExclusions[entity.Type]) 
                                and (((entity:ForceCollide(player, false) ~= true) 
                                or isCrawlspace) or (pickup and pickup:IsShopItem())) then
                                local tcainPickup = ((pickup and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE)
                                    and (player:GetPlayerType() == PlayerType.PLAYER_CAIN_B))
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
                                        if entity:TakeDamage(8, 0, EntityRef(player), 5)
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
                                            local pickupData = saveManager.GetRerollPickupSave(entity)
                                            pickupData.pickupEntity = player
                                        elseif pickup.Variant == PickupVariant.PICKUP_COIN
                                        and pickup.SubType == CoinSubType.COIN_STICKYNICKEL then
                                            pickup:GetSprite():Play("Touched")
                                        elseif tcainPickup and (not salvagingList[GetPtrHash(entity)] and canSalvageItem(entity.SubType)) then
                                            SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN, 1, 2, false, 1)
                                            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 2, pickup.Position, Vector.Zero, pickup)
                                            player:SalvageCollectible(pickup)
                                            Isaac.CreateTimer(function(_) 
                                                pickup:TriggerTheresOptionsPickup()
                                            end, 8, 1, true)
                                        end
                                    end
                                    if not (pickup and (pickup.Variant == mod.minecraftItemID 
                                        or pickup.Variant == PickupVariant.PICKUP_GRAB_BAG)) then
                                        local knockbackVelocity = ((math.max(1, player.Velocity:Length() / 3) * knockbackDirection) * math.max(20, 40 / entity.Mass))
                                        entity.Velocity = entity.Velocity + knockbackVelocity
                                    end
                                else -- DESTROY item
                                    generateGenericEffect(entity)
                                    bagCollisions[playerIndex][entityPointer] = entity
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
                            and not bagCollisions[playerIndex][entityPointer] then
                                bagCollisions[playerIndex][entityPointer] = entity
                            end
                        end
                    end
                    -- Detect Grid Collisions
                    if currentFrame > 2 then
                        local room = Game():GetRoom()
                        for i = 0, 8 do
                            for j = 0, 2 do
                                local gridEntity = room:GetGridEntityFromPos(swipeCapsule:GetPosition() + Vector(20 * j, 0):Rotated(i * 45))
                                if gridEntity and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE then
                                    local positionHash = utility.sha1(tostring(gridEntity.Position.X) .. "." .. tostring(gridEntity.Position.Y))
                                    if (not bagCollisions[playerIndex][positionHash]) then
                                        local itemTable = getEntityFromTable(gridEntity, true, player)
                                        local ableToAddItem = itemTable and mod:AddItemToInventory(itemTable.Type, itemTable.Amount)
                                        bagCollisions[playerIndex][positionHash] = gridEntity
                                        if not ableToAddItem then
                                            gridEntity:Hurt(3)
                                        else
                                            local lastPosition = Vector(gridEntity.Position.X, gridEntity.Position.Y)
                                            local gridIndex = gridEntity:GetGridIndex()
                                            generateGenericEffect(gridEntity, true)
                                            
                                            removedEntities[positionHash] = gridEntity
                                            room:RemoveGridEntityImmediate(gridIndex, 0, false)
                                            local replacementEntity = Isaac.GridSpawn(gridEntity:GetType(), 0, lastPosition, true)
                                            replacementEntity:Destroy()
                                            if replacementEntity then
                                                replacementEntity:GetSprite():SetRenderFlags(1 << 2)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    -- DebugRenderer.Get(1, true):Capsule(swipeCapsule)
                end
                bagSprite:SetFrame(math.floor(currentFrame))
                bagSprite:Update()
                bagSpritesFrame[playerIndex] = bagSpritesFrame[playerIndex] + 0.5
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
    local playerIndex = GetPtrHash(player)
    local rotation = ((bagSprites[playerIndex] and bagSprites[playerIndex].Rotation) 
        + ((math.min(bagSpritesFrame[playerIndex] or 0, 4) * 180) / 4) % 360)
    if rotation > 90 and rotation < 270 then
        return true
    end
    return false
end

mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, offset)
    hasRenderedThisFrame = {}
    if bagSprites[GetPtrHash(player)]
    and (not renderBagOver(player)) then
        renderBagOfCrafting(player, offset)
    end
end)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, offset)
    if bagSprites[GetPtrHash(player)]
    and (renderBagOver(player)
    or damageCancelRender(player)) then
        renderBagOfCrafting(player, offset)
    end
end)