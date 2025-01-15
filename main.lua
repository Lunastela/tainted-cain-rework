-- Register the Mod
local mod = RegisterMod("CainCraftingTable", 1)
TCainRework = mod

local saveManager = require("scripts.save_manager")
saveManager.Init(mod)
local utility = require("scripts.tcainrework.util")

-- Render Scale Options
if Options.MaxRenderScale <= 3 then
    Options.MaxRenderScale = 3
end
mod.elapsedTime = 0

-- Load Mod Data
include("scripts.tcainrework.inventory.inventoryenums")
local loadedIDs = {}
local function registerFromLoadOrder(namespace, orderList, dataFolder, returnFunction)
    if orderList then
        for loadFile in orderList:gmatch("(.-)\n") do
            local filename = loadFile:match("^%s*(.-)%s*$")
            local fullPath = "data." .. namespace .. "." .. dataFolder .. "." .. filename
            local pathExists, foundData = pcall(include, fullPath)
            if pathExists then
                local fullname = namespace .. ":" .. filename
                table.insert(loadedIDs, fullname)
                returnFunction(fullname, foundData)
            end
        end
    end
end

local itemDescriptions = require("scripts.tcainrework.stored.id_to_iteminfo")
local numberToItems = require("scripts.tcainrework.stored.num_to_id")
local entityToItemConversions = require("scripts.tcainrework.stored.entityid_to_id")
local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")
-- Recipes
local recipeStorage = require("scripts.tcainrework.stored.recipe_hashmap")
local recipeLookupIndex = require("scripts.tcainrework.stored.name_to_recipe")
local recipeReverseLookup = require("scripts.tcainrework.stored.recipe_from_ingredient")

local index = 0
function mod:loadRegistry(curLoad)
    -- Items
    registerFromLoadOrder(curLoad.Namespace, curLoad.Items, "items",
    function (registryName, foundData)
        if foundData and foundData.Properties then
            index = index + 1
            numberToItems[index] = registryName
            foundData.Properties.NumericID = index 
            itemDescriptions[registryName] = foundData.Properties
            if foundData.ObtainedFrom then -- Register Entities that turn into this item
                for _, entity in ipairs(foundData.ObtainedFrom) do
                    entityToItemConversions[entity.EntityID or entity] = {
                        Type = registryName, 
                        Amount = entity.Amount or 1
                    }
                end
            end
            local currentItemTags = foundData.Properties.ItemTags
            if currentItemTags then
                for i, itemTag in ipairs(currentItemTags) do
                    if not itemTagLookup[itemTag] then
                        itemTagLookup[itemTag] = {}
                    end
                    if not utility.tableContains(itemTagLookup[itemTag], registryName) then
                        table.insert(itemTagLookup[itemTag], registryName)
                    end
                end
            end
        else
            print('registry unavailable:', registryName)
        end
    end)
    -- Recipes
    local recipePath = "data." .. curLoad.Namespace .. ".recipe_hashes"
    local pathExists, foundData = pcall(include, recipePath)
    if pathExists then
        for key, value in pairs(foundData) do
            if not recipeStorage[key] then
                recipeStorage[key] = {}
            end
            for i, recipeData in ipairs(value) do
                table.insert(recipeStorage[key], recipeData)
                local recipeName = recipeData and recipeData.RecipeName
                if recipeName then
                    recipeLookupIndex[recipeName] = recipeData
                    if recipeData.ConditionTable then
                        for i, itemType in pairs(recipeData.ConditionTable) do
                            local nameType = itemType
                            if Isaac.GetItemIdByName(itemType) ~= -1 then
                                nameType = "tcainrework:collectible" .. tostring(Isaac.GetItemIdByName(itemType))
                            end
                            if not recipeReverseLookup[nameType] then
                                recipeReverseLookup[nameType] = {}
                            end
                            if (not utility.tableContains(recipeReverseLookup[nameType], recipeName)) then
                                table.insert(recipeReverseLookup[nameType], recipeName)
                            end
                        end
                    end
                end
            end
        end
    end
    return curLoad
end

-- Define Load Order list
mod.LoadOrder = { -- If you wish to add your own items, add them to this list using table.insert() before MC_POST_MODS_LOADED
    mod:loadRegistry(include("loadorder")),
    mod:loadRegistry(include("loadorder_minecraft"))
}

function mod:reloadRegistries()
    local currentTime = Isaac.GetTime()
    for _, curLoad in ipairs(mod.LoadOrder) do
        mod:loadRegistry(curLoad)
    end
    local allIds = ""
    for i, id in ipairs(loadedIDs) do
        allIds = allIds .. id
        if i < #loadedIDs then
            allIds = allIds .. ", "
        end
    end
    print("reloaded registries,", Isaac.GetTime() - currentTime, "ms elapsed", "{" .. allIds .. "}")
end

-- Load Supplementaries
mod.inventoryHelper = include("scripts.tcainrework.inventory.inventoryhelper")
include("scripts.tcainrework.bagreimplementation")
include("scripts.tcainrework.itementity")
include("scripts.tcainrework.inventory")
include("scripts.tcainrework.toasts")
include("scripts.tcainrework.commands")