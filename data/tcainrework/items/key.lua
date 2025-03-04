return {
    Properties = {
        DisplayName = "Key",
        GFX = "gfx/items/key.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:key", "#tcainrework:pickup", "#tcainrework:metal"},
        ClassicID = BagOfCraftingPickup.BOC_KEY,
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        "5.30.1",
        {
            EntityID = "5.30.3", 
            Amount = 2
        }
    }
}