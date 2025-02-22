local InputHelper = {}

local mouseHeld = {}
local mouseReleased = {}
function InputHelper.isMouseButtonTriggered(mouseButton)
    local mouseButtonPress = Input.IsMouseBtnPressed(mouseButton)
    if mouseButtonPress then
        local lastMouseHeld = mouseHeld[mouseButton] or false
        mouseHeld[mouseButton] = true
        return not lastMouseHeld
    end
    return false
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
function InputHelper.buttonHeldSticky(key)
    if Input.IsButtonTriggered(key, 0) then
        return true
    elseif Input.IsButtonPressed(key, 0) then
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

function InputHelper.Update()
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
end

return InputHelper
