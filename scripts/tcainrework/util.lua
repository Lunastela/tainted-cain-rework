local Utility = {}
function Utility.getEnumName(enumTable, value)
    for key, val in pairs(enumTable) do
        if val == value then
            return key
        end
    end
end

function Utility.tableContains(table, value)
    if table ~= nil then
        for i = 1, #table do
            if (table[i] == value) then
                return true
            end
        end
    end
    return false
end

function Utility.getIndexInTable(table, value)
    if table ~= nil then
        for i = 1, #table do
            if (table[i] == value) then
                return i
            end
        end
    end
    return nil
end

function Utility.trimType(itemType)
    if string.find(itemType, "{") then
        return itemType:sub(1, string.find(itemType, "{") - 1)
    end
    return itemType
end

local collectibleStorage = require("scripts.tcainrework.stored.collectible_storage_cache")
function Utility.fastItemIDByName(name)
    if (not (collectibleStorage.constructed and collectibleStorage.nameToIDLookup[name])
    and not (string.find(name, "tcainrework") or string.find(name, "minecraft"))) then
        local temporaryDesignation = Isaac.GetItemIdByName(name)
        if temporaryDesignation ~= -1 then
            collectibleStorage.nameToIDLookup[name] = temporaryDesignation
            collectibleStorage.IDToNameLookup[temporaryDesignation] = name
        end
    end
    return collectibleStorage.nameToIDLookup[name] or -1
end

local isaacItemConfig
local collectibleCache = {}
function Utility.getCollectibleConfig(collectibleID)
    if not collectibleCache[collectibleID] then
        if not isaacItemConfig then
            isaacItemConfig = Isaac.GetItemConfig()
        end
        collectibleCache[collectibleID] = isaacItemConfig:GetCollectible(collectibleID)
    end
    return collectibleCache[collectibleID]
end

local cardCache = {}
function Utility.getCardConfig(collectibleID)
    if not cardCache[collectibleID] then
        if not isaacItemConfig then
            isaacItemConfig = Isaac.GetItemConfig()
        end
        cardCache[collectibleID] = isaacItemConfig:GetCard(collectibleID)
    end
    return cardCache[collectibleID]
end

function Utility.generateCollectibleData(collectibleType)
    -- try to obtain sprite if it exists
    local collectibleID = Utility.fastItemIDByName(collectibleType)
    if collectibleID == -1 then
        collectibleID = collectibleType 
    end
    local itemConfig = Utility.getCollectibleConfig(collectibleID)
    if itemConfig then
        local initialCharges = ((itemConfig.Type == ItemType.ITEM_ACTIVE) and itemConfig.InitCharge) or nil
        if initialCharges == -1 then
            initialCharges = itemConfig.MaxCharges
        end
        return {
            [InventoryItemComponentData.COLLECTIBLE_ITEM] = collectibleID,
            [InventoryItemComponentData.COLLECTIBLE_CHARGES] = initialCharges or nil
        }
    end
    return nil
end

Utility.chestVariants = {
    [PickupVariant.PICKUP_CHEST] = true,
    [PickupVariant.PICKUP_SPIKEDCHEST] = true,
    [PickupVariant.PICKUP_ETERNALCHEST] = true,
    [PickupVariant.PICKUP_MIMICCHEST] = true,
    [PickupVariant.PICKUP_OLDCHEST] = true,
    [PickupVariant.PICKUP_WOODENCHEST] = true,
    [PickupVariant.PICKUP_HAUNTEDCHEST] = true,
    [PickupVariant.PICKUP_LOCKEDCHEST] = true,
    [PickupVariant.PICKUP_REDCHEST] = true,
    [PickupVariant.PICKUP_MOMSCHEST] = true,
}

function Utility.getPillColor(rawPillColor)
    if rawPillColor >= PillColor.PILL_GIANT_FLAG then
        return (rawPillColor - PillColor.PILL_GIANT_FLAG), true
    end
    return rawPillColor, false
end

-- https://github.com/gdyr/LuaSHA1
function Utility.sha1(message)
    -- magic numbers
    local h0 = 0x67452301;
    local h1 = 0xEFCDAB89;
    local h2 = 0x98BADCFE;
    local h3 = 0x10325476;
    local h4 = 0xC3D2E1F0;

    -- padding, etc
    local bits = #message * 8;
    message = message .. '\x80';
    local paddingAmount = (120 - (#message % 64)) % 64;
    message = message .. string.rep('\0', paddingAmount);
    message = message .. string.pack('>I8', bits);

    -- rotate function
    local function rol(value, bits)
        return (((value) << (bits)) | ((value) >> (32 - (bits))));
    end;

    -- process each chunk
    for i = 1, #message, 64 do
        local chunk = string.sub(message, i, i + 63);
        local parts = {};

        -- split chunk into 16 parts
        for i = 0, 15 do
            parts[i] = string.unpack('>I4', string.sub(chunk, 1 + i * 4, 4 + i * 4));
            --print(parts[i]);
        end;

        -- extend into 80 parts
        for i = 16, 79 do
            parts[i] = rol(parts[i - 3] ~ parts[i - 8] ~ parts[i - 14] ~ parts[i - 16], 1) & 0xFFFFFFFF;
        end;

        -- initialise hash values
        local a, b, c, d, e = h0, h1, h2, h3, h4;
        local f, k;

        -- main loop
        for i = 0, 79 do
            if 0 <= i and i <= 19 then
                f = (b & c) | ((~b) & d)
                k = 0x5A827999
            elseif 20 <= i and i <= 39 then
                f = b ~ c ~ d
                k = 0x6ED9EBA1
            elseif 40 <= i and i <= 59 then
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDC
            elseif 60 <= i and i <= 79 then
                f = b ~ c ~ d
                k = 0xCA62C1D6
            end

            local temp = (rol(a, 5) + f + e + k + parts[i]) & 0xFFFFFFFF
            e = d;
            d = c;
            c = rol(b, 30);
            b = a;
            a = temp;
        end;

        h0 = (h0 + a) & 0xFFFFFFFF;
        h1 = (h1 + b) & 0xFFFFFFFF;
        h2 = (h2 + c) & 0xFFFFFFFF;
        h3 = (h3 + d) & 0xFFFFFFFF;
        h4 = (h4 + e) & 0xFFFFFFFF;
    end;

    return string.format('%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4);
end

function Utility.getLocalizedString(category, key)
    local localizedString = Isaac.GetString(category, key)
    if localizedString ~= "StringTable::InvalidKey" then
        return localizedString
    end
    return key
end

--[[
    Avert your gaze
]]

function Utility.renderNineSlice(sprite, position, boxScale)
    position.X = position.X + boxScale.X / 2
    -- top left
    sprite.Scale = Vector.One
    sprite:Play("1")
    sprite:Render(position - boxScale / 2)

    -- top center
    local verticalBoxScale = Vector(boxScale.X / 80, 1)
    sprite.Scale = verticalBoxScale
    sprite:Play("2")
    sprite:Render(position - Vector(0, boxScale.Y) / 2)

    -- top right
    sprite.Scale = Vector.One
    sprite:Play("3")
    sprite:Render(position - Vector(-boxScale.X, boxScale.Y) / 2)

    -- left
    local horizontalBoxScale = Vector(1, boxScale.Y / 80)
    sprite.Scale = horizontalBoxScale
    sprite:Play("4")
    sprite:Render(position - Vector(boxScale.X, 0) / 2)

    -- center
    sprite.Scale = boxScale / 80
    sprite:Play("5")
    sprite:Render(position)

    -- right
    sprite.Scale = horizontalBoxScale
    sprite:Play("6")
    sprite:Render(position + Vector(boxScale.X, 0) / 2)

    -- bottom left
    sprite.Scale = Vector.One
    sprite:Play("7")
    sprite:Render(position - Vector(boxScale.X, -boxScale.Y) / 2)

    -- bottom center
    sprite.Scale = verticalBoxScale
    sprite:Play("8")
    sprite:Render(position + Vector(0, boxScale.Y) / 2)

    -- bottom right
    sprite.Scale = Vector.One
    sprite:Play("9")
    sprite:Render(position + boxScale / 2)
    position.X = position.X - boxScale.X / 2
end

-- https://github.com/Team-Compliance/libraryofisaac/blob/main/Input/KeyboardToString.lua
Utility.HeldKeysList = {}
Utility.KeyboardStringList = {
    [Keyboard.KEY_SPACE] = { " ", " " },
    [Keyboard.KEY_APOSTROPHE] = { "'", '"' },
    [Keyboard.KEY_COMMA] = { ",", "<" },
    [Keyboard.KEY_MINUS] = { "-", "_" },
    [Keyboard.KEY_PERIOD] = { ".", ">" },
    [Keyboard.KEY_SLASH] = { "/", "?" },

    [Keyboard.KEY_0] = { "0", ")" },
    [Keyboard.KEY_1] = { "1", "!" },
    [Keyboard.KEY_2] = { "2", "@" },
    [Keyboard.KEY_3] = { "3", "#" },
    [Keyboard.KEY_4] = { "4", "$" },
    [Keyboard.KEY_5] = { "5", "%" },
    [Keyboard.KEY_6] = { "6", "^" },
    [Keyboard.KEY_7] = { "7", "&" },
    [Keyboard.KEY_8] = { "8", "*" },
    [Keyboard.KEY_9] = { "9", "(" },

    [Keyboard.KEY_SEMICOLON] = { ";", ":" },
    [Keyboard.KEY_EQUAL] = { "=", "+" },

    [Keyboard.KEY_A] = { "a", "A" },
    [Keyboard.KEY_B] = { "b", "B" },
    [Keyboard.KEY_C] = { "c", "C" },
    [Keyboard.KEY_D] = { "d", "D" },
    [Keyboard.KEY_E] = { "e", "E" },
    [Keyboard.KEY_F] = { "f", "F" },
    [Keyboard.KEY_G] = { "g", "G" },
    [Keyboard.KEY_H] = { "h", "H" },
    [Keyboard.KEY_I] = { "i", "I" },
    [Keyboard.KEY_J] = { "j", "J" },
    [Keyboard.KEY_K] = { "k", "K" },
    [Keyboard.KEY_L] = { "l", "L" },
    [Keyboard.KEY_M] = { "m", "M" },
    [Keyboard.KEY_N] = { "n", "N" },
    [Keyboard.KEY_O] = { "o", "O" },
    [Keyboard.KEY_P] = { "p", "P" },
    [Keyboard.KEY_Q] = { "q", "Q" },
    [Keyboard.KEY_R] = { "r", "R" },
    [Keyboard.KEY_S] = { "s", "S" },
    [Keyboard.KEY_T] = { "t", "T" },
    [Keyboard.KEY_U] = { "u", "U" },
    [Keyboard.KEY_V] = { "v", "V" },
    [Keyboard.KEY_W] = { "w", "W" },
    [Keyboard.KEY_X] = { "x", "X" },
    [Keyboard.KEY_Y] = { "y", "Y" },
    [Keyboard.KEY_Z] = { "z", "Z" },

    [Keyboard.KEY_KP_0] = { "0", "0" },
    [Keyboard.KEY_KP_1] = { "1", "1" },
    [Keyboard.KEY_KP_2] = { "2", "2" },
    [Keyboard.KEY_KP_3] = { "3", "3" },
    [Keyboard.KEY_KP_4] = { "4", "4" },
    [Keyboard.KEY_KP_5] = { "5", "5" },
    [Keyboard.KEY_KP_6] = { "6", "6" },
    [Keyboard.KEY_KP_7] = { "7", "7" },
    [Keyboard.KEY_KP_8] = { "8", "8" },
    [Keyboard.KEY_KP_9] = { "9", "9" },

    [Keyboard.KEY_KP_DECIMAL] = { ".", "." },
    [Keyboard.KEY_KP_DIVIDE] = { "/", "/" },
    [Keyboard.KEY_KP_MULTIPLY] = { "*", "*" },
    [Keyboard.KEY_KP_SUBTRACT] = { "-", "-" },
    [Keyboard.KEY_KP_ADD] = { "+", "+" },

    [Keyboard.KEY_BACKSLASH] = { "\\", "|" },
    [Keyboard.KEY_GRAVE_ACCENT] = { "`", "~" },
    [Keyboard.KEY_BACKSPACE] = {},
    [Keyboard.KEY_DELETE] = {}
}

return Utility
