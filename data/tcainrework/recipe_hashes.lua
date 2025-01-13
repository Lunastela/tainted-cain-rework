return {
    ["shapeless_a7047d016cb3cf4dae1b2fc24d4467568770d0ae"] = {
        {
            RecipeName = "tcainrework:a_dollar",
            Category = "collectible",
            ConditionTable = {"A Quarter", "A Quarter", "A Quarter", "A Quarter", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("A Dollar")
            },
            DisplayRecipe = true
        },
    },
    ["shapeless_3ddb378a1270b5e20a80db44ef210218da75b510"] = {
        {
            RecipeName = "tcainrework:a_quarter",
            Category = "collectible",
            ConditionTable = {"tcainrework:nickel", "tcainrework:nickel", "tcainrework:nickel", "tcainrework:nickel", "tcainrework:nickel", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("A Quarter")
            },
            DisplayRecipe = true
        },
        {
            RecipeName = "tcainrework:nickel_from_penny",
            Category = "misc",
            ConditionTable = {"tcainrework:penny", "tcainrework:penny", "tcainrework:penny", "tcainrework:penny", "tcainrework:penny", },
            Results = {
                Type = "tcainrework:nickel",
                Count = 1
            },
            DisplayRecipe = true
        },
    },
    ["shapeless_21eddafa2b1af2b61ab1124e3b0b6fb69a631902"] = {
        {
            RecipeName = "tcainrework:a_quarter_alt",
            Category = "collectible",
            ConditionTable = {"tcainrework:dime", "tcainrework:dime", "tcainrework:nickel", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("A Quarter")
            },
            DisplayRecipe = true
        },
    },
    ["shapeless_edd9d21067eca47760eb0a0343c11a31963a5e6d"] = {
        {
            RecipeName = "tcainrework:dime_from_nickel",
            Category = "misc",
            ConditionTable = {"tcainrework:nickel", "tcainrework:nickel", },
            Results = {
                Type = "tcainrework:dime",
                Count = 1
            },
            DisplayRecipe = true
        },
    },
    ["6ae58c6b51e805637328b6bc94524fade48db365"] = {
        {
            RecipeName = "tcainrework:iron_bar",
            Category = "collectible",
            RecipeSize = Vector(3, 2),
            ConditionTable = {"tcainrework:key", "tcainrework:key", "tcainrework:key", "tcainrework:key", "tcainrework:key", "tcainrework:key", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("Iron Bar")
            },
            DisplayRecipe = true
        },
    },
    ["shapeless_6393b3f1bfcebf97d70ff589a5a79b04e77ed0c3"] = {
        {
            RecipeName = "tcainrework:nickel_from_dime",
            Category = "misc",
            ConditionTable = {"tcainrework:dime", },
            Results = {
                Type = "tcainrework:nickel",
                Count = 2
            },
            DisplayRecipe = true
        },
        {
            RecipeName = "tcainrework:penny_from_nickel",
            Category = "misc",
            ConditionTable = {"tcainrework:nickel", },
            Results = {
                Type = "tcainrework:penny",
                Count = 5
            },
            DisplayRecipe = true
        },
    },
    ["91ca69867146ca440f84e1a85fcb250698a8f01f"] = {
        {
            RecipeName = "tcainrework:notched_axe",
            Category = "collectible",
            RecipeSize = Vector(3, 3),
            ConditionTable = {"Iron Bar", "Iron Bar", "Iron Bar", nil, "minecraft:stick", nil, nil, "minecraft:stick", nil, },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("Notched Axe")
            },
            DisplayRecipe = true
        },
    },
    ["e453b4b3738fc4f5ccfa2824ab9bd148e64776fb"] = {
        {
            RecipeName = "tcainrework:poop_block",
            Category = "building",
            RecipeSize = Vector(3, 3),
            ConditionTable = {"tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", },
            Results = {
                Type = "tcainrework:poop_block",
                Count = 1
            },
            DisplayRecipe = true
        },
    },
    ["shapeless_a38e4df77d98e5802b4744d84d2a819835f3cf60"] = {
        {
            RecipeName = "tcainrework:red_key",
            Category = "collectible",
            ConditionTable = {"tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", "tcainrework:cracked_key", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("Red Key")
            },
            DisplayRecipe = true
        },
    },
    ["1014e06cd44ff078faba6f23c7c4467da5969aae"] = {
        {
            RecipeName = "tcainrework:repentogon",
            Category = "misc",
            RecipeSize = Vector(3, 3),
            ConditionTable = {"minecraft:fire", "minecraft:fire", nil, "minecraft:fire", "minecraft:fire", nil, "minecraft:fire", nil, "minecraft:fire", },
            Results = {
                Type = "tcainrework:repentogon",
                Count = 1
            },
            DisplayRecipe = true
        },
    },
    ["860bfb3bbfa6c2aa4a3a0c99b5ef584e98954612"] = {
        {
            RecipeName = "tcainrework:sacred_heart_alt",
            Category = "collectible",
            RecipeSize = Vector(1, 2),
            ConditionTable = {"minecraft:fire", "tcainrework:heart", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("Sacred Heart")
            },
            DisplayRecipe = false
        },
    },
    ["0fec2199af1136d2d78fadd12574fbb367f9e3d2"] = {
        {
            RecipeName = "tcainrework:sulfur",
            Category = "collectible",
            RecipeSize = Vector(3, 3),
            ConditionTable = {nil, "tcainrework:black_heart", nil, "tcainrework:black_heart", "The Mark", "tcainrework:black_heart", nil, "tcainrework:black_heart", nil, },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("Sulfur")
            },
            DisplayRecipe = true
        },
    },
    ["59d5d42bb856bace42b61fa7988ec5bd34b309ea"] = {
        {
            RecipeName = "tcainrework:the_mark",
            Category = "collectible",
            RecipeSize = Vector(3, 3),
            ConditionTable = {nil, "tcainrework:black_heart", nil, "tcainrework:black_heart", "tcainrework:black_heart", "tcainrework:black_heart", "tcainrework:black_heart", nil, "tcainrework:black_heart", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("The Mark")
            },
            DisplayRecipe = true
        },
    },
    ["635ea86801634e7a8b87c210f6d69c109c4e4cf5"] = {
        {
            RecipeName = "tcainrework:the_poop",
            Category = "collectible",
            RecipeSize = Vector(3, 3),
            ConditionTable = {"tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop_block", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", "tcainrework:poop", },
            Results = {
                Type = "tcainrework:collectible",
                Count = 1,
                Collectible = Isaac.GetItemIdByName("The Poop")
            },
            DisplayRecipe = true
        },
    },
}