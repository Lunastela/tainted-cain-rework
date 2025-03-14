local enchantingUI = {}

local enchantingWords = require("scripts.tcainrework.enchanting.enchanting_words")
local enchantingWordList = {}
for word in enchantingWords:gmatch("(.-)\n") do
    if word ~= "" then
        table.insert(enchantingWordList, word)
    end
end

-- Color Globals
--- @Type KColor
enchantingUI.MainColor = KColor(103 / 255, 93 / 255, 73 / 255, 1)
--- @Type KColor
enchantingUI.SelectedColor = InventoryItemRarityColors[InventoryItemRarity.ELEMENT_HOVER].Color
--- @Type KColor
enchantingUI.SubColor = KColor(51 / 255, 46 / 255, 37 / 255, 1)

local runSeed, INITIAL_SHIFT_INDEX = ((Isaac.IsInGame() and Game():GetSeeds():GetStartSeed()) or 1), 24
TCainRework:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
    runSeed = Game():GetSeeds():GetStartSeed()
end)
local enchantingRNG, rngStep = RNG(), 1
local minecraftFont = require("scripts.tcainrework.font")
function enchantingUI.getEnchantWords(additionalShift)
    local words = ""
    local wordLength, i, minWords = 0, 0, 2
    while (wordLength < 80) or (i < minWords) do
        enchantingRNG:SetSeed(runSeed, (((INITIAL_SHIFT_INDEX + i) + (additionalShift or 1) - 1)) % 80)
        local curSelectedWord = enchantingWordList[enchantingRNG:PhantomInt(#enchantingWordList - 1) + 1]
        wordLength = minecraftFont:GetStringWidth(words .. curSelectedWord)
        if (wordLength < 80) or (i < minWords) then
            words = words .. curSelectedWord .. " "
            i = i + 1
        end
    end
    return words, (i + 1)
end

local numberRanges = {
    {2, 10},
    {6, 21},
    {30, 30}
}

function enchantingUI.getEnchantment(costIndex)
    -- calculate enchantment cost
    local numberRange = numberRanges[costIndex]
    local enchantmentCost = enchantingRNG:PhantomInt(numberRange[2] - numberRange[1]) + numberRange[1]
    return enchantmentCost, "Unbreaking III"
end

function enchantingUI.canEnchant(item) 
    return (item ~= nil)
end

return enchantingUI