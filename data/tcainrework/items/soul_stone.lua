local utility = require("scripts.tcainrework.util")

return {
    Properties = {
        DisplayName = "Soul Stone",
        GFX = "gfx/items/cards/right_rune.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:rune", "#tcainrework:pickup"},
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.300", 
            Amount = 1,
            Condition = function(entity, player)
                local cardConfig = Isaac.GetItemConfig():GetCard(entity.SubType)
                local localizedName = utility.getLocalizedString("PocketItems", cardConfig.Name)
                if (cardConfig:IsRune() and string.find(string.lower(localizedName), "soul")) then
                    return {[InventoryItemComponentData.CARD_TYPE] = entity.SubType}
                end
                return false
            end
        }
    }
}