local inventoryHelper = {}

local saveManager = require("scripts.save_manager")
local utility = require("scripts.tcainrework.util")
local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
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
            local itemConfig = Isaac.GetItemConfig():GetCollectible(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            return utility.getLocalizedString("Items", itemConfig.Name)
        end
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].DisplayName then
        return itemRegistry[pickup.Type].DisplayName
    end
    return "Bone"
end

function inventoryHelper.getMaxStackFor(pickupType)
    if itemRegistry[pickupType]
    and itemRegistry[pickupType].StackSize then
        return itemRegistry[pickupType].StackSize
    end
    return 16
end

local itemRarities = InventoryItemRarity
function inventoryHelper.getItemRarity(pickup)
    if pickup.ComponentData 
    and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
        local itemQuality = Isaac.GetItemConfig()
            :GetCollectible(pickup.ComponentData
            [InventoryItemComponentData.COLLECTIBLE_ITEM])
            .Quality
        return itemQuality
    end
    if itemRegistry[pickup.Type]
    and itemRegistry[pickup.Type].Rarity then
        return itemRegistry[pickup.Type].Rarity
    end
    return itemRarities.COMMON
end

function inventoryHelper.getDefaultEnchanted(pickup)
    if pickup.ComponentData
    and pickup.ComponentData[InventoryItemComponentData.ENCHANTMENT_OVERRIDE] then
        return pickup.ComponentData[InventoryItemComponentData.ENCHANTMENT_OVERRIDE]
    end
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

function inventoryHelper.getItemGraphic(pickup)
    if pickup.ComponentData
    and pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX] then
        return pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX]
    end
    if pickup.ComponentData
    and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
        local itemConfig = Isaac.GetItemConfig():GetCollectible(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
        return itemConfig.GfxFileName
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
    if not runSave[name] then
        runSave[name] = {}
    end
    inventoryInformation[runSave[name]] = {
        Width = width, 
        Height = height, 
        Name = name, 
        RenderFunction = renderFunction, 
        ResultOnly = resultOnly
    }
end

function inventoryHelper.getInventory(inventoryType)
    local runSave = saveManager.GetRunSave()
    if not runSave[inventoryType] then
        runSave[inventoryType] = {}
    end
    return runSave[inventoryType]
end

function inventoryHelper.hoveringOver(mousePosition, buttonPosition, buttonWidth, buttonHeight)
    if mousePosition.X >= buttonPosition.X
    and mousePosition.Y >= buttonPosition.Y
    and mousePosition.X < buttonPosition.X + buttonWidth
    and mousePosition.Y < buttonPosition.Y + buttonHeight then
        return true
    end
    return false
end

function inventoryHelper.getUnlockedInventory(setUnlocked)
    local runSave = saveManager.GetRunSave()
    if not runSave.inventoryUnlocked and setUnlocked then
        TCainRework:CreateToast(
            InventoryToastTypes.TUTORIAL, 
            nil, "gfx/ui/recipe_book.png", 
            "Open your inventory", "Press §lI",
            240
        )
        runSave.inventoryUnlocked = setUnlocked
    end
    return runSave.inventoryUnlocked
end

function inventoryHelper.getRecipeBookOpen()
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

local recipeLookupIndex = require("scripts.tcainrework.stored.name_to_recipe")
local recipeItemLookupTable = {}
local function conditionalItemLookupType(itemID)
    if not recipeItemLookupTable[itemID] then
        local myItemID = itemID
        local itemCollectibleData = Isaac.GetItemIdByName(itemID)
        if itemCollectibleData ~= -1 then
            myItemID = "tcainrework:collectible" .. itemCollectibleData
        end
        recipeItemLookupTable[itemID] = myItemID
    end
    return recipeItemLookupTable[itemID]
end

function inventoryHelper.getRecipeBookRecipes(recipeBookTab, searchBarText, inventorySet)
    local recipeList, craftableRecipeList, storedItemCounts, availableTabs = {}, {}, {}, {}
    for i, inventory in ipairs(inventorySet) do
        if inventoryHelper.isValidInventory(inventory) then
            for j, item in pairs(inventory) do
                local itemName = item.Type
                local itemCollectibleData = ((item.ComponentData)
                    and item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
                if itemCollectibleData then
                    itemName = itemName .. itemCollectibleData
                end
                storedItemCounts[itemName] = (storedItemCounts[itemName] or 0) + (item.Count or 0)
            end
        end
    end
    local runSave = saveManager.TryGetRunSave()
    if runSave and #runSave.unlockedRecipes > 0 then
        for i, recipe in ipairs(runSave.unlockedRecipes) do
            local recipeFromName = recipeLookupIndex[runSave.unlockedRecipes[i]]
            availableTabs[recipeFromName.Category] = true
            if (not recipeBookTab) or (recipeBookTab and recipeFromName.Category == recipeBookTab) then
                local matchedTypes = {}
                for i, itemID in pairs(recipeFromName.ConditionTable) do
                    local myItemID = conditionalItemLookupType(itemID)
                    matchedTypes[myItemID] = (matchedTypes[myItemID] or 0) + 1
                end
                for type in pairs(matchedTypes) do
                    matchedTypes[type] = matchedTypes[type] - (storedItemCounts[type] or 0)
                    if matchedTypes[type] <= 0 then
                        matchedTypes[type] = nil
                    end
                end
                local recipeCraftable = true
                for type in pairs(matchedTypes) do
                    recipeCraftable = false
                end
                local fakeItem = inventoryHelper.resultItemFromRecipe(recipeFromName)
                if fakeItem then
                    local itemName = string.lower(inventoryHelper.getNameFor(fakeItem))
                    if (string.find(itemName, string.lower(searchBarText))) then
                        table.insert(recipeList, recipe)
                        if recipeCraftable then
                            table.insert(craftableRecipeList, recipe)
                        end
                    end
                end
            end
        end
    end
    return recipeList, craftableRecipeList, availableTabs
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
        return inventoryInformation[inventory].Name
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

local function canStackComponentData(item1, item2)
    -- if neither item has component data, they can stack
    if (not (item1.ComponentData or item2.ComponentData)) then
        return true
        -- otherwise only if both items have component data
    elseif (item1.ComponentData and item2.ComponentData) then 
        -- sift through component data and figure out if it is equal
        local equalData = true
        for i, inventoryAttribute in pairs(InventoryItemComponentData) do
            equalData = equalData and (item1.ComponentData[inventoryAttribute] == item2.ComponentData[inventoryAttribute])
            if not equalData then
                return false
            end
        end
        return true
    end
    return false
end

function inventoryHelper.itemCanStackWith(item1, item2)
    return (item1.Type == item2.Type) 
        and canStackComponentData(item1, item2)
end

-- Item Names
local pillLocalizationTable = {}
local pillSubClassTable = {}
function inventoryHelper.getPillNameIfFound(rawPillEffect)
    local itemPool = Game():GetItemPool()
    if itemPool:IsPillIdentified(itemPool:GetPillColor(rawPillEffect)) then
        if not pillLocalizationTable[rawPillEffect] then
            local itemConfig = Isaac.GetItemConfig():GetPillEffect(rawPillEffect)
            pillLocalizationTable[rawPillEffect] = utility.getLocalizedString("PocketItems", itemConfig.Name)
            pillSubClassTable[rawPillEffect] = itemConfig.EffectSubClass
        end
        return pillLocalizationTable[rawPillEffect]
    else
        pillLocalizationTable[rawPillEffect] = nil
        pillSubClassTable[rawPillEffect] = nil
    end
    return "???"
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
    table.insert(nameTable, {
        String = inventoryHelper.getNameFor(pickup), 
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
            table.insert(nameTable, {
                String = inventoryHelper.getPillNameIfFound(pillEffect),
                Rarity = InventoryItemRarity.SUBTEXT + (pillSubClassTable[pillEffect] or 0)
            })
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
        if pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
            local itemConfig = Isaac.GetItemConfig():GetCollectible(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            if itemTypeTable[itemConfig.Type] then
                table.insert(nameTable, {
                    String = itemTypeTable[itemConfig.Type],
                    Rarity = InventoryItemRarity.EFFECT_POSITIVE
                })
            end
            table.insert(nameTable, {
                String = utility.getLocalizedString("Items", itemConfig.Description),
                Rarity = InventoryItemRarity.SUBTEXT
            })
        end
    end
    if debugStats then
        table.insert(nameTable, {
            String = pickup.Type,
            Rarity = InventoryItemRarity.DEBUG_TEXT
        })
        table.insert(nameTable, {
            String = getComponentCount(pickup) .. " component(s)",
            Rarity = InventoryItemRarity.DEBUG_TEXT
        })
    end
    return nameTable
end

-- Inventory Helper Functions
function inventoryHelper.reconveneFromInventory(currentStack, inventoryList)
    if currentStack and currentStack.Count < inventoryHelper.getMaxStackFor(currentStack.Type) then
        local fakeInventory = {}
        for i, subInventory in ipairs(inventoryList) do
            if inventoryHelper.isValidInventory(subInventory) then
                for j, inventoryItem in pairs(subInventory) do
                    if inventoryItem ~= nil and inventoryItem.Count > 0 
                    and inventoryHelper.itemCanStackWith(inventoryItem, currentStack) then
                        table.insert(fakeInventory, {Slot = j, Inventory = subInventory})
                    end
                end
            end
        end
        table.sort(fakeInventory, function(a, b) 
            return a.Inventory[a.Slot].Count < b.Inventory[b.Slot].Count
        end)
        for i, inventoryPointer in pairs(fakeInventory) do
            local inventoryItem = inventoryPointer.Inventory[inventoryPointer.Slot]
            if inventoryHelper.itemCanStackWith(inventoryItem, currentStack) then
                local remainderAmount = inventoryHelper.getMaxStackFor(currentStack.Type) - currentStack.Count
                local reduceBy = math.min(remainderAmount, inventoryItem.Count)
                inventoryItem.Count = inventoryItem.Count - reduceBy
                currentStack.Count = currentStack.Count + reduceBy 
                if inventoryPointer.Inventory[inventoryPointer.Slot].Count <= 0 then
                    inventoryPointer.Inventory[inventoryPointer.Slot] = nil
                end
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
            and inventoryItem.Count < inventoryHelper.getMaxStackFor(pickup.Type)) then
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

function inventoryHelper.checkRecipeConditional(craftingInventory, recipeList, topLeft, bottomRight, shapeless)
    local anyReturn = false
    if recipeList then
        local craftingTable = craftingInventory
        if shapeless then
            craftingTable = {}
            for i, item in pairs(craftingInventory) do
                table.insert(craftingTable, item)
            end
            table.sort(craftingTable, function(a, b)
                return a.Type < b.Type
            end)
        end
        for i, recipe in ipairs(recipeList) do
            local index = 1
            if shapeless then
                table.sort(recipe.ConditionTable)
            end
            local craftingIndex = 0
            for k = topLeft.Y, bottomRight.Y do
                for l = topLeft.X, bottomRight.X do
                    craftingIndex = (((k - 1) * 3) + l)
                    if shapeless then
                        craftingIndex = index
                    end

                    local collectibleType = ((craftingTable[craftingIndex]
                        and craftingTable[craftingIndex].ComponentData)
                        and craftingTable[craftingIndex].ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])

                    -- mismatch recipe, if any conditions break out a recipe then check them here
                    if craftingTable[craftingIndex] 
                    and (craftingTable[craftingIndex].Type ~= recipe.ConditionTable[index]) -- doesn't match item type
                    and ((not collectibleType) or (collectibleType ~= Isaac.GetItemIdByName(recipe.ConditionTable[index]))) then -- doesn't match collectible type
                        goto recipeContinue
                    end
                    index = index + 1
                end
            end
            anyReturn = recipe.Results
            ::recipeContinue::
            if anyReturn then
                return anyReturn
            end
        end
    end
    return false
end

function inventoryHelper.resultItemFromRecipe(recipe, includeCount)
    if recipe.Results then
        local fakeResultItem = {
            Type = recipe.Results.Type,
            Count = (includeCount and recipe.Results.Count) or 1
        }
        if recipe.Results.Collectible then
            fakeResultItem.ComponentData = inventoryHelper.generateCollectibleData(recipe.Results.Collectible)
        end
        return fakeResultItem
    end
    return {Type = "minecraft:stick", Count = 1}
end

function inventoryHelper.conditionalItemFromRecipe(recipe, itemIndex)
    if recipe.ConditionTable and recipe.ConditionTable[itemIndex] then
        local presumedItemType = recipe.ConditionTable[itemIndex]
        local itemCollectibleData = Isaac.GetItemIdByName(presumedItemType)
        if itemCollectibleData ~= -1 then
            presumedItemType = "tcainrework:collectible"
        end
        local fakeResultItem = {
            Type = presumedItemType,
            Count = 1,
        }
        if itemCollectibleData ~= -1 then
            fakeResultItem.ComponentData = inventoryHelper.generateCollectibleData(itemCollectibleData)
        end
        return fakeResultItem
    end
    return {Type = "minecraft:stick", Count = 1}
end

local dummySprite = Sprite()
dummySprite:Load("gfx/items/inventoryitem.anm2", false)
local spriteLookupTable = {}
local interval = 4
function inventoryHelper.generateCollectibleData(collectibleType)
    -- try to obtain sprite if it exists
    local itemConfig = Isaac.GetItemConfig():GetCollectible(collectibleType)
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
    return {
        [InventoryItemComponentData.CUSTOM_GFX] = ((spriteLookupTable[spritesheetPath] ~= -1) and spriteLookupTable[spritesheetPath]) or nil,
        [InventoryItemComponentData.COLLECTIBLE_ITEM] = collectibleType
    }
end

local recipeLookupIndex = require('scripts.tcainrework.stored.name_to_recipe')
local recipeReverseLookup = require('scripts.tcainrework.stored.recipe_from_ingredient')
function inventoryHelper.runUnlockItemType(itemType, collectibleType)
    local runSave = saveManager.GetRunSave()
    if not runSave.obtainedItems then
        runSave.obtainedItems = {}
    end
    if not runSave.unlockedRecipes then
        runSave.unlockedRecipes = {}
    end
    local combinedNameType = itemType .. ((collectibleType and tostring(collectibleType)) or "")
    if not runSave.obtainedItems[combinedNameType] then
        runSave.obtainedItems[combinedNameType] = true
        if recipeReverseLookup[combinedNameType] then
            -- obtain recipe associations
            local resultItems = {}
            for i, recipeName in ipairs(recipeReverseLookup[combinedNameType]) do
                -- obtain recipe from lookup table
                local recipe = recipeLookupIndex[recipeName]
                if recipe and recipe.ConditionTable and recipe.DisplayRecipe then
                    for i, curType in pairs(recipe.ConditionTable) do
                        local potentialItemId = ((Isaac.GetItemIdByName(curType) ~= 1) 
                            and "tcainrework:collectible" .. Isaac.GetItemIdByName(curType)) or nil
                        if not runSave.obtainedItems[curType]
                        and not (potentialItemId and runSave.obtainedItems[potentialItemId]) then
                            goto skipUnlocking
                        end
                    end
                    if not utility.tableContains(runSave.unlockedRecipes, recipeName) then
                        local resultingType = (recipe.Results and recipe.Results.Type)
                        if resultingType then
                            local itemTable = {Type = resultingType, Count = 1}
                            if recipe.Results.Collectible then
                                itemTable.ComponentData = inventoryHelper.generateCollectibleData(recipe.Results.Collectible)
                            end
                            table.insert(resultItems, itemTable)
                        end
                        table.insert(runSave.unlockedRecipes, recipeName)
                    end
                end
                ::skipUnlocking::
            end
            if #resultItems >= 1 then
                TCainRework:CreateToast(
                    InventoryToastTypes.STANDARD, 
                    resultItems, nil,
                    nil, nil,
                    math.max(180, (60 * #resultItems))
                )
            end
        end
    end
    return runSave.obtainedItems[combinedNameType]
end

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

function inventoryHelper.renderItem(itemToDisplay, renderPosition, renderScale, elapsedTime)
    local renderType = inventoryHelper.getItemRenderType(itemToDisplay.Type)
    local renderFallback = (itemToDisplay.ComponentData 
        and (itemToDisplay.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] 
        and (not itemToDisplay.ComponentData[InventoryItemComponentData.CUSTOM_GFX])))
    if renderFallback then
        renderType = renderTypes.Collectible
    end
    local renderSprite = (((renderType == renderTypes.Default) and (elapsedTime and itemSprite3d))
                      or ((renderType == renderTypes.SimpleBlock) and blockSprite)
                      or ((renderType == renderTypes.Collectible) and defaultCollectibleSprite)
                      or ((renderType == renderTypes.CraftingTable) and craftingTableSprite)
                      or itemSprite)
    renderSprite:ReplaceSpritesheet(0, inventoryHelper.getItemGraphic(itemToDisplay))
    renderSprite:LoadGraphics()
    local isEnchanted = inventoryHelper.getDefaultEnchanted(itemToDisplay)
    renderSprite.Color = Color(
        1, 1, 1, 1, 
        0, 0, 0, 
        (((renderType == renderTypes.Default) and TCainRework.elapsedTime) 
        or ((elapsedTime ~= nil) and elapsedTime)) or 0, 
        0, 0, isEnchanted and TCainRework.elapsedTime or 0
    )
    renderSprite.Scale = renderScale or Vector.One
    if renderFallback then
        renderSprite.Scale = renderSprite.Scale / 2
        renderPosition = renderPosition + Vector(8, 13)
    end
    renderSprite:Play("Idle", true)
    renderSprite:Render(renderPosition)
end

local minecraftFont = include("scripts.tcainrework.font")
function inventoryHelper.renderMinecraftText(string, textPosition, textRarity, renderShadow, formatText)
    local textRarityColor = InventoryItemRarityColors[textRarity]
    if renderShadow then
        minecraftFont:DrawString(string, textPosition.X + 1, textPosition.Y + 1, textRarityColor.Shadow, 0, false, formatText)
    end
    minecraftFont:DrawString(string, textPosition.X, textPosition.Y, textRarityColor.Color, 0, false, formatText)
end

return inventoryHelper