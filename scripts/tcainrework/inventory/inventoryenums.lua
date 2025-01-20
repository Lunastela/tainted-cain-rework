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
    LEGENDARY = 4,
    SUBTEXT = 5,
    EFFECT_POSITIVE = 6,
    EFFECT_NEGATIVE = 7,
    DEBUG_TEXT = 8,
    TUTORIAL_PURPLE = 9,
    INVERT_TEXT = 10
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
    -- TODO change legendary colors
    [InventoryItemRarity.LEGENDARY] = {
        Color = KColor(224 / 255, 165 / 255, 31 / 255, 1),
        Shadow = KColor(114 / 255, 63 / 255, 0 / 255, 1)
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
    COLLECTIBLE_CHARGES = "collectible_charges",
    COLLECTIBLE_USED_BEFORE = "collectible_used_before",
    ENCHANTMENT_OVERRIDE = "enchanted",
}

InventoryToastTypes = {
    TUTORIAL = "tutorial",
    STANDARD = "recipe",
    ADVANCEMENT = "advancement"
}