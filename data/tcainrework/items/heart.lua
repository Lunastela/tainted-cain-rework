return {
    Properties = {
        DisplayName = "Heart",
        GFX = "gfx/items/heart.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:heart", "#tcainrework:pickup"},
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        "5.10.1",
        {
            EntityID = "5.10.5", 
            Amount = 2
        },
        "5.10.9"
    }
}