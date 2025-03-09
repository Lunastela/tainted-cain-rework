local mod = TCainRework

local saveManager = require("scripts.save_manager")
local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
local recipeStorage = require("scripts.tcainrework.stored.recipe_storage_cache")
local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")
local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")

local function recursiveTallyRecipes(recipe, tallyTable)
    for k, ingredient in pairs(recipe.ConditionTable) do
        if itemTagLookup[ingredient] then
            local firstTagItem = itemTagLookup[ingredient][1].Type 
            tallyTable[firstTagItem] = (tallyTable[firstTagItem] or 0) + 1
            goto continue
        end
        local itemIDFromName = collectibleStorage.fastItemIDByName(ingredient)
        if (itemIDFromName ~= -1) and recipeStorage.itemRecipeLookup[itemIDFromName] then
            local nextRecipe = recipeStorage.itemRecipeLookup[itemIDFromName][1]
            recursiveTallyRecipes(recipeStorage.nameToRecipe[nextRecipe], tallyTable)
        else
            tallyTable[ingredient] = (tallyTable[ingredient] or 0) + 1
        end
        ::continue::
    end
end

mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, command, arguments)
    local argList = {}
    for char in string.gmatch(arguments, "[^%s]+") do
        table.insert(argList, char)
    end
    local itemID = ""
    for i, arg in ipairs(argList) do
        itemID = itemID .. arg
        if collectibleStorage.fastItemIDByName(itemID) ~= -1 then
            break
        end
        if i < #argList then
            itemID = itemID .. " "
        end
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
            if itemRegistry[itemID] then
                mod:AddItemToInventory(itemID, tonumber(argList[#argList]) or 1)
            else
                print("Invalid ItemID: Argument 1")
            end
        end
    elseif command == "calculatebaseline" then
        if itemRegistry[itemID] then
            if collectibleStorage.fastItemIDByName(itemID) ~= -1 then
                local itemIDFromName = collectibleStorage.fastItemIDByName(itemID)
                if recipeStorage.itemRecipeLookup[itemIDFromName] then
                    local recipeChosen = tonumber(argList[#argList])
                    for index, recipe in ipairs(recipeStorage.itemRecipeLookup[itemIDFromName]) do
                        if (not recipeChosen) or (recipeChosen == index) then
                            print("Baseline for Recipe", recipe .. ":")
                            local tallyTable = {}
                            recursiveTallyRecipes(recipeStorage.nameToRecipe[recipe], tallyTable)
                            for k, v in pairs(tallyTable) do
                                print(k, v)
                            end
                        end
                    end
                end
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

Console.RegisterCommand("calculatebaseline", 
    "Calculates a baseline cost for an item's recipe", 
    "calculatebaseline [item]", 
    true, AutocompleteType.CUSTOM
)

Console.RegisterCommand("inventoryadd", 
    "Adds an item to the inventory", 
    "inventoryadd [namespace:itemid] [item amount]", 
    true, AutocompleteType.CUSTOM
)

local function customAutocomplete(_, command, arguments)
    if (command == "inventoryadd" or command == "calculatebaseline") then
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
    end
end
mod:AddCallback(ModCallbacks.MC_CONSOLE_AUTOCOMPLETE, customAutocomplete)