local mod = TCainRework

local saveManager = require("scripts.save_manager")
local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
local recipeStorage = require("scripts.tcainrework.stored.recipe_storage_cache")
mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, command, arguments)
    local argList = {}
    for char in string.gmatch(arguments, "[^%s]+") do
        table.insert(argList, char)
    end
    if command == "unlockrecipes" then
        local runSave = saveManager.GetRunSave()
        runSave.unlockedRecipes = {}
        for recipeName in pairs(recipeStorage.nameToRecipe) do
            if argList[1] == "forced" or recipeStorage.nameToRecipe[recipeName].DisplayRecipe then
                table.insert(runSave.unlockedRecipes, recipeName)
            end
        end
    elseif command == "inventoryadd" then
        if #argList >= 1 then
            local itemID = argList[1]
            if itemRegistry[itemID] then
                mod:AddItemToInventory(argList[1], tonumber(argList[2]) or 1)
            else
                print("Invalid ItemID: Argument 1")
            end
        end
    elseif command == "insomnia" then
        mod.summonPhantoms()
    end
end)

Console.RegisterCommand("unlockrecipes", 
    "Unlocks all T. Cain Rework Recipes", 
    "Unlocks all T. Cain Rework Recipes", 
    true, AutocompleteType.NONE
)

Console.RegisterCommand("inventoryadd", 
    "Adds an item to the inventory", 
    "inventoryadd [namespace:itemid] [item amount]", 
    true, AutocompleteType.CUSTOM
)
mod:AddCallback(ModCallbacks.MC_CONSOLE_AUTOCOMPLETE, function(_, command, arguments)
    local argList = {}
    for char in string.gmatch(arguments, "[^%s]+") do
        table.insert(argList, char)
    end
    local itemID = argList[1] or ""
    local returnList = {}
    for registryItem in pairs(itemRegistry) do
        if itemID == "" or string.find(registryItem, itemID) then
            table.insert(returnList, registryItem)
        end
    end
    table.sort(returnList)
    return returnList
end, "inventoryadd")