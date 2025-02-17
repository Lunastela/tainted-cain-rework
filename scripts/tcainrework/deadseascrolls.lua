-- I stole this from Headcrab, who stole it from DSS repo, but I stole it from Headcrab
local mod = TCainRework
local SaveManager = require('scripts.save_manager')

local menuSaveData = (SaveManager.GetDeadSeaScrollsSave() and SaveManager.GetDeadSeaScrollsSave().saveData) or {}
local function getSaveWrapper()
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
    dssSave.saveData = menuSaveData
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
blackBG:GetLayer(0):GetBlendMode():SetMode(BlendType.MULTIPLICATIVE)

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
local function renderButtonSize(position, buttonSize)
    local halfwayResize = Vector(100, 0)
    menuButton:Render(position + halfwayResize - Vector(buttonSize / 2, 0), Vector.Zero, Vector(200 - leftRightPadding, 0))
    menuButton:Render(position + halfwayResize - Vector(buttonSize / 2, 0), Vector(leftRightPadding, 0), Vector((200 - leftRightPadding) - buttonSize, 0))
    menuButton:Render(position - halfwayResize + Vector(buttonSize / 2 + leftRightPadding, 0), Vector(200 - leftRightPadding, 0), Vector.Zero)
end

local stringTable = {
    ["Resume Game"] = "Back to Game",
    ["false"] = "OFF",
    ["true"] = "ON",
    ["Fabulous"] = "§oFabulous!"
}

local selectedOption = nil
local inputHelper = include("scripts.tcainrework.mouseinputs")
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
        local mousePosition = Isaac.WorldToScreen(Input.GetMousePosition(true))
        local anyHoveringOption = nil
        local leftBound = (Isaac.GetScreenWidth() / 2) - (TEXTURE_SIZE / 2)
        local rightBound = (Isaac.GetScreenWidth() / 2) + (TEXTURE_SIZE / 2)
        local function mouseWrapper(mousePosition, position, length, width)
            if mousePosition.Y > (topPosition.Y + 1) and mousePosition.Y < (bottomPosition.Y - 1) then
                return mod.inventoryHelper.hoveringOver(mousePosition, position, length, width)
            end
            return false
        end

        for i, button in ipairs(item.buttons) do
            local textPosition = Vector(leftBound, topPosition.Y + ((i - 0.5) * separationDistance) - (scrollAmount * differenceDistance))
            if not button.choices then
                textPosition.X = (Isaac.GetScreenWidth() / 2) - (minecraftFont:GetStringWidth(button.str) / 2)
            end
            mod.inventoryHelper.renderMinecraftText(button.str, 
                textPosition, 
                InventoryItemRarity.COMMON
            )
            if mouseWrapper(mousePosition, textPosition, 
                minecraftFont:GetStringWidth(button.str), minecraftFont:GetLineHeight()) then
                anyHoveringOption = button
            end

            if button.choices then
                local boxSize = 90
                textPosition.X = rightBound - (boxSize / 2)
                menuButton:SetFrame("Idle", 0)
                if mouseWrapper(mousePosition, textPosition - Vector(boxSize / 2, 5), boxSize + leftRightPadding, 20) then
                    menuButton:SetFrame("Idle", 1)
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
                    local choiceText = stringTable[button.choices[button.setting]] or button.choices[button.setting]
                    mod.inventoryHelper.renderMinecraftText(choiceText, 
                        textPosition - Vector(minecraftFont:GetStringWidth(choiceText) / 2, (minecraftFont:GetLineHeight() / 2)), 
                        InventoryItemRarity.COMMON, true, true
                    )
                end
            end
        end

        -- Render top and bottom gradients
        blackGradient:Render(topPosition)
        blackGradient.Scale.Y = -blackGradient.Scale.Y
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

            if isLMBPressed
            and mod.inventoryHelper.hoveringOver(mousePosition, sliderPosition, 6, screenSpace) then
                scrollSelected = true
            elseif not inputHelper.isMouseButtonHeld(Mouse.MOUSE_BUTTON_LEFT) then
                scrollSelected = false
            end
            if scrollSelected and lastMousePosition then
                scrollAmount = scrollAmount + (mousePosition - lastMousePosition).Y / endScreenDistance
            end
            -- honestly menu scrolling in minecraft is pretty shitty with the mouse wheel so who cares?
            scrollAmount = scrollAmount - ((Input:GetMouseWheel().Y * 8) / endScreenDistance)
            scrollAmount = math.min(math.max(scrollAmount, 0), 1)
        end

        -- Render Title Text
        mod.inventoryHelper.renderMinecraftText("Settings", 
            Vector((Isaac.GetScreenWidth() / 2) - (minecraftFont:GetStringWidth("Settings") / 2), topPosition.Y / 2), 
            InventoryItemRarity.COMMON
        )

        -- Done button
        local donePosition = bottomPosition + Vector(Isaac.GetScreenWidth() / 2, 16)
        menuButton:SetFrame("Idle", 0)
        if mod.inventoryHelper.hoveringOver(mousePosition, donePosition - Vector(100, 10), 200, 20) then
            menuButton:SetFrame("Idle", 1)
            if isLMBPressed then
                SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                deadSeaScrollsMod.back(tbl)
                SFXManager():Stop(Isaac.GetSoundIdByName("deadseascrolls_pop"))
            end
        end
        menuButton:Render(donePosition)
        mod.inventoryHelper.renderMinecraftText("Done", 
            donePosition - Vector(minecraftFont:GetStringWidth("Done") / 2, (minecraftFont:GetLineHeight() / 2)), 
            InventoryItemRarity.COMMON, true
        )

        -- Render tooltips above everything else
        if anyHoveringOption and (anyHoveringOption.variable or anyHoveringOption.tooltip) then
            local stringTable = {}
            if anyHoveringOption.variable then
                table.insert(stringTable, {
                    String = anyHoveringOption.variable, 
                    Rarity = InventoryItemRarity.UNCOMMON
                })
            end
            if (anyHoveringOption.tooltip and anyHoveringOption.tooltip.strset) then 
                local textString = ""
                for i, string in ipairs(anyHoveringOption.tooltip.strset) do
                    textString = textString .. string .. " "
                    if string.len(textString) >= 28 then
                        table.insert(stringTable, {String = textString, Rarity = InventoryItemRarity.COMMON})
                        textString = ""
                    end
                end
                if textString ~= "" then
                    table.insert(stringTable, {String = textString, Rarity = InventoryItemRarity.COMMON})
                end
            end
            table.insert(stringTable, {
                String = "Default: " .. anyHoveringOption.choices[1], 
                Rarity = InventoryItemRarity.SUBTEXT
            })
            mod.inventoryHelper.renderTooltip(mousePosition, stringTable)
        end

        lastMousePosition = mousePosition
        inputHelper.Update()
        pos.Y = 900
        return
    end
    menuWrapper(panel, pos, item, tbl)
end

local function mainMenuRenderer(panel, pos, item, tbl)
    if minecraftStyledUI() then
        local isLMBPressed = inputHelper.isMouseButtonTriggered(MouseButton.LEFT)
        blackBG.Color = primaryBlack
        blackBG.Scale = Vector(Isaac.GetScreenWidth() + 16, Isaac.GetScreenHeight() + 16)
        blackBG:Render(Vector.One * -8)

        local positionLogo = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 4)
        modLogo:Render(positionLogo)
        
        local mousePosition = Isaac.WorldToScreen(Input.GetMousePosition(true))
        for i, button in ipairs(item.buttons) do
            if button.str ~= "changelogs" then
                local buttonPosition = positionLogo + Vector(0, (Isaac.GetScreenHeight() / 8) + (i * 25))
                menuButton:SetFrame("Idle", 0)
                if mod.inventoryHelper.hoveringOver(mousePosition, buttonPosition - Vector(100, 10), 200, 20) then
                    menuButton:SetFrame("Idle", 1)
                    -- run submenu when triggered mouse button 
                    if isLMBPressed then
                        SFXManager():Play(Isaac.GetSoundIdByName("Minecraft_Click"), 1, 0, false, 1, 0)
                        selectedOption = button
                    end
                end
                menuButton:Render(buttonPosition)
                local buttonName = stringTable[button.str] or button.str
                mod.inventoryHelper.renderMinecraftText(buttonName, 
                    Vector(
                        buttonPosition.X - (minecraftFont:GetStringWidth(buttonName) / 2), 
                        buttonPosition.Y - minecraftFont:GetLineHeight() / 2
                    ), 
                    InventoryItemRarity.COMMON, true
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
                Vector(2, (Isaac.GetScreenHeight() - minecraftFont:GetLineHeight() * 2) - 2), 
                InventoryItemRarity.COMMON, true
            )
        end
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

        inputHelper.Update()
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
local function panelBackWrapper(panel, pos, tbl)
    if not minecraftStyledUI() then
        deadSeaScrollsMod.defaultPanelRenderBack(panel, pos, tbl)
    end
end
local function panelFrontWrapper(panel, pos, tbl)
    if not minecraftStyledUI() then
        deadSeaScrollsMod.defaultPanelRenderFront(panel, pos, tbl)
    end
end

local cainCraftingDirectory = {
    main = {
        title = string.lower(displayName),
        buttons = {
            { str = 'Resume Game', action = 'resume' },
            { str = 'Settings',    dest = 'settings' },
            { str = 'Credits',    dest = 'credits' },
            deadSeaScrollsMod.changelogsButton,
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
            {str = "Gameplay", fsize = 2, nosel = true},
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
                tooltip = {strset = {"Toggle when", "DSS should", "use the", "Tainted Cain", "Rework skin."}}
            },
            {
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
                tooltip = {strset = {"Changes the", "behavior of", "crafting a", "new active", "item."}}
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
                tooltip = {strset = {"Whether to", "use custom", "sprites for", "collectibles", "whenever", "possible."}}
            },
            {
                str = "Unlock Condition",
                choices = {"Per Save", "Every Run"},
                setting = 1,
                variable = "minecraftJumpscare",
                load = function ()
                    return getSaveWrapper().minecraftJumpscare or 1
                end,
                store = function (var)
                    getSaveWrapper().minecraftJumpscare = var
                end,
                tooltip = {strset = {"When the", "player should", "unlock certain", "conditions."}}
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
                tooltip = {strset = {"Whether to", "display", "pop-ups", "whenever", "they appear."}}
            },
            {str = "", fsize = 2, nosel = true},
            {str = "Experimental", fsize = 2, nosel = true},
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
                str = "Chaos Mode",
                choices = {"false", "true"},
                setting = 1,
                variable = "chaosMode",
                load = function ()
                    return getSaveWrapper().chaosMode or 1
                end,
                store = function (var)
                    getSaveWrapper().chaosMode = var
                end,
                tooltip = {strset = {"Shuffles all", "recipes", "similarly to", "the chaos", "item."}}
            }
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
            creditsWrapper("elitemastereric", "thinking about it", {""}),
            {str = "", nosel = true},
            {str = "special thanks", nosel = true},
            creditsWrapper("lynn sharcys", "detractor", {"www.", "gaywhiteboy", ".com"}),
            -- creditsWrapper("", "eden essence sprite", {""}, true),
            creditsWrapper("cat", "detractor", {"shoutout", "to lizzie", "for pulling", "through and", "finishing this", "mod. i'm so", "proud of her."}),
            creditsWrapper("snowystarfall", "particle", {"gatekeep", "", "graphics", "program", "", "girlboss"}),
            creditsWrapper("lily", "wife", {"i worked the", "hardestr for", "this mod."}),
            creditsWrapper("silentib", "\"balance\"", {"dirt rod", "challeng."}),
            creditsWrapper("jakevox", "observer (like the block)", {""}),
            creditsWrapper("madeline", "silly creature", {"40 dead", "309 injured", ":3 :3 :3"}),
            creditsWrapper("glasscanyon", "warframe", {"hi"}),
            creditsWrapper("benevolusgoat", "goat", {"hmmm", "no wait"}),
            creditsWrapper("wofsauge", "font kerning issue", {""}),
            creditsWrapper("you", "playing the mod", {"[          ]", "write your", "quote here!"})
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

DeadSeaScrollsMenu.AddMenu(displayName, {
    Run = deadSeaScrollsMod.runMenu,
    Open = function(tbl, openedFromNothing)
        deadSeaScrollsMod.openMenu(tbl, openedFromNothing)
    end,
    Close = deadSeaScrollsMod.closeMenu,
    Directory = cainCraftingDirectory,
    DirectoryKey = cainCraftingDirectoryKey
})

include("scripts.tcainrework.changelogs")