local inventoryHelper = {}

local saveManager = require("scripts.save_manager")
local utility = require("scripts.tcainrework.util")

local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")

local recipeStorage = require("scripts.tcainrework.stored.recipe_storage_cache")
local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")
local classicCrafting = include("scripts.tcainrework.inventory.classic_recipes")
--[[
    Pardon the mess, I am currently in the process of rewriting large chunks of the inventory system to be
    modular for if ever in the future I decide I want to add more inventory types with ease.

    As of now this is half object oriented structure and half functional structure that assumes a lot of
    key details about the inventory. In the future this shouldn't be the case.
--]]

function inventoryHelper.getNameFor(pickup)
    if pickup.ComponentData then
        if pickup.ComponentData[InventoryItemComponentData.CUSTOM_NAME] then
            return pickup.ComponentData[InventoryItemComponentData.CUSTOM_NAME]
        end
        if pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
            return utility.getLocalizedString("Items", utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]).Name, true)
        end
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].DisplayName then
        return utility.getCustomLocalizedString(
            "items." .. string.gsub(pickup.Type, ":", ".") .. ".name", 
            itemRegistry[pickup.Type].DisplayName
        )
    end
    return "Bone"
end

-- this function doesn't need to exist anymore i have streamlined its functionality
local function isActiveFromComponent(itemID)
    return (utility.getCollectibleConfig(itemID).Type == ItemType.ITEM_ACTIVE)
end

function inventoryHelper.getMaxStackFor(pickup)
    -- limited stack size for active items
    if pickup.ComponentData
    and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
    and isActiveFromComponent(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]) then
        return 1
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].StackSize then
        return itemRegistry[pickup.Type].StackSize
    end
    return 16
end

function inventoryHelper.getNumericIDFor(pickup) 
    if pickup.ComponentData
    and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
        return (TCainRework.itemIterator + pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].NumericID then
        return itemRegistry[pickup.Type].NumericID
    end
    return 0
end

local itemRarities = InventoryItemRarity
function inventoryHelper.getItemRarity(pickup)
    if pickup.ComponentData 
    and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
        return utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]).Quality
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].Rarity then
        return itemRegistry[pickup.Type].Rarity
    end
    return itemRarities.COMMON
end

function inventoryHelper.getDefaultEnchanted(pickup)
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].Enchanted then
        return itemRegistry[pickup.Type].Enchanted
    end
    return false
end

local renderTypes = InventoryItemRenderType
function inventoryHelper.getItemRenderType(pickupType)
    if itemRegistry[pickupType] 
    and itemRegistry[pickupType].RenderModel then
        return itemRegistry[pickupType].RenderModel
    end
    return renderTypes.Default
end

function inventoryHelper.getItemUnlocked(item)
    local persistentGameData = Isaac.GetPersistentGameData()
    if item.ComponentData and item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
        local collectibleConfig = utility.getCollectibleConfig(item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
        if collectibleConfig and collectibleConfig.AchievementID then
            return persistentGameData:Unlocked(collectibleConfig.AchievementID)
        end
    end
    return true
end

local levelObject = (Game() and Game():GetLevel()) or nil
TCainRework:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
    levelObject = Game():GetLevel()
end)

local function getCurseOfBlind()
    if levelObject 
    and (not PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BLACK_CANDLE)) then
        return (levelObject:GetCurses() & LevelCurse.CURSE_OF_BLIND ~= 0)
    end
    return false
end

local dummySprite = Sprite()
dummySprite:Load("gfx/items/inventoryitem.anm2", false)

local spriteLookupTable = {}
local interval = 4
local function getCustomCollectibleSprite(itemID)
    local canDisplaySprites = TCainRework.getModSettings().customCollectibleSprites
    if canDisplaySprites and (canDisplaySprites == 2) then
        return -1
    end
    local itemConfig = utility.getCollectibleConfig(itemID)
    local lastIndex = string.find(itemConfig.GfxFileName, "/[^/]*$")
    local spritesheetPath = string.lower(itemConfig.GfxFileName:sub(lastIndex + 1))
    local spriteFullPath = "gfx/isaac/items/" .. spritesheetPath
    if not spriteLookupTable[spritesheetPath] then
        dummySprite:ReplaceSpritesheet(0, spriteFullPath)
        dummySprite:LoadGraphics()
        dummySprite:SetFrame("Idle", 0)
        for i = -16, 16, interval do
            for j = -16, 16, interval do
                local positionVector = Vector(i, j)
                local result = dummySprite:GetTexel(positionVector, Vector.Zero, 1, 0)
                if (result.Red ~= 0 or result.Green ~= 0
                        or result.Blue ~= 0 or result.Alpha ~= 0) then
                    spriteLookupTable[spritesheetPath] = spriteFullPath
                    goto spriteFound
                end
            end
        end
        spriteLookupTable[spritesheetPath] = -1
        ::spriteFound::
    end
    return spriteLookupTable[spritesheetPath]
end

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

function inventoryHelper.getItemGraphic(pickup)
    if pickup.ComponentData then
        -- test custom gfx
        if pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX] then
            return pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX]
        end
        -- Hardcoded Pill Colors
        if (pickup.ComponentData[InventoryItemComponentData.PILL_COLOR]
        or pickup.ComponentData[InventoryItemComponentData.PILL_EFFECT]) then
            local gfxPath, isHorsePill = "", false
            if pickup.ComponentData[InventoryItemComponentData.PILL_COLOR] then
                local localizedColor = -1
                localizedColor, isHorsePill = utility.getPillColor(pickup.ComponentData[InventoryItemComponentData.PILL_COLOR])
                gfxPath = "_" .. gfxPath .. tostring(localizedColor)
            elseif pickup.ComponentData[InventoryItemComponentData.PILL_EFFECT] then -- backup pill color if the pill is discovered
                local itemPool = Game():GetItemPool()
                local pillColor = itemPool:GetPillColor(pickup.ComponentData[InventoryItemComponentData.PILL_EFFECT])
                if itemPool:IsPillIdentified(pillColor) then
                    gfxPath = "_" .. pillColor
                end
            end
            return  "gfx/items/pills/" .. (isHorsePill and "horse" or "") .. "pill_base" .. gfxPath .. ".png"
        end

        -- hardcoding runes
        if (pickup.ComponentData[InventoryItemComponentData.CARD_TYPE]) then
            if (pickup.Type == "tcainrework:soul_stone") then
                local localizedName = utility.getLocalizedString(
                    "PocketItems", utility.getCardConfig(pickup.ComponentData[InventoryItemComponentData.CARD_TYPE]).Name
                )
                local soulName = string.lower(localizedName):gsub("% ", "_")
                if soulName == "soul_of_???" then
                    soulName = "soul_of_blue_baby"
                end
                return "gfx/items/cards/" .. soulName .. ".png"
            end
            if runeList[pickup.ComponentData[InventoryItemComponentData.CARD_TYPE]] then
                return "gfx/items/cards/" .. runeList[pickup.ComponentData[InventoryItemComponentData.CARD_TYPE]] .. "_rune.png"
            end
        end

        if pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
            local customGfx = getCustomCollectibleSprite(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            if getCurseOfBlind() then
                return ((customGfx ~= -1) and "gfx/isaac/items/questionmark.png") or "gfx/items/collectibles/questionmark.png"
            end
            if customGfx ~= -1 then
                return getCustomCollectibleSprite(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            end
            return utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]).GfxFileName
        end
    end
    if itemRegistry[pickup.Type] 
    and itemRegistry[pickup.Type].GFX then
        return itemRegistry[pickup.Type].GFX
    end
    return ""
end

-- Registering Inventories
local inventoryInformation = {}
function inventoryHelper.createInventory(width, height, name, renderFunction, resultOnly)
    local runSave = saveManager.GetRunSave()
    if not runSave.Inventories then
        runSave.Inventories = {}
    end
    inventoryHelper.getInventory(name)
    inventoryInformation[runSave.Inventories[name]] = {
        Width = width, 
        Height = height, 
        Name = name, 
        RenderFunction = renderFunction, 
        ResultOnly = resultOnly
    }
end

function inventoryHelper.getInventory(inventoryType)
    local runSave = saveManager.GetRunSave()
    if not runSave.Inventories then
        runSave.Inventories = {}
    end
    if not runSave.Inventories[inventoryType] then
        runSave.Inventories[inventoryType] = {}
    end
    return runSave.Inventories[inventoryType]
end

local function unlockWrapper()
    local minecraftJumpscare = TCainRework.getModSettings().minecraftJumpscare
    return ((minecraftJumpscare == 2) and saveManager.GetRunSave())
        or saveManager.GetPersistentSave()
end

local function recipeStorageWrapper()
    local recipeUnlockStyle = TCainRework.getModSettings().recipeUnlockStyle
    local saveStorage = ((recipeUnlockStyle == 2) and saveManager.GetPersistentSave()) or saveManager.GetRunSave()
    if not saveStorage.unlockedRecipes then
        saveStorage.unlockedRecipes = {}
    end
    return saveStorage.unlockedRecipes
end

function inventoryHelper.getUnlockedInventory(setUnlocked)
    local runSave = unlockWrapper()
    if not runSave.inventoryUnlocked and setUnlocked then
        local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
        if player then
            local wasOpen = false
            TCainRework:CreateToast(
                InventoryToastTypes.TUTORIAL, 
                nil, "gfx/ui/recipe_book.png", 
                "Open your inventory", "Press §l" .. (((player.ControllerIndex > 0) and "RIGHT STICK") or "I"),
                240,
                function()
                    if (TCainRework.getInventoryState() == InventoryStates.CRAFTING) then
                        wasOpen = true
                    end
                    return wasOpen
                end
            )
            runSave.inventoryUnlocked = setUnlocked
        end
    end
    return runSave.inventoryUnlocked
end

function inventoryHelper.getCollectibleCrafted(setUnlocked)
    local runSave = unlockWrapper()
    if not runSave.collectibleCrafted and setUnlocked then
        local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
        if player and player.ControllerIndex > 0 then
            TCainRework:CreateToast(
                InventoryToastTypes.TUTORIAL, 
                nil, "gfx/ui/button_alt.png", 
                "Switch inventory slots", "Hold §lRT§r, press §lLB§r or §lRB§r",
                640
            )
            TCainRework:CreateToast(
                InventoryToastTypes.TUTORIAL, 
                nil, "gfx/ui/button_alt_2.png", 
                "Consume a collectible", "Hold §lRT§r and §lLT",
                640
            )
        else
            TCainRework:CreateToast(
                InventoryToastTypes.TUTORIAL, 
                nil, "gfx/ui/right_click.png", 
                "Consume a collectible", "Hold §lRMB",
                240
            )
        end
        runSave.collectibleCrafted = setUnlocked
    end
    return runSave.collectibleCrafted
end

inventoryHelper.IsClassicCrafting = false
--- Classic Crafting Wrapper
function inventoryHelper.isClassicCrafting()
    return (saveManager.GetRunSave().ClassicCrafting or false)
end

function inventoryHelper.getRecipeBookOpen()
    if inventoryHelper.isClassicCrafting() then
        return false
    end
    local settingsSave = saveManager.GetSettingsSave()
    if settingsSave then
        return settingsSave.RecipeBookEnabled
    end
    return true
end

function inventoryHelper.setRecipeBookOpen(isOpen)
    local settingsSave = saveManager.GetSettingsSave()
    if settingsSave then
        settingsSave.RecipeBookEnabled = isOpen
    end
end

function inventoryHelper.getRecipeBookFilter()
    local settingsSave = saveManager.GetSettingsSave()
    if settingsSave then
        return settingsSave.RecipeBookFilter
    end
    return false
end

function inventoryHelper.setRecipeBookFilter(isEnabled)
    local settingsSave = saveManager.GetSettingsSave()
    if settingsSave then
        settingsSave.RecipeBookFilter = isEnabled
    end
end

local json = require("json")
--- Creates an item object.
function inventoryHelper.createItem(itemString, count)
    local itemType, componentData, forcedCollectible = itemString, nil, nil
    local isNumber = (type(itemString) == "number")
    if isNumber or tonumber(itemString) then
        forcedCollectible = ((isNumber and itemString) or tonumber(itemString))
    else
        local splitPosition = itemString:find("{")
        if splitPosition then
            itemType = itemString:sub(1, splitPosition - 1)
            componentData = json.decode(itemString:sub(splitPosition, -1))
            -- Sanitize Data
            if componentData then 
                -- Card Checking
                if componentData[InventoryItemComponentData.CARD_TYPE] then
                    local cardID = Isaac.GetCardIdByName(componentData[InventoryItemComponentData.CARD_TYPE])
                    if cardID ~= -1 then
                        componentData[InventoryItemComponentData.CARD_TYPE] = cardID
                    end
                end
            end
        end
    end
    if forcedCollectible or (collectibleStorage.fastItemIDByName(itemString) ~= -1) then
        componentData = utility.generateCollectibleData(forcedCollectible or collectibleStorage.fastItemIDByName(itemString))
        itemType = "tcainrework:collectible"
    end
    return {
        Type = itemType,
        Count = count or 1,
        ComponentData = componentData
    }
end

--- Creates a unique hash for an item based on its components.
--- Should replace conditional item lookups in new system.
function inventoryHelper.createHashedItem(item)
    local itemHash = ""
    itemHash = itemHash .. item.Type
    if item.ComponentData then
        for i, component in pairs(item.ComponentData) do
            itemHash = itemHash .. "_" .. i .. tostring(component)
        end
    end
    return itemHash -- utility.sha1(itemHash)
end

--[[
    Side tangent, to document my development:

    This system, prior to the time of writing, used something
    known as a conditional lookup type. What that was,
    was an easy way for me to poll if an item was different
    from another based on a set of few key components.
    Sadly, this system was hacky, and didn't allow
    for other components to be added to items, or for
    checking of multiple components. I was originally not
    going to tidy this up, and live with it, but I have some
    plans and would like the inventory system to be fully feature
    complete so I can start working on them :)

    The dangers of premature optimization. It disallowed me from
    being able to broadly check for lots of things in all honesty. 
--]]

--- Used to distinguish generics for recipe unlock performance reasons 
function inventoryHelper.getInternalStorageName(item)
    local itemName = item.Type
    if item.ComponentData and item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
    and collectibleStorage.IDToNameLookup[item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]] then
        itemName = collectibleStorage.IDToNameLookup[item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]]
    end
    return itemName
end

--- Sorts a table by 
function inventoryHelper.sortTableByTags(a, b)
    return ((not itemTagLookup[a] and itemTagLookup[b]) 
    or ((itemTagLookup[a] and itemTagLookup[b]) and #itemTagLookup[a] < #itemTagLookup[b])
    or false)
end

--[[
    =======================    
    Recipe Helper Functions
    =======================
--]]

local function conditionalItemFromRecipe(recipe, itemIndex)
    if recipe.ConditionTable and recipe.ConditionTable[itemIndex] then
        return inventoryHelper.createItem(recipe.ConditionTable[itemIndex])
    end
    return {Type = "minecraft:stick", Count = 1}
end

local function conditionalItemFromShapedRecipe(recipe, inventory, itemIndex)
    local x, y = (((itemIndex - 1) % inventoryHelper.getInventoryWidth(inventory)) + 1), 
        (math.floor((itemIndex - 1) / inventoryHelper.getInventoryHeight(inventory)) + 1)
    x = x + math.floor((recipe.RecipeSize.X - inventoryHelper.getInventoryWidth(inventory)) / 2)
    y = y + (recipe.RecipeSize.Y - inventoryHelper.getInventoryHeight(inventory))

    if (x > 0 and x <= recipe.RecipeSize.X)
    and (y > 0 and y <= recipe.RecipeSize.Y) then
        local offsetIndex = x + ((y - 1) * recipe.RecipeSize.X)
        if recipe.ConditionTable[offsetIndex] then
            return conditionalItemFromRecipe(recipe, offsetIndex)
        end
    end
end

inventoryHelper.lastStartTime = 0
--- Returns a compiled item or list of items at the index required in a recipe
function inventoryHelper.getRecipeConditionalItem(recipe, inventory, index, noTag)
    local recipeIngredientDisplay = nil
    if recipe.RecipeSize then
        recipeIngredientDisplay = conditionalItemFromShapedRecipe(recipe, inventory, index)
    elseif recipe.ConditionTable[index] then
        recipeIngredientDisplay = conditionalItemFromRecipe(recipe, index)
    end
    if not noTag and recipeIngredientDisplay and itemTagLookup[recipeIngredientDisplay.Type] then
        local itemTagTable = itemTagLookup[recipeIngredientDisplay.Type]
        return itemTagTable[math.floor(((Isaac.GetTime() - inventoryHelper.lastStartTime) / 1000) % (#itemTagTable)) + 1]
    end
    return recipeIngredientDisplay
end

--- Returns a list of a recipe's necessary ingredients
function inventoryHelper.getRecipeItemList(recipe)
    local itemsNeeded = {}
    local craftingInventory = inventoryHelper.getInventory(InventoryTypes.CRAFTING)
    local inventoryWidth = inventoryHelper.getInventoryWidth(craftingInventory) - 1
    local inventoryHeight = inventoryHelper.getInventoryHeight(craftingInventory) - 1
    for j = 0, inventoryHeight do
        for i = 0, inventoryWidth do
            local currentItemIndex = ((i * (inventoryWidth + 1)) + j) + 1
            local getItem = inventoryHelper.getRecipeConditionalItem(recipe, craftingInventory, currentItemIndex, true)
            itemsNeeded[currentItemIndex] = getItem
        end
    end
    return itemsNeeded
end

local cachedRecipeOutputs = {}
inventoryHelper.recipeCraftableDirty = true
--- Returns if a recipe is craftable and caches it until recipes are flagged as dirty
function inventoryHelper.checkRecipeCraftable(recipeName, recipeFromName, inventorySet)
    if (not inventoryHelper.recipeCraftableDirty) and (cachedRecipeOutputs[recipeName]) then
        return table.unpack(cachedRecipeOutputs[recipeName])
    end
    -- get necessary items
    local itemsNeeded, sortedItemStack = inventoryHelper.getRecipeItemList(recipeFromName), {}
    for i in pairs(itemsNeeded) do
        table.insert(sortedItemStack, i)
    end
    -- Sort item stacks by least accessible to most accessible 
    -- this helps break out easier & helps prioritize materials that need to be specific ones
    table.sort(sortedItemStack, function(a, b)
        return inventoryHelper.sortTableByTags(itemsNeeded[a].Type, itemsNeeded[b].Type)
    end)
    -- break out of items that aren't craftable
    -- good philosophy because the items that ARE craftable will always be limited
    local usedItems = {}
    for index, itemIndex in ipairs(sortedItemStack) do
        local itemOrTag = itemsNeeded[itemIndex]
        if itemOrTag then
            for i, inventory in ipairs(inventorySet) do
                if (inventoryHelper.isValidInventory(inventory)) then
                    for j in pairs(inventory) do
                        if not usedItems[inventory] then
                            usedItems[inventory] = {}
                        end
                        if ((inventory[j] and inventory[j].Type) 
                        and ((usedItems[inventory][j] or 0) < inventory[j].Count)
                        and inventoryHelper.itemCanStackWithTag(inventory[j], itemOrTag)) then
                            usedItems[inventory][j] = (usedItems[inventory][j] or 0) + 1
                            goto nextItemInStack
                        end
                    end
                end
            end
            cachedRecipeOutputs[recipeName] = {false, false, false}
            return table.unpack(cachedRecipeOutputs[recipeName])
        end
        ::nextItemInStack::
    end
    -- return the sorted stack to reuse it if we're autocrafting the item :)
    cachedRecipeOutputs[recipeName] = {true, itemsNeeded, sortedItemStack}
    return table.unpack(cachedRecipeOutputs[recipeName])
end

local cachedRecipeTables = {}
local lastSearchBarText, lastBookTab, lastRecipeCount = "stupid", nil, 0
--- Returns a list of recipe book recipes.
function inventoryHelper.getRecipeBookRecipes(recipeBookTab, searchBarText, inventorySet)
    local recipeList, craftableRecipeList, recipeLookup, availableTabs = {}, {}, {}, {}
    local recipeSave = recipeStorageWrapper()
    local currentRecipeCount = (recipeSave and #recipeSave) or 0
    if (not (inventoryHelper.recipeCraftableDirty or (lastSearchBarText ~= searchBarText)
    or (lastBookTab ~= recipeBookTab) or (lastRecipeCount ~= currentRecipeCount)) and (#cachedRecipeTables > 0)) then
        return table.unpack(cachedRecipeTables)
    end
    if currentRecipeCount > 0 then
        for i, recipe in ipairs(recipeSave) do
            local recipeFromName = recipeStorage.nameToRecipe[recipeSave[i]]
            if recipeFromName then
                availableTabs[recipeFromName.Category] = true
                if recipeFromName.Results then
                    local displayRecipe = (not recipeBookTab) or (recipeBookTab and (recipeFromName.Category == recipeBookTab))
                    local collectible = recipeFromName.Results.Collectible and collectibleStorage.fastItemIDByName(recipeFromName.Results.Collectible)
                    if collectible and (collectible ~= -1) then
                        -- collectible tab auto gen
                        availableTabs["collectible"] = true
                        if (recipeBookTab == "collectible") then
                            displayRecipe = true
                        end
                        -- active tab auto gen
                        local collectibleType = utility.getCollectibleConfig(collectible).Type
                        if (collectibleType == ItemType.ITEM_ACTIVE) then
                            availableTabs["active"] = true
                            if recipeBookTab == "active" then
                                displayRecipe = true
                            end
                        else
                            availableTabs["passive"] = true
                            if recipeBookTab == "passive" then
                                displayRecipe = true
                            end
                        end
                    end
                    if displayRecipe then
                        local recipeCraftable, _, _ = inventoryHelper.checkRecipeCraftable(recipeSave[i], recipeFromName, inventorySet)
                        local fakeItem = inventoryHelper.resultItemFromRecipe(recipeFromName)
                        if fakeItem then
                            local itemName = string.lower(inventoryHelper.getNameFor(fakeItem))
                            if (string.find(itemName, string.lower(searchBarText))) then
                                local itemCondition = inventoryHelper.createHashedItem(fakeItem)
                                if not utility.tableContains(recipeList, itemCondition) then
                                    table.insert(recipeList, itemCondition)
                                end
                                if (recipeCraftable and not utility.tableContains(craftableRecipeList, itemCondition)) then
                                    table.insert(craftableRecipeList, itemCondition)
                                end
                                if not recipeLookup[itemCondition] then
                                    recipeLookup[itemCondition] = {}
                                end
                                table.insert(recipeLookup[itemCondition], {Name = recipe, Craftable = recipeCraftable})
                            end
                        end
                    end
                end
            end
        end
        lastSearchBarText = searchBarText
        lastBookTab = recipeBookTab 
        lastRecipeCount = currentRecipeCount
        inventoryHelper.recipeCraftableDirty = false
    end
    cachedRecipeTables = {recipeList, recipeLookup, craftableRecipeList, availableTabs}
    return table.unpack(cachedRecipeTables)
end

function inventoryHelper.getMaxInventorySize(inventory)
    if inventoryInformation[inventory] then
        return (inventoryInformation[inventory].Width * inventoryInformation[inventory].Height)
    end
    return 36
end

function inventoryHelper.getInventoryWidth(inventory)
    if inventoryInformation[inventory] then
        return inventoryInformation[inventory].Width
    end
    return 9
end

function inventoryHelper.getInventoryHeight(inventory)
    if inventoryInformation[inventory] then
        return inventoryInformation[inventory].Height
    end
    return 4
end

function inventoryHelper.getInventoryName(inventory)
    if inventoryInformation[inventory] then
        return utility.getCustomLocalizedString(
            "container." .. inventoryInformation[inventory].Name, 
            inventoryInformation[inventory].Name
        )
    end
    return "Inventory"
end

function inventoryHelper.isValidInventory(inventory)
    if inventoryInformation[inventory] then
        return (not inventoryInformation[inventory].ResultOnly)
    end
    return false
end

function inventoryHelper.getRenderFunction(inventory)
    if inventoryInformation[inventory] then
        return inventoryInformation[inventory].RenderFunction
    end
    return function(_) end
end

local function canStackComponentData(item1, item2, soft)
    -- if neither item has component data, they can stack
    if (not (item1.ComponentData or item2.ComponentData)) then
        return true
        -- otherwise only if both items have component data
    elseif (item1.ComponentData and item2.ComponentData) then 
        -- sift through component data and figure out if it is equal
        for i, inventoryAttribute in pairs(InventoryItemComponentData) do
            local equalData = (item1.ComponentData[inventoryAttribute] == item2.ComponentData[inventoryAttribute])
            if soft and (not equalData) then
                equalData = (not item1.ComponentData[inventoryAttribute]) or (not item2.ComponentData[inventoryAttribute])
                -- print(equalData, "reseting equal data for soft collectible", item1.ComponentData[inventoryAttribute], item2.ComponentData[inventoryAttribute])
            end
            if not equalData then
                return false
            end
        end
        return true
    end
    return (soft and (item1.ComponentData == nil or item2.ComponentData == nil))
end

function inventoryHelper.itemCanStackWith(item1, item2, soft)
    return ((item1.Type == item2.Type) 
        and canStackComponentData(item1, item2, soft))
end

--- Long overdue. checks if an item is in an item tag.
function inventoryHelper.isInItemTag(itemTagName, item)
    local itemTag = itemTagLookup[itemTagName]
    if itemTag then
        for i, tagItem in ipairs(itemTag) do
            if inventoryHelper.itemCanStackWith(item, tagItem, true) then
                return true, i
            end
        end
    end
    return false
end

--- Generic "of item type" esque function
function inventoryHelper.itemCanStackWithTag(item1, itemOrList)
    if itemTagLookup[itemOrList.Type] then
        return inventoryHelper.isInItemTag(itemOrList.Type, item1)
    end
    return (itemOrList.Type and inventoryHelper.itemCanStackWith(item1, itemOrList, true))
end

-- Item Names
local pillLocalizationTable = {}
local pillSubClassTable = {}
function inventoryHelper.getPillNameIfFound(rawPillEffect, forceIdentify)
    local itemPool = Game():GetItemPool()
    local pillColor = itemPool:GetPillColor(rawPillEffect)
    local pillExists = (pillColor ~= -1)
    if itemPool:IsPillIdentified(pillColor) or forceIdentify then
        if (not pillLocalizationTable[rawPillEffect]) then
            local itemConfig = Isaac.GetItemConfig():GetPillEffect(rawPillEffect)
            pillLocalizationTable[rawPillEffect] = utility.getLocalizedString("PocketItems", itemConfig.Name, true)
            pillSubClassTable[rawPillEffect] = itemConfig.EffectSubClass
        end
        return pillLocalizationTable[rawPillEffect], pillExists
    else
        pillLocalizationTable[rawPillEffect] = nil
        pillSubClassTable[rawPillEffect] = nil
    end
    return "???", pillExists
end

local function getComponentCount(pickup)
    local totalComponentCount = 0
    if itemRegistry[pickup.Type] then
        for i, j in pairs(itemRegistry[pickup.Type]) do
            totalComponentCount = totalComponentCount + 1
        end
    end
    if pickup.ComponentData then
        for i, j in pairs(pickup.ComponentData) do
            totalComponentCount = totalComponentCount + 1
        end
    end
    return totalComponentCount
end

local debugStats = true
local pillColorNames = require("scripts.tcainrework.inventory.color_to_name")
local itemTypeTable = {
    [ItemType.ITEM_PASSIVE] = "Passive Item",
    [ItemType.ITEM_ACTIVE] = "Active Item",
    [ItemType.ITEM_FAMILIAR] = "Familiar",
}
function inventoryHelper.itemGetFullName(pickup)
    local nameTable = {}
    local blindTextAppend = (((pickup.ComponentData 
        and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] 
        and getCurseOfBlind()) and "§k") or "")
    table.insert(nameTable, {
        String = blindTextAppend .. inventoryHelper.getNameFor(pickup), 
        Rarity = inventoryHelper.getItemRarity(pickup)
    })
    if pickup.ComponentData then
        if pickup.ComponentData[InventoryItemComponentData.PILL_COLOR] then
            -- print(pickup.ComponentData[InventoryItemComponentData.PILL_COLOR])
            local localizedColor, isHorsePill = utility.getPillColor(pickup.ComponentData[InventoryItemComponentData.PILL_COLOR])
            if isHorsePill then
                nameTable[1].String = "Horse Pill"
            end
            if pillColorNames[localizedColor] then
                -- nameTable[1].String = pillColorNames[localizedColor] .. " " .. nameTable[1].String
                table.insert(nameTable, {
                    String = pillColorNames[localizedColor],
                    Rarity = InventoryItemRarity.SUBTEXT
                })
            end
        end
        if pickup.ComponentData[InventoryItemComponentData.PILL_EFFECT] then
            local pillEffect = pickup.ComponentData[InventoryItemComponentData.PILL_EFFECT]
            local pillName, pillExists = inventoryHelper.getPillNameIfFound(
                pillEffect, (pickup.ComponentData[InventoryItemComponentData.PILL_COLOR] == nil)
            )
            table.insert(nameTable, {
                String = pillName,
                Rarity = InventoryItemRarity.SUBTEXT + (pillSubClassTable[pillEffect] or 0)
            })
            if not pillExists then
                table.insert(nameTable, {
                    String = "Unavailable in this Run",
                    Rarity = InventoryItemRarity.EFFECT_NEGATIVE
                })
            end
        end
        if pickup.ComponentData[InventoryItemComponentData.CUSTOM_DESC] then
            local descString = pickup.ComponentData[InventoryItemComponentData.CUSTOM_DESC]
            for string in descString:gmatch("[^\r\n]+") do
                table.insert(nameTable, {
                    String = string,
                    Rarity = InventoryItemRarity.SUBTEXT
                })
            end
        end
        if pickup.ComponentData[InventoryItemComponentData.CARD_TYPE] then
            local cardConfig = utility.getCardConfig(pickup.ComponentData[InventoryItemComponentData.CARD_TYPE])
            table.insert(nameTable, {
                String = utility.getLocalizedString("PocketItems", cardConfig.Name, true),
                Rarity = InventoryItemRarity.SUBTEXT
            })
        end
        if pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
            local itemConfig = utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            if not inventoryHelper.getItemUnlocked(pickup) then
                table.insert(nameTable, {
                    String = "Locked, Inventory Only",
                    Rarity = InventoryItemRarity.EFFECT_NEGATIVE
                })
            else
                if itemTypeTable[itemConfig.Type] then
                    table.insert(nameTable, {
                        String = utility.getCustomLocalizedString("items.tooltip." .. itemTypeTable[itemConfig.Type] .. ".name", itemTypeTable[itemConfig.Type]),
                        Rarity = InventoryItemRarity.EFFECT_POSITIVE
                    })
                end
            end
            table.insert(nameTable, {
                String = blindTextAppend .. utility.getLocalizedString("Items", itemConfig.Description, true),
                Rarity = InventoryItemRarity.SUBTEXT
            })
            if debugStats and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] then
                if (itemConfig.MaxCharges > 0 and (pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] / itemConfig.MaxCharges ~= 1)) then
                    table.insert(nameTable, {
                        String = "Durability: " 
                        .. tostring(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES]) 
                        .. " / " .. tostring(itemConfig.MaxCharges),
                        Rarity = InventoryItemRarity.COMMON
                    })
                end
            end
        end
    end
    if debugStats then
        table.insert(nameTable, {
            String = pickup.Type,
            Rarity = InventoryItemRarity.DEBUG_TEXT
        })
        table.insert(nameTable, {
            String = getComponentCount(pickup) .. " " .. utility.getCustomLocalizedString("items.tooltip.components.name", "component(s)"),
            Rarity = InventoryItemRarity.DEBUG_TEXT
        })
    end
    -- Recipe Stuff
    if pickup.MultipleRecipes then
        table.insert(nameTable, {
            String = utility.getCustomLocalizedString("items.tooltip.more_recipes.name", "Right Click for More"),
            Rarity = InventoryItemRarity.COMMON
        })
    end
    return nameTable
end

local minecraftFont = include("scripts.tcainrework.font")
function inventoryHelper.renderMinecraftText(string, textPosition, textRarity, renderShadow, formatText)
    local textRarityColor = InventoryItemRarityColors[textRarity]
    if renderShadow then
        minecraftFont:DrawString(string, textPosition.X + 1, textPosition.Y + 1, textRarityColor.Shadow, 0, false, formatText)
    end
    minecraftFont:DrawString(string, textPosition.X, textPosition.Y, textRarityColor.Color, 0, false, formatText)
end

local tooltipBackground = Sprite()
tooltipBackground:Load("gfx/ui/tooltip.anm2", false)
tooltipBackground:ReplaceSpritesheet(0, "gfx/ui/background.png")
tooltipBackground:LoadGraphics()

local tooltipFrame = Sprite()
tooltipFrame:Load("gfx/ui/tooltip.anm2", false)
tooltipFrame:ReplaceSpritesheet(0, "gfx/ui/frame.png")
tooltipFrame:LoadGraphics()

function inventoryHelper.renderTooltip(mousePosition, stringTable)
    local longestWidth = 0
    for i, string in ipairs(stringTable) do
        longestWidth = math.max(longestWidth, minecraftFont:GetStringWidth(string.String))
    end
    local lineSep = (minecraftFont:GetLineHeight() + 2)
    local textboxPosition = mousePosition + Vector(10, (math.max(0, (#stringTable - 2) / 2)) * lineSep)
    textboxPosition.X, textboxPosition.Y = math.floor(textboxPosition.X), math.floor(textboxPosition.Y)
    local nineSliceSize = Vector(longestWidth + 4, (lineSep * #stringTable) + 1)
    utility.renderNineSlice(tooltipBackground, textboxPosition, nineSliceSize)
    for i, subString in ipairs(stringTable) do
        inventoryHelper.renderMinecraftText(subString.String, textboxPosition 
            + Vector(2, (lineSep * ((i - 1) - (#stringTable / 2)))), subString.Rarity, true, true)
    end
    utility.renderNineSlice(tooltipFrame, textboxPosition, nineSliceSize)
end

function inventoryHelper.removePossibleAmount(inventory, itemIndex, removeAmount)
    local currentItem = inventory[itemIndex]
    if currentItem then
        local amountRemoved = math.min(removeAmount, currentItem.Count)
        currentItem.Count = currentItem.Count - amountRemoved
        if currentItem.Count <= 0 then
            inventory[itemIndex] = nil
        end
        return amountRemoved
    end
    inventoryHelper.recipeCraftableDirty = true
    return 0
end

-- Inventory Helper Functions
function inventoryHelper.reconveneFromInventory(currentStack, inventoryList)
    if currentStack and currentStack.Count < inventoryHelper.getMaxStackFor(currentStack) then
        local fakeInventory = {}
        local inventoryDisplacement = 0
        for i, subInventory in ipairs(inventoryList) do
            if inventoryHelper.isValidInventory(subInventory) then
                for j, inventoryItem in pairs(subInventory) do
                    if inventoryItem ~= nil and inventoryItem.Count > 0 
                    and inventoryHelper.itemCanStackWith(inventoryItem, currentStack) then
                        table.insert(fakeInventory, {
                            Slot = j, 
                            Inventory = subInventory, 
                            AbsoluteSlot = j + inventoryDisplacement
                        })
                    end
                end
                inventoryDisplacement = inventoryDisplacement + (inventoryHelper.getInventoryWidth(subInventory) * inventoryHelper.getInventoryHeight(subInventory))
            end
        end
        table.sort(fakeInventory, function(a, b) 
            -- print(a.Inventory[a.Slot].Count, b.Inventory[b.Slot].Count, "-", a.AbsoluteSlot, b.AbsoluteSlot)
            return (a.AbsoluteSlot < b.AbsoluteSlot)
        end)
        for i, inventoryPointer in pairs(fakeInventory) do
            local inventoryItem = inventoryPointer.Inventory[inventoryPointer.Slot]
            if inventoryHelper.itemCanStackWith(inventoryItem, currentStack) then
                local remainderAmount = inventoryHelper.getMaxStackFor(currentStack) - currentStack.Count
                local reduceBy = inventoryHelper.removePossibleAmount(inventoryPointer.Inventory, inventoryPointer.Slot, remainderAmount)
                currentStack.Count = currentStack.Count + reduceBy 
            end
        end
    end
end

--[[
    Uses an inventory list parameter because Minecraft does a search for the first available slot that contains an item
    in all inventories before even attempting to consider an empty slot. This only happens when picking up items, however,
    and when shift clicking this is ignored in favor of doing inventory wide searches. For this, I will instead just 
    provide an array with a single index, as I'd like to reuse the logic here because it's very heavy :p
--]]
function inventoryHelper.searchForFreeSlot(inventoryList, pickup) 
    -- prioritize trying to find any existing stacks of the item
    for i, inventory in ipairs(inventoryList) do
        for inventorySlot, inventoryItem in pairs(inventory) do
            if (inventoryItem ~= nil and inventoryHelper.itemCanStackWith(inventoryItem, pickup)
            and inventoryItem.Count < inventoryHelper.getMaxStackFor(pickup)) then
                return {
                    Slot = inventorySlot,
                    Inventory = inventory
                }
            end
        end
    end
    -- add item to empty slot
    for i, inventory in ipairs(inventoryList) do
        local firstAvailableSlot = 1
        while firstAvailableSlot <= inventoryHelper.getMaxInventorySize(inventory) do
            if inventory[firstAvailableSlot] == nil
            or inventory[firstAvailableSlot].Count <= 0 then
                return {
                    Slot = firstAvailableSlot,
                    Inventory = inventory
                }
            end
            firstAvailableSlot = firstAvailableSlot + 1
        end
    end
    return nil
end

function inventoryHelper.shiftClickSearchFree(inventorySet, curInventory, curItem)
    -- go through all inventories (in order) and find the first inventory with the first available slot
    local fakeInventorySet = {}
    for j, inventory in ipairs(inventorySet) do
        if inventory ~= curInventory and inventoryHelper.isValidInventory(inventory)
        and (inventoryHelper.isValidInventory(curInventory) or (j > (#inventorySet - 2))) then
            table.insert(fakeInventorySet, inventory)
        end
    end
    -- attempt to find first free slot in inventory list
    local invFreeSlot = inventoryHelper.searchForFreeSlot(fakeInventorySet, curItem)
    if invFreeSlot and invFreeSlot.Slot then
        return true, invFreeSlot.Slot, invFreeSlot.Inventory
    end
    -- no more available slots are found, break out of shift clicking
    return false, nil, nil
end

function inventoryHelper.resultItemFromRecipe(recipe)
    if recipe.Results then
        return inventoryHelper.createItem(recipe.Results.Collectible or recipe.Results.Type, recipe.Results.Count)
    end
    return {Type = "minecraft:stick", Count = 1}
end

--- used to actually craft and check if recipes are craftable
function inventoryHelper.checkRecipeConditional(craftingInventory, recipeList, topLeft, bottomRight, shapeless)
    local anyReturn = nil
    -- Classic Crafting
    if inventoryHelper.isClassicCrafting() then
        -- compile a list of ingredients
        local itemList = {}
        for i, item in pairs(craftingInventory) do
            local itemID = itemRegistry[item.Type] and itemRegistry[item.Type].ClassicID
            if itemID and (#itemList < 9) then
                table.insert(itemList, itemID)
            end
        end
        if #itemList == 8 then
            local fakePlayer = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
            return inventoryHelper.createItem(classicCrafting.emulateRecipe(fakePlayer, itemList))
        end
        return false
    end
    -- T. Cain Rework
    if recipeList then
        local craftingTable = craftingInventory
        if shapeless then
            craftingTable = {}
            for i, item in pairs(craftingInventory) do
                table.insert(craftingTable, item)
            end
            -- these tables just need to be sorted by something consistent. hashed items should do
            table.sort(craftingTable, function(a, b)
                return inventoryHelper.createHashedItem(a)
                    < inventoryHelper.createHashedItem(b)
            end)
        end
        for i, recipe in ipairs(recipeList) do
            local index = 1
            local myConditionTable = {}
            for i, type in pairs(recipe.ConditionTable) do
                myConditionTable[i] = inventoryHelper.createItem(type)
                if myConditionTable[i].ComponentData 
                and myConditionTable[i].ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] then
                    myConditionTable[i].ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] = nil
                end
            end
            if shapeless then
                for i, item in pairs(craftingInventory) do
                    if item and item.Type then
                        for j, type in ipairs(myConditionTable) do
                            if inventoryHelper.isInItemTag(type.Type, item) then
                                myConditionTable[j] = item
                                goto nextItemTag
                            end
                        end
                        ::nextItemTag::
                    end
                end
                table.sort(myConditionTable, function(a, b)
                    return inventoryHelper.createHashedItem(a)
                        < inventoryHelper.createHashedItem(b)
                end)
            end

            local craftingIndex = 0
            for k = topLeft.Y, bottomRight.Y do
                for l = topLeft.X, bottomRight.X do
                    craftingIndex = (((k - 1) * 3) + l)
                    if shapeless then
                        craftingIndex = index
                    end
                    if myConditionTable[index] then
                        if (not inventoryHelper.itemCanStackWithTag(craftingTable[craftingIndex], myConditionTable[index])) then
                            goto recipeContinue
                        end
                    end
                    index = index + 1
                end
            end
            anyReturn = inventoryHelper.resultItemFromRecipe(recipe)
            ::recipeContinue::
            if anyReturn then
                return anyReturn
            end
        end
    end
    return false
end

local collectibleTypeReturns = {
    [CollectibleType.COLLECTIBLE_ISAACS_TEARS] = "minecraft:bucket"
}

--- Behavior for consuming recipe ingredients during crafting
function inventoryHelper.consumeRecipeIngredient(recipe, inventory, index)
    local myIngredient = inventory[index]
    if myIngredient.ComponentData then
        -- Items that return custom items
        if myIngredient.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
        and collectibleTypeReturns[myIngredient.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]] then
            return inventoryHelper.createItem(collectibleTypeReturns[myIngredient.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]])
        end
    end
    -- Default remove 1 item behavior
    inventoryHelper.removePossibleAmount(inventory, index, 1)
    return inventory[index]
end

local toastStorage = require("scripts.tcainrework.stored.toast_storage")
function TCainRework:UnlockItemRecipe(recipeName)
    if recipeName then
        local recipeSave = recipeStorageWrapper()
        local recipe = recipeStorage.nameToRecipe[recipeName]
        if not utility.tableContains(recipeSave, recipeName) then
            local resultingType = (recipe.Results and recipe.Results.Type)
            if resultingType then
                local itemTable = inventoryHelper.createItem(resultingType)
                if recipe.Results.Collectible then
                    itemTable.ComponentData = utility.generateCollectibleData(recipe.Results.Collectible)
                end
                table.insert(toastStorage, itemTable)
            end
            -- print('unlocking recipe:', recipeName)
            table.insert(recipeSave, recipeName)
            -- Saving Recipes persistently
            local persistentSave = saveManager.GetPersistentSave()
            if persistentSave and (recipeSave ~= persistentSave.unlockedRecipes) then
                if not persistentSave.unlockedRecipes then
                    persistentSave.unlockedRecipes = {}
                end
                if not utility.tableContains(persistentSave.unlockedRecipes, recipeName) then
                    table.insert(persistentSave.unlockedRecipes, recipeName)
                end
            end
        end
    end
end

function inventoryHelper.runUnlockItem(item, forceUnlockAll)
    local runSave = saveManager.GetRunSave()
    if not runSave.obtainedItems then
        runSave.obtainedItems = {}
    end
    local unlockAll = (forceUnlockAll or (itemRegistry[item.Type] and itemRegistry[item.Type].UnlockAll))
    local itemTypeFiltered = inventoryHelper.getInternalStorageName(item)
    if recipeStorage.recipeFromIngredient[itemTypeFiltered] then
        for i, recipeName in ipairs(recipeStorage.recipeFromIngredient[itemTypeFiltered]) do
            local recipe = recipeStorage.nameToRecipe[recipeName]
            if recipe and recipe.ConditionTable and recipe.DisplayRecipe then
                local lockedItems = 0
                for i, curType in pairs(recipe.ConditionTable) do
                    local currentItem = inventoryHelper.createItem(curType)
                    local curHash = inventoryHelper.createHashedItem(currentItem)
                    if ((itemTagLookup[item.Type] and inventoryHelper.itemCanStackWith(currentItem, item))
                    or inventoryHelper.itemCanStackWithTag(item, currentItem)) then
                        runSave.obtainedItems[curHash] = true
                        if unlockAll and inventoryHelper.itemCanStackWith(currentItem, item) then
                            lockedItems = 0
                            goto unlockItem
                        end
                    elseif not (runSave.obtainedItems[curHash]) then
                        lockedItems = lockedItems + 1
                    end
                end
                ::unlockItem::
                if (lockedItems <= 0) then
                    TCainRework:UnlockItemRecipe(recipeName)
                end
            end
        end
    end
end

TCainRework:AddCallback(ModCallbacks.MC_USE_PILL, function(_, pillEffect, entityPlayer, useFlags)
    if (inventoryHelper.getUnlockedInventory()
    and entityPlayer:HasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)) then
        inventoryHelper.runUnlockItem(
            inventoryHelper.createItem("tcainrework:pill{\"pill_effect\":" .. tostring(pillEffect) .. "}")
        )
    end
end)

function inventoryHelper.unlockItemBatch(item)
    if item.Type and itemRegistry[item.Type] and itemRegistry[item.Type].ItemTags then
        for i, itemTag in ipairs(itemRegistry[item.Type].ItemTags) do
            inventoryHelper.runUnlockItem(  
                inventoryHelper.createItem(itemTag), 
                itemRegistry[item.Type] and itemRegistry[item.Type].UnlockTags
            )
        end
    end
    inventoryHelper.runUnlockItem(item)
end

if REPENTOGON then
    -- Item Renderer
    local itemSprite = Sprite()
    itemSprite:Load("gfx/items/inventoryitem.anm2", false)
    itemSprite:SetCustomShader("shaders/coloroffset_enchantment_glint")

    local defaultCollectibleSprite = Sprite()
    defaultCollectibleSprite:Load("gfx/itemanimation.anm2", true)
    defaultCollectibleSprite:Play("Idle", true)

    -- Simple Block Renderer
    local blockSprite = Sprite()
    blockSprite:Load("gfx/blocks/inventoryblock.anm2", false)
    blockSprite:ReplaceSpritesheet(0, "gfx/items/blocks/cobblestone.png")
    blockSprite:LoadGraphics()
    blockSprite:Play("Idle", true)
    blockSprite:SetCustomShader("shaders/block_renderer")

    -- Crafting Table Renderer
    local craftingTableSprite = Sprite()
    craftingTableSprite:Load("gfx/blocks/craftingtable.anm2", false)
    craftingTableSprite:ReplaceSpritesheet(0, "gfx/items/blocks/crafting_table.png")
    craftingTableSprite:LoadGraphics()
    craftingTableSprite:Play("Idle", true)
    craftingTableSprite:SetCustomShader("shaders/crafting_renderer")

    -- 3D Item Renderer
    local itemSprite3d = Sprite()
    itemSprite3d:Load("gfx/items/inventoryitem.anm2", false)
    itemSprite3d:Play("Idle", true)
    itemSprite3d:SetCustomShader("shaders/item_renderer")

    -- 3D Collectible Renderer
    local collectibleSprite3d = Sprite()
    collectibleSprite3d:Load("gfx/itemanimation.anm2", true)
    collectibleSprite3d:Play("Idle", true)
    collectibleSprite3d:SetCustomShader("shaders/item_renderer")

    local chestSprite = Sprite()
    chestSprite:Load("gfx/blocks/craftingtable.anm2", false)
    chestSprite:ReplaceSpritesheet(0, "gfx/items/blocks/chest.png")
    chestSprite:LoadGraphics()
    chestSprite:Play("Idle", true)
    chestSprite:SetCustomShader("shaders/chest_renderer")

    local durabilityBar = Sprite()
    durabilityBar:Load("gfx/items/inventoryitem.anm2", false)
    durabilityBar:ReplaceSpritesheet(0, "gfx/ui/durability.png")
    durabilityBar:LoadGraphics()
    durabilityBar:Play("Idle", true)

    local blackColor = Color(1, 1, 1, 1)
    local yellowBarColor = Color(
        0, 0, 0, 1, 
        255 / 255, 219 / 255, 16 / 255
    )
    function inventoryHelper.renderItem(itemToDisplay, renderPosition, renderScale, elapsedTime, itemAlpha)
        if not itemToDisplay then
            return
        end
        local collectibleItem = itemToDisplay.ComponentData and itemToDisplay.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
        local originalRenderPosition = Vector(renderPosition.X, renderPosition.Y)
        local renderType = inventoryHelper.getItemRenderType(itemToDisplay.Type)
        local renderFallback = ((collectibleItem ~= nil) and (getCustomCollectibleSprite(collectibleItem) == -1))
        local renderSprite = (((renderType == renderTypes.Default) and (elapsedTime and itemSprite3d))
            or ((renderType == renderTypes.SimpleBlock) and blockSprite)
            or ((renderType == renderTypes.CraftingTable) and craftingTableSprite)
            or ((renderType == renderTypes.Chest) and chestSprite) or itemSprite)
        if renderFallback then
            renderType = renderTypes.Collectible
            renderSprite = (elapsedTime and collectibleSprite3d) or defaultCollectibleSprite
        end
        renderSprite:ReplaceSpritesheet(0, inventoryHelper.getItemGraphic(itemToDisplay))
        renderSprite:LoadGraphics()
        local isEnchanted = inventoryHelper.getDefaultEnchanted(itemToDisplay)
        local spriteSize = ((renderType == renderTypes.Collectible) and 32) or 16
        renderSprite.Color = Color(
            1, 1, 1, itemAlpha or 1, 
            0, 0, 0, 
            (((elapsedTime ~= nil) and elapsedTime) or ((renderType == renderTypes.Default) and TCainRework.elapsedTime)) or 0, 
            spriteSize, spriteSize, isEnchanted and TCainRework.elapsedTime or 0
        )
        renderSprite.Scale = renderScale or Vector.One
        if renderFallback then
            renderSprite.Scale = renderSprite.Scale / 2
            renderPosition = renderPosition + Vector(8, 13) * (renderScale or Vector.One)
        end
        renderSprite:Play("Idle", true)
        renderSprite:Render(renderPosition)
        local currentCharges = itemToDisplay.ComponentData and itemToDisplay.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES]
        if (not elapsedTime) and (currentCharges and utility.getCollectibleConfig(collectibleItem).MaxCharges > 0) then
            local chargeRatio = itemToDisplay.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] / utility.getCollectibleConfig(collectibleItem).MaxCharges
            if chargeRatio ~= 1 then
                local firstBarCharge = math.min(chargeRatio, 1)
                durabilityBar.Color = blackColor
                durabilityBar.Scale = renderScale or Vector.One
                durabilityBar:Render(originalRenderPosition + Vector(2, 13))
                durabilityBar.Scale.Y = (durabilityBar.Scale.Y / 2)
                durabilityBar.Scale.X = firstBarCharge

                local red, green = 1, 1
                if firstBarCharge >= 0.5 then
                    green = 1
                    red = (1 - firstBarCharge) * 2
                else
                    green = firstBarCharge * 2
                    red = 1
                end
                durabilityBar.Color = Color(
                    0, 0, 0, 1, 
                    red, green, 0
                )
                durabilityBar:Render(originalRenderPosition + Vector(2, 13))
                
                local secondBarCharge = math.max(chargeRatio, 1)
                if secondBarCharge > 1 then
                    -- Second Charge Bar
                    durabilityBar.Color = yellowBarColor
                    durabilityBar.Scale.X = (secondBarCharge - 1)
                    durabilityBar:Render(originalRenderPosition + Vector(2, 13))
                end
            end
        end
    end
end

return inventoryHelper