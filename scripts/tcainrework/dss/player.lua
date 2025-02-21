local mod = TCainRework
local playerRenderer = Sprite()
playerRenderer:Load("gfx/minecraft/skins/player.anm2", true)
playerRenderer:Play("Idle", true)
playerRenderer:SetCustomShader("shaders/skin_renderer")
playerRenderer.Scale = Vector.One * 2

local elapsedTime = 0
local playerTable = {
    {Name = "lunastela", Skin = "me"},
    {Name = "jjohnsnaill", Skin = "john"},
    {Name = "Mr_Headcrab", Skin = "headcrab"},
    {Name = "EliteMasterEric", Skin = "eric"},
    {Name = "pread1129", Skin = "pread"},
    {Name = "ENVtuber", Skin = "lynn"}
}

-- I dont wanna call inventoryhelper for one function
local function hoveringOver(mousePosition, buttonPosition, buttonWidth, buttonHeight)
    if mousePosition.X >= buttonPosition.X
    and mousePosition.Y >= buttonPosition.Y
    and mousePosition.X < buttonPosition.X + buttonWidth
    and mousePosition.Y < buttonPosition.Y + buttonHeight then
        return true
    end
    return false
end

local function signOf(signNum)
    if not signNum then
        return 0
    end
    return (signNum == 0 and 0 or (math.abs(signNum) / signNum))
end

local function clamp(value, clampBy)
    return math.max(math.min(value, clampBy), -clampBy)
end

local lastMousePosition = Vector.Zero
local inputHelper = include("scripts.tcainrework.mouse_inputs")
local targetPlayer = nil
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    local mousePosition = Isaac.WorldToScreen(Input.GetMousePosition(true))
    elapsedTime = elapsedTime + .05
    local lmbTrigger = inputHelper.isMouseButtonTriggered(MouseButton.LEFT)
    for i, player in ipairs(playerTable) do
        local rotationX = 180 + (player.Rotation or 0)
        local position = Vector(Isaac.GetScreenWidth() + (i - (math.ceil(#playerTable / 2) + 0.5)) * 96, Isaac.GetScreenHeight()) / 2

        local width, height = 24, 48
        -- if ((not targetPlayer and hoveringOver(mousePosition, position - (Vector(width, height) * playerRenderer.Scale) / 2, 
        --     width * playerRenderer.Scale.X, height * playerRenderer.Scale.Y)) or (targetPlayer == player)) then
        --     if inputHelper.isMouseButtonHeld(MouseButton.LEFT) then
        --         player.RotationAcceleration = (player.RotationAcceleration or 0) + clamp((mousePosition - lastMousePosition).X / 2, 15)
        --         targetPlayer = player
        --     else
        --         targetPlayer = nil
        --     end
        -- end
        if inputHelper.isMouseButtonHeld(MouseButton.LEFT) then
            if ((not targetPlayer) and hoveringOver(
                mousePosition, position - (Vector(width, height) * playerRenderer.Scale) / 2, 
                width * playerRenderer.Scale.X, height * playerRenderer.Scale.Y
            )) or (targetPlayer == player) then
                if lmbTrigger then
                    targetPlayer = player
                end
                player.RotationAcceleration = (player.RotationAcceleration or 0) + clamp((mousePosition - lastMousePosition).X / 2, 15)
            end
        else
            targetPlayer = nil
        end
        player.RotationAcceleration = clamp((player.RotationAcceleration or 0) - signOf(player.RotationAcceleration) / 2., 30)
        if (math.abs(player.RotationAcceleration) <= 0.5) then
            player.RotationAcceleration = 0
        end
        player.Rotation = (player.Rotation or 0) + player.RotationAcceleration

        playerRenderer:ReplaceSpritesheet(0, "gfx/minecraft/skins/" .. player.Skin .. ".png")
        playerRenderer:LoadGraphics()

        playerRenderer.Color:SetColorize((rotationX / 360), elapsedTime, 0.45, 0.)
        playerRenderer:Render(position)
    end
    lastMousePosition = mousePosition
    inputHelper.Update()
end)