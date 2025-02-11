local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Tarot Card",
        GFX = "gfx/items/cards/tarot_reverse.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:card", "#tcainrework:pickup"},
        StackSize = 16,
        Rarity = InventoryItemRarity.UNCOMMON,
        Enchanted = true
    },
    ObtainedFrom = {
        {
            EntityID = "5.300", 
            Amount = 1,
            Condition = function(entity, player)
                if (entity.SubType >= 56 and entity.SubType <= 77) then
                    return {[InventoryItemComponentData.CARD_TYPE] = entity.SubType}
                end
                return false
            end
        }
    }
}