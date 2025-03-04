local utility = require("scripts.tcainrework.util")
return {
    Properties = {
        DisplayName = "Rune",
        GFX = "gfx/items/cards/right_rune.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:rune", "#tcainrework:pickup"},
        ClassicID = BagOfCraftingPickup.BOC_RUNE,
        StackSize = 16,
        UnlockAll = true,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "5.300", 
            Amount = 1,
            Condition = function(entity, player)
                local cardConfig = Isaac.GetItemConfig():GetCard(entity.SubType)
                if cardConfig:IsRune() and entity.SubType >= 32 and entity.SubType <= 41 then
                    return {[InventoryItemComponentData.CARD_TYPE] = entity.SubType}
                end 
                return false
            end
        }
    }
}