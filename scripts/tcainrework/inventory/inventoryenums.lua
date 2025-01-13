InventoryTypes = {
    INVENTORY = "Inventory",
    HOTBAR = " ",
    CRAFTING = "Crafting",
    OUTPUT = ""
}

InventoryStates = {
    CLOSED = 0,
    PLAYER = 1,
    CRAFTING = 2
}

InventoryItemRarity = {
    COMMON = 0,
    UNCOMMON = 1,
    RARE = 2,
    EPIC = 3,
    SUBTEXT = 4,
    EFFECT_POSITIVE = 5,
    EFFECT_NEGATIVE = 6,
    DEBUG_TEXT = 7,
    TUTORIAL_PURPLE = 8,
    INVERT_TEXT = 9
}

InventoryItemRenderType = {
    Collectible = -1,
    Default = 0,
    SimpleBlock = 1,
    CraftingTable = 2
}

InventoryItemRarityColors = {
    [InventoryItemRarity.COMMON] = {
        Color = KColor(1, 1, 1, 1),
        Shadow = KColor(62 / 255, 62 / 255, 62 / 255, 1)
    },
    [InventoryItemRarity.UNCOMMON] = {
        Color = KColor(252 / 255, 252 / 255, 84 / 255, 1),
        Shadow = KColor(62 / 255, 62 / 255, 21 / 255, 1)
    },
    [InventoryItemRarity.RARE] = {
        Color = KColor(84 / 255, 252 / 255, 252 / 255, 1),
        Shadow = KColor(21 / 255, 62 / 255, 62 / 255, 1)
    },
    [InventoryItemRarity.EPIC] = {
        Color = KColor(255 / 255, 85 / 255, 255 / 255, 1),
        Shadow = KColor(63 / 255, 21 / 255, 63 / 255, 1)
    },
    -- Subtext / Effect Colors
    [InventoryItemRarity.SUBTEXT] = {
        Color = KColor(168 / 255, 168 / 255, 168 / 255, 1),
        Shadow = KColor(41 / 255, 41 / 255, 41 / 255, 1)
    },
    [InventoryItemRarity.EFFECT_POSITIVE] = {
        Color = KColor(84 / 255, 84 / 255, 252 / 255, 1),
        Shadow = KColor(21 / 255, 21 / 255, 62 / 255, 1)
    },
    [InventoryItemRarity.EFFECT_NEGATIVE] = {
        Color = KColor(252 / 255, 84 / 255, 84 / 255, 1),
        Shadow = KColor(62 / 255, 21 / 255, 21 / 255, 1)
    },
    -- Meta Text Colors
    [InventoryItemRarity.DEBUG_TEXT] = {
        Color = KColor(84 / 255, 84 / 255, 84 / 255, 1),
        Shadow = KColor(21 / 255, 21 / 255, 21 / 255, 1)
    },
    [InventoryItemRarity.TUTORIAL_PURPLE] = {
        Color = KColor(84 / 255, 21 / 255, 84 / 255, 1)
        -- No Shadow
    },
    [InventoryItemRarity.INVERT_TEXT] = {
        Color = KColor(0, 0, 0, 1),
        Shadow = KColor(1, 1, 1, 1)
    },
}

InventoryItemComponentData = {
    PILL_EFFECT = "pill_effect",
    PILL_COLOR = "pill_color",
    CUSTOM_GFX = "custom_gfx",
    CUSTOM_DESC = "custom_desc",
    CUSTOM_NAME = "custom_name",
    COLLECTIBLE_ITEM = "collectible_item",
    ENCHANTMENT_OVERRIDE = "enchanted",
}

InventoryToastTypes = {
    TUTORIAL = "tutorial",
    STANDARD = "recipe",
    ADVANCEMENT = "advancement"
}