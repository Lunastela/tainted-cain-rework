local utility = require("scripts.tcainrework.util")
local runeList = {
    [Card.RUNE_HAGALAZ] = "left",
    [Card.RUNE_JERA] = "left",
    [Card.RUNE_EHWAZ] = "left",
    [Card.RUNE_DAGAZ] = "left",
    [Card.RUNE_ANSUZ] = "right",
    [Card.RUNE_PERTHRO] = "right",
    [Card.RUNE_BERKANO] = "right",
    [Card.RUNE_ALGIZ] = "right",
    [Card.RUNE_BLANK] = "right",
    [Card.RUNE_BLACK] = "black"
}

return {
    Properties = {
        DisplayName = "Rune",
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
                if cardConfig:IsRune() and runeList[entity.SubType] then
                    return { 
                        [InventoryItemComponentData.CUSTOM_GFX] = "gfx/items/cards/" .. runeList[entity.SubType] .. "_rune" .. ".png",
                        [InventoryItemComponentData.CARD_TYPE] = entity.SubType
                    }
                end 
                return false
            end
        }
    }
}