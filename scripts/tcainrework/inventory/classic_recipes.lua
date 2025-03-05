local ClassicRecipes = {}

--- Returns functionality to emulate classic recipes
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