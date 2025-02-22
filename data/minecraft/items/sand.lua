--[[
    If you're making a Revelations recipe mod, please use sand
    It would make me very happy. :)
--]]

return {
    Properties = {
        DisplayName = "Sand",
        GFX = "gfx/minecraft/blocks/sand.png",
        RenderModel = InventoryItemRenderType.SimpleBlock,
        StackSize = 64,
        Rarity = InventoryItemRarity.COMMON,
        Enchanted = false
    },
    ObtainedFrom = {
        {
            EntityID = "grid.14",
            Amount = 1,
            Condition = function(gridEntity, player)
                if REVEL and gridEntity then
                    local customGrid = StageAPI and StageAPI.GetCustomGrids(gridEntity:GetGridIndex())[1]
                    local customGridName = customGrid and customGrid.GridConfig and customGrid.GridConfig.Name
                    if customGridName and customGridName == "SandCastle" then
                        return {}
                    end
                end
                return false
            end
        },
    }
}