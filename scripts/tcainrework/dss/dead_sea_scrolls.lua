-- I stole this from Headcrab, who stole it from DSS repo, but I stole it from Headcrab
local mod = TCainRework
local SaveManager = require('scripts.save_manager')
local utility = require("scripts.tcainrework.util")

local function getSaveWrapper()
    local menuSaveData = (SaveManager.GetDeadSeaScrollsSave() and SaveManager.GetDeadSeaScrollsSave().saveData) or {}
    local dssSave = SaveManager.GetDeadSeaScrollsSave()
    if dssSave then
        menuSaveData = dssSave.saveData or {}
        return menuSaveData
    end
end

function mod.getModSettings()
    return getSaveWrapper()
end

local function storeSaveData()
    local dssSave = SaveManager.GetDeadSeaScrollsSave()
    dssSave.saveData = getSaveWrapper()
end

local DSSModName = "Dead Sea Scrolls (Tainted Cain Rework)"
local MenuProvider = {}
function MenuProvider.SaveSaveData()
    storeSaveData()
end

function MenuProvider.GetPaletteSetting()
    return getSaveWrapper().MenuPalette
end

function MenuProvider.SavePaletteSetting(var)
    getSaveWrapper().MenuPalette = var
end

function MenuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return getSaveWrapper().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function MenuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        getSaveWrapper().HudOffset = var
    end
end

function MenuProvider.GetGamepadToggleSetting()
    return getSaveWrapper().GamepadToggle
end

function MenuProvider.SaveGamepadToggleSetting(var)
    getSaveWrapper().GamepadToggle = var
end

function MenuProvider.GetMenuKeybindSetting()
    return getSaveWrapper().MenuKeybind
end

function MenuProvider.SaveMenuKeybindSetting(var)
    getSaveWrapper().MenuKeybind = var
end

function MenuProvider.GetMenuHintSetting()
    return getSaveWrapper().MenuHint
end

function MenuProvider.SaveMenuHintSetting(var)
    getSaveWrapper().MenuHint = var
end

function MenuProvider.GetMenuBuzzerSetting()
    return getSaveWrapper().MenuBuzzer
end

function MenuProvider.SaveMenuBuzzerSetting(var)
    getSaveWrapper().MenuBuzzer = var
end

function MenuProvider.GetMenusNotified()
    return getSaveWrapper().MenusNotified
end

function MenuProvider.SaveMenusNotified(var)
    getSaveWrapper().MenusNotified = var
end

function MenuProvider.GetMenusPoppedUp()
    return getSaveWrapper().MenusPoppedUp
end

function MenuProvider.SaveMenusPoppedUp(var)
    getSaveWrapper().MenusPoppedUp = var
end

local dssMenuCore = include("scripts.dssmenucore")
local deadSeaScrollsMod = dssMenuCore.init(DSSModName, MenuProvider)

local minecraftFont = include("scripts.tcainrework.font")

local backgroundSprite = Sprite()
backgroundSprite:Load("gfx/ui/dirtbackground.anm2", true)
backgroundSprite:Play("Idle")
backgroundSprite.Scale = Vector.One / 2

local blackBG = Sprite()
blackBG:Load("gfx/ui/blackbg.anm2", true)
blackBG:Play("Idle", true)
if REPENTOGON then
    blackBG:GetLayer(0):GetBlendMode():SetMode(BlendType.MULTIPLICATIVE)
end

local sliderSprite = Sprite()
sliderSprite:Load("gfx/ui/blackbg.anm2", true)
sliderSprite:Play("Idle", true)

local blackGradient = Sprite()
blackGradient:Load("gfx/ui/blackgradient.anm2", true)
blackGradient:Play("Idle", true)
-- blackGradient:GetLayer(0):GetBlendMode():SetMode(BlendType.MULTIPLICATIVE)

local modLogo = Sprite()
modLogo:Load("gfx/ui/logo.anm2", true)
modLogo:Play("Idle", true)
modLogo.Scale = Vector.One * 0.5

local menuButton = Sprite()
menuButton:Load("gfx/ui/button.anm2", true)
menuButton:SetFrame("Idle", 0)

local primaryBlack, secondaryBlack = Color(1, 1, 1, 1, 0.25, 0.25, 0.25),
    Color(1, 1, 1, 1, 22 / 255, 22 / 255, 22 / 255)
local sliderBack = Color(1, 1, 1, 1)
local sliderMiddle = Color(1, 1, 1, 1, 128 / 255, 128 / 255, 128 / 255)
local sliderTop = Color(1, 1, 1, 1, 192 / 255, 192 / 255, 192 / 255)

local TEXTURE_SIZE = 256

local spriteFont = Sprite()
spriteFont:Load("gfx/ui/spritefont.anm2", true)
spriteFont:SetFrame("Char", 0)
spriteFont.Scale = Vector.One / 3

local spriteFontMap = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()1234567890-={}[]?,"
local constructedFontMap = {}
for i = 1, string.len(spriteFontMap) do
    constructedFontMap[string.sub(spriteFontMap, i, i)] = i - 1
end

local function minecraftStyledUI()
    return ((getSaveWrapper().dssStyleChange ~= 2) and mod.inventoryHelper.getUnlockedInventory())
end

local function renderDirtStrip(y)
    -- Horizontal Strip
    local sizeVector = Vector(backgroundSprite.Scale.X, backgroundSprite.Scale.Y) * TEXTURE_SIZE
    for i = 0, math.ceil(Isaac.GetScreenWidth() / sizeVector.X) - 1 do
        backgroundSprite:Render(Vector.Zero + Vector(i * sizeVector.X, y), Vector.Zero, Vector(0, sizeVector.Y))
    end
    -- Render Darkness over
    blackBG.Color = primaryBlack
    blackBG.Scale = Vector(Isaac.GetScreenWidth(), sizeVector.Y / 2)
    blackBG:Render(Vector.Zero + Vector(0, y))
end

local function menuWrapper(panel, pos, item, tbl)
    if (not minecraftStyledUI()) and item then
        local getDrawButtons = panel.PanelData.GetDrawButtons or panel.Panel.GetDrawButtons
        if getDrawButtons then
            local drawings = deadSeaScrollsMod.generateMenuDraw(item, getDrawButtons(panel, item, tbl), pos,
            panel.Panel)
            for _, drawing in ipairs(drawings) do
                deadSeaScrollsMod.drawMenu(tbl, drawing)
            end
        end
    end
end

local leftRightPadding = 2
local function renderButtonSize(position, buttonSize, sliderPosition)
    local halfwayResize = Vector(100, 0)
    menuButton:Render(position + halfwayResize - Vector(buttonSize / 2, 0), Vector.Zero, Vector(200 - leftRightPadding, 0))
    local maxWidth = ((halfwayResize.X - leftRightPadding) * 2)
    for i = 1, math.ceil(buttonSize / maxWidth) do
        menuButton:Render(position + halfwayResize - Vector((buttonSize / 2) - (maxWidth * (i - 1)), 0), Vector(leftRightPadding, 0), 
            Vector((200 - leftRightPadding) - math.min(buttonSize - (maxWidth * (i - 1)), maxWidth), 0)
        )
    end
    menuButton:Render(position - halfwayResize + Vector(buttonSize / 2 + leftRightPadding, 0), Vector(200 - leftRightPadding, 0), Vector.Zero)
    if sliderPosition then
        menuButton:SetFrame("Slider", 1)
        menuButton:Render(position - Vector(((buttonSize / 2) - (leftRightPadding * 2)) - (sliderPosition * (buttonSize - (leftRightPadding * 3))), 0))
    end
end

local stringTable = {
    ["Resume Game"] = "Back to Game",
    ["false"] = "OFF",
    ["true"] = "ON",
    ["fabulous"] = "§oFabulous!",
    ["do not drop pickups"] = "Keep inventory after death",
    ["fade hud"] = "When to fade Hotbar",
    ["high"] = "Fancy",
    ["low"] = "Fast"
}

if not REPENTOGON then
    -- don't feel too good about redefining this but apparently
    -- it just breaks otherwise so
    MouseButton = {
        LEFT = 0,
        RIGHT = 1,
        SCROLLWHEEL = 2,
        BACK = 3,
        FORWARD = 4,
    }
end

local selectedOption, selectedSlider = nil, nil
local inputHelper = include("scripts.tcainrework.input_helper")
local separationDistance = 24
local scrollAmount, scrollSelected, lastMousePosition = 0, false, Vector.Zero
local function settingsMenuRenderer(panel, pos, item, tbl)
    if minecraftStyledUI() then
        local isLMBPressed = inputHelper.isMouseButtonTriggered(MouseButton.LEFT)

        -- Define Position Bounds
        local topPosition, bottomPosition = Vector(0, 32), Vector(0, Isaac.GetScreenHeight() - 32)
        local screenSpace = (bottomPosition - topPosition).Y
        local fullSize = ((#item.buttons + 0.5) * separationDistance)
        local differenceDistance = ((fullSize > screenSpace) and fullSize - screenSpace) or 0

        -- dirt background
        local sizeVector = Vector(backgroundSprite.Scale.X, backgroundSprite.Scale.Y) * TEXTURE_SIZE
        for i = 0, math.ceil(Isaac.GetScreenWidth() / sizeVector.X) - 1 do
            for j = -1, math.ceil(math.max(fullSize, Isaac.GetScreenHeight()) / sizeVector.Y) - 1 do
                backgroundSprite:Render(Vector.Zero + Vector(i * sizeVector.X, (j * sizeVector.Y) - (scrollAmount * differenceDistance)))
            end
        end
        -- Set Up Gradient Colors and Scale
        blackBG.Color = secondaryBlack
        blackGradient.Scale = Vector(Isaac.GetScreenWidth(), 1)

        -- Render Center Gradient
        blackBG.Scale = Vector(Isaac.GetScreenWidth(), (bottomPosition.Y - topPosition.Y))
        blackBG:Render(topPosition)

        -- Render ui elements
        local mousePosition, mouseVector = inputHelper.getMousePosition()
        local anyHoveringOption = nil
        local leftBound = (Isaac.GetScreenWidth() / 2) - (TEXTURE_SIZE / 2)
        local rightBound = (Isaac.GetScreenWidth() / 2) + (TEXTURE_SIZE / 2)
        local function mouseWrapper(position, length, width, disableSnapping)
            if mousePosition.Y > (topPosition.Y + 1) and mousePosition.Y < (bottomPosition.Y - 1) then
                return inputHelper.hoveringOver(position, length, width, disableSnapping)
            end
            return false
        end

        for i, button in ipairs(item.buttons) do
            local buttonString = (button.str ~= "") and utility.getCustomLocalizedString(
                "gui.settings." .. (button.variable or button.str) .. ".name", stringTable[button.str] or button.str
            ) or ""
            local textPosition = Vector(leftBound, topPosition.Y + ((i - 0.5) * separationDistance) - (scrollAmount * differenceDistance))
            if not button.choices then
                textPosition.X = (Isaac.GetScreenWidth() / 2) - (minecraftFont:GetStringWidth(buttonString) / 2)
            end

            local titleColor = InventoryItemRarity.COMMON
            if button.slider then
                buttonString = buttonString .. ": " .. tostring(button.setting)
                local boxSize = (rightBound - leftBound)
                menuButton:SetFrame("Idle", 3)
                local sliderPosition = Vector(Isaac.GetScreenWidth() / 2, textPosition.Y + minecraftFont:GetLineHeight() / 2)                
                local hoveringOverSlider = mouseWrapper(sliderPosition - Vector((boxSize / 2), 10), boxSize + leftRightPadding, 20, true)

                local fakePlayer = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
                local controllerPress = (fakePlayer and fakePlayer.ControllerIndex > 0) and (Input.IsButtonPressed(Controller.CROSS, fakePlayer.ControllerIndex))
                local mousePress = controllerPress or ((not (fakePlayer and fakePlayer.ControllerIndex > 0)) and inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_LEFT))
                if ((not selectedOption) and hoveringOverSlider) and mousePress then
                    selectedSlider = button
                elseif not mousePress then
                    selectedSlider = nil
                end

                if selectedSlider == button then
                    local leftMost = sliderPosition - Vector((boxSize / 2) - (leftRightPadding * 2), 0)
                    local sliderSize = (boxSize - (leftRightPadding * 3))
                    local sliderMouse = math.min(math.max((mousePosition.X - leftMost.X) / (sliderSize), 0), 1)
                    button.setting = math.ceil((((sliderMouse * (button.max - button.min)) + button.min) / button.increment) - 0.5) * button.increment
                    local directorykey = tbl.DirectoryKey
                    deadSeaScrollsMod.setOption(button.variable, button.setting, selectedOption, directorykey.Item, directorykey)
                    if controllerPress then
                        inputHelper.setMousePosition(Vector(math.min(math.max(mousePosition.X, leftMost.X), leftMost.X + sliderSize), sliderPosition.Y))
                    end
                end

                if hoveringOverSlider then
                    titleColor = InventoryItemRarity.ELEMENT_HOVER
                end
                renderButtonSize(sliderPosition, boxSize, ((button.setting - button.min) / (button.max - button.min)))
                -- menuButton:SetFrame("Slider", 1)
                -- local buttonSetting = ((button.max - button.min) * math.abs(math.sin(Isaac.GetTime() / 1000))) + button.min
                -- local sliderAdjustment = ((buttonSetting - button.min) / sliderCeil)
                -- menuButton:Render(textPosition + Vector(shiftPosition + (boxSize * sliderAdjustment), 5))
            end

            if mouseWrapper(textPosition, 
                minecraftFont:GetStringWidth(buttonString), minecraftFont:GetLineHeight(), button.slider) then
                anyHoveringOption = button
            end
            mod.inventoryHelper.renderMinecraftText(buttonString, 
                textPosition, 
                titleColor
            )

            if button.choices then
                local boxSize = 90
                textPosition.X = rightBound - (boxSize / 2)
                menuButton:SetFrame("Idle", 0)
                local buttonColor = InventoryItemRarity.COMMON
                if mouseWrapper(textPosition - Vector(boxSize / 2, 5), boxSize + leftRightPadding, 20) then
                    menuButton:SetFrame("Idle", 1)
                    buttonColor = InventoryItemRarity.ELEMENT_HOVER
                    anyHoveringOption = button
                    if isLMBPressed then
                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                        button.setting = button.setting + 1
                        if button.setting > #button.choices then
                            button.setting = 1
                        end
                        selectedOption = button
                    end
                end
                textPosition.Y = textPosition.Y + (minecraftFont:GetLineHeight() / 2)
                renderButtonSize(textPosition, boxSize)
                if button.choices[button.setting] then
                    local choiceText = utility.getCustomLocalizedString(
                        "gui.settings.choices." .. button.choices[button.setting] .. ".name", 
                        stringTable[button.choices[button.setting]] or button.choices[button.setting]
                    )
                    mod.inventoryHelper.renderMinecraftText(choiceText, 
                        textPosition - Vector(minecraftFont:GetStringWidth(choiceText) / 2, 
                        (minecraftFont:GetLineHeight() / 2)), buttonColor, true, true
                    )
                end
            end
        end

        -- Render top and bottom gradients
        blackGradient:Render(topPosition)
        blackGradient.Scale = Vector(blackGradient.Scale.X, -blackGradient.Scale.Y)
        blackGradient:Render(bottomPosition)

        -- Render top and bottom strips
        renderDirtStrip(-topPosition.Y)
        renderDirtStrip(bottomPosition.Y)

        -- Render scrollbar
        if fullSize > screenSpace then
            blackBG.Color = sliderBack
            blackBG.Scale = Vector(6, screenSpace)
            blackBG:Render(Vector(rightBound + (separationDistance / 2), topPosition.Y))

            local sliderPosition = Vector(rightBound + (separationDistance / 2), topPosition.Y)
            local sliderSize = screenSpace * (screenSpace / fullSize)
            local endScreenDistance = (screenSpace - sliderSize)
            sliderPosition.Y = sliderPosition.Y + (scrollAmount * endScreenDistance)
            
            sliderSprite.Color = sliderMiddle
            sliderSprite.Scale = Vector(6, sliderSize)
            sliderSprite:Render(sliderPosition)

            sliderSprite.Color = sliderTop
            sliderSprite.Scale = Vector(5, sliderSize - 1)
            sliderSprite:Render(sliderPosition)

            if mouseVector and inputHelper.hoveringOver(sliderPosition, 6, screenSpace, true) 
            and (Input.IsButtonPressed(Controller.CROSS, PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING).ControllerIndex)
            and (not selectedSlider)) then
                scrollAmount = scrollAmount + (mouseVector.Y / endScreenDistance)
                inputHelper.setMousePosition(sliderPosition + Vector(3, sliderSize / 2))
            else
                if isLMBPressed
                and inputHelper.hoveringOver(sliderPosition, 6, screenSpace, true) then
                    scrollSelected = true
                elseif not inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_LEFT) then
                    scrollSelected = false
                end
                if scrollSelected and lastMousePosition then
                    scrollAmount = scrollAmount + (mousePosition - lastMousePosition).Y / endScreenDistance
                end
                if REPENTOGON then
                    -- honestly menu scrolling in minecraft is pretty shitty with the mouse wheel so who cares?
                    scrollAmount = scrollAmount - ((Input.GetMouseWheel().Y * 8) / endScreenDistance)
                end
            end
            scrollAmount = math.min(math.max(scrollAmount, 0), 1)
        end

        -- Render Title Text
        mod.inventoryHelper.renderMinecraftText(utility.getCustomLocalizedString("gui.settings", "Settings"), 
            Vector((Isaac.GetScreenWidth() / 2) - (minecraftFont:GetStringWidth("Settings") / 2), topPosition.Y / 2), 
            InventoryItemRarity.COMMON
        )

        -- Done button
        local donePosition = bottomPosition + Vector(Isaac.GetScreenWidth() / 2, 16)
        menuButton:SetFrame("Idle", 0)
        local buttonColor = InventoryItemRarity.COMMON
        if inputHelper.hoveringOver(donePosition - Vector(100, 10), 200, 20) then
            menuButton:SetFrame("Idle", 1)
            buttonColor = InventoryItemRarity.ELEMENT_HOVER
            if isLMBPressed then
                SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                deadSeaScrollsMod.back(tbl)
                SFXManager():Stop(Isaac.GetSoundIdByName("deadseascrolls_pop"))
            end
        end
        menuButton:Render(donePosition)
        local doneText = utility.getCustomLocalizedString("gui.done", "Done")
        mod.inventoryHelper.renderMinecraftText(doneText, 
            donePosition - Vector(minecraftFont:GetStringWidth(doneText) / 2, (minecraftFont:GetLineHeight() / 2)), 
            buttonColor, true
        )

        -- Render tooltips above everything else
        if anyHoveringOption and (not anyHoveringOption.slider) 
        and (anyHoveringOption.variable or anyHoveringOption.tooltip) then
            local stringTable = {}
            if anyHoveringOption.variable then
                table.insert(stringTable, {
                    String = anyHoveringOption.variable, 
                    Rarity = InventoryItemRarity.UNCOMMON
                })
            end
            if (anyHoveringOption.tooltip and anyHoveringOption.tooltip.extraMinecraftDescription) then 
                -- minecraft tooltip lol
                local isTable = type(anyHoveringOption.tooltip.extraMinecraftDescription) == "table"
                local minecraftExtraDescription = (isTable and anyHoveringOption.tooltip.extraMinecraftDescription[anyHoveringOption.setting])
                    or anyHoveringOption.tooltip.extraMinecraftDescription
                
                if minecraftExtraDescription then
                    minecraftExtraDescription = utility.getCustomLocalizedString(
                        "gui.settings." .. anyHoveringOption.variable .. ".desc" 
                        .. (isTable and tostring(anyHoveringOption.setting) or ""), 
                        minecraftExtraDescription
                    ) or ""
                    local myString = ""
                    for subString in minecraftExtraDescription:gmatch("%S+") do
                        myString = myString .. ((myString ~= "" and " ") or "") .. subString
                        if string.len(myString) >= 28 then
                            table.insert(stringTable, {String = myString, Rarity = InventoryItemRarity.COMMON})
                            myString = ""
                        end
                    end
                    if myString ~= "" then
                        table.insert(stringTable, {String = myString, Rarity = InventoryItemRarity.COMMON})
                    end
                end
            end
            if anyHoveringOption.choices then
                table.insert(stringTable, {
                    String = utility.getCustomLocalizedString("editGamerule.default", "Default") .. ": " 
                        .. utility.getCustomLocalizedString(
                            "gui.settings.choices." .. anyHoveringOption.choices[1] .. ".name", anyHoveringOption.choices[1]
                        ), 
                    Rarity = InventoryItemRarity.SUBTEXT
                })
            end
            mod.inventoryHelper.renderTooltip(mousePosition, stringTable)
        end

        lastMousePosition = mousePosition
        inputHelper.Update(Isaac.GetPlayer(0).ControllerIndex > 0)
        pos.Y = 900
        return
    end
    menuWrapper(panel, pos, item, tbl)
end

local minecraftGeneric = Sprite()
minecraftGeneric:Load("gfx/ui/tooltip.anm2", false)
minecraftGeneric:ReplaceSpritesheet(0, "gfx/ui/recipe_book_9slice.png")
minecraftGeneric:LoadGraphics()

local minecraftInner = Sprite()
minecraftInner:Load("gfx/ui/tooltip.anm2", false)
minecraftInner:ReplaceSpritesheet(0, "gfx/ui/inverse_inventory_9slice.png")
minecraftInner:LoadGraphics()

local repentogonStage = {
[==[
IMPORTANT NOTICE:

Tainted Cain Rework requires 
REPENTOGON.

Without REPENTOGON, it is impossible 
to do many of the things 
Tainted Cain Rework achieves.

Please consider installing it at 
https://repentogon.com/

Tainted Cain Rework will be disabled.
Thank you.
]==]
}
function rgonNoticeMenu(panel, pos, item, tbl)
    local uiSize = Vector(200, 0)
    local uiPosition = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2
    if minecraftStyledUI() then
        local mousePosition = inputHelper.getMousePosition()
        local isLMBPressed = inputHelper.isMouseButtonTriggered(MouseButton.LEFT)
        -- repentogon text
        local repentogonPlease = utility.getCustomLocalizedString(
            "gui.settings.repentogon_notice.desc", repentogonStage[1]
        )
        local stringTable = {}
        for subString in repentogonPlease:gmatch("(.-)\n") do
            table.insert(stringTable, subString)
        end
        uiSize.Y = (minecraftFont:GetLineHeight() * #stringTable) + 48
        utility.renderNineSlice(
            minecraftGeneric, 
            uiPosition - Vector(uiSize.X / 2, 0), 
            uiSize
        )
        local paddingInverse = 12
        local inverseBottomPadding = 24
        utility.renderNineSlice(
            minecraftInner, 
            uiPosition - Vector((uiSize.X - paddingInverse) / 2, (inverseBottomPadding / 2)), 
            (uiSize - Vector(paddingInverse, paddingInverse + inverseBottomPadding))
        )    
        local stringPosition = Vector(uiPosition.X, uiPosition.Y - ((uiSize.Y / 2) - 16))
        for i, subString in ipairs(stringTable) do
            mod.inventoryHelper.renderMinecraftText(subString, 
                stringPosition - Vector(minecraftFont:GetStringWidth(subString) / 2, (minecraftFont:GetLineHeight() / 2)), 
                InventoryItemRarity.COMMON, true, true
            )
            stringPosition.Y = stringPosition.Y + minecraftFont:GetLineHeight()
        end

        local buttonPosition = uiPosition + Vector(-1, (uiSize.Y / 2) - 12)
        local buttonColor = InventoryItemRarity.COMMON
        menuButton:SetFrame("Idle", 0)
        if inputHelper.hoveringOver(buttonPosition - Vector((uiSize.X - 8) / 2, 10), (uiSize.X - 8) + leftRightPadding, 20) then
            buttonColor = InventoryItemRarity.ELEMENT_HOVER
            menuButton:SetFrame("Idle", 1)
            if isLMBPressed then
                SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                DeadSeaScrollsMenu.CloseMenu(true, true)
                SFXManager():Stop(Isaac.GetSoundIdByName("deadseascrolls_pop"))
            end
        end
        renderButtonSize(buttonPosition, uiSize.X - 8)
        local fineText = "Just let me play the game"
        mod.inventoryHelper.renderMinecraftText(fineText, 
            buttonPosition - Vector(minecraftFont:GetStringWidth(fineText) / 2, (minecraftFont:GetLineHeight() / 2)), 
            buttonColor, true, true
        )
        inputHelper.Update()
        return
    end
    menuWrapper(panel, pos, item, tbl)
end

local splashTexts = include("data.splash_texts")
local splashTable = {}
for splash in splashTexts:gmatch("(.-)\n") do
    table.insert(splashTable, splash)
end

local splashText = ""
local textRotation, textSize = -18, 1
local rotationAngle = Vector.FromAngle(textRotation)

local splashYellow, splashShadow = Color(255 / 255, 255 / 255, 0 / 255, 1), 
    Color(62 / 255, 62 / 255, 0 / 255, 1)
local modVersion = include("scripts.tcainrework.dss.changelogs")
local function mainMenuRenderer(panel, pos, item, tbl)
    if minecraftStyledUI() then
        local mousePosition = inputHelper.getMousePosition()
        local isLMBPressed = inputHelper.isMouseButtonTriggered(MouseButton.LEFT)
        blackBG.Color = primaryBlack
        blackBG.Scale = Vector(Isaac.GetScreenWidth() + 16, Isaac.GetScreenHeight() + 16)
        blackBG:Render(Vector.One * -8)

        local positionLogo = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 4)
        modLogo:Render(positionLogo)

        -- splash text rendering
        if splashText == "" then
            splashText = splashTable[math.random(1, #splashTable)]
        end
        local splashTextPosition = Vector(positionLogo.X + 120, positionLogo.Y - 8)
        textSize = (1.5 - (math.abs(math.sin((mod.elapsedTime or 0) * math.pi * 2.5)) / 10)) * 0.75
        splashTextPosition = splashTextPosition - ((minecraftFont:GetStringWidth(splashText) / 2) * textSize * rotationAngle)
        for i = 1, string.len(splashText) do
            local currentCharacter = string.sub(splashText, i, i)
            local characterIndex = constructedFontMap[currentCharacter]
            if characterIndex then
                spriteFont.Scale = ((Vector.One * textSize) / 3)
                spriteFont.Rotation = textRotation
                spriteFont:SetFrame("Char", characterIndex)
                spriteFont.Color = splashShadow
                spriteFont:Render(splashTextPosition + Vector.One:Rotated(textRotation) * textSize)
                spriteFont.Color = splashYellow
                spriteFont:Render(splashTextPosition)
            end
            splashTextPosition = splashTextPosition + (minecraftFont:GetStringWidth(currentCharacter) * textSize * rotationAngle)
        end
        
        for i, button in ipairs(item.buttons) do
            if button.str ~= "changelogs"
            and ((not button.displayif) or button.displayif(button, item, tbl)) then
                local buttonPosition = positionLogo + Vector(0, (Isaac.GetScreenHeight() / 8) + (i * 25))
                menuButton:SetFrame("Idle", 0)
                local buttonColor = InventoryItemRarity.COMMON
                if inputHelper.hoveringOver(buttonPosition - Vector(100, 10), 200, 20) then
                    menuButton:SetFrame("Idle", 1)
                    buttonColor = InventoryItemRarity.ELEMENT_HOVER
                    -- run submenu when triggered mouse button 
                    if isLMBPressed then
                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                        selectedOption = button
                    end
                end
                menuButton:Render(buttonPosition)
                local buttonName = utility.getCustomLocalizedString("gui." .. button.str, stringTable[button.str] or button.str)
                mod.inventoryHelper.renderMinecraftText(buttonName, 
                    Vector(
                        buttonPosition.X - (minecraftFont:GetStringWidth(buttonName) / 2), 
                        buttonPosition.Y - minecraftFont:GetLineHeight() / 2
                    ), 
                    buttonColor, true
                )
            end
        end
        -- copyright texts
        mod.inventoryHelper.renderMinecraftText(
            "The Binding of Isaac: Repentance" .. ((REPENTANCE_PLUS and "+") or ""), 
            Vector(2, Isaac.GetScreenHeight() - minecraftFont:GetLineHeight() - 2), 
            InventoryItemRarity.COMMON, true
        )
        if REPENTOGON then
            mod.inventoryHelper.renderMinecraftText(
                "REPENTOGON " .. REPENTOGON.Version, 
                Vector(2, (Isaac.GetScreenHeight() - minecraftFont:GetLineHeight() * 3) - 2), 
                InventoryItemRarity.COMMON, true
            )
        end
        mod.inventoryHelper.renderMinecraftText(
            "Tainted Cain Rework " .. modVersion, 
            Vector(2, (Isaac.GetScreenHeight() - minecraftFont:GetLineHeight() * 2) - 2), 
            InventoryItemRarity.COMMON, true
        )
        -- 
        local rightHandString = "Minecraft by Mojang Studios"
        mod.inventoryHelper.renderMinecraftText(
            rightHandString,
            Vector(Isaac.GetScreenWidth() - minecraftFont:GetStringWidth(rightHandString), Isaac.GetScreenHeight() - minecraftFont:GetLineHeight() * 2) - (Vector.One * 2), 
            InventoryItemRarity.COMMON, true
        )
        rightHandString = "No Copyright Infringement Intended"
        mod.inventoryHelper.renderMinecraftText(
            rightHandString,
            Vector(Isaac.GetScreenWidth() - minecraftFont:GetStringWidth(rightHandString), Isaac.GetScreenHeight() - minecraftFont:GetLineHeight()) - (Vector.One * 2), 
            InventoryItemRarity.COMMON, true
        )

        inputHelper.Update(Isaac.GetPlayer(0).ControllerIndex > 0)
        pos.Y = 900
        return
    end
    menuWrapper(panel, pos, item, tbl)
end

local displayName = "T. Cain Rework"
local function creditsWrapper(name, credit, tooltip, nosel)
    return {
        strpair = {{str = name}, {str = credit}},
        nosel = nosel,
        tooltip = {strset = tooltip}
    }
end
local function inputWrapper(panel, input, item, itemswitched, tbl)
    if not minecraftStyledUI() then
        deadSeaScrollsMod.handleInputs(item, itemswitched, tbl)
        return
    end
    -- wrap input handling for mouse controls
    if selectedOption then
        -- if selected option has a destination go to that path
        local directorykey = tbl.DirectoryKey
        if selectedOption.choices then
            deadSeaScrollsMod.setOption(selectedOption.variable, selectedOption.setting, selectedOption, directorykey.Item, directorykey)
            selectedOption = nil
            return
        end
        local action = selectedOption.action or "openmenu"
        if action == 'resume' then
            DeadSeaScrollsMenu.CloseMenu(true, true)
            SFXManager():Stop(Isaac.GetSoundIdByName("deadseascrolls_whoosh"))
        elseif action == "openmenu" then
            scrollAmount = 0
            table.insert(directorykey.Path, { menuname = tbl.Name, item = item })
            if selectedOption.dest then
                DeadSeaScrollsMenu.OpenMenuToPath(tbl.Name, selectedOption.dest, directorykey.Path)
            else
                DeadSeaScrollsMenu.OpenMenuToPath(tbl.Name, "main", directorykey.Path)
            end
        elseif action == "back" then
            deadSeaScrollsMod.back(tbl)
        end
    end
    selectedOption = nil
end
local whoosh = Isaac.GetSoundIdByName("deadseascrolls_whoosh")
local function panelBackWrapper(panel, pos, tbl)
    if not minecraftStyledUI() then
        deadSeaScrollsMod.defaultPanelRenderBack(panel, pos, tbl)
    else
        if SFXManager():IsPlaying(whoosh) then
            SFXManager():Stop(whoosh)
            splashText = ""
        end
    end
end
local function panelFrontWrapper(panel, pos, tbl)
    if not minecraftStyledUI() then
        deadSeaScrollsMod.defaultPanelRenderFront(panel, pos, tbl)
    end
end

local monkeysPaw = Sprite()
monkeysPaw:Load("gfx/ui/skibidi.anm2")
monkeysPaw:LoadGraphics()
monkeysPaw:SetFrame("sheet0", 1)
-- monkeysPaw.Scale = (Vector(0.5, 0.30) / 1.65)
local monkeysPawAlpha, monkeysPawStartTime = 0, 0
local monkeysPawSound = Isaac.GetSoundIdByName("hi_eric")
local function resetMonkeysPaw()
    monkeysPawAlpha = -0.5
    monkeysPawStartTime = 0
    if SFXManager():IsPlaying(monkeysPawSound) then
        SFXManager():Stop(monkeysPawSound)
    end
end

local cainCraftingDirectory = {
    main = {
        title = string.lower(displayName),
        buttons = {
            { str = 'Resume Game', action = 'resume' },
            { str = 'Settings',    dest = 'settings' },
            { str = 'Credits',    dest = 'credits' },
            {
                str = 'How to Play',
                displayif = function(btn, item, tbl)
                    return false
                    -- return minecraftStyledUI()
                end
            },
        },
        tooltip = deadSeaScrollsMod.menuOpenToolTip,
        format = {
            Panels = {
                {
                    Panel = deadSeaScrollsMod.panels.tooltip,
                    Offset = Vector(130, -2),
                    Draw = menuWrapper,
                    RenderBack = panelBackWrapper,
                    RenderFront = panelFrontWrapper,
                    Color = 1
                },
                {
                    Panel = deadSeaScrollsMod.panels.main,
                    Offset = Vector(-42, 10),
                    HandleInputs = inputWrapper,
                    RenderBack = panelBackWrapper,
                    RenderFront = panelFrontWrapper,
                    Draw = mainMenuRenderer,
                    Color = 1,
                },
            }
        }
    },
    settings = {
        title = 'settings',
        buttons = {
            {str = "Quality", fsize = 2, nosel = true},
            {str = "", fsize = 2, nosel = true},
            {
                str = "Graphics",
                choices = {"high", "low"},
                setting = 1,
                variable = "graphicsSettings",
                load = function ()
                    return getSaveWrapper().graphicsSettings or 1
                end,
                store = function (var)
                    getSaveWrapper().graphicsSettings = var
                end,
                tooltip = {
                    strset = {"changes the", "graphical", "quality of", "items in", "the mod"},
                    extraMinecraftDescription = {
                        "Fancy graphics renders items with 3D raymarching shaders. This can cause performance issues on larger Render Scales. A base render scale of 3 is recommended to make Items and Blocks look decent.",
                        "Fast graphics uses classic Minecraft billboarding for item sprites. Blocks will still be raymarched. It is recommended to lower Render Scale if performance issues persist."
                    },
                }
            },
            {
                str = 'Render Scale',
                increment = 1, max = 4, min = 1,
                variable = "maxRenderScale",
                slider = true,
                setting = Options.MaxRenderScale,
                load = function()
                    return Options.MaxRenderScale
                end,
                store = function(var)
                    Options.MaxRenderScale = var
                    Isaac.TriggerWindowResize()
                end,
                tooltip = {
                    strset = {'the scale', "at which the", "game renders", "at"}
                }            
            },
            {str = "", fsize = 2, nosel = true},
            {str = "Cosmetic", fsize = 2, nosel = true},
            {str = "", fsize = 2, nosel = true},
            {
                str = "DSS Style Change",
                choices = {"When unlocked", "Never"},
                setting = 1,
                variable = "dssStyleChange",
                load = function ()
                    return getSaveWrapper().dssStyleChange or 1
                end,
                store = function (var)
                    getSaveWrapper().dssStyleChange = var
                end,
                tooltip = {
                    strset = {"Toggle when", "DSS should", "use the", "Tainted Cain", "Rework skin."},
                    extraMinecraftDescription = "Toggles whether or not to use the \"Minecraft\" skin for the §oDead Sea Scrolls§r menu. The \"Minecraft\" style has more descriptive text below some options."
                }
            },
            {
                str = "Custom Sprites",
                choices = {"Enabled", "Disabled"},
                setting = 1,
                variable = "customCollectibleSprites",
                load = function ()
                    return getSaveWrapper().customCollectibleSprites or 1
                end,
                store = function (var)
                    getSaveWrapper().customCollectibleSprites = var
                end,
                tooltip = {
                    strset = {"Whether to", "use custom", "sprites for", "collectibles", "whenever", "possible."},
                    extraMinecraftDescription = "The custom sprites appear for collectibles within the inventory. Disable this if you wish to easily distinguish between items."
                }
            },
            {
                str = "Display Pop-ups",
                choices = {"Always", "Muted", "Never"},
                setting = 1,
                variable = "toastControl",
                load = function ()
                    return getSaveWrapper().toastControl or 1
                end,
                store = function (var)
                    getSaveWrapper().toastControl = var
                end,
                tooltip = {
                    strset = {"Whether to", "display", "pop-ups", "whenever", "they appear."},
                    extraMinecraftDescription = "Serves as a way of shutting off those pesky toasts that appear whenever you unlock a new recipe.",
                },
            },
            {
                str = "fade hud",
                choices = {"Boss Fights", "Always", "Never"},
                setting = 1,
                variable = "fadeHotbar",
                load = function ()
                    return getSaveWrapper().fadeHotbar or 1
                end,
                store = function (var)
                    getSaveWrapper().fadeHotbar = var
                end,
                tooltip = {
                    strset = {
                        "in what",
                        "scenario",
                        "should the",
                        "hud be hidden"
                    },
                    extraMinecraftDescription = {
                        "Currently, the Hotbar will fade out  unless hovered over during a boss fight.",
                        "Currently, the Hotbar will always fade out unless hovered over.",
                        "Currently, the Hotbar never fades out."
                    },
                },
            },
            {
                str = 'Fade Percent',
                increment = 5, max = 100, min = 0,
                variable = "fadePercentage",
                slider = true,
                setting = Options.MaxRenderScale,
                load = function()
                    return getSaveWrapper().fadePercentage or 50
                end,
                store = function(var)
                    getSaveWrapper().fadePercentage = var
                end,
                tooltip = {
                    strset = {
                        "percent of",
                        "what to",
                        "fade by"
                    }
                }            
            },
            {str = "", fsize = 2, nosel = true},
            {str = "Gameplay", fsize = 2, nosel = true},
            {str = "", fsize = 2, nosel = true},
            --[[{
                str = "Active Item Style",
                choices = {"Swap with last", "Destroy last"},
                setting = 1,
                variable = "activeItemStyle",
                load = function ()
                    return getSaveWrapper().activeItemStyle or 1
                end,
                store = function (var)
                    getSaveWrapper().activeItemStyle = var
                end,
                tooltip = {
                    strset = {"Changes the", "behavior of", "crafting a", "new active", "item."},
                    extraMinecraftDescription = {
                        "Currently, the last active item will swap back into the inventory when a new one is consumed.",
                        "Currently, the last active item will be salvaged into pickups whenever a new one is consumed."
                    }
                }
            },]]--
            {
                str = "Recipe Unlocks",
                choices = {"Discovery", "Relaxed"},
                setting = 1,
                variable = "recipeUnlockStyle",
                load = function ()
                    return getSaveWrapper().recipeUnlockStyle or 1
                end,
                store = function (var)
                    getSaveWrapper().recipeUnlockStyle = var
                end,
                tooltip = {
                    strset = {
                        "Discovery:", "Recipes are", "unlocked", "per run.", "                                    ",
                        "Relaxed:", "Recipes are", "unlocked", "forever."
                    },
                    extraMinecraftDescription = {
                        "Currently, recipe progression will be reset upon starting a new run. Use this if you wish to memorize all of the recipes. Your progress from Relaxed will NOT carry over.",
                        "Currently, recipe progression will persist between runs. Use this if you wish to have a more relaxed experienced, focusing on build-crafting rather than memorization or discovery. Your progress from Discovery will carry over."
                    },
                },
                
            },
            {
                str = "Global Unlocks",
                choices = {"Per Save", "Every Run"},
                setting = 1,
                variable = "minecraftJumpscare",
                load = function ()
                    return getSaveWrapper().minecraftJumpscare or 1
                end,
                store = function (var)
                    getSaveWrapper().minecraftJumpscare = var
                end,
                tooltip = {
                    strset = {"When the", "player should", "unlock certain", "conditions."},
                    extraMinecraftDescription = {
                        "Currently, the player will always have the inventory and hotbar unlocked.",
                        "Currently, the player will unlock the inventory and hotbar per run whenever a pickup is placed in the Bag of Crafting."
                    }
                }
            },
            {
                str = "do not drop pickups",
                choices = {"false", "true"},
                setting = 1,
                variable = "keepInventory",
                load = function ()
                    return getSaveWrapper().keepInventory or 1
                end,
                store = function (var)
                    getSaveWrapper().keepInventory = var
                end,
                tooltip = {
                    strset = {"whether to", "drop pickups", "on death"},
                }
            },
            {str = "", fsize = 2, nosel = true},
            {str = "Experiments", fsize = 2, nosel = true},
            {str = "", fsize = 2, nosel = true},
            {
                str = "Insomnia",
                choices = {"false", "true"},
                setting = 1,
                variable = "doInsomnia",
                load = function ()
                    return getSaveWrapper().doInsomnia or 1
                end,
                store = function (var)
                    getSaveWrapper().doInsomnia = var
                end,
                tooltip = {strset = {"Go to sleep."}}
            },
            {
                str = "Classic Crafting",
                choices = {"Disabled", "Enabled"},
                setting = 1,
                variable = "classicCrafting",
                load = function ()
                    return getSaveWrapper().classicCrafting or 1
                end,
                store = function (var)
                    getSaveWrapper().classicCrafting = var
                end,
                tooltip = {
                    strset = {"uses classic", "tainted cain", "recipes for", "items instead", "", "not balanced"},
                    extraMinecraftDescription = {
                        "Currently, recipes are fixed and use the Tainted Cain Rework style. Any changes will apply next run.",
                        "Currently, recipes all require 8 items, are randomized, and will use the vanilla crafting system. Any changes will apply next run. §lNot §lbalanced."
                    }
                }
            },
            -- {
            --     str = "Chaos Mode [NOT DONE]",
            --     choices = {"false", "true"},
            --     setting = 1,
            --     variable = "chaosMode",
            --     load = function ()
            --         return getSaveWrapper().chaosMode or 1
            --     end,
            --     store = function (var)
            --         getSaveWrapper().chaosMode = var
            --     end,
            --     tooltip = {
            --         strset = {"Shuffles all", "recipes", "similarly to", "the Chaos", "item."},
            --         extraMinecraftDescription = "Shuffles all recipes, similarly to the Chaos item's effect."
            --     }
            -- }
        },
        format = {
            Panels = {
                {
                    Panel = deadSeaScrollsMod.panels.tooltip,
                    Offset = Vector(130, -2),
                    Draw = menuWrapper,
                    RenderBack = panelBackWrapper,
                    RenderFront = panelFrontWrapper,
                    Color = 1
                },
                {
                    Panel = deadSeaScrollsMod.panels.main,
                    Offset = Vector(-42, 10),
                    RenderBack = panelBackWrapper,
                    RenderFront = panelFrontWrapper,
                    HandleInputs = inputWrapper,
                    Draw = settingsMenuRenderer,
                    Color = 1,
                },
            }
        }
    },
    credits = {
        title = 'credits',
        fsize = 1,
        buttons = {
            {str = "tainted cain rework", nosel = true},
            creditsWrapper("liz", "everything", {"display", "my sticks"}),
            {str = "", nosel = true},
            {str = "additional recipes", nosel = true},
            creditsWrapper("john snail", "made subworld library", {"oh baby!"}),
            creditsWrapper("mr. headcrab", "the guy", {"can you make", "a non", "repentogon", "version"}),
            creditsWrapper("pread1129", "liminal", {"play tainted", "blue baby"}),
            creditsWrapper("elitemastereric", "thinking about it", {"skibidi", "edge", "rizz"}),
            {str = "", nosel = true},
            {str = "translations", nosel = true},
            creditsWrapper("scribble", "french", {"i like", "flowers", "n bats"}),
            {str = "", nosel = true},
            {str = "special thanks", nosel = true},
            creditsWrapper("lynn sharcys", "detractor", {"www.", "gaywhiteboy", ".com"}),
            -- creditsWrapper("", "eden essence sprite", {""}, true),
            creditsWrapper("keeteeh", "detractor", {"shoutout", "to lizzie", "for pulling", "through and", "finishing this", "mod. i'm so", "proud of her."}),
            creditsWrapper("snowystarfall", "particle", {"gatekeep", "", "graphics", "program", "", "girlboss"}),
            creditsWrapper("lily", "wife", {"i worked the", "hardestr for", "this mod."}),
            creditsWrapper("silentib", "\"balance\"", {"dirt rod", "challeng."}),
            creditsWrapper("jakevox", "observer (like the block)", {""}),
            creditsWrapper("madeline", "silly creature", {"40 dead", "309 injured", ":3 :3 :3"}),
            creditsWrapper("glasscanyon", "warframe", {"hi"}),
            creditsWrapper("benevolusgoat", "goat", {"hmmm", "no wait"}),
            creditsWrapper("wofsauge", "font keming issue", {""}),
            creditsWrapper("you", "playing the mod", {"[          ]", "write your", "quote here!"})
        },
        format = {
            Panels = {
                {
                    Panel = deadSeaScrollsMod.panels.tooltip,
                    Offset = Vector(130, -2),
                    Draw = function(panel, pos, item, tbl)
                        if item then
                            local getDrawButtons = panel.PanelData.GetDrawButtons or panel.Panel.GetDrawButtons
                            if getDrawButtons then
                                local drawings = deadSeaScrollsMod.generateMenuDraw(item, getDrawButtons(panel, item, tbl), pos, panel.Panel)
                                for _, drawing in ipairs(drawings) do
                                    deadSeaScrollsMod.drawMenu(tbl, drawing)
                                    if item.strset and item.strset[1] == "skibidi" then
                                        local frame = ((monkeysPawStartTime > 0) and (math.floor((Isaac.GetTime() - monkeysPawStartTime) / 1000) * 24)) or 0
                                        monkeysPaw.Color = Color(1, 1, 1, monkeysPawAlpha + (frame / 50))
                                        if ((monkeysPawAlpha >= 1) and (monkeysPawStartTime <= 0)) then
                                            monkeysPawStartTime = Isaac.GetTime()
                                            SFXManager():Play(monkeysPawSound, 1)
                                        else
                                            monkeysPawAlpha = math.min(monkeysPawAlpha + (0.0125 / 2), 1)
                                        end
                                        monkeysPaw:SetFrame("sheet0", frame)
                                        monkeysPaw:Render(pos - Vector(24, 40))
                                    else
                                        resetMonkeysPaw()
                                    end
                                end
                            end
                        end
                    end,
                    Color = 1
                },
                {
                    Panel = deadSeaScrollsMod.panels.main,
                    Offset = Vector(-42, 10),
                    Color = 1,
                },
            }
        }
    },
    rgonpopup = {
		title = "repentogon notice",
		fsize = 1,
		buttons = {
            {str = "", nosel = true, fsize = 1},
            {str = "tainted cain rework requires", nosel = true, fsize = 1},
            {str = "repentogon.", nosel = true, fsize = 1},
            {str = "", nosel = true, fsize = 1},
            {str = "without repentogon it is impossible", nosel = true, fsize = 1},
            {str = "to do many of the things", nosel = true, fsize = 1},
            {str = "tainted cain rework achieves", nosel = true, fsize = 1},
            {str = "", nosel = true, fsize = 1},
            {str = "please consider installing it at", nosel = true, fsize = 1},
            {str = "https://repentogon.com/", nosel = true, fsize = 1},
            {str = "", nosel = true, fsize = 1},
            {str = "tainted cain rework will be disabled.", nosel = true, fsize = 1},
            {str = "", nosel = true, fsize = 1},
			{
				str = "i understand",
				action = "resume",
				fsize = 3,
				glowcolor = 3,
			},
		},
        format = {
            Panels = {
                {
                    Panel = deadSeaScrollsMod.panels.main,
                    Offset = Vector(0, 10),
                    RenderBack = panelBackWrapper,
                    RenderFront = panelFrontWrapper,
                    HandleInputs = inputWrapper,
                    Draw = rgonNoticeMenu,
                    Color = 1,
                },
            }
        }
	},
}

local cainCraftingDirectoryKey = {
    Item = cainCraftingDirectory.main,
    Main = 'main',
    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

if REPENTOGON then
    cainCraftingDirectoryKey.Main = 'rgonpopup'
end

DeadSeaScrollsMenu.AddMenu(displayName, {
    Run = deadSeaScrollsMod.runMenu,
    Open = function(tbl, openedFromNothing)
        deadSeaScrollsMod.openMenu(tbl, openedFromNothing)
    end,
    Close = deadSeaScrollsMod.closeMenu,
    Directory = cainCraftingDirectory,
    DirectoryKey = cainCraftingDirectoryKey
})

