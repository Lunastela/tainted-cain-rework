local mod = TCainRework
local inventoryHelper = mod.inventoryHelper

local function easeInCubic(x)
    return x * x;
end

local toastList = {}
function mod:CreateToast(toastType, renderItems, renderIcon, toastText, toastSubtext, toastTime, toastCondition)
    local toastSprite = Sprite()
    toastSprite:Load("gfx/ui/toast.anm2", false)
    toastSprite:Play("Idle", true)
    toastSprite:ReplaceSpritesheet(0, "gfx/ui/" .. toastType .. ".png")
    toastSprite:LoadGraphics()
    local myToast = {
        Sprite = toastSprite,
        Time = 0,
        HoldTime = 0,
        Type = toastType,
        RenderItems = renderItems or { { Type = "minecraft:stick", Count = 1 } },
        RenderIcon = renderIcon,
        Text = toastText
            or ((toastType == InventoryToastTypes.STANDARD) and "New Recipe(s) Unlocked!")
            or ((toastType == InventoryToastTypes.ADVANCEMENT) and "Advancement Made!") or "",
        SubText = toastSubtext
            or ((toastType == InventoryToastTypes.STANDARD) and "Check your recipe book") or "",
        ToastTime = toastTime or 180,
        Condition = toastCondition or nil
    }
    table.insert(toastList, myToast)

    -- print(mod.getModSettings().toastControl)
    if ((mod.getModSettings().toastControl or 1) <= 1) then
        SFXManager():Play(Isaac.GetSoundIdByName("Toast_InventoryIn"), 1, 2, false, 1, 0)
    end
    return myToast
end

local customSprite = Sprite()
customSprite:Load("gfx/items/inventoryitem.anm2", true)

local additionConstant = 0.025
local toastStorage = require("scripts.tcainrework.stored.toast_storage")
local activeRecipeToast = nil
mod:AddPriorityCallback(ModCallbacks.MC_POST_HUD_RENDER, CallbackPriority.EARLY, function(_)
    if (not mod.inventoryHelper.isClassicCrafting())
    and (#toastStorage > 0 and (not activeRecipeToast)) then
        activeRecipeToast = TCainRework:CreateToast(
            InventoryToastTypes.STANDARD,
            toastStorage, nil,
            nil, nil,
            180
        )
    end
    local flaggedForDeletion = {}
    for i, toast in pairs(toastList) do
        local toastSprite = toast.Sprite
        toast.Time = toast.Time + additionConstant

        local condition = (toast.Condition and toast.Condition())
        if toast.HoldTime < toast.ToastTime then
            if toast.Time > 1 then
                toast.Time = 1
                toast.HoldTime = toast.HoldTime + 1
            end
            toast.X = 160 - (easeInCubic(toast.Time) * 160)
        elseif (not toast.Condition) or condition then
            if not toast.Reverse then
                if ((mod.getModSettings().toastControl or 1) <= 1) then
                    SFXManager():Play(Isaac.GetSoundIdByName("Toast_InventoryOut"), 1, 2, false, 1, 0)
                end
                toast.Reverse = true
                toast.Time = 0
            else
                if toast.Time > 1 then
                    table.insert(flaggedForDeletion, i)
                end
            end
            toast.X = (easeInCubic(toast.Time) * 160)
        end
        local toastPosition = Vector(Isaac.GetScreenWidth() + (toast.X or 0), (32 * (i - 1)))
        if ((mod.getModSettings().toastControl or 1) < 3) then
            toastSprite:Render(toastPosition)

            if toast.Type and toast.Text and toast.SubText then
                -- Render Toasts and Icons
                toastPosition = (toastPosition - Vector(160, 0)) + Vector(8, 8)

                -- crafting table :sob:
                if (toast.Type == InventoryToastTypes.STANDARD) then
                    inventoryHelper.renderItem({ Type = "minecraft:crafting_table", Count = 1 }, toastPosition - Vector(6, 6),
                        Vector.One / 1.625)
                end

                -- Item Rendering
                local itemToRender = toast.RenderItems[
                math.min(math.max(math.ceil((toast.HoldTime * (#toast.RenderItems)) / toast.ToastTime), 1), #toast.RenderItems)
                ]
                if toast.RenderIcon then
                    if not itemToRender.ComponentData then
                        itemToRender.ComponentData = {}
                    end
                    itemToRender.ComponentData[InventoryItemComponentData.CUSTOM_GFX] = toast.RenderIcon
                end
                inventoryHelper.renderItem(itemToRender, toastPosition)

                -- Text Rendering
                toastPosition.Y = toastPosition.Y - 2
                toastPosition.X = toastPosition.X + 24
                inventoryHelper.renderMinecraftText(toast.Text, toastPosition,
                    ((toast.Type == InventoryToastTypes.ADVANCEMENT) and InventoryItemRarity.UNCOMMON) or
                    InventoryItemRarity.TUTORIAL_PURPLE, false, true)
                toastPosition.Y = toastPosition.Y + 11
                inventoryHelper.renderMinecraftText(toast.SubText, toastPosition,
                    ((toast.Type == InventoryToastTypes.ADVANCEMENT) and InventoryItemRarity.COMMON) or
                    InventoryItemRarity.INVERT_TEXT, false, true)
            end
        end
    end
    if #flaggedForDeletion > 0 then
        for i, j in ipairs(flaggedForDeletion) do
            if activeRecipeToast == toastList[j] then
                for k in ipairs(toastStorage) do
                    toastStorage[k] = nil
                end
                activeRecipeToast = nil
            end
            toastList[j] = nil
        end
    end
    mod.elapsedTime = mod.elapsedTime + 0.0125
end)
