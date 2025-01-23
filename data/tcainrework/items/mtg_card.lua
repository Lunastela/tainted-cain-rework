local utility = require("scripts.tcainrework.util")
local mtgCard = {
    [Card.CARD_CHAOS] = true,
    [Card.CARD_HUGE_GROWTH] = true,
    [Card.CARD_ANCIENT_RECALL] = true,
    [Card.CARD_ERA_WALK] = true
}
return {
    Properties = {
        DisplayName = "Card",
        GFX = "gfx/items/cards/mtg_card.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:card", "#tcainrework:pickup"},
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.300", 
            Amount = 1,
            Condition = function(entity, player)
                if mtgCard[entity.SubType] then
                    return {
                        [InventoryItemComponentData.CUSTOM_DESC] = utility.getLocalizedString(
                            "PocketItems", Isaac.GetItemConfig():GetCard(entity.SubType).Name
                        )
                    }
                end
                return false
            end
        }
    }
}