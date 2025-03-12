local modFolderName = "cain-crafting_3408837286"
local minecraftFont = {}

-- Thank you Wofsauge
function minecraftFont.getCurrentModPath() 
    if debug then -- luadebug launch parameter is set
        return string.sub(debug.getinfo(minecraftFont.getCurrentModPath).source, 2) .. "/../../../"
    end
    local _, err = pcall(require, "")
    local _, basePathStart = string.find(err, "no file '", 1)
    local _, modPathStart = string.find(err, "no file '", basePathStart)
    local modPathEnd, _ = string.find(err, ".lua'", modPathStart)
    local modPath = string.sub(err, modPathStart + 1, modPathEnd - 1)
    modPath = string.gsub(modPath, "\\", "/")
    modPath = string.gsub(modPath, "//", "/")
    modPath = string.gsub(modPath, ":/", ":\\")
    return modPath
end
minecraftFont.modPath = minecraftFont.getCurrentModPath()

function minecraftFont.loadFont(fontPath)
    local font = Font()
    font:Load(minecraftFont.modPath .. "resources/font/" .. fontPath ..".fnt")
    if not font:IsLoaded() then
        font:Load("../mods/" .. modFolderName .. "/resources/font/" .. fontPath .. ".fnt")
        if font:IsLoaded() then
            minecraftFont.modPath = "../mods/" .. modFolderName .. "/"
        end
    end
    -- print(minecraftFont.modPath)
    return font
end

minecraftFont.FontType = {
    DEFAULT = 1,
    ITALIC = 2,
    BOLD = 3,
    GALACTIC = 4
}

local fontType = minecraftFont.FontType
-- Create fonts (compatibility with non-repentogon)
local defaultFont, italicFont, boldFont, galacticFont = minecraftFont.loadFont("minecraftseven"), 
    minecraftFont.loadFont("minecraftsevenitalic"), minecraftFont.loadFont("minecraftsevenbold"), minecraftFont.loadFont("standardgalactic")

local fontList = {
    [fontType.DEFAULT] = defaultFont,
    [fontType.ITALIC] = italicFont,
    [fontType.BOLD] = boldFont,
    [fontType.GALACTIC] = galacticFont
}
local defaultFont = fontList[fontType.DEFAULT]

minecraftFont.fontScale = 3
function minecraftFont.GetStringWidth(minecraftFont, myString)
    local cleanedString = myString:gsub("§.", "")
    return defaultFont:GetStringWidth(cleanedString) / minecraftFont.fontScale
end

function minecraftFont.GetLineHeight(minecraftFont)
    return defaultFont:GetLineHeight() / minecraftFont.fontScale
end

local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
local fontSwitchCodes = {
    [""] = fontType.DEFAULT,
    ["l"] = fontType.BOLD, 
    ["o"] = fontType.ITALIC,
    ["r"] = fontType.DEFAULT,
    ["g"] = fontType.GALACTIC
}

local function drawTextWrapper(font, myString, posX, posY, scaleX, scaleY, color, boxWidth, center) 
    font:DrawStringScaledUTF8(myString, posX, posY, scaleX, scaleY, color, boxWidth, center)
end
function minecraftFont.DrawString(minecraftFont, String, PositionX, PositionY, RenderColor, BoxWidth, Center, Format)
    local textType = fontType.DEFAULT
    PositionX = PositionX - (1 / minecraftFont.fontScale)
    PositionX, PositionY = PositionX + Game().ScreenShakeOffset.X, PositionY + Game().ScreenShakeOffset.Y
    if Format then
        local stringsToFormat = {} 
        local lastIndex = 1
        for i in String:gmatch("()§") do
            table.insert(stringsToFormat, {
                String = String:sub(lastIndex, i - 1), 
                FormatCode = String:sub(lastIndex - 1, lastIndex - 1)
            })
            lastIndex = i + 3
        end
        table.insert(stringsToFormat, {
            String = String:sub(lastIndex, -1), 
            FormatCode = String:sub(lastIndex - 1, lastIndex - 1)
        })
        local xDisplacement = 0
        for i, substring in ipairs(stringsToFormat) do
            -- print(substring.String, substring.FormatCode)
            if fontSwitchCodes[substring.FormatCode] then
                textType = fontSwitchCodes[substring.FormatCode]
            end
            if substring.FormatCode == "k" then
                local obfuscatedString = ""
                for i = 1, string.len(substring.String) do
                    local stringPosition = math.random(1, #charset)
                    if minecraftFont:GetStringWidth(obfuscatedString) < minecraftFont:GetStringWidth(substring.String) then
                        if string.sub(substring.String, i, i) == " " then
                            obfuscatedString = obfuscatedString .. " "
                        else
                            obfuscatedString = obfuscatedString .. charset:sub(stringPosition, stringPosition)
                        end
                    end
                end
                substring.String = obfuscatedString
            end
            drawTextWrapper(
                fontList[textType],
                substring.String, PositionX + xDisplacement, PositionY, 
                1 / minecraftFont.fontScale, 1 / minecraftFont.fontScale, RenderColor, BoxWidth, Center
            )
            xDisplacement = xDisplacement + minecraftFont:GetStringWidth(substring.String)
        end
    else
        drawTextWrapper(
            fontList[textType],
            String, PositionX, PositionY, 
            1 / minecraftFont.fontScale, 1 / minecraftFont.fontScale, 
            RenderColor, BoxWidth, Center
        )
    end
end
return minecraftFont