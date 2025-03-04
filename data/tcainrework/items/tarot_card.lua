local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Tarot Card",
        GFX = "gfx/items/cards/tarot.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:card", "#tcainrework:pickup"},
        ClassicID = BagOfCraftingPickup.BOC_CARD,
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.300", 
            Amount = 1,
            Condition = function(entity, player)
                if (entity.SubType <= 22) then
                    return {[InventoryItemComponentData.CARD_TYPE] = entity.SubType}
                end
                return false
            end
        }
    }
}