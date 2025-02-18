local inventoryHelper = {}

local saveManager = require("scripts.save_manager")
local utility = require("scripts.tcainrework.util")
local itemRegistry = require("scripts.tcainrework.stored.id_to_iteminfo")
local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")
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
            return utility.getLocalizedString("Items", utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]).Name)
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
        return utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]).Quality
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

function inventoryHelper.getItemGraphic(pickup)
    if pickup.ComponentData then
        -- test custom gfx
        if pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX] then
            return pickup.ComponentData[InventoryItemComponentData.CUSTOM_GFX]
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

local function unlockWrapper()
    local minecraftJumpscare = TCainRework.getModSettings().minecraftJumpscare
    return ((minecraftJumpscare == 2) and saveManager.GetRunSave())
        or saveManager.GetPersistentSave()
end

function inventoryHelper.getUnlockedInventory(setUnlocked)
    local runSave = unlockWrapper()
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

function inventoryHelper.getCollectibleCrafted(setUnlocked)
    local runSave = unlockWrapper()
    if not runSave.collectibleCrafted and setUnlocked then
        TCainRework:CreateToast(
            InventoryToastTypes.TUTORIAL, 
            nil, "gfx/ui/right_click.png", 
            "Consume a collectible", "Press §lRMB",
            240
        )
        runSave.collectibleCrafted = setUnlocked
    end
    return runSave.collectibleCrafted
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

local json = require("json")
function inventoryHelper.createItem(itemString, count)
    local itemType, componentData = itemString, nil
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
    if utility.fastItemIDByName(itemString) ~= -1 then
        if not componentData then
            componentData = {}
        end
        componentData[InventoryItemComponentData.COLLECTIBLE_ITEM] = utility.fastItemIDByName(itemString)
        itemType = "tcainrework:collectible"
    end
    return {
        Type = itemType,
        Count = 1 or count,
        ComponentData = componentData
    }
end

local recipeLookupIndex = require("scripts.tcainrework.stored.name_to_recipe")
local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")
function inventoryHelper.conditionalItemLookupType(item)
    local itemName = item.Type
    if item.ComponentData then
        itemName = itemName .. (item.ComponentData[InventoryItemComponentData.CARD_TYPE] or "")
        itemName = itemName .. (item.ComponentData[InventoryItemComponentData.PILL_EFFECT] or "")
        -- fucking hell just replace it entirely I guess
        if item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
        and collectibleStorage.IDToNameLookup[item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]] then
            itemName = collectibleStorage.IDToNameLookup[item.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]]
        end
    end
    return itemName
end

function inventoryHelper.getInventoryItemList(inventorySet, inventoryBlacklist)
    local storedItemCounts = {}
    for i, inventory in ipairs(inventorySet) do
        if inventoryHelper.isValidInventory(inventory)
        and not (inventoryBlacklist and utility.tableContains(inventoryBlacklist, inventory)) then
            for j, item in pairs(inventory) do
                local itemName = inventoryHelper.conditionalItemLookupType(item)
                storedItemCounts[itemName] = (storedItemCounts[itemName] or 0) + (item.Count or 0)
            end
        end
    end
    return storedItemCounts
end

function inventoryHelper.sortTableByTags(a, b)
    return ((not itemTagLookup[a] and itemTagLookup[b]) 
    or ((itemTagLookup[a] and itemTagLookup[b]) and #itemTagLookup[a] < #itemTagLookup[b])
    or false)
end

local cachedRecipeOutputs = {}
inventoryHelper.recipeCraftableDirty = true
function inventoryHelper.checkRecipeCraftable(recipeName, recipe, storedItemCounts)
    if (not inventoryHelper.recipeCraftableDirty) and cachedRecipeOutputs[recipeName] ~= nil then
        return cachedRecipeOutputs[recipeName]
    end
    local typedIndex, matchedTypes = {}, {}
    for i, itemID in pairs(recipe.ConditionTable) do
        local fakeItem = inventoryHelper.createItem(itemID)
        local myItemID = inventoryHelper.conditionalItemLookupType(fakeItem)
        matchedTypes[myItemID] = (matchedTypes[myItemID] or 0) + 1
        table.insert(typedIndex, myItemID)
    end
    table.sort(typedIndex, inventoryHelper.sortTableByTags)

    -- Sift through matching types
    for index, type in ipairs(typedIndex) do
        local itemTags = {type}
        if itemTagLookup[type] then
            itemTags = {}
            -- add different component items to the tags
            for i, itemInTag in ipairs(itemTagLookup[type]) do
                table.insert(itemTags, itemInTag)
                for storedItem, j  in pairs(storedItemCounts) do
                    if storedItem ~= itemInTag 
                    and string.find(storedItem, itemInTag) then
                        table.insert(itemTags, storedItem)
                        -- print(storedItem)
                    end
                end
            end
        end
        for i, itemInTag in ipairs(itemTags) do
            local itemAmount = matchedTypes[typedIndex[index]]
            if storedItemCounts[itemInTag] and itemAmount then
                local subtractableAmount = math.min(storedItemCounts[itemInTag], itemAmount)
                storedItemCounts[itemInTag] = storedItemCounts[itemInTag] - subtractableAmount
                matchedTypes[typedIndex[index]] = itemAmount - subtractableAmount
                if matchedTypes[typedIndex[index]] <= 0 then
                    matchedTypes[typedIndex[index]] = nil
                    goto nextItem
                end
            end
        end
        ::nextItem::
    end
    for type in pairs(matchedTypes) do
        return false
    end
    return true
end

function inventoryHelper.getRecipeBookRecipes(recipeBookTab, searchBarText, inventorySet)
    local recipeList, craftableRecipeList, availableTabs = {}, {}, {}
    local runSave = saveManager.TryGetRunSave()
    if runSave and (runSave.unlockedRecipes and #runSave.unlockedRecipes > 0) then
        for i, recipe in ipairs(runSave.unlockedRecipes) do
            local recipeFromName = recipeLookupIndex[runSave.unlockedRecipes[i]]
            availableTabs[recipeFromName.Category] = true
            if (not recipeBookTab) or (recipeBookTab and recipeFromName.Category == recipeBookTab) then
                local recipeCraftable = inventoryHelper.checkRecipeCraftable(
                    runSave.unlockedRecipes[i], recipeFromName, inventoryHelper.getInventoryItemList(inventorySet)
                )
                cachedRecipeOutputs[runSave.unlockedRecipes[i]] = recipeCraftable
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
        inventoryHelper.recipeCraftableDirty = false
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

-- this function doesn't need to exist anymore i have streamlined its functionality
local function isActiveFromComponent(itemID)
    return (utility.getCollectibleConfig(itemID).Type == ItemType.ITEM_ACTIVE)
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
            elseif inventoryAttribute == InventoryItemComponentData.COLLECTIBLE_ITEM and not soft then
                -- Force Active Items to not stack
                if ((item1.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] 
                and isActiveFromComponent(item1.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]))
                or (item2.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
                and isActiveFromComponent(item2.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]))) then
                    return ((item1.Count or 0) + (item2.Count or 0)) <= 1        
                end
            end
        end
        return true
    end
    return (soft and (item1.ComponentData == nil or item2.ComponentData == nil))
end

function inventoryHelper.itemCanStackWith(item1, item2)
    return (((item1.Type == item2.Type) 
        and canStackComponentData(item1, item2)))
end

-- Generic "of item type" esque function
function inventoryHelper.itemCanStackWithTag(item1, itemOrList)
    if itemTagLookup[itemOrList.Type] then
        return utility.tableContains(itemTagLookup[itemOrList.Type], item1.Type)
            or utility.tableContains(itemTagLookup[itemOrList.Type], inventoryHelper.conditionalItemLookupType(item1))
    elseif (itemOrList.Type and item1.Type == itemOrList.Type
        and canStackComponentData(item1, itemOrList, true)) then
        return true
    end 
    return false
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
        if pickup.ComponentData[InventoryItemComponentData.CARD_TYPE] then
            local cardConfig = utility.getCardConfig(pickup.ComponentData[InventoryItemComponentData.CARD_TYPE])
            table.insert(nameTable, {
                String = utility.getLocalizedString("PocketItems", cardConfig.Name),
                Rarity = InventoryItemRarity.SUBTEXT
            })
        end
        if pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM] then
            local itemConfig = utility.getCollectibleConfig(pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
            if itemTypeTable[itemConfig.Type] then
                table.insert(nameTable, {
                    String = itemTypeTable[itemConfig.Type],
                    Rarity = InventoryItemRarity.EFFECT_POSITIVE
                })
            end
            table.insert(nameTable, {
                String = blindTextAppend .. utility.getLocalizedString("Items", itemConfig.Description),
                Rarity = InventoryItemRarity.SUBTEXT
            })
            if debugStats and pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] then
                if (pickup.ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES] / itemConfig.MaxCharges < 1) then
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
            String = getComponentCount(pickup) .. " component(s)",
            Rarity = InventoryItemRarity.DEBUG_TEXT
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
    if currentStack and currentStack.Count < inventoryHelper.getMaxStackFor(currentStack.Type) then
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
                local remainderAmount = inventoryHelper.getMaxStackFor(currentStack.Type) - currentStack.Count
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
                return inventoryHelper.conditionalItemLookupType(a)
                    < inventoryHelper.conditionalItemLookupType(b)
            end)
        end
        for i, recipe in ipairs(recipeList) do
            local index = 1
            local myConditionTable = {}
            for i, type in pairs(recipe.ConditionTable) do
                myConditionTable[i] = inventoryHelper.createItem(type)
            end
            if shapeless then
                for i, item in pairs(craftingInventory) do
                    if item and item.Type then
                        for j, type in ipairs(myConditionTable) do
                            if utility.tableContains(itemTagLookup[type.Type], item.Type)
                            or utility.tableContains(itemTagLookup[type.Type], inventoryHelper.conditionalItemLookupType(item)) then
                                myConditionTable[j] = item
                                goto nextItemTag
                            end
                        end
                        ::nextItemTag::
                    end
                end
                table.sort(myConditionTable, function(a, b)
                    return inventoryHelper.conditionalItemLookupType(a)
                        < inventoryHelper.conditionalItemLookupType(b)
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
            fakeResultItem.ComponentData = utility.generateCollectibleData(recipe.Results.Collectible)
        end
        return fakeResultItem
    end
    return {Type = "minecraft:stick", Count = 1}
end

function inventoryHelper.conditionalItemFromRecipe(recipe, itemIndex)
    if recipe.ConditionTable and recipe.ConditionTable[itemIndex] then
        local presumedItemType = recipe.ConditionTable[itemIndex]
        local itemCollectibleData = utility.fastItemIDByName(presumedItemType)
        if itemCollectibleData ~= -1 then
            presumedItemType = "tcainrework:collectible"
        end
        local fakeResultItem = inventoryHelper.createItem(presumedItemType)
        if itemCollectibleData ~= -1 then
            fakeResultItem.ComponentData = utility.generateCollectibleData(itemCollectibleData)
        end
        return fakeResultItem
    end
    return {Type = "minecraft:stick", Count = 1}
end

function inventoryHelper.conditionalItemFromShapedRecipe(recipe, inventory, itemIndex)
    local x, y = (((itemIndex - 1) % inventoryHelper.getInventoryWidth(inventory)) + 1), 
        (math.floor((itemIndex - 1) / inventoryHelper.getInventoryHeight(inventory)) + 1)
    x = x + math.floor((recipe.RecipeSize.X - inventoryHelper.getInventoryWidth(inventory)) / 2)
    y = y + (recipe.RecipeSize.Y - inventoryHelper.getInventoryHeight(inventory))

    if (x > 0 and x <= recipe.RecipeSize.X)
    and (y > 0 and y <= recipe.RecipeSize.Y) then
        local offsetIndex = x + ((y - 1) * recipe.RecipeSize.X)
        if recipe.ConditionTable[offsetIndex] then
            return inventoryHelper.conditionalItemFromRecipe(recipe, offsetIndex)
        end
    end
end

local toastStorage = require("scripts.tcainrework.stored.toast_storage")
local recipeLookupIndex = require('scripts.tcainrework.stored.name_to_recipe')
local recipeReverseLookup = require('scripts.tcainrework.stored.recipe_from_ingredient')
function TCainRework:UnlockItemRecipe(recipeName)
    if recipeName then
        local runSave = saveManager.GetRunSave()
        if not runSave.unlockedRecipes then
            runSave.unlockedRecipes = {}
        end
        local recipe = recipeLookupIndex[recipeName]
        if not utility.tableContains(runSave.unlockedRecipes, recipeName) then
            local resultingType = (recipe.Results and recipe.Results.Type)
            if resultingType then
                local itemTable = inventoryHelper.createItem(resultingType)
                if recipe.Results.Collectible then
                    itemTable.ComponentData = utility.generateCollectibleData(recipe.Results.Collectible)
                end
                table.insert(toastStorage, itemTable)
            end
            print('unlocking recipe:', recipeName)
            table.insert(runSave.unlockedRecipes, recipeName)
        end
    end
end

function inventoryHelper.runUnlockItem(item)
    local runSave = saveManager.GetRunSave()
    if not runSave.obtainedItems then
        runSave.obtainedItems = {}
    end
    local combinedNameType = inventoryHelper.conditionalItemLookupType(item)
    runSave.obtainedItems[combinedNameType] = true
    print(combinedNameType)
    if recipeReverseLookup[combinedNameType] then
        -- obtain recipe associations
        for i, recipeName in ipairs(recipeReverseLookup[combinedNameType]) do
            -- obtain recipe from lookup table
            local recipe = recipeLookupIndex[recipeName]
            if recipe and recipe.ConditionTable and recipe.DisplayRecipe then
                for i, curType in pairs(recipe.ConditionTable) do
                    local fakeItem = inventoryHelper.conditionalItemLookupType(inventoryHelper.createItem(curType))
                    if not (runSave.obtainedItems[curType]
                    or runSave.obtainedItems[fakeItem]) then
                        goto skipUnlocking
                    end
                end
                TCainRework:UnlockItemRecipe(recipeName)
            end
            ::skipUnlocking::
        end
    end
end

function inventoryHelper.unlockItemBatch(item)
    if item.Type and itemRegistry[item.Type]
    and itemRegistry[item.Type].ItemTags then
        for i, itemTag in ipairs(itemRegistry[item.Type].ItemTags) do
            inventoryHelper.runUnlockItem(inventoryHelper.createItem(itemTag))
        end
    end
    local itemType = inventoryHelper.conditionalItemLookupType(item)
    if itemType and itemRegistry[itemType] and itemRegistry[itemType].ItemTags then
        for i, itemTag in ipairs(itemRegistry[itemType].ItemTags) do
            inventoryHelper.runUnlockItem(inventoryHelper.createItem(itemTag))
        end
    end
    inventoryHelper.runUnlockItem(item)
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
function inventoryHelper.renderItem(itemToDisplay, renderPosition, renderScale, elapsedTime)
    local collectibleItem = itemToDisplay.ComponentData and itemToDisplay.ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
    local originalRenderPosition = Vector(renderPosition.X, renderPosition.Y)
    local renderType = inventoryHelper.getItemRenderType(itemToDisplay.Type)
    local renderFallback = ((collectibleItem ~= nil) and (getCustomCollectibleSprite(collectibleItem) == -1))
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
        (((elapsedTime ~= nil) and elapsedTime) or ((renderType == renderTypes.Default) and TCainRework.elapsedTime)) or 0, 
        0, 0, isEnchanted and TCainRework.elapsedTime or 0
    )
    renderSprite.Scale = renderScale or Vector.One
    if renderFallback then
        renderSprite.Scale = renderSprite.Scale / 2
        renderPosition = renderPosition + Vector(8, 13)
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

return inventoryHelper