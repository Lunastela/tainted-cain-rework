local ClassicRecipes = {}
--- Returns if classic recipes are enabled
function ClassicRecipes.getClassicRecipeEnabled()
    return (TCainRework.getModSettings().classicCrafting == 2)
end

function ClassicRecipes.emulateRecipe(player, bagContents)
    -- just in case, but not really necessary
    local previousBagContent, previousBagOutput = player:GetBagOfCraftingContent(), player:GetBagOfCraftingOutput()
    player:SetBagOfCraftingContent(bagContents)
    local forcedOutput = player:GetBagOfCraftingOutput()
    player:SetBagOfCraftingContent(previousBagContent)
    player:SetBagOfCraftingOutput(previousBagOutput)
    return forcedOutput
end

return ClassicRecipes