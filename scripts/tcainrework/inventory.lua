local mod = TCainRework

-- load input helpers and utility helpers
local inputHelper = include("scripts.tcainrework.input_helper")
local inventoryHelper = mod.inventoryHelper
local minecraftFont = include("scripts.tcainrework.font")
local saveManager = require("scripts.save_manager")
local utility = require("scripts.tcainrework.util")
local enchantingUI = include("scripts.tcainrework.enchanting.enchanting_ui")

-- Hide Bag of Crafting Inventory
mod:AddCallback(ModCallbacks.MC_HUD_RENDER, function(_)
    local hud = Game():GetHUD()
    local craftingHUD = hud:GetCraftingSprite()
    if inventoryHelper.getUnlockedInventory() then
        craftingHUD:SetRenderFlags(1 << 2)
    else
        craftingHUD:SetRenderFlags(1)
    end
end)

-- Inventory Rendering
local userInterface = Sprite()
userInterface:Load("gfx/ui/ui_elements.anm2", true)
userInterface:Play("Crafting", true)
userInterface.PlaybackSpeed = 0

local enchantmentElements = Sprite()
enchantmentElements:Load("gfx/ui/enchanting_ui_elements.anm2")
enchantmentElements:Play("Tab")
enchantmentElements.PlaybackSpeed = 0

local recipeBookUI = Sprite()
recipeBookUI:Load("gfx/ui/recipe_book_ui.anm2", true)
recipeBookUI.PlaybackSpeed = 0

local hotbarInterface = Sprite()
hotbarInterface:Load("gfx/ui/hotbar.anm2", true)
hotbarInterface:Play("Idle", true)

local hotbarSlotSelected = 1

local blackBG = Sprite()
blackBG:Load("gfx/ui/blackbg.anm2", true)
blackBG:Play("Idle", true)
local blackColor = Color(1, 1, 1, 0.5)

local cellColorRGB = Color(1, 1, 1, 96 / 256, 1, 1, 1, 1)
local cellColorFrontRGB = Color(1, 1, 1, 32 / 256, 1, 1, 1, 1)

local cellColorRed = Color(1, 1, 1, 1, 161 / 255, 113 / 255, 113 / 255, 1)
local cellColorRedOverlay = Color(1, 1, 1, 40 / 255, 1, 1, 1, 1)

local currentTooltipInformation = nil
local cursorHeldItem = nil
local cursorHeldItemLock = {}

local snakeType = nil
local cursorGatherAll = 0
local lockSnaking = false

local cursorSnaking = {}
local snakeFakeItemCount = {}
local snakeCursorRemainder = nil

local searchBarSelected = false
local searchBarText = ""
local searchBarTimer = 0

local function calculateMaxSnake()
    local maxSnakeAmount = 0
    for snakedInventory, snakedIndices in pairs(cursorSnaking) do
        maxSnakeAmount = maxSnakeAmount + #snakedIndices
    end
    return maxSnakeAmount
end

local function resetSnaking(inventory)
    lockSnaking = false
    snakeType = nil
    cursorSnaking[inventory] = {}
    snakeFakeItemCount[inventory] = {}
    cursorHeldItemLock = {}
    snakeCursorRemainder = nil
end

local activeInventories
local inventoryState = InventoryStates.CLOSED

function mod.setInventoryState(newState)
    inventoryState = newState
end

function mod.getInventoryState()
    return inventoryState
end

local eatTimer, breakTimer, eatParticles = -1, 0, {}

local curDisplayingRecipe = nil
local CELL_SIZE = 18

local tooltipBackground = Sprite()
tooltipBackground:Load("gfx/ui/tooltip.anm2", false)
tooltipBackground:ReplaceSpritesheet(0, "gfx/ui/background.png")
tooltipBackground:LoadGraphics()

local recipeBookSlice = Sprite()
recipeBookSlice:Load("gfx/ui/tooltip.anm2", false)
recipeBookSlice:ReplaceSpritesheet(0, "gfx/ui/recipe_book_9slice.png")
recipeBookSlice:LoadGraphics()

local tooltipFrame = Sprite()
tooltipFrame:Load("gfx/ui/tooltip.anm2", false)
tooltipFrame:ReplaceSpritesheet(0, "gfx/ui/frame.png")
tooltipFrame:LoadGraphics()

-- Create Inventories
local lastCombinedString = ""
local outputSlotOccupied = false
local lastOutputItem = nil

local recipeStorage = require("scripts.tcainrework.stored.recipe_storage_cache")
local function checkRecipes()
    -- establish paradoxical bounds
    local craftingInventory = inventoryHelper.getInventory(InventoryTypes.CRAFTING)
    local width = inventoryHelper.getInventoryWidth(craftingInventory)
    local height = inventoryHelper.getInventoryHeight(craftingInventory)
    local topLeft = Vector(width, height)
    local bottomRight = Vector(0, 0)

    -- sift through inventory and readjust bounds
    for k, contents in pairs(craftingInventory) do
        local x, y = (((k - 1) % width) + 1), (math.floor((k - 1) / height) + 1)
        topLeft.X, topLeft.Y = math.min(topLeft.X, x), math.min(topLeft.Y, y)
        bottomRight.X, bottomRight.Y = math.max(bottomRight.X, x), math.max(bottomRight.Y, y)
    end

    local combinedString, itemTagCombinedString, trueCombinedString = "", "", ""
    local recipeIngredientCount = 0
    for k = topLeft.Y, bottomRight.Y do
        for l = topLeft.X, bottomRight.X do
            local craftingIndex = (((k - 1) * 3) + l)
            local craftingType = (craftingInventory[craftingIndex] and craftingInventory[craftingIndex].Type)
            if craftingType then
                local itemCollectibleData = ((craftingInventory[craftingIndex].ComponentData)
                    and craftingInventory[craftingIndex].ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
                if itemCollectibleData then
                    craftingType = craftingType .. itemCollectibleData
                end
                recipeIngredientCount = recipeIngredientCount + 1
            end
            combinedString = combinedString .. ((craftingInventory[craftingIndex] and "#") or " ")
            trueCombinedString = trueCombinedString .. ((craftingInventory[craftingIndex] 
                and (inventoryHelper.createHashedItem(craftingInventory[craftingIndex]))) or " ")
        end
        if k < bottomRight.Y then
            combinedString = combinedString .. "\n"
            trueCombinedString = trueCombinedString .. "\n"
        end
    end

    if trueCombinedString ~= lastCombinedString then
        -- hash current string and update recipe
        local recipeHash = utility.sha1(combinedString)
        local shapelessHash = "shapeless_" .. utility.sha1("count_" .. tostring(recipeIngredientCount))
        local recipeOutput = inventoryHelper.checkRecipeConditional(craftingInventory, recipeStorage.recipeHashmap[recipeHash], topLeft, bottomRight)
            or inventoryHelper.checkRecipeConditional(craftingInventory, recipeStorage.recipeHashmap[shapelessHash], topLeft, bottomRight, true)
        local outputInventory = inventoryHelper.getInventory(InventoryTypes.OUTPUT)
        if recipeOutput then
            lastOutputItem = {
                Type = recipeOutput.Type,
                Count = recipeOutput.Count,
                ComponentData = recipeOutput.ComponentData
            }
            if recipeOutput.Collectible then
                lastOutputItem.ComponentData = utility.generateCollectibleData(recipeOutput.Collectible)
            end
            outputInventory[1] = lastOutputItem
            outputSlotOccupied = true
        else
            outputSlotOccupied = false
            outputInventory[1] = nil
        end
        lastCombinedString = trueCombinedString
    end
end

local function finalizeOutputs()
    local craftingInventory = inventoryHelper.getInventory(InventoryTypes.CRAFTING)
    local outputInventory = inventoryHelper.getInventory(InventoryTypes.OUTPUT)
    if outputSlotOccupied and outputInventory[1] == nil then
        if lastOutputItem then
            inventoryHelper.unlockItemBatch(lastOutputItem)
            lastOutputItem = nil
        else
            print('apparently no last output item? something is DEEPLY wrong')
        end
        for i in pairs(craftingInventory) do
            inventoryHelper.removePossibleAmount(craftingInventory, i, 1)
        end
        outputSlotOccupied = false
        lastCombinedString = ""
    end
    checkRecipes()
    return outputInventory[1]
end

local cancelRecipeOverlay = false
local function inventoryShiftClick(inventorySet, itemInventory, itemIndex)
    local slotsAvailable = true
    local currentItem = itemInventory[itemIndex]
    while (slotsAvailable and currentItem.Count > 0) do
        -- prioritize shift clicking into the topmost inventory
        local firstFreeSlot, foundInventory
        local topmostInventory = inventorySet[1]
        if inventoryHelper.isValidInventory(itemInventory) 
        and topmostInventory and itemInventory ~= topmostInventory then
            local invFreeSlot = inventoryHelper.searchForFreeSlot({topmostInventory}, currentItem)
            if invFreeSlot and invFreeSlot.Slot then
                firstFreeSlot, foundInventory = invFreeSlot.Slot, invFreeSlot.Inventory
                cancelRecipeOverlay = true
            end
        end
        if not (firstFreeSlot and foundInventory) then
            slotsAvailable, firstFreeSlot, foundInventory = inventoryHelper.shiftClickSearchFree(
                inventorySet, itemInventory, currentItem
            )
        end
        -- if there is an item in the slot
        if foundInventory then
            local slotWasAvailable = slotsAvailable
            if foundInventory[firstFreeSlot] then
                local availableStackSpace = inventoryHelper.getMaxStackFor(foundInventory[firstFreeSlot]) - foundInventory[firstFreeSlot].Count
                local mostAllowed = math.min(availableStackSpace, currentItem.Count)
                foundInventory[firstFreeSlot].Count = foundInventory[firstFreeSlot].Count + mostAllowed
                currentItem.Count = currentItem.Count - mostAllowed
                if currentItem.Count <= 0 then
                    itemInventory[itemIndex] = nil
                end
            elseif firstFreeSlot then -- if the slot is empty, relocate the stack there instead
                foundInventory[firstFreeSlot] = currentItem
                itemInventory[itemIndex] = nil
                slotsAvailable = false
            end
            -- please just do one more pass please??? PLEASE??????
            if (itemInventory == inventoryHelper.getInventory(InventoryTypes.OUTPUT)) 
            and (slotWasAvailable and finalizeOutputs()) then
                currentItem = itemInventory[itemIndex]
                slotsAvailable, firstFreeSlot, foundInventory = inventoryHelper.shiftClickSearchFree(
                    inventorySet, itemInventory, currentItem
                )
            end
        end
    end
    inventoryHelper.recipeCraftableDirty = true
end

local function RenderInventorySlot(inventoryPosition, inventory, itemIndex, isLMBPress, isRMBPress, isLMBReleased, isRMBReleased, held)
    local myItem = held or inventory[itemIndex]
    if inventory then
        if not cursorSnaking[inventory] then
            cursorSnaking[inventory] = {}
        end
        if not snakeFakeItemCount[inventory] then
            snakeFakeItemCount[inventory] = {}
        end
    end

    -- mouseover collision check
    local mouseover = inputHelper.hoveringOver(inventoryPosition - Vector.One, CELL_SIZE, CELL_SIZE)

    -- render background box
    local fakeDisplayRecipe, recipeIngredientDisplay = false, nil
    blackBG.Scale = Vector.One * 16
    local cellOffset = Vector.Zero
    if curDisplayingRecipe then
        local isOutput = inventory == inventoryHelper.getInventory(InventoryTypes.OUTPUT)
        local isCrafting = inventory == inventoryHelper.getInventory(InventoryTypes.CRAFTING)
        if (isOutput or isCrafting) and (mouseover and ((cursorHeldItem and (isLMBReleased or isRMBReleased)) 
        or (not cursorHeldItem and (isLMBPress or isRMBPress)))) then
            cancelRecipeOverlay = true
        elseif not held then
            if (isOutput or isCrafting) then
                if not ((#cursorSnaking[inventory] > 1) and utility.tableContains(cursorSnaking[inventory], itemIndex)) then
                    if isOutput then
                        fakeDisplayRecipe = true
                        recipeIngredientDisplay = inventoryHelper.resultItemFromRecipe(curDisplayingRecipe)
                        blackBG.Color = cellColorRed
                        blackBG.Scale = Vector.One * 24
                        cellOffset = -Vector(4, 4)
                    elseif isCrafting then
                        recipeIngredientDisplay = inventoryHelper.getRecipeConditionalItem(curDisplayingRecipe, inventory, itemIndex)
                        fakeDisplayRecipe = (recipeIngredientDisplay ~= nil)
                    end
                    if fakeDisplayRecipe then
                        blackBG.Color = cellColorRed
                        blackBG:Render(inventoryPosition + cellOffset)
                    end

                    -- Shift click any items out of the crafting slots
                    if inventory[itemIndex] and inventoryHelper.isValidInventory(inventory) then
                        inventoryShiftClick(
                            activeInventories[inventoryState],
                            inventory, itemIndex
                        )
                    end
                end
            end
        end
    end

    if not held and mouseover then
        if (not inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_1)
        and not inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_2))
        and not isLMBReleased and not isRMBReleased then
            resetSnaking(inventory)
        else
            if inventoryHelper.isValidInventory(inventory) then
                if not cursorHeldItem then -- simple picking up stacks / half stacks
                    if (not inputHelper.isShiftHeld()) and ((isLMBPress or isRMBPress) and (inventory[itemIndex] and inventory[itemIndex].Count > 0)) then
                        -- lock controls until mouse is released once
                        local takeAmount = inventory[itemIndex].Count
                        if isLMBPress then
                            cursorHeldItemLock[Mouse.MOUSE_BUTTON_1] = true
                            cursorGatherAll = 16
                        elseif isRMBPress then
                            cursorHeldItemLock[Mouse.MOUSE_BUTTON_2] = true
                            takeAmount = math.ceil(takeAmount / 2)
                        end
                        cursorHeldItem = {
                            Type = inventory[itemIndex].Type,
                            Count = takeAmount,
                            ComponentData = inventory[itemIndex].ComponentData or nil
                        }
                        inventory[itemIndex].Count = inventory[itemIndex].Count - takeAmount
                        if inventory[itemIndex].Count <= 0 then
                            inventory[itemIndex] = nil
                        end
                        inventoryHelper.recipeCraftableDirty = true
                    end
                elseif cursorHeldItem then
                    -- releasing item stacks with cursor locks disabled
                    if (not inputHelper.isShiftHeld()) and (isLMBPress and not isRMBPress) then  -- just now realizing I called it "is right mouse button press" and not pressed :facepalm:
                        if cursorGatherAll > 0 
                        and (not inventory[itemIndex])  -- reconvene items if on an empty slot
                        or (inventory[itemIndex] and inventory[itemIndex].Count <= 0) then 
                            inventoryHelper.reconveneFromInventory(cursorHeldItem, activeInventories[inventoryState])
                            cursorHeldItemLock[Mouse.MOUSE_BUTTON_1] = true -- lock mouse from placing again
                        end
                    elseif (not inputHelper.isShiftHeld())
                    and ((isLMBReleased and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_1]) 
                    or (isRMBReleased and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_2])) then
                        cursorHeldItemLock = {}
                        if (snakeType == nil 
                        or calculateMaxSnake() <= 1) then
                            if inventory[itemIndex] 
                            and inventory[itemIndex].Count > 0
                            and not inventoryHelper.itemCanStackWith(inventory[itemIndex], cursorHeldItem) then -- switching between two items
                                local lastItem = inventory[itemIndex]
                                inventory[itemIndex] = cursorHeldItem
                                cursorHeldItem = lastItem
                                lockSnaking = true
                            elseif ((inventory[itemIndex] == nil)
                            or (inventory[itemIndex] 
                            and (inventoryHelper.itemCanStackWith(inventory[itemIndex], cursorHeldItem)) 
                            or inventory[itemIndex].Count <= 0)) then -- place amount into stack
                                local amountToPlace = cursorHeldItem.Count
                                if (not isLMBReleased) and isRMBReleased then
                                    amountToPlace = 1
                                end
                                local remainderAmount = ((inventory[itemIndex] and inventory[itemIndex].Count > 0)
                                    and inventoryHelper.getMaxStackFor(inventory[itemIndex]) - inventory[itemIndex].Count)
                                    or amountToPlace
                                local mostAllowed = math.min(remainderAmount, amountToPlace)
                                cursorHeldItem.Count = cursorHeldItem.Count - mostAllowed
                                if (not inventory[itemIndex]) or (inventory[itemIndex] and inventory[itemIndex].Count <= 0) then
                                    inventory[itemIndex] = {
                                        Type = cursorHeldItem.Type,
                                        Count = 0,
                                        ComponentData = cursorHeldItem.ComponentData or nil
                                    }
                                end
                                inventory[itemIndex].Count = inventory[itemIndex].Count + mostAllowed
                                if cursorHeldItem.Count <= 0 then
                                    cursorHeldItem = nil
                                end
                            end
                            inventoryHelper.recipeCraftableDirty = true
                        end
                    elseif ((inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_1) and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_1]) 
                    or (inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_2) and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_2]))
                    and cursorHeldItem.Count > 0
                    and not lockSnaking then
                        if snakeType == nil then
                            snakeType = (inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_1) and Mouse.MOUSE_BUTTON_1) or Mouse.MOUSE_BUTTON_2
                        elseif (cursorHeldItem.Count > 1)
                        and ((not inventory[itemIndex])
                        or (inventoryHelper.itemCanStackWith(inventory[itemIndex], cursorHeldItem)))
                        and (not utility.tableContains(cursorSnaking[inventory], itemIndex))
                        and (calculateMaxSnake() < cursorHeldItem.Count) then
                            table.insert(cursorSnaking[inventory], itemIndex)
                        end
                    end
                    if isLMBReleased or isRMBReleased then
                        cursorHeldItemLock = {}
                    end
                end
            else -- output only inventory slot
                -- only if there is an item in the output slot
                if (inventory[itemIndex] and inventory[itemIndex].Count > 0) then
                    if not cursorHeldItem
                    and (not inputHelper.isShiftHeld())
                    and (isLMBPress or isRMBPress) then
                        if isLMBPress then
                            cursorHeldItemLock[Mouse.MOUSE_BUTTON_1] = true
                        elseif isRMBPress then
                            cursorHeldItemLock[Mouse.MOUSE_BUTTON_2] = true
                        end
                        cursorHeldItem = {
                            Type = inventory[itemIndex].Type,
                            Count = inventory[itemIndex].Count,
                            ComponentData = inventory[itemIndex].ComponentData or nil
                        }
                        inventory[itemIndex] = nil
                    elseif cursorHeldItem and inventoryHelper.itemCanStackWith(cursorHeldItem, inventory[itemIndex]) and ((not inputHelper.isShiftHeld()) 
                    and ((isLMBReleased and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_1]) or (isRMBReleased and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_2])))
                    and ((cursorHeldItem.Count + inventory[itemIndex].Count) <= inventoryHelper.getMaxStackFor(inventory[itemIndex])) then
                        cursorHeldItem.Count = cursorHeldItem.Count + inventory[itemIndex].Count
                        inventory[itemIndex] = nil
                    end
                    inventoryHelper.recipeCraftableDirty = true
                end

                if isLMBReleased or isRMBReleased then
                    cursorHeldItemLock = {}
                end
            end
        end
        -- inventory controls thingies
        if not searchBarSelected then
            for i = 1, 10 do 
                if (Input.IsButtonTriggered(Keyboard.KEY_0 + i, 0)) then
                    local hotbarInventory = inventoryHelper.getInventory(InventoryTypes.HOTBAR)
                    local lastHotbarItem, lastInventoryItem = hotbarInventory[i], inventory[itemIndex]
                    inventory[itemIndex] = lastHotbarItem
                    hotbarInventory[i] = lastInventoryItem

                    if curDisplayingRecipe then
                        local isOutput = inventory == inventoryHelper.getInventory(InventoryTypes.OUTPUT)
                        local isCrafting = inventory == inventoryHelper.getInventory(InventoryTypes.CRAFTING)
                        if isOutput or isCrafting then
                            curDisplayingRecipe = false
                        end
                    end
                end
            end
            if inventory[itemIndex] then
                local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
                if player and (inputHelper.buttonHeldSticky(Keyboard.KEY_Q, player.ControllerIndex)) then
                    local itemType, componentData = inventory[itemIndex].Type, inventory[itemIndex].ComponentData
                    local amountRemoved = inventoryHelper.removePossibleAmount(inventory, itemIndex, 
                        (inputHelper.isControlHeld() and 64) or 1
                    )
                    if (amountRemoved > 0) then
                        local minecraftItem = Isaac.Spawn(
                            EntityType.ENTITY_PICKUP, mod.minecraftItemID, 0, 
                            player.Position, (player.Velocity:Normalize() or Vector(0, 1)) * 2, player
                        )
                        local pickupData = saveManager.GetRerollPickupSave(minecraftItem)
                        pickupData.Type, pickupData.ComponentData = itemType, componentData
                        pickupData.Count = amountRemoved
                    end
                end
            end
        end
        currentTooltipInformation = {Index = itemIndex, Inventory = inventory}
        myItem = inventory[itemIndex]
    end
    
    if ((not (held or fakeDisplayRecipe)) 
    and (mouseover or (#cursorSnaking[inventory] > 1 and utility.tableContains(cursorSnaking[inventory], itemIndex)))) then
        blackBG.Color = cellColorRGB
        blackBG:Render(inventoryPosition)
    end

    -- Render Item
    local falseSnake = calculateMaxSnake() <= 1 
    local fakeDisplaySnaking = (snakeType ~= nil and cursorHeldItem) and ((inventory and snakeFakeItemCount[inventory][itemIndex]
        and (not falseSnake)) or (held and snakeCursorRemainder))
    if (myItem and myItem.Type and myItem.Count > 0) or fakeDisplaySnaking or fakeDisplayRecipe then
        if not (held and (snakeType ~= nil and not falseSnake and snakeCursorRemainder ~= nil and snakeCursorRemainder <= 0)) then
            local displayItem = ((fakeDisplaySnaking and cursorHeldItem) or (fakeDisplayRecipe and recipeIngredientDisplay)) or myItem
            inventoryHelper.renderItem(displayItem, inventoryPosition)
        
            local itemCount = (myItem and myItem.Count) or 0
            if fakeDisplaySnaking and not falseSnake then
                itemCount = (held and snakeCursorRemainder) or (itemCount + snakeFakeItemCount[inventory][itemIndex])
            end
            if recipeIngredientDisplay and recipeIngredientDisplay.Count then
                itemCount = recipeIngredientDisplay.Count
            end

            local itemCountString = tostring(itemCount)
            if itemCount > 1 then
                local inventoryPositionText = Vector(inventoryPosition.X + (CELL_SIZE - minecraftFont:GetStringWidth(itemCountString)) - 1, 
                    inventoryPosition.Y + CELL_SIZE - (minecraftFont:GetLineHeight() + 1))
                local itemRarity = InventoryItemRarity.COMMON
                if not falseSnake and utility.tableContains(cursorSnaking[inventory], itemIndex)
                and (itemCount >= inventoryHelper.getMaxStackFor(cursorHeldItem)) then
                    itemRarity = InventoryItemRarity.UNCOMMON
                end
                inventoryHelper.renderMinecraftText(itemCountString, inventoryPositionText, itemRarity, true)
            end
        end
    end
    if fakeDisplayRecipe then
        blackBG.Color = cellColorRedOverlay
        blackBG:Render(inventoryPosition + cellOffset)
        if recipeIngredientDisplay and mouseover then
            if not currentTooltipInformation then 
                currentTooltipInformation = {}
            end
            currentTooltipInformation.FakeTooltip = recipeIngredientDisplay
        end
    end
    if not held and mouseover then
        blackBG.Color = (fakeDisplayRecipe and cellColorRGB) or cellColorFrontRGB
        blackBG.Scale = Vector.One * 16
        blackBG:Render(inventoryPosition)
    end
end

local inventoriesGenerated = false
local function getInventories() 
    if not inventoriesGenerated then
        inventoryHelper.createInventory(9, 3, InventoryTypes.INVENTORY, 
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease)
                local inventoryPosition = Vector(gridAlignedTextX - (CELL_SIZE * 4) + 1, gridAlignedTextY + CELL_SIZE - 5)
                inventoryPosition.X = inventoryPosition.X + j * CELL_SIZE
                inventoryPosition.Y = inventoryPosition.Y + i * CELL_SIZE
                RenderInventorySlot(inventoryPosition, inventory, ((i * 9) + j) + 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)
            end
        )
        inventoryHelper.createInventory(9, 1, InventoryTypes.HOTBAR,
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease)
                local inventoryPosition = Vector(gridAlignedTextX - (CELL_SIZE * 4) + 1, gridAlignedTextY + (CELL_SIZE * 4) - 1)
                inventoryPosition.X = inventoryPosition.X + j * CELL_SIZE
                RenderInventorySlot(inventoryPosition, inventory, j + 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)
            end
        )

        inventoryHelper.createInventory(3, 3, InventoryTypes.CRAFTING, 
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease) 
                local inventoryPosition = Vector(gridAlignedTextX - (CELL_SIZE * 3) + 5, gridAlignedTextY - (CELL_SIZE * 3))
                inventoryPosition.X = inventoryPosition.X + j * CELL_SIZE
                inventoryPosition.Y = inventoryPosition.Y + i * CELL_SIZE
                RenderInventorySlot(inventoryPosition, inventory, ((i * 3) + j) + 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)
            end
        )

        inventoryHelper.createInventory(1, 1, InventoryTypes.OUTPUT, 
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease)
                local inventoryPosition = Vector(gridAlignedTextX + (CELL_SIZE * 2.5), gridAlignedTextY - (CELL_SIZE * 2))
                RenderInventorySlot(inventoryPosition, inventory, 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)

                finalizeOutputs()
            end,
        true)

        inventoryHelper.createInventory(1, 1, InventoryTypes.ENCHANTING, 
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease)
                local inventoryPosition = Vector(gridAlignedTextX - (CELL_SIZE * 4) + 8, gridAlignedTextY - (CELL_SIZE + 6))
                RenderInventorySlot(inventoryPosition, inventory, 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)
            end
        )
        inventoryHelper.createInventory(1, 1, InventoryTypes.ENCHANTING_LAPIS, 
            function(i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease)
                local inventoryPosition = Vector(gridAlignedTextX - (CELL_SIZE * 3) + 10, gridAlignedTextY - (CELL_SIZE + 6))
                RenderInventorySlot(inventoryPosition, inventory, 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, nil)
            end,
        true)
        inventoriesGenerated = true
    end

    local inventoryList = {
        [InventoryStates.CRAFTING] = {
            inventoryHelper.getInventory(InventoryTypes.CRAFTING), 
            inventoryHelper.getInventory(InventoryTypes.OUTPUT), 
            inventoryHelper.getInventory(InventoryTypes.INVENTORY), 
            inventoryHelper.getInventory(InventoryTypes.HOTBAR)
        },
        [InventoryStates.ENCHANTING] = {
            inventoryHelper.getInventory(InventoryTypes.ENCHANTING),
            inventoryHelper.getInventory(InventoryTypes.ENCHANTING_LAPIS),
            inventoryHelper.getInventory(InventoryTypes.INVENTORY), 
            inventoryHelper.getInventory(InventoryTypes.HOTBAR)
        }
    }
    return inventoryList
end

-- Add Item Logic
local cellAnimation = {}
function mod:AddItemToInventory(pickupType, amount, optionalComponentData)
    local addedAny = false
    for i = 1, amount do
        local fakeItem = inventoryHelper.createItem(pickupType, -1)
        if optionalComponentData then
            fakeItem.ComponentData = optionalComponentData
        end
        local freeSlotData = inventoryHelper.searchForFreeSlot({
            inventoryHelper.getInventory(InventoryTypes.HOTBAR), 
            inventoryHelper.getInventory(InventoryTypes.INVENTORY)
        }, fakeItem) -- Inventories are flipped when picking up items
        if freeSlotData and freeSlotData.Slot then
            mod.inventoryHelper.getUnlockedInventory(true)
            -- add item
            local slotData = freeSlotData.Inventory[freeSlotData.Slot]
            local lastCount = (slotData and slotData.Count) or 0
            fakeItem.Count = lastCount + 1
            freeSlotData.Inventory[freeSlotData.Slot] = fakeItem
            if freeSlotData.Inventory == inventoryHelper.getInventory(InventoryTypes.HOTBAR) then
                cellAnimation[freeSlotData.Slot] = nil
            end
            addedAny = true
        end
    end
    if addedAny then
        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Pop"), 2, 2, false, math.random(16, 24) / 10, 0)
        local myItem = inventoryHelper.createItem(pickupType)
        if optionalComponentData then
            myItem.ComponentData = optionalComponentData
        end
        inventoryHelper.unlockItemBatch(myItem)
        inventoryHelper.recipeCraftableDirty = true
    end
    return addedAny
end

local itemTagLookup = require("scripts.tcainrework.stored.itemtag_to_items")
local function attemptAutocraftItem(selectedRecipeData, inventorySet)
    SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
    recipeFromName = recipeStorage.nameToRecipe[selectedRecipeData.Name]
    local isCraftable, itemsNeeded, sortedItemList = inventoryHelper.checkRecipeCraftable(selectedRecipeData.Name, recipeFromName, inventorySet)
    if isCraftable then
        local craftingInventory = inventoryHelper.getInventory(InventoryTypes.CRAFTING)
        local outputInventory = inventoryHelper.getInventory(InventoryTypes.OUTPUT)
        -- local itemsNeeded = inventoryHelper.getRecipeItemList(recipeFromName)
        if (not (outputInventory[1] and inventoryHelper.itemCanStackWithTag(
            outputInventory[1], inventoryHelper.resultItemFromRecipe(recipeFromName)))) then
            -- Clear Crafting Inventory First
            local inventoryWidth = inventoryHelper.getInventoryWidth(craftingInventory) - 1
            local inventoryHeight = inventoryHelper.getInventoryHeight(craftingInventory) - 1
            for j = 0, inventoryHeight do
                for i = 0, inventoryWidth do
                    local currentItemIndex = ((i * (inventoryWidth + 1)) + j) + 1
                    if (craftingInventory[currentItemIndex]) then -- and ((not itemsNeeded[currentItemIndex])
                    -- or (not inventoryHelper.itemCanStackWithTag(craftingInventory[currentItemIndex], itemsNeeded[currentItemIndex])))) then
                        inventoryShiftClick(inventorySet, craftingInventory, currentItemIndex)
                    end
                end
            end
        end
        local times = 1
        if inputHelper.isShiftHeld() then
            times = 64
            for i, item in pairs(itemsNeeded) do
                if item and item.Type then
                    times = math.min(times, inventoryHelper.getMaxStackFor(item) + 1)
                end
            end
        end
        while times > 0 do
            inventoryHelper.recipeCraftableDirty = true
            -- refresh sorted item list
            isCraftable, itemsNeeded, sortedItemList = inventoryHelper.checkRecipeCraftable(selectedRecipeData.Name, recipeFromName, inventorySet)
            if isCraftable then
                -- Obtain the highest amount of items per slot able to be placed (based on previous configurations)
                local lowestNumber, highestAllowedNumber = nil, nil
                for index, itemIndex in ipairs(sortedItemList) do
                    local currentAmount = (craftingInventory[itemIndex] and craftingInventory[itemIndex].Count) or -1
                    if currentAmount >= 0 then
                        local currentMaxStack = (craftingInventory[itemIndex] and inventoryHelper.getMaxStackFor(craftingInventory[itemIndex]))
                        lowestNumber = math.min(currentAmount, ((lowestNumber ~= nil) and lowestNumber) or currentAmount)
                        highestAllowedNumber = math.min(currentMaxStack, ((highestAllowedNumber ~= nil) and highestAllowedNumber) or currentMaxStack)
                    end
                end
                if not lowestNumber then
                    lowestNumber = 0
                end
                -- Loop through necessary ingredients
                for index, itemIndex in ipairs(sortedItemList) do
                    local itemOrTag = itemsNeeded[itemIndex]
                    if itemOrTag then
                        -- Get best items for the list in order
                        local itemLookupTable = {}
                        for i, inventory in ipairs(inventorySet) do
                            if (inventory ~= craftingInventory
                            and inventoryHelper.isValidInventory(inventory)) then
                                for j in pairs(inventory) do
                                    if (inventory[j] and inventory[j].Type) 
                                    and inventoryHelper.itemCanStackWithTag(inventory[j], itemOrTag) then
                                        -- print(inventory[j].Type, itemOrTag.Type)
                                        table.insert(itemLookupTable, {Inventory = inventory, Index = j})
                                    end
                                end
                            end
                        end
                        -- if itemTagLookup[itemOrTag.Type] then
                        --     table.sort(itemLookupTable, function(a, b)
                        --         return ((utility.getIndexInTable(itemTagLookup[itemOrTag.Type], a.Inventory[a.Index].Type)
                        --             or utility.getIndexInTable(itemTagLookup[itemOrTag.Type], inventoryHelper.conditionalItemLookupType(a.Inventory[a.Index])))
                        --             < (utility.getIndexInTable(itemTagLookup[itemOrTag.Type], b.Inventory[b.Index].Type)
                        --             or utility.getIndexInTable(itemTagLookup[itemOrTag.Type], inventoryHelper.conditionalItemLookupType(b.Inventory[b.Index]))))
                        --     end)
                        -- end
                        if itemTagLookup[itemOrTag.Type] then
                            table.sort(itemLookupTable, function(a, b)
                                local itemA, itemB = a.Inventory[a.Index], b.Inventory[b.Index]
                                local isInA, positionA = inventoryHelper.isInItemTag(itemOrTag.Type, itemA)
                                local isInB, positionB = inventoryHelper.isInItemTag(itemOrTag.Type, itemB)
                                return (positionA < positionB)
                            end)
                        end
                        for j, itemLookup in ipairs(itemLookupTable) do
                            local inventoryItem = itemLookup.Inventory[itemLookup.Index]
                            if inventoryItem then
                                if inventoryHelper.itemCanStackWithTag(inventoryItem, itemOrTag) and ((not craftingInventory[itemIndex]) 
                                or (inventoryHelper.itemCanStackWith(inventoryItem, craftingInventory[itemIndex]) 
                                and craftingInventory[itemIndex].Count < lowestNumber + 1))
                                and ((not highestAllowedNumber) or (lowestNumber < highestAllowedNumber)) then
                                    local lastItemData = inventoryItem.ComponentData
                                    local removeAmount = inventoryHelper.removePossibleAmount(itemLookup.Inventory, itemLookup.Index, 1)
                                    if removeAmount > 0 then
                                        craftingInventory[itemIndex] = {
                                            Type = inventoryItem.Type,
                                            Count = ((craftingInventory[itemIndex] and craftingInventory[itemIndex].Count) or 0) + removeAmount,
                                            ComponentData = lastItemData
                                        }
                                        itemsNeeded[itemIndex] = nil
                                    end
                                end
                            end
                        end
                    end
                end
            else
                times = 0
            end
            times = times - 1
        end
        curDisplayingRecipe = nil
        lastCombinedString = ""
    else
        -- otherwise just display recipe
        curDisplayingRecipe = recipeFromName
        inventoryHelper.lastStartTime = Isaac.GetTime()
        cancelRecipeOverlay = false
    end
end

local craftingGray = 55 / 255
local craftingFontColor = KColor(craftingGray, craftingGray, craftingGray, 1)

local hotbarCellSize = 20
local inventorySize = Vector(178, 166)

local recipeBookTabs = {"collectible", "active", "passive", "misc"}
local selectedTab = 1
local selectedPage = 0
local currentRecipeCycle, lastSelectedRecipe = 1, nil
local recipeOverlayDisplay, hoveringOverRecipe = nil, nil
local function resetRecipeBook()
    curDisplayingRecipe = nil
    inventoryHelper.lastStartTime = 0
    searchBarSelected = false
    if searchBarText ~= "" then
        searchBarText = ""
    end
    selectedTab = 1
    selectedPage = 0
    -- Recipe Book Cycling
    currentRecipeCycle = 1
    lastSelectedRecipe = nil
    recipeOverlayDisplay = nil
end

if EID then
    local bagOfCraftingDescModifier = EID.ItemReminderDescriptionModifier["5.100.710"]
    bagOfCraftingDescModifier.modifierFunction = function(descObj, _, inOverview)

    end
end

if EID then
    -- Replace Bag Description Modifier
    EID:addDescriptionModifier("TCainReworkBag", 
    function(objectDescription)
        if objectDescription.ObjType == EntityType.ENTITY_PICKUP
        and objectDescription.ObjVariant == PickupVariant.PICKUP_COLLECTIBLE 
        and objectDescription.ObjSubType == CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING then
            return true
        end
    end, 
    function(descObject)
        descObject.description = ""
        return descObject
    end)
end

local cellAnimationSpeed = 0.65
local defaultScale = Vector(42, 46)
local cellAnimationScales = {
    Vector(14, 73),
    Vector(18, 69),
    Vector(21, 65),
    Vector(29, 58),
    Vector(33, 53),
    Vector(37, 49),
    defaultScale
}

local function playerAddCollectible(player, collectibleType, configItem, hotbarInventory)
    local lastActiveItem, lastActiveCharges = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY), 
        (player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) + player:GetBatteryCharge(ActiveSlot.SLOT_PRIMARY))
    if lastActiveItem ~= 0 and (configItem.Type == ItemType.ITEM_ACTIVE) then
        player:RemoveCollectible(lastActiveItem, true, ActiveSlot.SLOT_PRIMARY, true)
    end
    player:AddCollectible(
        collectibleType, 
        hotbarInventory[hotbarSlotSelected].ComponentData[InventoryItemComponentData.COLLECTIBLE_CHARGES], 
        not (hotbarInventory[hotbarSlotSelected].ComponentData[InventoryItemComponentData.COLLECTIBLE_USED_BEFORE]),
        ActiveSlot.SLOT_PRIMARY
    )
    SFXManager():Play(SoundEffect.SOUND_POWERUP_SPEWER)
    Isaac.CreateTimer(function(_) 
        -- show custom birthright text (not working otherwise for now)
        if collectibleType == CollectibleType.COLLECTIBLE_BIRTHRIGHT 
        and player:GetPlayerType() == PlayerType.PLAYER_CAIN_B then
            Game():GetHUD():ShowItemText(
                utility.getLocalizedString("Items", configItem.Name, true), 
                utility.getCustomLocalizedString("items.isaac.birthright.desc", "The Power of Books"),
                false, false
            )
        else
            Game():GetHUD():ShowItemText(player, configItem, false)
        end
    end, 1, 1, true)
    inventoryHelper.removePossibleAmount(hotbarInventory, hotbarSlotSelected, 1)
    if lastActiveItem ~= 0 and (configItem.Type == ItemType.ITEM_ACTIVE) then
        hotbarInventory[hotbarSlotSelected] = {
            Type = "tcainrework:collectible",
            Count = 1,
            ComponentData = {
                [InventoryItemComponentData.COLLECTIBLE_ITEM] = lastActiveItem,
                [InventoryItemComponentData.COLLECTIBLE_CHARGES] = lastActiveCharges,
                [InventoryItemComponentData.COLLECTIBLE_USED_BEFORE] = true
            }
        }
    end
    inventoryHelper.recipeCraftableDirty = true
end

local lastItemName, slotTimer = "", 0
function mod:RenderInventory()
    if EID then
        EID.CraftingIsHidden = true
    end
    if PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    and inventoryHelper.getUnlockedInventory() then
        activeInventories = getInventories()

        local screenSize = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
        local screenCenter = screenSize / 2

        -- Cache Mouse Information
        local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
        local lmbTrigger, rmbTrigger = inputHelper.isMouseButtonTriggered(Mouse.MOUSE_BUTTON_1), inputHelper.isMouseButtonTriggered(Mouse.MOUSE_BUTTON_2)
        if (not (hoveringOverRecipe and (lmbTrigger and not rmbTrigger)))
            and (recipeOverlayDisplay and (lmbTrigger or rmbTrigger)) then
            recipeOverlayDisplay = nil
            lmbTrigger, rmbTrigger = false, false
        end

        local lmbRelease, rmbRelease = inputHelper.isMouseButtonReleased(Mouse.MOUSE_BUTTON_1), inputHelper.isMouseButtonReleased(Mouse.MOUSE_BUTTON_2)

        -- Render Hotbar before everything else
        hotbarInterface:Play("Idle", true)
        local hotbarPosition = screenCenter + Vector(0, Isaac.GetScreenHeight() / 2)
        hotbarInterface:Render(hotbarPosition)
        -- Update Hotbar Selection
        local inventoryClosed = (not (Game():IsPaused() or DeadSeaScrollsMenu:IsOpen())) and (inventoryState == InventoryStates.CLOSED)
        if inventoryClosed then
            local lastHotbarSlot = hotbarSlotSelected
            for i = 1, 10 do 
                local hotbarPosition = screenCenter + Vector(CELL_SIZE - 6, (Isaac.GetScreenHeight() / 2)) 
                    - Vector((hotbarCellSize * 5) - ((i - 1) * hotbarCellSize), hotbarCellSize - 1)
                local hoveringOverHotbar = (inputHelper.hoveringOver(hotbarPosition, hotbarCellSize, hotbarCellSize)
                    and (inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_1) or inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_2)))

                if ((i < 10) and hoveringOverHotbar) or (Input.IsButtonPressed(Keyboard.KEY_0 + i, 0)) then
                    hotbarSlotSelected = i
                    goto continueHotbar
                end
            end
            -- Mouse Wheel Scrolling
            if player and player.ControllerIndex > 0 then
                local leftBumperSticky, rightBumperSticky = inputHelper.buttonHeldSticky(Controller.LEFT_BUMPER, player.ControllerIndex),
                    inputHelper.buttonHeldSticky(Controller.RIGHT_BUMPER, player.ControllerIndex)
                if Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex) then
                    hotbarSlotSelected = hotbarSlotSelected - (((leftBumperSticky and 1) or 0)
                        - ((rightBumperSticky and 1) or 0))
                end
            else
                hotbarSlotSelected = hotbarSlotSelected - Input:GetMouseWheel().Y
            end

            if hotbarSlotSelected <= 0 then
                hotbarSlotSelected = 9
            elseif hotbarSlotSelected > 9 then
                hotbarSlotSelected = 1
            end

            if lastHotbarSlot ~= hotbarSlotSelected then
                eatTimer = -1
            end
        end
        ::continueHotbar::

        -- Render Hotbar
        hotbarInterface:Play("Selector", true)
        hotbarInterface:Render(screenCenter + Vector((hotbarSlotSelected - 1) * hotbarCellSize, Isaac.GetScreenHeight() / 2))
        local hotbarInventory = inventoryHelper.getInventory(InventoryTypes.HOTBAR)
        for i = 1, inventoryHelper.getInventoryWidth(hotbarInventory) do
            local hotbarSlot = hotbarInventory[i]
            cellAnimation[i] = math.min((cellAnimation[i] or (1 - cellAnimationSpeed)) + cellAnimationSpeed, #cellAnimationScales)
            if hotbarSlot then
                local hotbarPosition = screenCenter + Vector(CELL_SIZE - 6, (Isaac.GetScreenHeight() / 2)) 
                    - Vector((hotbarCellSize * 5) - ((i - 1) * hotbarCellSize), hotbarCellSize - 1)
                local myScale = cellAnimationScales[math.floor(cellAnimation[i])] / defaultScale
                inventoryHelper.renderItem(
                    hotbarInventory[i], 
                    (hotbarPosition + Vector(8, 16) - (Vector(8, 16) * myScale)), 
                    myScale
                )
                if hotbarSlot.Count > 1 then
                    local itemCountString = tostring(hotbarSlot.Count)
                    local inventoryPositionText = Vector(hotbarPosition.X + (CELL_SIZE - minecraftFont:GetStringWidth(itemCountString)) - 1, 
                        hotbarPosition.Y + CELL_SIZE - (minecraftFont:GetLineHeight() + 1))
                    inventoryHelper.renderMinecraftText(itemCountString, inventoryPositionText, InventoryItemRarity.COMMON, true)
                end

                if (hotbarSlotSelected == i) then
                    local itemName = inventoryHelper.itemGetFullName(hotbarSlot)[1]
                    if (not lastItemName) or (lastItemName.String ~= itemName.String) then
                        slotTimer = 400
                        lastItemName = itemName
                    end
                    -- hacky text color render fix
                    local colorRarities = InventoryItemRarityColors
                    if lastItemName and lastItemName.Rarity and lastItemName.String then
                        local currentAlpha, currentAlphaShadow = colorRarities[lastItemName.Rarity].Color.Alpha, colorRarities[lastItemName.Rarity].Shadow.Alpha
                        local myAlpha = math.max(math.min(slotTimer, 100) / 100, 0)
                        -- Set colors to our alpha temporarily
                        colorRarities[lastItemName.Rarity].Color.Alpha, colorRarities[lastItemName.Rarity].Shadow.Alpha = myAlpha, myAlpha
                        -- Render text at center of hotbar
                        inventoryHelper.renderMinecraftText(lastItemName.String, 
                            screenCenter + Vector(-(minecraftFont:GetStringWidth(lastItemName.String) / 2), (Isaac.GetScreenHeight() / 2) - 46), 
                            lastItemName.Rarity, true, true
                        )
                        -- Set color back to original colors
                        colorRarities[lastItemName.Rarity].Color.Alpha, colorRarities[lastItemName.Rarity].Shadow.Alpha = currentAlpha, currentAlphaShadow
                    end
                    if slotTimer > 0 then
                        slotTimer = slotTimer - 3
                    end
                end

                if (inventoryState == InventoryStates.CLOSED)
                and ((hotbarInventory[i].ComponentData
                and hotbarInventory[i].ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM])
                and (not inventoryHelper.getCollectibleCrafted())) then
                    inventoryHelper.getCollectibleCrafted(true)
                end
            elseif (hotbarSlotSelected == i) then
                lastItemName = ""
            end
        end

        -- local currentTime = Isaac.GetTime()
        if (not Game():IsPaused()) and player then
            if (not searchBarSelected) 
            and (Input.IsButtonTriggered(Keyboard.KEY_I, 0) 
            or (player.ControllerIndex > 0 and (Input.IsButtonTriggered(Controller.RSTICK_PRESS, player.ControllerIndex)
            or (inventoryState ~= InventoryStates.CLOSED and Input.IsButtonTriggered(Controller.CIRCLE, player.ControllerIndex)))))
            and (not (DeadSeaScrollsMenu and DeadSeaScrollsMenu:IsOpen()))  then
                inventoryState = ((inventoryState ~= InventoryStates.CLOSED) and InventoryStates.CLOSED) or InventoryStates.CRAFTING
            end

            if cursorGatherAll > 0 then
                cursorGatherAll = cursorGatherAll - 1
            end

            if inventoryState ~= InventoryStates.CLOSED then
                local mousePosition = inputHelper.getMousePosition()
                if DeadSeaScrollsMenu and DeadSeaScrollsMenu:IsOpen() then
                    DeadSeaScrollsMenu.CloseMenu(true, true)
                    SFXManager():Stop(Isaac.GetSoundIdByName("deadseascrolls_whoosh"))
                end

                blackBG.Scale = screenSize
                blackBG.Color = blackColor
                blackBG:Render(Vector.Zero)

                local inventorySet = activeInventories[inventoryState]
                -- recipe book icon
                userInterface:SetFrame(inventoryState, 0)
                local buttonLayer = userInterface:GetLayerFrameData(2)
                local regularCrafting = (not inventoryHelper.isClassicCrafting()) and (inventoryState == InventoryStates.CRAFTING)
                local recipeBookOpen = regularCrafting and inventoryHelper.getRecipeBookOpen() 
                if buttonLayer then
                    userInterface:GetLayer(2):SetVisible(regularCrafting)
                    if regularCrafting then
                        local buttonPosition = screenCenter + (Vector((recipeBookOpen and (inventorySize.X / 2)) or 0, 0) + (buttonLayer:GetPos()))
                        if inputHelper.hoveringOver(buttonPosition, 20, 20) then
                            userInterface:SetFrame(inventoryState, 1)
                            if lmbTrigger then
                                recipeBookOpen = inventoryHelper.setRecipeBookOpen(not recipeBookOpen)
                                SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                            end
                        end
                    end
                end
                screenCenter.X = screenCenter.X + ((recipeBookOpen and (inventorySize.X / 2)) or 0)

                userInterface:Render(screenCenter)

                -- Inventory Text Rendering
                local gridAlignedTextX = screenCenter.X - (CELL_SIZE / 2)
                local gridAlignedTextY = screenCenter.Y - (CELL_SIZE / 2) - 3
                minecraftFont:DrawString(
                    utility.getCustomLocalizedString("container.inventory", "Inventory"), 
                    gridAlignedTextX - (CELL_SIZE * 4) + 1, 
                    gridAlignedTextY, craftingFontColor, 0, false
                )

                -- Secondary Inventories Rendering
                for i, inventory in ipairs(inventorySet) do
                    if inventory ~= inventoryHelper.getInventory(InventoryTypes.INVENTORY) then
                        local textOffset = Vector.Zero
                        if inventory == inventoryHelper.getInventory(InventoryTypes.ENCHANTING) then
                            textOffset.X = textOffset.X - 21
                        end
                        minecraftFont:DrawString(inventoryHelper.getInventoryName(inventory), gridAlignedTextX - (CELL_SIZE * 3) + 4 + textOffset.X, 
                            gridAlignedTextY - (CELL_SIZE * 4) + 6 + textOffset.Y, craftingFontColor, 0, false)
                    end
                end

                -- Render Inventories
                for i, inventory in ipairs(inventorySet) do
                    if inventoryHelper.getRenderFunction(inventory) then
                        for i = 0, inventoryHelper.getInventoryHeight(inventory) - 1 do
                            for j = 0, inventoryHelper.getInventoryWidth(inventory) - 1 do
                                inventoryHelper.getRenderFunction(inventory)(
                                    i, j, inventory, gridAlignedTextX, gridAlignedTextY, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease
                                )
                            end
                        end
                    end
                end

                if recipeBookOpen then
                    -- filter button
                    local recipeBookPosition = screenCenter - Vector(inventorySize.X, 0)
                    local hoveringOver = false
                    local recipeBookFilter = inventoryHelper.getRecipeBookFilter()
                    userInterface:SetFrame("Recipe", 0)
                    -- Filter Recipes by whether or not they can be crafted
                    local filterLayer = userInterface:GetLayerFrameData(3)
                    if filterLayer then
                        local filterPosition = recipeBookPosition + (filterLayer:GetPos())
                        hoveringOver = inputHelper.hoveringOver(filterPosition, 26, 16)
                        if hoveringOver and lmbTrigger then
                            recipeBookFilter = inventoryHelper.setRecipeBookFilter(not recipeBookFilter)
                            SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                            selectedPage = 0
                            inventoryHelper.recipeCraftableDirty = true
                        end
                    end
                    local searchLayer = userInterface:GetLayer("search_bar_highlight")
                    if searchLayer then
                        searchLayer:SetVisible(searchBarSelected)
                    end
                    
                    local recipeBookFrame = ((recipeBookFilter and 1 or 0) * 2) + (hoveringOver and 1 or 0)
                    userInterface:SetFrame("Recipe", recipeBookFrame)
                    userInterface:Render(recipeBookPosition)

                    -- Search bar for recipes
                    local searchPosition = recipeBookPosition + Vector(-34, -70)
                    local displaySearchText = utility.getCustomLocalizedString("gui.recipebook.search_hint", "§oSearch§r...")
                    if lmbTrigger then
                        searchBarSelected = lmbTrigger and inputHelper.hoveringOver(searchPosition, 81, 14)
                        searchBarTimer = 0
                    end
                    displaySearchText = (searchBarSelected or searchBarText ~= "") and searchBarText or displaySearchText
                    if searchBarSelected then
                        local exceededSearchBar = (minecraftFont:GetStringWidth(searchBarText) >= 72)
                        searchBarTimer = searchBarTimer + 0.03125
                        if math.floor(searchBarTimer) % 2 == 0
                        and not exceededSearchBar then
                            displaySearchText = displaySearchText .. "_"
                        end

                        for key, keyResponse in pairs(utility.KeyboardStringList) do
                            local alternateKey = inputHelper.isShiftHeld()
                            -- no way to check caps lock
                            -- if key >= Keyboard.KEY_A and key <= Keyboard.KEY_Z
                            -- and Input.IsButtonPressed(Keyboard.KEY_CAPS_LOCK, 0) then
                            --     alternateKey = true
                            -- end
                            
                            local appendChar = keyResponse[1 + (alternateKey and 1 or 0)]
                            if inputHelper.buttonHeldSticky(key, 0) then
                                if key == Keyboard.KEY_BACKSPACE then
                                    searchBarText = searchBarText.sub(searchBarText, 1, -2)
                                elseif not exceededSearchBar then
                                    searchBarText = searchBarText .. appendChar
                                end
                            end
                        end
                    end
                    
                    -- Render Searchbar Text
                    inventoryHelper.renderMinecraftText(displaySearchText, searchPosition + Vector(3, 2),
                        ((searchBarText ~= "" or searchBarSelected) and InventoryItemRarity.COMMON) or InventoryItemRarity.SUBTEXT, true, true)

                    -- Display Recipes
                    local recipeDisplayDisplacement = recipeBookPosition - Vector(48, 52)
    
                    local toRenderTooltip = nil
                    local filteredRecipes, recipeLookup, craftableRecipes, availableTabs = inventoryHelper.getRecipeBookRecipes(
                        recipeBookTabs[selectedTab - 1], searchBarText, inventorySet
                    )
                    if #filteredRecipes > 0 then
                        local recipeDisplacement = Vector.Zero
                        local chosenList = (recipeBookFilter and craftableRecipes) or filteredRecipes
                        local maxPage = math.ceil(#chosenList / 20)
                        if selectedPage > maxPage - 1 then
                            selectedPage = maxPage - 1
                        end
                        local pageDisplacement = (selectedPage * 20)
                        for i = 1, 20 do
                            local recipeNames = recipeLookup[chosenList[i + pageDisplacement]]
                            if recipeNames then
                                local isCraftableRecipe = ((chosenList == craftableRecipes) 
                                    or utility.tableContains(craftableRecipes, chosenList[i + pageDisplacement]))
                                recipeBookUI:SetFrame("CraftingSlot", 1 - ((isCraftableRecipe and 1) or 0))
                                recipeBookUI:Render(recipeDisplayDisplacement + recipeDisplacement)
                                
                                -- mark recipe amount 
                                local recipeAmount = #recipeNames
                                if (chosenList == craftableRecipes) then
                                    recipeAmount = 0
                                    for i, recipeData in ipairs(recipeNames) do
                                        if recipeData.Craftable then
                                            recipeAmount = recipeAmount + 1
                                        end
                                    end
                                end
                                local recipeDisplayIndex = 1
                                for _, recipeData in ipairs(recipeNames) do
                                    local recipe = recipeStorage.nameToRecipe[recipeData.Name]
                                    local fakeItem = inventoryHelper.resultItemFromRecipe(recipe)
                                    if ((chosenList ~= craftableRecipes) or recipeData.Craftable) then
                                        local itemDisplacement = 4 + ((recipeDisplayIndex - recipeAmount) * 2) + (recipeAmount - 1) * 1
                                        inventoryHelper.renderItem(
                                            fakeItem, recipeDisplayDisplacement 
                                            + recipeDisplacement + (Vector.One * itemDisplacement)
                                        )
                                        recipeDisplayIndex = recipeDisplayIndex + 1
                                    end
                                end
                                if inputHelper.hoveringOver(recipeDisplayDisplacement + recipeDisplacement, 26, 26) then
                                    -- early recipe detection for prioritizing recipes that are craftable
                                    local lastRecipeCycle = currentRecipeCycle
                                    if lmbTrigger then
                                        if (lastSelectedRecipe ~= chosenList[i + pageDisplacement]) then
                                            -- attempt to select a craftable recipe
                                            currentRecipeCycle = 1
                                            for i, recipeData in ipairs(recipeNames) do
                                                if recipeData.Craftable then
                                                    currentRecipeCycle = i
                                                    break
                                                end
                                            end
                                            lastSelectedRecipe = chosenList[i + pageDisplacement]
                                        else
                                            -- advance recipes only if the output slot is full
                                            if (curDisplayingRecipe or (inventoryHelper.getInventory(InventoryTypes.OUTPUT)[1] ~= nil)) then
                                                currentRecipeCycle = (currentRecipeCycle % (#recipeNames)) + 1
                                                while ((chosenList == craftableRecipes) and (not recipeNames[currentRecipeCycle].Craftable)) do
                                                    currentRecipeCycle = (currentRecipeCycle % (#recipeNames)) + 1
                                                end
                                            end
                                        end
                                    end
                                    local recipeFromName = recipeStorage.nameToRecipe[recipeNames[1].Name]
                                    toRenderTooltip = inventoryHelper.resultItemFromRecipe(recipeFromName)
                                    toRenderTooltip.MultipleRecipes = true
                                    if rmbTrigger then
                                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                                        recipeOverlayDisplay = {Recipes = recipeNames, Position = Vector(recipeDisplacement.X, recipeDisplacement.Y)}
                                    elseif lmbTrigger then
                                        local selectedRecipeData = recipeNames[currentRecipeCycle]
                                        attemptAutocraftItem(selectedRecipeData, inventorySet)
                                    end
                                end

                                recipeDisplacement.X = recipeDisplacement.X + 25
                                if (i % 5) == 0 then
                                    recipeDisplacement.Y = recipeDisplacement.Y + 25
                                    recipeDisplacement.X = 0
                                end
                            end
                        end

                        -- Page Switch Buttons
                        if maxPage > 1 then
                            local centerRecipeBook = recipeDisplayDisplacement + Vector(60, 114)
                            if selectedPage >= 1 then
                                local leftPos = centerRecipeBook - Vector(21, 0)
                                recipeBookUI:SetFrame("Left", 0)
                                if inputHelper.hoveringOver(leftPos - Vector(12, 8), 12, 18) then
                                    recipeBookUI:SetFrame("Left", 1)
                                    if lmbTrigger then
                                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                                        selectedPage = selectedPage - 1
                                    end
                                end
                                recipeBookUI:Render(leftPos)
                            end
                        
                            local curPage = tonumber(selectedPage + 1)
                            local maxPage = tonumber(maxPage)
                            local textLength = minecraftFont:GetStringWidth(curPage .. maxPage) / 2
                            inventoryHelper.renderMinecraftText(curPage .. "/" .. maxPage, centerRecipeBook - Vector(1 + textLength, 5), InventoryItemRarity.COMMON, true)

                            if maxPage > selectedPage + 1 then
                                local rightPos = centerRecipeBook + Vector(22, 0)
                                recipeBookUI:SetFrame("Right", 0)
                                if inputHelper.hoveringOver(rightPos - Vector(0, 8), 11, 18) then
                                    recipeBookUI:SetFrame("Right", 1)
                                    if lmbTrigger then
                                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                                        selectedPage = selectedPage + 1
                                    end
                                end
                                recipeBookUI:Render(rightPos)
                            end
                        end
                    end

                    -- Render Tabs
                    local tabAdvancePosition = 0
                    for i = 1, #recipeBookTabs + 1 do
                        if i <= 1 or availableTabs[recipeBookTabs[i - 1]] then
                            recipeBookUI:SetFrame("Tab", (i == selectedTab and 0) or 1)
                            local recipeBookTabPosition = recipeDisplayDisplacement - Vector(8, 15 - (27 * (tabAdvancePosition)))
                            recipeBookUI:ReplaceSpritesheet(4, "gfx/ui/" .. (recipeBookTabs[i - 1] or "search") .. ".png", true)
                            recipeBookUI:Render(recipeBookTabPosition)
                            if inputHelper.hoveringOver(recipeBookTabPosition - Vector(32, 13), 32, 26) then
                                if lmbTrigger then
                                    SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                                    selectedTab = i
                                    selectedPage = 0
                                end
                            end
                            tabAdvancePosition = tabAdvancePosition + 1
                        end
                    end

                    if hoveringOver then
                        local tooltipPosition = mousePosition + Vector(8, 12)
                        -- local textString = "Showing " .. (recipeBookFilter and "Craftable" or "All")
                        local textString = utility.getCustomLocalizedString(
                            "gui.recipebook.toggleRecipes." .. ((recipeBookFilter and "craftable") or "all"), 
                            (recipeBookFilter and "Showing Craftable") or "Showing All"
                        )

                        local nineSliceSize = Vector(
                            minecraftFont:GetStringWidth(textString) + 4, 
                            minecraftFont:GetLineHeight() + 2
                        )
                        utility.renderNineSlice(tooltipBackground, tooltipPosition, nineSliceSize)
                        inventoryHelper.renderMinecraftText(textString, tooltipPosition 
                            + Vector(2, -(minecraftFont:GetLineHeight() / 2)), InventoryItemRarity.COMMON, true)
                        utility.renderNineSlice(tooltipFrame, tooltipPosition, nineSliceSize)
                    elseif (not recipeOverlayDisplay) and toRenderTooltip then
                        inventoryHelper.renderTooltip(mousePosition, inventoryHelper.itemGetFullName(toRenderTooltip))
                    end
                
                    -- Recipe Peeking
                    if recipeOverlayDisplay then
                        local maxWidth = 5
                        local recipeList = recipeOverlayDisplay.Recipes
                        if recipeBookFilter then
                            recipeList = {}
                            for i, recipeData in ipairs(recipeOverlayDisplay.Recipes) do
                                if recipeData.Craftable then
                                    table.insert(recipeList, recipeData)
                                end
                            end
                        end
                        local width, height = math.min(maxWidth, #recipeList), math.ceil(#recipeList / maxWidth)
                        local sizeVector = (Vector(width, height) * 25) + (Vector.One * 2)
                        local recipePeekPosition = (recipeDisplayDisplacement + recipeOverlayDisplay.Position 
                            + ((Vector(0, sizeVector.Y) - (Vector.One * 2)) / 2) + (Vector.One * 4))
                        while ((recipePeekPosition + sizeVector).X > (Isaac.GetScreenWidth() / 2)) do
                            recipePeekPosition.X = recipePeekPosition.X - 25
                        end
                        while ((recipePeekPosition + sizeVector).Y > (recipeDisplayDisplacement.Y + 175)) do
                            recipePeekPosition.Y = recipePeekPosition.Y - 25
                        end
                        utility.renderNineSlice(
                            recipeBookSlice, 
                            recipePeekPosition, 
                            sizeVector
                        )

                        local overlayRenderPosition = Vector.Zero
                        local craftingInventory = inventoryHelper.getInventory(InventoryTypes.CRAFTING)
                        local inventoryWidth = inventoryHelper.getInventoryWidth(craftingInventory) - 1
                        local inventoryHeight = inventoryHelper.getInventoryHeight(craftingInventory) - 1
                        hoveringOverRecipe = nil
                        for i, recipe in ipairs(recipeList) do
                            local isCraftableOverlay = recipe.Craftable
                            local totalOverlayPosition = (recipePeekPosition - Vector(-1, (12 * height) - (2 / height) + 2)) + overlayRenderPosition
                            local hoveringOver = inputHelper.hoveringOver(totalOverlayPosition, 24, 24)
                            recipeBookUI:SetFrame("Overlay", (2 - ((isCraftableOverlay and 2) or 0)) + ((hoveringOver and 1) or 0))
                            recipeBookUI:Render(totalOverlayPosition)
                            if hoveringOver then
                                hoveringOverRecipe = i
                            end
                            if (hoveringOverRecipe == i) and lmbTrigger then
                                attemptAutocraftItem(recipe, inventorySet)
                            end
                            -- Render Mini Recipe Overlay
                            for j = 0, inventoryHeight do
                                for i = 0, inventoryWidth do
                                    local currentItemIndex = ((i * (inventoryWidth + 1)) + j) + 1
                                    local fakeItem = inventoryHelper.getRecipeConditionalItem(recipeStorage.nameToRecipe[recipe.Name], craftingInventory, currentItemIndex)
                                    if fakeItem then
                                        inventoryHelper.renderItem(fakeItem, 
                                            totalOverlayPosition + (Vector(j, i) * 7) + (Vector.One * 2.5), 
                                            Vector.One / 3
                                        )
                                    end
                                end
                            end

                            overlayRenderPosition.X = overlayRenderPosition.X + 25
                            if (i % maxWidth <= 0) then
                                overlayRenderPosition.X = 0
                                overlayRenderPosition.Y = overlayRenderPosition.Y + 25
                            end
                        end
                        lmbTrigger, rmbTrigger = false, false
                    end
                else
                    resetRecipeBook()
                end

                -- enchanting UI
                if (inventoryState == InventoryStates.ENCHANTING) then
                    local enchantmentTooltip = {}
                    local maxEnchantTabs, enchantWordDisplacement = 3, 1
                    local elementHeight = 19
                    local displayEnchantments = enchantingUI.canEnchant(inventoryHelper.getInventory(InventoryTypes.ENCHANTING)[1])
                    for i = 1, maxEnchantTabs do
                        local canChooseEnchantment = i < maxEnchantTabs
                        local enchantAnimationDisplace = ((displayEnchantments and canChooseEnchantment) and 1) or 0
                        local positionElement = Vector(28, 69 - ((i - 1) * elementHeight))
                        local selectedColor = enchantingUI.MainColor
                        enchantmentElements:SetFrame("Tab", enchantAnimationDisplace)
                        local isHoveringEnchantment = displayEnchantments and inputHelper.hoveringOver(screenCenter - positionElement, 108, elementHeight)
                        if isHoveringEnchantment then
                            if canChooseEnchantment then
                                enchantmentElements:SetFrame("Tab", 2)
                                selectedColor = enchantingUI.SelectedColor
                            end
                        end
                        enchantmentElements:Render(screenCenter - positionElement)
                        if displayEnchantments then
                            enchantmentElements:SetFrame("Cost", ((maxEnchantTabs + i) - 1) - (maxEnchantTabs * enchantAnimationDisplace))
                            positionElement.X = positionElement.X + 1
                            enchantmentElements:Render(screenCenter - positionElement)
                            
                            -- Render standard galactic text
                            local textPosition = (screenCenter - positionElement) + (Vector.One * 2)
                            local enchantWords, wordDisplacement = enchantingUI.getEnchantWords(i + enchantWordDisplacement)
                            enchantWordDisplacement = enchantWordDisplacement + wordDisplacement
                            minecraftFont:DrawString(
                                "§g" .. enchantWords, 
                                textPosition.X + ((1 / minecraftFont.fontScale) + 19), textPosition.Y, 
                                (canChooseEnchantment and selectedColor) or enchantingUI.SubColor, 0, false, true
                            )
                            local enchantmentCost, enchantmentName = enchantingUI.getEnchantment(i)
                            local enchantCostString = tostring(enchantmentCost)
                            inventoryHelper.renderMinecraftText(
                                enchantCostString, 
                                textPosition + Vector(
                                    105 - minecraftFont:GetStringWidth(enchantCostString), 
                                    elementHeight - (minecraftFont:GetLineHeight() + 4)
                                ), 
                                (canChooseEnchantment and InventoryItemRarity.EXPERIENCE) 
                                or InventoryItemRarity.EXPERIENCE_DISABLED, true, false
                            )
                            if isHoveringEnchantment then
                                table.insert(enchantmentTooltip, {
                                    String = enchantmentName .. " . . . ?",
                                    Rarity = (canChooseEnchantment and InventoryItemRarity.COMMON) 
                                        or InventoryItemRarity.SUBTEXT
                                })
                                table.insert(enchantmentTooltip, {String = "", Rarity = InventoryItemRarity.COMMON})
                                table.insert(enchantmentTooltip, {String = "Level Requirement: " .. enchantCostString, Rarity = InventoryItemRarity.EFFECT_NEGATIVE})
                            end
                        end
                    end
                    if #enchantmentTooltip > 0 then
                        inventoryHelper.renderTooltip(mousePosition, enchantmentTooltip)
                    end
                end

                if cursorHeldItem then
                    RenderInventorySlot(mousePosition - Vector.One * 8, nil, 1, lmbTrigger, rmbTrigger, lmbRelease, rmbRelease, cursorHeldItem)
                    -- Handle Snaking for next frame
                    local maxSnake = calculateMaxSnake()
                    if (snakeType ~= nil and maxSnake > 1) then
                        local maxSnakeAmount = math.min(maxSnake, cursorHeldItem.Count)
                        local itemDistribution = (snakeType == Mouse.MOUSE_BUTTON_1 and math.floor(cursorHeldItem.Count / maxSnakeAmount)) or 1
                        snakeCursorRemainder = cursorHeldItem.Count - (itemDistribution * maxSnakeAmount)
                        for snakedInventory, snakedIndices in pairs(cursorSnaking) do
                            for i, index in ipairs(snakedIndices) do
                                local remainder = math.max(0, (((snakedInventory[index] and snakedInventory[index].Count) or 0) + itemDistribution) 
                                    - inventoryHelper.getMaxStackFor(cursorHeldItem))
                                if remainder > 0 then
                                    snakeCursorRemainder = snakeCursorRemainder + remainder
                                end
                                snakeFakeItemCount[snakedInventory][index] = itemDistribution - remainder
                            end
                        end
                        -- controls to finalize snaking
                        if ((lmbRelease and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_1]) 
                        or (rmbRelease and not cursorHeldItemLock[Mouse.MOUSE_BUTTON_2])) then
                            if (snakeType == Mouse.MOUSE_BUTTON_1 and rmbRelease)
                            or (snakeType == Mouse.MOUSE_BUTTON_2 and lmbRelease) then
                                if lmbRelease then
                                    cursorHeldItemLock[Mouse.MOUSE_BUTTON_2] = true
                                elseif rmbRelease then
                                    cursorHeldItemLock[Mouse.MOUSE_BUTTON_1] = true
                                end
                                lmbRelease = false
                                rmbRelease = false
                            else
                                -- apply snaking effects (sigh)
                                for snakedInventory, snakedIndices in pairs(cursorSnaking) do
                                    for i, index in ipairs(snakedIndices) do
                                        if not snakedInventory[index] then
                                            snakedInventory[index] = {
                                                Type = cursorHeldItem.Type,
                                                Count = 0,
                                                ComponentData = cursorHeldItem.ComponentData or nil
                                            }
                                        end
                                        snakedInventory[index].Count = snakedInventory[index].Count + snakeFakeItemCount[snakedInventory][index]
                                    end
                                end
                                cursorHeldItem.Count = snakeCursorRemainder
                                if cursorHeldItem.Count <= 0 then
                                    cursorHeldItem = nil
                                end
                            end
                            for snakedInventory, snakedIndices in pairs(cursorSnaking) do
                                resetSnaking(snakedInventory)
                            end
                            inventoryHelper.recipeCraftableDirty = true
                            cancelRecipeOverlay = true
                        end
                    else -- attempt dropping item
                        if not (inputHelper.hoveringOver(screenCenter - (inventorySize / 2), inventorySize.X, inventorySize.Y, true)
                        or (recipeBookOpen and inputHelper.hoveringOver(screenCenter - (Vector(inventorySize.X - 30, 0) + (inventorySize / 2)),  inventorySize.X, inventorySize.Y, true))) then
                            local amount = (rmbRelease and 1) or (cursorHeldItem.Count)
                            if lmbRelease or rmbRelease then
                                cursorHeldItem.Count = cursorHeldItem.Count - amount
                                local minecraftItem = Isaac.Spawn(EntityType.ENTITY_PICKUP, mod.minecraftItemID, 0, player.Position, (player.Velocity:Normalize() or Vector(0, 1)) * 2, player)
                                local pickupData = saveManager.GetRerollPickupSave(minecraftItem)
                                pickupData.Type = cursorHeldItem.Type
                                pickupData.Count = amount
                                pickupData.ComponentData = cursorHeldItem.ComponentData
                                if cursorHeldItem.Count <= 0 then
                                    cursorHeldItem = nil
                                end
                                inventoryHelper.recipeCraftableDirty = true
                            end
                        end
                    end
                end
                if currentTooltipInformation then -- Render Tooltips
                    if currentTooltipInformation.FakeTooltip then
                        inventoryHelper.renderTooltip(mousePosition, inventoryHelper.itemGetFullName(currentTooltipInformation.FakeTooltip))
                    end
                    local currentItemTooltip = (currentTooltipInformation.Inventory[currentTooltipInformation.Index])
                    if currentItemTooltip and currentItemTooltip.Type then
                        if not cursorHeldItem then
                            inventoryHelper.renderTooltip(mousePosition, inventoryHelper.itemGetFullName(currentItemTooltip))
                        end

                        -- Item Shift Clicking
                        if (player.ControllerIndex > 0 and (inputHelper.isMouseButtonTriggered(Controller.TRIANGLE))) 
                        or ((player.ControllerIndex <= 0) and (inputHelper.isShiftHeld() and (((not cursorHeldItem) and (lmbTrigger or rmbTrigger))
                        or ((cursorHeldItem) and (lmbRelease or rmbRelease))))) then
                            inventoryShiftClick(
                                inventorySet, 
                                currentTooltipInformation.Inventory, 
                                currentTooltipInformation.Index
                            )
                        end
                    end
                    currentTooltipInformation = nil
                end
                if cancelRecipeOverlay then
                    curDisplayingRecipe = nil
                    cancelRecipeOverlay = false
                end
                -- Update Inputs
            else
                resetRecipeBook()

                -- Hotbar Usage
                if hotbarInventory[hotbarSlotSelected]
                and hotbarInventory[hotbarSlotSelected].Type then
                    -- if collectible item
                    if hotbarInventory[hotbarSlotSelected].ComponentData
                    and hotbarInventory[hotbarSlotSelected].ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
                    and inventoryHelper.getItemUnlocked(hotbarInventory[hotbarSlotSelected]) then
                        local collectibleType = hotbarInventory[hotbarSlotSelected].ComponentData[InventoryItemComponentData.COLLECTIBLE_ITEM]
                        -- Well aware this doesn't work with multiplayer. won't fix yet
                        if inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_2) and player and player:IsItemQueueEmpty() then
                            local configItem = Isaac.GetItemConfig():GetCollectible(collectibleType)
                            local isActiveItem = (configItem.Type == ItemType.ITEM_ACTIVE)
                            if isActiveItem then
                                if rmbTrigger then
                                    player:AnimateCollectible(collectibleType)
                                    playerAddCollectible(player, collectibleType, configItem, hotbarInventory)
                                end
                            elseif breakTimer <= 0 then
                                if eatTimer <= -1 then
                                    eatTimer = 80
                                end
                                eatTimer = eatTimer - 1
                                if eatTimer % 12 == 0 then
                                    SFXManager():Play(
                                        Isaac.GetSoundIdByName("Minecraft_Eat"), 
                                        (math.random(1, 3) / 2), 2, false, 
                                        (math.random(8, 12) / 10), 0
                                    )

                                    if not eatParticles[GetPtrHash(player)] then
                                        eatParticles[GetPtrHash(player)] = {}
                                    end
                                    for i = 1, math.random(3, 5) do
                                        local particleSprite = Sprite()
                                        particleSprite:Load("gfx/itemanimation.anm2")
                                        particleSprite:ReplaceSpritesheet(0, configItem.GfxFileName)
                                        particleSprite:LoadGraphics()
                                        particleSprite:Play("Idle")

                                        local bitSize = math.random(5, 10)
                                        local clipPosition = Vector(
                                            math.random(0, 32 - bitSize), 
                                            math.random(0, 32 - bitSize)
                                        )
                                        local particleEffect = {
                                            Position = player.Position + (RandomVector() * math.random(1, 4)) / 8,
                                            Sprite = particleSprite,
                                            ClipPosition = clipPosition,
                                            ClipSize = bitSize,
                                            Velocity = Vector(math.random(-10, 10) / 10, (math.random(-9, -3) / 2)),
                                            Life = math.random(15, 35)
                                        }
                                        table.insert(eatParticles[GetPtrHash(player)], particleEffect)
                                    end
                                end
                                if eatTimer <= 0 then
                                    playerAddCollectible(player, collectibleType, configItem, hotbarInventory)
                                    SFXManager():Play(
                                        Isaac.GetSoundIdByName("Minecraft_Burp"), 
                                        0.5, 2, false, 
                                        (math.random(90, 100) / 100), 0
                                    )
                                    eatTimer = -1
                                    breakTimer = 32
                                end
                            end
                        elseif not inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_2) then
                            eatTimer = -1
                        end
                    end
                end
            end
            breakTimer = math.max(breakTimer - 1, 0)

            inputHelper.Update(
                ((not (Game():IsPaused() or DeadSeaScrollsMenu:IsOpen()) 
                and (inventoryState ~= InventoryStates.CLOSED)) and player.ControllerIndex > 0)
            )
            -- print(Isaac.GetTime() - currentTime)
        end
    end
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, offset)
    if eatParticles[GetPtrHash(player)] then
        local toRemove = {}
        local reflection = Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
        for i, particle in pairs(eatParticles[GetPtrHash(player)]) do
            local particleSprite = particle.Sprite
            particleSprite:Render(
                Isaac.WorldToScreen(particle.Position) + offset, 
                particle.ClipPosition, 
                (Vector.One * 32) - (particle.ClipPosition + Vector(particle.ClipSize, particle.ClipSize))
            )
            if not reflection then
                particle.Position = particle.Position + particle.Velocity
                particle.Velocity.Y = particle.Velocity.Y + 0.25
                particle.Life = particle.Life - 1
                if particle.Life <= 0 then
                    eatParticles[GetPtrHash(player)][i] = nil
                end
            end
        end
    end
end)

if StageAPI and StageAPI.Loaded then
    StageAPI.UnregisterCallbacks("CainCraftingTable")
    StageAPI.AddCallback(
        "CainCraftingTable",
        "POST_HUD_RENDER",
        CallbackPriority.DEFAULT,
        function()
            if PauseMenu.GetState() <= PauseMenuStates.CLOSED
            and not StageAPI.IsHUDAnimationPlaying() then
                mod:RenderInventory()
            end
        end
    )
    mod:AddCallback(ModCallbacks.MC_POST_HUD_RENDER, function()
        if ((PauseMenu.GetState() > PauseMenuStates.CLOSED)
        or StageAPI.IsHUDAnimationPlaying()) then
            mod:RenderInventory()
        end
    end)
else
    mod:AddCallback(ModCallbacks.MC_POST_HUD_RENDER, mod.RenderInventory)
end

local function resetInventories(_)
    inventoryState = InventoryStates.CLOSED
    inventoriesGenerated = false
    resetRecipeBook()
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_)
    local runSave = saveManager.GetRunSave()
    if not runSave.ClassicCrafting then
        runSave.ClassicCrafting = (mod.getModSettings().classicCrafting == 2)
    end
    local toastStorage = require("scripts.tcainrework.stored.toast_storage")
    for i in pairs(toastStorage) do
        toastStorage[i] = nil
    end
    resetInventories()
end)
mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD, resetInventories)

-- Pause Screen Handling (for inventory)
mod:AddPriorityCallback(ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
CallbackPriority.IMPORTANT,
function(_, pauseBody, pauseStats) 
    if inventoryState ~= InventoryStates.CLOSED
    or DeadSeaScrollsMenu:IsOpen() then
        PauseMenu.SetState(PauseMenuStates.CLOSED)
        if (not EscClosesDSS) and DeadSeaScrollsMenu:IsOpen() then
            DeadSeaScrollsMenu.CloseMenu(false, false)
            -- DeadSeaScrollsMenu.back()
        end
        inventoryState = InventoryStates.CLOSED
        return false
    end
end)
function mod:pageTurnStopSound(ID, Volume, FrameDelay, Loop, Pitch, Pan)
    if inventoryState ~= InventoryStates.CLOSED
    or DeadSeaScrollsMenu:IsOpen() then
        return false
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_SFX_PLAY, mod.pageTurnStopSound, SoundEffect.SOUND_PAPER_IN)
mod:AddCallback(ModCallbacks.MC_PRE_SFX_PLAY, mod.pageTurnStopSound, SoundEffect.SOUND_PAPER_OUT)

mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, entity, inputHook, buttonAction)
    if inventoryState ~= InventoryStates.CLOSED then
        return 0
    end
end, InputHook.GET_ACTION_VALUE)

local excludeDisable = {
    [ButtonAction.ACTION_MENUBACK] = true
}

local rubberBandFrame = false
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, entity, inputHook, buttonAction)
    if inputHook ~= InputHook.GET_ACTION_VALUE then
        local player = entity and entity:ToPlayer()
        if inventoryState ~= InventoryStates.CLOSED then
            if (buttonAction < ButtonAction.ACTION_PAUSE)
            or searchBarSelected and not excludeDisable[buttonAction] then
                return false
            end
        elseif player and player.ControllerIndex > 0 then
            if Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex)
            and ((buttonAction == ButtonAction.ACTION_BOMB) or (buttonAction == ButtonAction.ACTION_PILLCARD)) then
                rubberBandFrame = false
                return false
            elseif (buttonAction == ButtonAction.ACTION_DROP) 
            and (Input.IsActionPressed(ButtonAction.ACTION_BOMB, player.ControllerIndex)
            or Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, player.ControllerIndex)) then
                return false
            end
        end
    end
end)