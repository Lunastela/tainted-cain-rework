local mod = TCainRework

local midasTouchFalloff = {}
mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_MIDAS_TOUCH) then
        -- Midas Touch tweaks
        if (entity and entity.SpawnerEntity 
        and (entity:GetMidasFreezeCountdown() > 0)) then
            midasTouchFalloff[GetPtrHash(entity.SpawnerEntity)] = (midasTouchFalloff[GetPtrHash(entity.SpawnerEntity)] or 0) + 1
        end
        -- Clear entity falloff when killed
        if midasTouchFalloff[GetPtrHash(entity)] then
            midasTouchFalloff[GetPtrHash(entity)] = nil
        end
    end
end)

local maxRemoveChance = 10
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, function(_, pickup)
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_MIDAS_TOUCH) then
        local coinSpawns = Isaac.FindInRadius(pickup.Position, 0, EntityPartition.ENEMY)
        for i, spawnerEnemy in pairs(coinSpawns) do
            if spawnerEnemy.SpawnerEntity and midasTouchFalloff[GetPtrHash(spawnerEnemy.SpawnerEntity)] then
                local chanceRemove = spawnerEnemy:GetDropRNG():RandomInt(maxRemoveChance)
                if chanceRemove <= midasTouchFalloff[GetPtrHash(spawnerEnemy.SpawnerEntity)] then
                    pickup:Remove()
                end
            end
            -- Tainted Cain only Coin Nerf
            if PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_CAIN_B) then
                if spawnerEnemy:GetDropRNG():RandomInt(maxRemoveChance) <= 6 then
                    print('*eats ur coin*')
                    pickup:Remove()
                end
            end
        end
    end
end, PickupVariant.PICKUP_COIN)