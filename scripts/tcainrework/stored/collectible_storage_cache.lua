local mod = TCainRework

local collectibleStorage = {}
collectibleStorage.nameToIDLookup = {}
collectibleStorage.IDToNameLookup = {}

local itemDescriptions = require("scripts.tcainrework.stored.id_to_iteminfo")
local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")
local utility = require("scripts.tcainrework.util")

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

local eyeItems = {
    [CollectibleType.COLLECTIBLE_EYE_OF_BELIAL] = true,
    [CollectibleType.COLLECTIBLE_EYE_OF_GREED] = true,
    [CollectibleType.COLLECTIBLE_INNER_EYE] = true,
    [CollectibleType.COLLECTIBLE_MOMS_EYE] = true,
    [CollectibleType.COLLECTIBLE_BLOODSHOT_EYE] = true,
    [CollectibleType.COLLECTIBLE_POP] = true,
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

collectibleStorage.itemIterator = 1
collectibleStorage.itemOffset = 0
collectibleStorage.constructed = false
function collectibleStorage:loadCollectibleCache()
    if not collectibleStorage.constructed then
        local itemConfig, currentTime, curCollectible = Isaac.GetItemConfig(), Isaac.GetTime(), nil
        while ((collectibleStorage.itemIterator < CollectibleType.NUM_COLLECTIBLES) or (curCollectible ~= nil)) do
            curCollectible = itemConfig:GetCollectible(collectibleStorage.itemIterator)
            if curCollectible then
                -- Create Registry Entry for item (so we don't have to use the shitty Name to ID function provided)
                local itemName = utility.getLocalizedString("Items", curCollectible.Name)
                collectibleStorage.nameToIDLookup[itemName] = collectibleStorage.itemIterator
                collectibleStorage.IDToNameLookup[collectibleStorage.itemIterator] = itemName

                itemDescriptions[itemName] = {
                    Rarity = curCollectible.Quality,
                    NumericID = collectibleStorage.itemIterator
                }
                -- Check Familiar Types (for item tags with familiars in them)
                if curCollectible.Type == ItemType.ITEM_FAMILIAR then
                    addToTag("#familiar", itemName)
                    if (string.find(string.lower(itemName), "baby")
                    or string.find(string.lower(itemName), "bum") or hardcodedBabies[collectibleStorage.itemIterator]) then
                        addToTag("#baby", itemName)
                    end
                else
                    -- Check if it is a Box for the Box item tag
                    if (string.find(string.lower(itemName), "box")) then
                        addToTag("#box", itemName)
                    end

                    if eyeItems[collectibleStorage.itemIterator] then
                        addToTag("#eye", itemName)
                    end
                end
                -- Check associated config tags with different itemTags
                for tagType, itemConfigTag in pairs(itemTagCounterparts) do
                    if (curCollectible.Tags & tagType ~= 0) then
                        addToTag(itemConfigTag, itemName) 
                    end
                end
            end
            collectibleStorage.itemIterator = collectibleStorage.itemIterator + 1
        end
        collectibleStorage.itemOffset = collectibleStorage.itemIterator
        collectibleStorage.constructed = true
        print("loaded item cache in:", Isaac.GetTime() - currentTime, "ms")
        mod:sortItemTags()
    end
end

function collectibleStorage.fastItemIDByName(name)
    if not collectibleStorage.constructed then
        TCainRework:loadCollectibleCache()
    end
    if (not (collectibleStorage.constructed and collectibleStorage.nameToIDLookup[name])
    and not (string.find(name, "tcainrework") or string.find(name, "minecraft"))) then
        local temporaryDesignation = Isaac.GetItemIdByName(name)
        if temporaryDesignation ~= -1 then
            collectibleStorage.nameToIDLookup[name] = temporaryDesignation
            collectibleStorage.IDToNameLookup[temporaryDesignation] = name
        end
    end
    return collectibleStorage.nameToIDLookup[name] or -1
end

return collectibleStorage