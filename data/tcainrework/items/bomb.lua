return {
    Properties = {
        DisplayName = "Bomb",
        GFX = "gfx/items/bomb.png",
        RenderModel = InventoryItemRenderType.Default,
        ItemTags = {"#tcainrework:bomb", "#tcainrework:pickup"},
        StackSize = 16,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        "5.40.1",
        {
            EntityID = "5.40.2", 
            Amount = 2
        }
    }
}