local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Collectible",
        GFX = "gfx/isaac/items/questionmark.png",
        RenderModel = InventoryItemRenderType.Default,
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.100",
            Amount = 1,
            Condition = function(entity, player)
                return utility.generateCollectibleData(entity.SubType)
            end
        }
    }
}