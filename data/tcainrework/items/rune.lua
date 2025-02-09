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
                if cardConfig:IsRune() then
                    local gfxName = (((runeList[entity.SubType] ~= nil) and runeList[entity.SubType]) or "shard") .. "_rune"
                    local localizedName = utility.getLocalizedString("PocketItems", cardConfig.Name)
                    local isSoulStone = string.find(string.lower(localizedName), "soul")
                    if isSoulStone then
                        gfxName = string.lower(localizedName):gsub("% ", "_")
                    end
                    return { 
                        [InventoryItemComponentData.CUSTOM_NAME] = (isSoulStone and "Soul Stone") or nil,
                        [InventoryItemComponentData.CUSTOM_GFX] = "gfx/items/cards/" .. gfxName .. ".png",
                        [InventoryItemComponentData.CARD_TYPE] = entity.SubType
                    }
                end 
                return false
            end
        }
    }
}