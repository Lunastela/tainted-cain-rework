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

local bagActions = {
    ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_SHOOTRIGHT, 
    ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_SHOOTDOWN
}
local bagRotations = {90, -90, 180, 0}
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if (player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and (player:GetSprite():GetAnimation():find("Pickup"))) then
        local bagSprite = bagSprites[player.Index]
        if bagSprite and bagSprite:GetAnimation():find("Idle") then
            for i = 1, #bagActions do
                if Input.IsActionPressed(bagActions[i], player.ControllerIndex) then
                    bagSprite:Play("Swing", true)
                    bagSpritesFrame[player.Index] = bagSprite:GetFrame()
                    bagSprite.Scale = player.SpriteScale
                    bagSprite.Rotation = bagRotations[i]
                    player:AnimateCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING, "HideItem")
                    SFXManager():Play(SoundEffect.SOUND_BIRD_FLAP, 1, 2, false, 1 + (math.random(-50, 50) / 1000))
                end
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
local function getEntityFromTable(entity, gridEntity)
    local allVariants = (gridEntity and {entity:GetType(), entity:GetVariant()})
        or {tostring(entity.Type), tostring(entity.Variant), tostring(entity.SubType)}
    for i = #allVariants, 1, -1 do
        local totalString = (gridEntity and "grid." or "") .. allVariants[1]
        for j = 1, i - 1 do
            totalString = totalString .. "." .. allVariants[j + 1]
        end
        if entityToItemLookupTable and entityToItemLookupTable[totalString] then
            if totalString == "5.300" then
                local cardConfig = Isaac.GetItemConfig():GetCard(entity.SubType)
                entityToItemLookupTable[totalString].Type = (cardConfig:IsRune() and "tcainrework:rune" or "tcainrework:card")
            end
            return entityToItemLookupTable[totalString]
        end
    end
    return nil
end 

local unoCard = {
    [Card.CARD_WILD] = true
}

local runeList = {
    [Card.RUNE_HAGALAZ] = "left",
    [Card.RUNE_JERA] = "left",
    [Card.RUNE_EHWAZ] = "left",
    [Card.RUNE_DAGAZ] = "left",
    [Card.RUNE_ANSUZ] = "right",
    [Card.RUNE_PERTHRO] = "right",
    [Card.RUNE_BERKANO] = "right",
    [Card.RUNE_ALGIZ] = "right",
    [Card.RUNE_BLANK] = "right",
    [Card.RUNE_BLACK] = "black"
}

local mtgCard = {
    [Card.CARD_CHAOS] = true,
    [Card.CARD_HUGE_GROWTH] = true,
    [Card.CARD_ANCIENT_RECALL] = true,
    [Card.CARD_ERA_WALK] = true
}
local function getComponentDataFromEntity(entity)
    -- Pills
    if entity.Type == EntityType.ENTITY_PICKUP then 
        if entity.Variant == PickupVariant.PICKUP_PILL then
            local pillEffect = Game():GetItemPool():GetPillEffect(entity.SubType)
            local gfxPath = "pill_base_"
            local localizedColor, isHorsePill = utility.getPillColor(entity.SubType)
            gfxPath = (isHorsePill and "horse" or "") .. gfxPath .. tostring(localizedColor) .. ".png"
            return {
                [InventoryItemComponentData.PILL_EFFECT] = pillEffect,
                [InventoryItemComponentData.PILL_COLOR] = entity.SubType,
                [InventoryItemComponentData.CUSTOM_GFX] = "gfx/items/pills/" .. gfxPath
            }
        elseif entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            return mod.inventoryHelper.generateCollectibleData(entity.SubType)
        elseif entity.Variant == PickupVariant.PICKUP_TAROTCARD then
            -- check if any entity slot specifically exists for this card
            local absoluteIDName = tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType)
            if entityToItemLookupTable[absoluteIDName] then
                return nil
            else -- generic cards
                local gfxPath = "tarot"
                local customName, localizedName, customDescription
                local cardConfig = Isaac.GetItemConfig():GetCard(entity.SubType)
                localizedName = utility.getLocalizedString("PocketItems", cardConfig.Name)
                local returnTable = {}
                if cardConfig:IsCard() then
                    if entity.SubType <= 22 
                    or (entity.SubType >= 56 and entity.SubType <= 77) then
                        customDescription = "Major Arcana"
                        customName = "Tarot Card"
                        if (entity.SubType >= 56 and entity.SubType <= 77) then
                            gfxPath = gfxPath .. "_reverse"
                            customDescription = "Reverse " .. customDescription
                            returnTable[InventoryItemComponentData.ENCHANTMENT_OVERRIDE] = true
                        end
                    elseif unoCard[entity.SubType] then
                        gfxPath = "uno_card"
                        customName = "Uno Card"
                    elseif mtgCard[entity.SubType] then
                        gfxPath = "mtg_card"
                        customName = "Magic: The Gathering Card"
                    else
                        gfxPath = "playing_card"
                    end
                elseif cardConfig:IsRune() then
                    customName = "Rune"
                    gfxPath = "rune_shard"
                    if runeList[entity.SubType] then
                        gfxPath = runeList[entity.SubType] .. "_rune"
                    end
                    if string.find(string.lower(localizedName), "soul") then
                        customName = "Soul Stone"
                    end
                end
                returnTable[InventoryItemComponentData.CUSTOM_GFX] = "gfx/items/cards/" .. gfxPath .. ".png"
                returnTable[InventoryItemComponentData.CUSTOM_DESC] = (((customDescription and (customDescription .. "\n")) or "") .. localizedName)
                returnTable[InventoryItemComponentData.CUSTOM_NAME] = customName
                return returnTable
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

local function renderBagOfCrafting(player, offset)
    if not damageCancelRender(player) and (bagSprites[player.Index]
    and player:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)) then
        local bagSprite = bagSprites[player.Index]
        if canRenderBagSprite(bagSprite) then
            local bagPosition = Isaac.WorldToRenderPosition(player.Position) - (Vector(0, 3) * bagSprite.Scale)
            bagSprite:Render(bagPosition + offset)
            if not hasRenderedThisFrame[player.Index] 
            and (not Game():IsPaused())
            and Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
                hasRenderedThisFrame[player.Index] = true
                -- Null Frame Collisions
                local currentFrame = bagSpritesFrame[player.Index]
                if currentFrame <= 5 then
                    local swipePosition = getBagSwipePosition(bagSprite, player)
                    local swipeCapsule = Capsule(player.Position + swipePosition * 0.75, 
                        player.Position + swipePosition, 25 * player.SpriteScale:Length())
                    local foundEntities = Isaac.FindInCapsule(swipeCapsule, 
                        EntityPartition.ENEMY | EntityPartition.PICKUP | EntityPartition.BULLET
                    )
                    for i, entity in ipairs(foundEntities) do
                        local entityPointer = GetPtrHash(entity)
                        if not utility.tableContains(bagCollisions[player.Index], entityPointer) then
                            local knockbackDirection = (entity.Position - swipeCapsule:GetPosition()):Normalized()
                            local pickup = entity:ToPickup()
                            if ((pickup and ((not pickup:IsShopItem()) 
                            and pickup.Wait <= 0 and (not pickup.Touched)))
                            or (not pickup)) and not bagExclusions[entity.Type] then
                                local tcainPickup = (pickup and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE)
                                    and (player:GetPlayerType() == PlayerType.PLAYER_CAIN_B)
                                local itemTable = (not tcainPickup) and getEntityFromTable(entity)
                                local ableToAddItem = itemTable and mod:AddItemToInventory(
                                    itemTable.Type, itemTable.Amount, getComponentDataFromEntity(entity, player)
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
                                        utility.canOpenChest(pickup, player)
                                        if pickup.Variant == mod.minecraftItemID then
                                            local pickupData = saveManager.GetRoomFloorSave(entity) 
                                                and saveManager.GetRoomFloorSave(entity).RerollSave
                                            pickupData.pickupEntity = player
                                        elseif pickup.Variant == PickupVariant.PICKUP_COIN
                                        and pickup.SubType == CoinSubType.COIN_STICKYNICKEL then
                                            pickup:GetSprite():Play("Touched")
                                        elseif tcainPickup then
                                            SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN, 1, 2, false, 1)
                                            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 2, entity.Position, Vector.Zero, pickup)
                                            player:SalvageCollectible(pickup)
                                            Isaac.CreateTimer(function(_) 
                                                pickup:TriggerTheresOptionsPickup()
                                            end, 8, 1, true)
                                        end
                                    end
                                    if not (pickup and pickup.Variant == mod.minecraftItemID) then
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
                                        local itemTable = getEntityFromTable(gridEntity, true)
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

mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, offset)
    hasRenderedThisFrame = {}
    if bagSprites[player.Index]
    and (bagSprites[player.Index].Rotation == bagRotations[3]
    or (bagSprites[player.Index].Rotation == bagRotations[1] and bagSpritesFrame[player.Index] <= 3)
    or (bagSprites[player.Index].Rotation == bagRotations[2] and bagSpritesFrame[player.Index] > 3)) then
        renderBagOfCrafting(player, offset)
    end
end)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, offset)
    if bagSprites[player.Index]
    and (bagSprites[player.Index].Rotation == bagRotations[4]
    or (bagSprites[player.Index].Rotation == bagRotations[1] and bagSpritesFrame[player.Index] > 3)
    or (bagSprites[player.Index].Rotation == bagRotations[2] and bagSpritesFrame[player.Index] <= 3)) then
        renderBagOfCrafting(player, offset)
    end
end)

-- mod:AddCallback(ModCallbacks.MC_PRE_SFX_PLAY, function(_, ID, Volume, FrameDelay, Loop, Pitch, Pan)
--     print(ID, Volume, FrameDelay, Loop, Pitch, Pan)
-- end)