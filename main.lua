-- Register the Mod
local mod = RegisterMod("CainCraftingTable", 1)
TCainRework = mod

local saveManager = require("scripts.save_manager")
saveManager.Init(mod)

local utility = require("scripts.tcainrework.util")
include("scripts.tcainrework.inventory.inventoryenums")
mod.inventoryHelper = include("scripts.tcainrework.inventory.inventoryhelper")

include("scripts.tcainrework.deadseascrolls")

-- Render Scale Options
if Options.MaxRenderScale <= 3 then
    Options.MaxRenderScale = 3
end
mod.elapsedTime = 0

-- Load Mod Data
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
local collectibleToRecipe = require("scripts.tcainrework.stored.collectible_to_recipe")

local function sortItemTags()
    for tagName in pairs(itemTagLookup) do
        table.sort(itemTagLookup[tagName], function(a, b)
            return ((itemDescriptions[a].Rarity == itemDescriptions[b].Rarity)
                    and (itemDescriptions[a].NumericID < itemDescriptions[b].NumericID))
                or (itemDescriptions[a].Rarity) < (itemDescriptions[b].Rarity)
        end)
    end
end

local index = 0

-- Define Load Order list
mod.LoadOrder = {}
function mod:loadRegistry(curLoad)
    -- Items
    registerFromLoadOrder(curLoad.Namespace, curLoad.Items, "items",
        function(registryName, foundData)
            if foundData and foundData.Properties then
                index = index + 1
                numberToItems[index] = registryName
                foundData.Properties.NumericID = index
                itemDescriptions[registryName] = foundData.Properties
                if foundData.ObtainedFrom then -- Register Entities that turn into this item
                    for _, entity in ipairs(foundData.ObtainedFrom) do
                        -- if entity has conditional or entity table already exists
                        local entityID = entity.EntityID or entity
                        local entityTable = {
                            Type = registryName,
                            Amount = entity.Amount or 1,
                            Condition = entity.Condition or nil
                        }
                        if entityToItemConversions[entityID] then
                            -- convert into larger table for multiple entities
                            if entityToItemConversions[entityID].Type then
                                local storedEntity = {
                                    Type = entityToItemConversions[entityID].Type,
                                    Amount = entityToItemConversions[entityID].Amount or 1,
                                    Condition = entityToItemConversions[entityID].Condition or nil
                                }
                                entityToItemConversions[entityID] = {}
                                table.insert(entityToItemConversions[entityID], storedEntity)
                            end
                            -- insert entity table
                            table.insert(entityToItemConversions[entityID], entityTable)
                        else
                            entityToItemConversions[entityID] = entityTable
                        end
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
                            local nameType = mod.inventoryHelper.conditionalItemLookupType(mod.inventoryHelper.createItem(itemType))
                            if not recipeReverseLookup[nameType] then
                                recipeReverseLookup[nameType] = {}
                            end
                            if (not utility.tableContains(recipeReverseLookup[nameType], recipeName)) then
                                table.insert(recipeReverseLookup[nameType], recipeName)
                            end
                        end
                    end
                    if recipeData.Results
                    and recipeData.Results.Collectible
                    and recipeData.DisplayRecipe then
                        local collectible = utility.fastItemIDByName(recipeData.Results.Collectible)
                        if not collectibleToRecipe[collectible] then
                            collectibleToRecipe[collectible] = {}
                        end
                        if (not utility.tableContains(collectibleToRecipe[collectible], recipeName)) then
                            table.insert(collectibleToRecipe[collectible], recipeName)
                        end
                    end
                end
            end
        end
    end
    -- sort item tags
    sortItemTags()

    for i, loadedMod in ipairs(mod.LoadOrder) do
        if (loadedMod.Namespace and curLoad.Namespace)
        and (loadedMod.Namespace == curLoad.Namespace) then
            mod.LoadOrder[i] = curLoad
            return true
        end
    end
    return table.insert(mod.LoadOrder, curLoad)
end

mod:loadRegistry(include("loadorder"))
mod:loadRegistry(include("loadorder_minecraft"))


local function getItemTag(tagName)
    if not itemTagLookup[tagName] then
        itemTagLookup[tagName] = {}
    end
    return itemTagLookup[tagName]
end

local hardcodedBabies = {
    [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = true,
    [CollectibleType.COLLECTIBLE_SISTER_MAGGY] = true,
    [CollectibleType.COLLECTIBLE_BUMBO] = true,
    [CollectibleType.COLLECTIBLE_GUARDIAN_ANGEL] = true,
    [CollectibleType.COLLECTIBLE_SWORN_PROTECTOR] = true,
    [CollectibleType.COLLECTIBLE_LITTLE_CHAD] = true,
    [CollectibleType.COLLECTIBLE_LOST_SOUL] = true,
    [CollectibleType.COLLECTIBLE_ABEL] = true,
    [CollectibleType.COLLECTIBLE_INCUBUS] = true,
    [CollectibleType.COLLECTIBLE_TWISTED_PAIR] = true,
    [CollectibleType.COLLECTIBLE_LIL_BRIMSTONE] = true,
    [CollectibleType.COLLECTIBLE_LIL_ABADDON] = true,
}

local itemTagCounterparts = {
    [ItemConfig.TAG_FLY] = "#fly",
    [ItemConfig.TAG_FOOD] = "#food",
    [ItemConfig.TAG_BOOK] = "#book",
    [ItemConfig.TAG_TEARS_UP] = "#tears_up",
    [ItemConfig.TAG_MUSHROOM] = "#mushroom",
    [ItemConfig.TAG_SPIDER] = "#spider",
    [ItemConfig.TAG_POOP] = "#poop",
    [ItemConfig.TAG_ANGEL] = "#seraphim",
    [ItemConfig.TAG_DEVIL] = "#leviathan"
}

-- the things we do for performance :sob:
local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")
local function addToTag(tagName, itemName)
    local myTag = getItemTag(tagName)
    if not utility.tableContains(myTag, itemName) then
        table.insert(myTag, itemName)
        if not itemDescriptions[itemName].ItemTags then
            itemDescriptions[itemName].ItemTags = {}
        end
        if not utility.tableContains(itemDescriptions[itemName].ItemTags, tagName) then
            table.insert(itemDescriptions[itemName].ItemTags, tagName)
        end
    end
end
function mod:loadCollectibleCache()
    local itemConfig = Isaac.GetItemConfig()
    local curCollectible, iterator = nil, 1
    local currentTime = Isaac.GetTime()
    while ((iterator < CollectibleType.NUM_COLLECTIBLES) or (curCollectible ~= nil)) do
        curCollectible = itemConfig:GetCollectible(iterator)
        if curCollectible then
            -- Create Registry Entry for item (so we don't have to use the shitty Name to ID function provided)
            local itemName = utility.getLocalizedString("Items", curCollectible.Name)
            collectibleStorage.nameToIDLookup[itemName] = iterator
            collectibleStorage.IDToNameLookup[iterator] = itemName

            itemDescriptions[itemName] = {
                Rarity = curCollectible.Quality,
                NumericID = (index + iterator)
            }
            -- Check Familiar Types (for item tags with familiars in them)
            if curCollectible.Type == ItemType.ITEM_FAMILIAR then
                addToTag("#familiar", itemName)
                if (string.find(string.lower(itemName), "baby")
                or string.find(string.lower(itemName), "bum") or hardcodedBabies[iterator]) then
                    addToTag("#baby", itemName)
                end
            else
                -- Check if it is a Box for the Box item tag
                if (string.find(string.lower(itemName), "box")) then
                    addToTag("#box", itemName)
                end
            end
            -- Check associated config tags with different itemTags
            for tagType, itemConfigTag in pairs(itemTagCounterparts) do
                if (curCollectible.Tags & tagType ~= 0) then
                    addToTag(itemConfigTag, itemName) 
                end
            end
        end
        iterator = iterator + 1
    end
    collectibleStorage.constructed = true
    print("loaded item cache in:", Isaac.GetTime() - currentTime)
    sortItemTags()
end
mod:AddPriorityCallback(ModCallbacks.MC_POST_MODS_LOADED, CallbackPriority.LATE, mod.loadCollectibleCache)

-- Load Supplementaries
include("scripts.tcainrework.bagreimplementation")
include("scripts.tcainrework.itementity")
include("scripts.tcainrework.inventory")
include("scripts.tcainrework.toasts")
include("scripts.tcainrework.commands")
include("scripts.tcainrework.phantom")
-- include("scripts.tcainrework.player")