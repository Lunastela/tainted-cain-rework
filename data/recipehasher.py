import shutil
import os
import json
import hashlib
import pathlib

# Hashes JSON Recipes into a Lua table.
# Provided JSON files are in the Minecraft format and support shaped and shapeless crafting recipes.

# Prerequisites: "recipes/" folder

localPath = str(pathlib.Path(__file__).parent.resolve()) 
for entry in os.listdir(localPath):
    subFolderName = "\\{}".format(entry)
    if os.path.isdir(localPath + subFolderName):
        recipePath = localPath + subFolderName + "\\recipes"
        recipeDictionary = {}
        for file in os.listdir(recipePath):
            if file.endswith(".json"):
                with open(recipePath + "\\" + file, 'r') as jsonFile:
                    data = json.load(jsonFile)

                    # Shaped Recipes
                    shapeHash = ""
                    recipeCondition = []
                    Width, Height = (None, None)
                    if data['type'] == "minecraft:crafting_shaped":
                        # Gather a list of keys and their replacements
                        keyReplacements = {" " : ""}
                        for mapKey in data['key']:
                            keyReplacements[mapKey] = data['key'].get(mapKey)

                        # Gather pattern and translate it to Recipe Hash
                        totalRecipeString = ""
                        uniqueElements = {}
                        replacementIndex = 1
                        Height = 0
                        for i in range(len(data['pattern'])):
                            patternLine = data['pattern'][i]
                            Width = 0
                            for char in patternLine:
                                recipeCondition.append(keyReplacements[char])
                                if char != " ":
                                    if not uniqueElements.get(char):
                                        uniqueElements[char] = replacementIndex
                                        replacementIndex += 1
                                    totalRecipeString += str(uniqueElements[char])
                                else:
                                    totalRecipeString += " "
                                Width += 1
                            totalRecipeString += "\n"
                            Height += 1
                        totalRecipeString = totalRecipeString[:-1]

                        # Create Recipe Shape Hash
                        shapeHash = hashlib.sha1(totalRecipeString.encode()).hexdigest()
                    elif data['type'] == "minecraft:crafting_shapeless":
                        recipeCondition = []
                        uniqueElements = {}
                        uniqueElementCount = 1
                        for i in range(len(data['ingredients'])):
                            typeName = data['ingredients'][i]
                            recipeCondition.append(typeName)
                            if not uniqueElements.get(typeName):
                                uniqueElementCount += 1
                                uniqueElements[typeName] = True
                        totalRecipeString = "count_" + str(len(recipeCondition)) + "_unique_" + str(uniqueElementCount)
                        shapeHash = "shapeless_" + hashlib.sha1(totalRecipeString.encode()).hexdigest()

                    # Get Recipe Results
                    resultingOutput = ""
                    if data['result'].get('item'):
                        resultingOutput = data['result'].get('item')
                    if data['result'].get('id'):
                        resultingOutput = data['result'].get('id')

                    # Set Recipe Count
                    resultingAmount = 1
                    if data['result'].get('count'):
                        resultingAmount = data['result'].get('count')

                    collectibleType = None
                    if data['result'].get('collectible'):
                        collectibleType = data['result'].get('collectible')

                    # Obtain Category
                    recipeCategory = "misc"
                    if data['category']:
                        recipeCategory = data['category']

                    # Show Notification
                    displayRecipe = True
                    if data.get('show_notification') != None:
                        displayRecipe = data['show_notification']

                    # Include Information about Recipes
                    if not recipeDictionary.get(shapeHash):
                        recipeDictionary[shapeHash] = []
                    recipeDictionary[shapeHash].append({
                        'name' : (entry + ":" + file[:-5]),
                        'category' : recipeCategory,
                        'condition' : recipeCondition,
                        'result': [resultingOutput, resultingAmount],
                        'collectible': collectibleType,
                        'display' : displayRecipe,
                        'width' : Width,
                        'height' : Height
                    })

        # Create Lua File
        recipeExport = open(localPath + subFolderName + "\\recipe_hashes.lua", "w")
        recipeExport.write("return {\n")

        space = "    "
        for recipeHash in recipeDictionary:
            recipeExport.write(space + "[\"{}\"] = {{\n".format(recipeHash))
            for recipeTable in recipeDictionary[recipeHash]:
                recipeExport.write((space * 2) + "{\n")

                # Category Recipe
                recipeExport.write(space * 3 + "RecipeName = \"{}\",\n".format(recipeTable['name']))
                recipeExport.write(space * 3 + "Category = \"{}\",\n".format(recipeTable['category']))
                if recipeTable.get("width") and recipeTable.get("height"):
                    recipeExport.write(space * 3 + "RecipeSize = Vector({}, {}),\n".format(recipeTable['width'], recipeTable['height']))
                recipeExport.write(space * 3 + "ConditionTable = {")

                for recipeCondition in recipeTable['condition']:
                    if recipeCondition == "":
                        recipeExport.write("nil, ")
                    else:
                        recipeExport.write("\"{}\", ".format(recipeCondition))

                # Recipe Result Table
                recipeExport.write("},\n" + space * 3 + "Results = {\n" 
                    + space * 4 + "Type = \"{}\",\n{}Count = {}".format(
                        recipeTable['result'][0], space * 4, 
                        recipeTable['result'][1]) 
                )
                if recipeTable['collectible'] != None:
                    if isinstance(recipeTable['collectible'], int) or recipeTable['collectible'].isnumeric():
                        recipeExport.write(",\n" + space * 4 + "Collectible = {}".format(recipeTable['collectible']))
                    else:
                        recipeExport.write(",\n" + space * 4 + "Collectible = Isaac.GetItemIdByName(\"{}\")".format(recipeTable['collectible']))
                recipeExport.write("\n" + space * 3 + "},\n" + space * 3 + "DisplayRecipe = " + "{}\n".format(recipeTable['display']).lower() + space * 2 + "},\n")
            recipeExport.write(space + "},\n")

        recipeExport.write("}")
        recipeExport.close()