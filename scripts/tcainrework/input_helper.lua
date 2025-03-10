local InputHelper = {}

local mouseHeld = {}
local mouseReleased = {}

Controller = {
    CROSS = 4,
    CIRCLE = 5,
    SQUARE = 6,
    TRIANGLE = 7,
    LEFT_BUMPER = 8,
    LEFT_TRIGGER = 9,
    LSTICK_PRESS = 10,
    RIGHT_BUMPER = 11,
    RIGHT_TRIGGER = 12,
    RSTICK_PRESS = 13
}

local mouseMap = {
    [Mouse.MOUSE_BUTTON_1] = Controller.CROSS,
    [Mouse.MOUSE_BUTTON_2] = Controller.SQUARE
}
function InputHelper.isMouseButtonTriggered(mouseButton)
    local mouseButtonPress = (mouseMap[mouseButton] and Input.IsMouseBtnPressed(mouseButton))
    local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    if player and (player.ControllerIndex > 0) then
        mouseButtonPress = Input.IsButtonTriggered(mouseMap[mouseButton] or mouseButton, player.ControllerIndex)
    end
    if mouseButtonPress then
        local lastMouseHeld = mouseHeld[mouseButton] or false
        mouseHeld[mouseButton] = true
        return not lastMouseHeld
    end
    return false
end

function InputHelper.resetMousePosition()
    return (Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) / 2)
end

local controllerMouseVector = nil
local outerPadding = 32
local mouseUpdated = false
function InputHelper.getMousePosition(dontUpdate)
    local player = PlayerManager.FirstCollectibleOwner(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    if player and (player.ControllerIndex > 0) then
        local mouseDirection = (Vector(
            Input.GetActionValue(ButtonAction.ACTION_RIGHT, player.ControllerIndex) - Input.GetActionValue(ButtonAction.ACTION_LEFT, player.ControllerIndex),
            Input.GetActionValue(ButtonAction.ACTION_DOWN, player.ControllerIndex) - Input.GetActionValue(ButtonAction.ACTION_UP, player.ControllerIndex)
        ):Normalized() * 5)
        if not controllerMouseVector then
            controllerMouseVector = InputHelper.resetMousePosition()
        end
        if (not (mouseUpdated or dontUpdate)) then
            controllerMouseVector = controllerMouseVector + mouseDirection
            controllerMouseVector.X = math.min(math.max(0, controllerMouseVector.X), Isaac.GetScreenWidth())
            controllerMouseVector.Y = math.min(math.max(0, controllerMouseVector.Y), Isaac.GetScreenHeight())
            mouseUpdated = true
        end
        return controllerMouseVector, mouseDirection
    end
    return Isaac.WorldToScreen(Input.GetMousePosition(true))
end

function InputHelper.hoveringOver(buttonPosition, buttonWidth, buttonHeight, disableSnapping)
    local mousePosition, mouseVector = InputHelper.getMousePosition(true)
    if mousePosition.X >= buttonPosition.X
    and mousePosition.Y >= buttonPosition.Y
    and mousePosition.X < buttonPosition.X + buttonWidth
    and mousePosition.Y < buttonPosition.Y + buttonHeight then
        if not disableSnapping and (mouseVector and ((mouseVector:LengthSquared() * 100) < 0.5)) then
            InputHelper.setMousePosition(buttonPosition + ((Vector(buttonWidth, buttonHeight) / 2) * Vector.One))
        end
        return true
    end
    return false
end

function InputHelper.setMousePosition(newPosition)
    controllerMouseVector = newPosition
end

function InputHelper.isMouseButtonHeld(mouseButton)
    -- I'm so smart
    local mouseTriggered = InputHelper.isMouseButtonTriggered(mouseButton)
    return mouseTriggered or mouseHeld[mouseButton]
end

function InputHelper.isMouseButtonReleased(mouseButton)
    local mouseButtonReleased = mouseReleased[mouseButton]
    if mouseButtonReleased then
        mouseReleased[mouseButton] = nil
    end
    return mouseButtonReleased
end

-- Behavior for Minecraft Sticky Buttons (chat / Q in crafting menu)
local heldKeysList = {}
function InputHelper.buttonHeldSticky(key, controllerIndex)
    if Input.IsButtonTriggered(key, controllerIndex) then
        return true
    elseif Input.IsButtonPressed(key, controllerIndex) then
        heldKeysList[key] = (heldKeysList[key] or 0) + 1
        if heldKeysList[key] > 24 
        and heldKeysList[key] % 3 == 0 then
            return true
        end
    else
        heldKeysList[key] = nil
    end
    return false
end

function InputHelper.isShiftHeld()
    return Input.IsButtonPressed(Keyboard.KEY_LEFT_SHIFT, 0)
        or Input.IsButtonPressed(Keyboard.KEY_RIGHT_SHIFT, 0)
end

function InputHelper.isControlHeld()
    return Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0)
        or Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0)
end

local mouseSprite = Sprite()
mouseSprite:Load("gfx/ui/legacy_console_cursor.anm2", true)
mouseSprite:Play("Idle")
mouseSprite.Scale = Vector.One / 2

local mouseTimer, mouseAlpha = 180, 1
local lastMousePosition = Vector.Zero
function InputHelper.Update(renderMouse, forceMouse)
    -- Clear held mouse inputs and register released ones
    for mouseButton, isHeld in pairs(mouseHeld) do
        if isHeld then
            local newMouseInput = Input.IsMouseBtnPressed(mouseButton)
            if newMouseInput ~= mouseHeld[mouseButton] then
                mouseReleased[mouseButton] = true
            end
            mouseHeld[mouseButton] = newMouseInput
        end
    end

    mouseUpdated = false
    if renderMouse or ((not renderMouse) and (Options.Fullscreen and not Options.MouseControl)) then
        local mousePosition, _ = InputHelper.getMousePosition(true)
        if (not forceMouse) and ((lastMousePosition - mousePosition):Length() <= 0) then
            mouseTimer = math.max(mouseTimer - 1, 0)
            if mouseTimer <= 0 then
                mouseAlpha = math.max(mouseAlpha - 0.05, 0)
            end
        else
            mouseTimer = 180
            mouseAlpha = math.min(mouseAlpha + 0.05, 1)
        end
        mouseSprite.Color = Color(1, 1, 1, mouseAlpha)
        mouseSprite:Render(mousePosition)
        lastMousePosition = Vector(mousePosition.X, mousePosition.Y)
    end
end

return InputHelper
