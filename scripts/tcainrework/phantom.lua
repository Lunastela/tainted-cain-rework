local mod = TCainRework
local phantomRenderer = Sprite()
phantomRenderer:Load("gfx/minecraft/phantom.anm2", true)
phantomRenderer:Play("Idle", true)
phantomRenderer:SetCustomShader("shaders/phantom_renderer")
phantomRenderer.Scale = Vector.One * 1.5

local phantomID = Isaac.GetEntityTypeByName("Phantom")
local phantomVariant = Isaac.GetEntityVariantByName("Phantom")

local phantomSoundIdle = Isaac.GetSoundIdByName("Phantom_Idle")
local phantomSoundBite = Isaac.GetSoundIdByName("Phantom_Bite")
local phantomSoundDeath = Isaac.GetSoundIdByName("Phantom_Death")
local phantomSoundFlap = Isaac.GetSoundIdByName("Phantom_Flap")
local phantomSoundHurt = Isaac.GetSoundIdByName("Phantom_Hurt")
local phantomSoundSwoop = Isaac.GetSoundIdByName("Phantom_Swoop")
  
local baseColor = Color(1., 1., 1., 1.)
local function slerp(a, b, amount)
    local difference = math.abs(b - a)
    if difference > 180 then
        if (b > a) then
            a = a + 360
        else
            b = b + 360
        end
    end
    local value = (a + ((b - a) * amount))
    if value >= 0 and value <= 360 then
        return value
    end
    return value % 360
end

local phantomSfxType = {
    IDLE = 0,
    BITE = 1,
    DEATH = 2,
    FLAP = 3,
    HURT = 4,
    SWOOP = 5
}

local function playPhantomSFX(sfxType)
    local sfxManager = SFXManager()
    if sfxType == phantomSfxType.SWOOP then 
        sfxManager:Play(phantomSoundSwoop, 2., 2, false, 0.95 + math.random(0, 15) / 100., 0.)
    elseif sfxType == phantomSfxType.FLAP then 
        sfxManager:Play(phantomSoundFlap, 1., 2, false, 0.95 + math.random(0, 5) / 100., 0.)
    end
end

function mod.summonPhantoms()
    local room = Game():GetRoom()
    local roomSize = ((room:GetCenterPos() - room:GetTopLeftPos()) * 2)
    local spawnPosition = room:GetCenterPos() + Vector.One:Rotated(math.random(0, 360)) * roomSize 
    for i = 1, math.random(2, 4) do
        Isaac.Spawn(phantomID, phantomVariant, 0, spawnPosition + (RandomVector() * math.random(3, 8)), Vector.Zero, nil)
    end
end

local phantomRestingPosition = 0.33
local phantomRestingHeight = 75
local saveManager = require("scripts.save_manager")
local function getPhantomHash(phantom)
    return "p" .. tostring(GetPtrHash(phantom))
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_RENDER, function(_, entity, offset)
    if entity.Variant == phantomVariant then
        local reflected = Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
        local localTime = mod.elapsedTime
        local rotationX, rotationY = 0, phantomRestingPosition + (math.sin(localTime * math.pi / 2.) / 25)
        phantomRenderer.Color = baseColor
        local saveData = saveManager.GetFloorSave()
        if not saveData.phantomTable then
            saveData.phantomTable = {}
        end
        local phantomHash = getPhantomHash(entity)
        if not saveData.phantomTable[phantomHash] then
            saveData.phantomTable[phantomHash] = {}
        end
        local phantomData = saveData.phantomTable[phantomHash]
        if (not (Game():IsPaused() or reflected)) then
            local targetPos = Isaac.GetPlayer(0).Position
            local potentialRotation = (((entity.Position - targetPos):GetAngleDegrees() + 270) % 360)
            local maxCooldown = 270
            if entity.Position:Distance(targetPos) < 128
            or (phantomData.swoopingCooldown or 0) > 32 then
                if not phantomData.swooping then
                    phantomData.swoopingCooldown = (phantomData.swoopingCooldown or 0) + 1
                    if phantomData.swoopingCooldown >= maxCooldown then
                        phantomData.swoopingCooldown = nil
                        phantomData.swooping = true
                    elseif phantomData.swoopingCooldown == 32 then
                        playPhantomSFX(phantomSfxType.SWOOP)
                    end
                end
            end
            if phantomData.swooping then
                if phantomData.endSwooping then
                    if phantomData.hoverPosition < phantomRestingHeight then
                        phantomData.fakeRotation = math.max(phantomData.fakeRotation - 0.125, -1)
                    else 
                        phantomData.fakeRotation = phantomData.fakeRotation + 0.125
                        if phantomData.fakeRotation >= phantomRestingPosition then
                            phantomData.fakeRotation = phantomRestingPosition
                            phantomData.endSwooping = nil
                            phantomData.swooping = nil
                        end
                    end
                else
                    phantomData.fakeRotation = (phantomData.fakeRotation or rotationY)
                    if phantomData.hoverPosition >= 16 then
                        phantomData.fakeRotation = math.min(phantomData.fakeRotation + 0.5, 1.)
                        if phantomData.hoverPosition >= phantomRestingHeight / 2 then
                            phantomData.lockedRotation = (entity.Position - targetPos):GetAngleDegrees()
                        end
                    else
                        phantomData.fakeRotation = math.max(phantomData.fakeRotation - 0.125, 0)
                        phantomData.hoverPosition = math.min(phantomData.hoverPosition, 8 - phantomData.fakeRotation)
                        if entity.Position:Distance(targetPos) > 96 then
                            phantomData.endSwooping = true
                        end
                    end
                    potentialRotation = phantomData.lockedRotation or potentialRotation
                    phantomData.smoothRotation = phantomData.lockedRotation - 90
                end
            else
                phantomData.flapTimer = (phantomData.flapTimer or math.random(90, 180)) - 1
                if phantomData.flapTimer <= 0 then
                    playPhantomSFX(phantomSfxType.FLAP)
                    phantomData.flapTimer = nil
                end
            end
            rotationY = (phantomData.fakeRotation or rotationY)
            phantomData.smoothRotation = slerp(phantomData.smoothRotation or potentialRotation, potentialRotation, 0.05)
            phantomData.hoverPosition = math.max(0, (phantomData.hoverPosition or phantomRestingHeight) - (rotationY - phantomRestingPosition))

            entity.Velocity = entity.Velocity + (Vector.One:Rotated(potentialRotation + 180) / 4.)
            entity.Velocity = entity.Velocity:Resized(math.min(entity.Velocity:Length(), 8.))
        end
        if phantomData.fakeRotation then
            rotationY = phantomData.fakeRotation
        end

        -- phantom rendering
        local hoverVector = Vector(0, phantomData.hoverPosition or phantomRestingHeight)
        local renderPosition = Isaac.WorldToScreen(entity.Position - hoverVector)
        rotationX = 360 - (phantomData.smoothRotation or 0)

        if reflected then
            hoverVector.Y = -hoverVector.Y
            renderPosition = Isaac.WorldToRenderPosition(entity.Position - hoverVector) + offset
            rotationY = -rotationY
        end
        local transposedRotationAngle, transposedRotationCamera = 0., 0.
        transposedRotationCamera = (math.sin(2 * ((rotationX + 90) / 360) * math.pi)) * rotationY
        transposedRotationAngle = (math.cos(2 * ((rotationX + 90) / 360) * math.pi))

        phantomRenderer.Rotation = (((transposedRotationAngle * rotationY) * 45))
        phantomRenderer.Color:SetColorize((rotationX / 360), localTime, transposedRotationCamera * .75 + .5 * (1. - transposedRotationCamera), 0.)
        phantomRenderer:Render(renderPosition)

        -- minecraftFont:DrawString(tostring(phantomRenderer.Rotation), renderPosition.X, renderPosition.Y, KColor(1., 1., 1., 1.))
        return false
    end
end, phantomID)

local phantomHitboxSize = 48
local function canCollideWithPhantom(phantom, entity)
    local saveData = saveManager.TryGetFloorSave()
    if saveData then
        local phantomHash = getPhantomHash(phantom)
        local phantomPosition = (saveData 
            and saveData.phantomTable and saveData.phantomTable[phantomHash]
            and saveData.phantomTable[phantomHash].hoverPosition)
        local entityHash = getPhantomHash(entity)
        local otherPotentialPosition = (saveData 
            and saveData.phantomTable and saveData.phantomTable[entityHash]
            and saveData.phantomTable[entityHash].hoverPosition)
        if phantomPosition and otherPotentialPosition then
            return math.abs(phantomPosition - otherPotentialPosition) <= phantomHitboxSize
        end
        return (phantomPosition or phantomRestingHeight) <= phantomHitboxSize
    end
    return false
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, function(_, entity, collider, low)
    if (entity.Type == phantomID and entity.Variant == phantomVariant
    and (not canCollideWithPhantom(entity, collider))) then
        return true
    end
end, phantomID)

mod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
    if (collider.Type == phantomID and collider.Variant == phantomVariant
    and (not canCollideWithPhantom(collider, tear)))  then
        return true
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, function(_, entity)
    if entity.Type == phantomID and entity.Variant == phantomVariant then
        if not entity:HasEntityFlags(EntityFlag.FLAG_PERSISTENT) then
            entity:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
        end
    end
end, phantomID)

-- Not too dissimilar from my original approach
local function vectorFromIndex(index)
    local x = index % 13
    local y = math.floor(index / 13)
    return Vector(x, y)
end

-- I got this code from Headcrab who got it from someone else who got it from someone else.
local OFFSET_SIZE = Vector(520, 280)
local ROOM_SIZE = Vector(600, 360)
local function getQuadrantOffset(index) -- thanks tem! -- thanks cucco!
    local level = Game():GetLevel()
    local gridIdx = level:GetRoomByIdx(index).GridIndex
    local quadrant = vectorFromIndex(index) - vectorFromIndex(gridIdx)
    
    return quadrant * OFFSET_SIZE
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    if Isaac.IsInGame() then
        local level = Game():GetLevel()
        local previousRoom = level:GetPreviousRoomIndex()
        local currentRoom = level:GetCurrentRoomIndex()
    
        local posOffset = (getQuadrantOffset(currentRoom) - getQuadrantOffset(previousRoom))
        local distance = (vectorFromIndex(currentRoom) - vectorFromIndex(previousRoom)) * ROOM_SIZE
        for i, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity.Type == phantomID and entity.Variant == phantomVariant then
                entity.Position = entity.Position - distance + posOffset
            end
        end

        local currentRoomDesc = level:GetCurrentRoomDesc()
        if currentRoomDesc and currentRoomDesc.GridIndex ~= level:GetStartingRoomIndex() then
            if (mod.getModSettings().doInsomnia or 1) == 2
            and (#Isaac.FindByType(phantomID, phantomVariant) <= 0) then
                if level:GetCurses() & LevelCurse.CURSE_OF_DARKNESS == 0 then
                    level:AddCurse(LevelCurse.CURSE_OF_DARKNESS, false)
                end
                mod.summonPhantoms()
            end
        end
    end
end)