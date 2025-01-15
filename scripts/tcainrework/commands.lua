local mod = TCainRework

local saveManager = require("scripts.save_manager")
local recipeLookupIndex = require("scripts.tcainrework.stored.name_to_recipe")
mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, command, arguments)
    local argList = {}
    for char in string.gmatch(arguments, "[^%s]+") do
        table.insert(argList, char)
    end
    if command == "reloadregistry" or command == "reloadregistries" then
        mod:reloadRegistries()
    elseif command == "unlockrecipes" then
        local runSave = saveManager.GetRunSave()
        runSave.unlockedRecipes = {}
        for recipeName in pairs(recipeLookupIndex) do
            if argList[1] == "forced"
            or recipeLookupIndex[recipeName].DisplayRecipe then
                table.insert(runSave.unlockedRecipes, recipeName)
            end
        end
    elseif command == "inventoryadd" then
        if #argList >= 1 then
            local itemID = argList[1]
            if require("scripts.tcainrework.stored.id_to_iteminfo")[itemID] then
                mod:AddItemToInventory(argList[1], tonumber(argList[2]) or 1)
            else
                print("Invalid ItemID: Argument 1")
            end
        end
    end
end)

local runSave = saveManager.GetRunSave()
Console.RegisterCommand("reloadregistry", 
    "Reloads all T. Cain Rework Item Registries", 
    "Reloads all T. Cain Rework Item Registries", 
    true, AutocompleteType.NONE
)

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
local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
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
-- ModCallbacks.MC_CONSOLE_AUTOCOMPLETE