return {
    Properties = {
        DisplayName = "Penny",
        GFX = "gfx/items/penny.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:small_coin", "#tcainrework:small_pickup"},
        ClassicID = BagOfCraftingPickup.BOC_PENNY,
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        "5.20.1",
        {
            EntityID = "5.20.4", 
            Amount = 2
        }
    }
}