local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Pill",
        GFX = "gfx/items/pills/pill_base.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:pill"},
        UnlockAll = true,
        ClassicID = BagOfCraftingPickup.BOC_PILL,
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
                return {
                    [InventoryItemComponentData.PILL_EFFECT] = pillEffect,
                    [InventoryItemComponentData.PILL_COLOR] = entity.SubType
                }
            end
        }
    }
}