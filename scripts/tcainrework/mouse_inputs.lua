local mouseInputHelper = {}

local mouseHeld = {}
local mouseReleased = {}
function mouseInputHelper.isMouseButtonTriggered(mouseButton)
    local mouseButtonPress = Input.IsMouseBtnPressed(mouseButton)
    if mouseButtonPress then
        local lastMouseHeld = mouseHeld[mouseButton] or false
        mouseHeld[mouseButton] = true
        return not lastMouseHeld
    end
    return false
end

function mouseInputHelper.isMouseButtonHeld(mouseButton)
    -- I'm so smart
    local mouseTriggered = mouseInputHelper.isMouseButtonTriggered(mouseButton)
    return mouseTriggered or mouseHeld[mouseButton]
end

function mouseInputHelper.isMouseButtonReleased(mouseButton)
    local mouseButtonReleased = mouseReleased[mouseButton]
    if mouseButtonReleased then
        mouseReleased[mouseButton] = nil
    end
    return mouseButtonReleased
end

-- i KNOW this isnt a mouse thing
function mouseInputHelper.isShiftHeld()
    return Input.IsButtonPressed(Keyboard.KEY_LEFT_SHIFT, 0)
        or Input.IsButtonPressed(Keyboard.KEY_RIGHT_SHIFT, 0)
end

function mouseInputHelper.Update()
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

return mouseInputHelper
