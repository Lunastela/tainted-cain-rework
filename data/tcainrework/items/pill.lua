local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Pill",
        GFX = "gfx/items/pills/pill_base.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:pill"},
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.70",
            Amount = 1,
            Condition = function(entity, player)
                local pillEffect = Game():GetItemPool():GetPillEffect(entity.SubType)
                local gfxPath = "pill_base_"
                local localizedColor, isHorsePill = utility.getPillColor(entity.SubType)
                gfxPath = (isHorsePill and "horse" or "") .. gfxPath .. tostring(localizedColor) .. ".png"
                return {
                    [InventoryItemComponentData.PILL_EFFECT] = pillEffect,
                    [InventoryItemComponentData.PILL_COLOR] = entity.SubType,
                    [InventoryItemComponentData.CUSTOM_GFX] = "gfx/items/pills/" .. gfxPath
                }
            end
        }
    }
}