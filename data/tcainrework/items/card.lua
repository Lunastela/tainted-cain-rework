local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Card",
        GFX = "gfx/items/cards/playing_card.png",
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
                -- only accounts for vanilla cards. last card added, so will always be fallback
                local cardConfig = Isaac.GetItemConfig():GetCard(entity.SubType)
                if cardConfig:IsCard() and entity.SubType < Card.NUM_CARDS then
                    return {[InventoryItemComponentData.CARD_TYPE] = entity.SubType}
                end 
                return false
            end
        }
    }
}